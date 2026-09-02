//
//  LocalInstallServer.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Liquid Signer Local OTA Installation Server (Network.framework NWListener)
//

import Foundation
import Network
#if canImport(UIKit)
import UIKit
#endif

@Observable
public final class LocalInstallServer: @unchecked Sendable {
    public static let shared = LocalInstallServer()
    
    public var isRunning: Bool = false
    public var lastError: String? = nil
    
    private var listener: NWListener?
    private var activeIpaUrl: URL?
    private var activeBundleId: String = "com.liquidsigner.app"
    private var activeAppName: String = "Liquid App"
    private let port: NWEndpoint.Port = 8080
    
    public init() {}
    
    // MARK: - Start Server
    
    public func start() {
        guard !isRunning else { return }
        
        do {
            let parameters = NWParameters.tcp
            listener = try NWListener(using: parameters, on: port)
            
            listener?.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        self?.isRunning = true
                        self?.lastError = nil
                    case .failed(let error):
                        self?.isRunning = false
                        self?.lastError = error.localizedDescription
                    case .cancelled:
                        self?.isRunning = false
                    default:
                        break
                    }
                }
            }
            
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }
            
            listener?.start(queue: .global(qos: .userInitiated))
        } catch {
            DispatchQueue.main.async {
                self.isRunning = false
                self.lastError = error.localizedDescription
            }
        }
    }
    
    public func stop() {
        listener?.cancel()
        listener = nil
        DispatchQueue.main.async {
            self.isRunning = false
        }
    }
    
    // MARK: - 1-Tap On-Device Installation
    
    public func installApp(signedIpaUrl: URL, bundleId: String, appName: String) {
        self.activeIpaUrl = signedIpaUrl
        self.activeBundleId = bundleId
        self.activeAppName = appName
        
        if !isRunning {
            start()
        }
        
        // Wait briefly for server ready, then dispatch itms-services url
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            #if canImport(UIKit)
            let otaUrlString = "itms-services://?action=download-manifest&url=http://127.0.0.1:\(self.port.rawValue)/manifest.plist"
            if let url = URL(string: otaUrlString) {
                UIApplication.shared.open(url, options: [:]) { success in
                    if success {
                        SoundAndHapticManager.shared.triggerHaptic(.success)
                        SoundAndHapticManager.shared.playSuccessSound()
                    }
                }
            }
            #endif
        }
    }
    
    // MARK: - Connection & HTTP Routing
    
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4096) { [weak self] content, _, isComplete, error in
            guard let self = self, let content = content, error == nil else {
                connection.cancel()
                return
            }
            
            let requestString = String(data: content, encoding: .utf8) ?? ""
            self.routeRequest(requestString, connection: connection)
        }
    }
    
    private func routeRequest(_ requestString: String, connection: NWConnection) {
        if requestString.contains("GET /manifest.plist") {
            serveManifest(connection: connection)
        } else if requestString.contains("GET /app.ipa") || requestString.contains("GET /download.ipa") {
            serveIPA(connection: connection)
        } else {
            let notFound = "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
            connection.send(content: notFound.data(using: .utf8), completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }
    
    private func serveManifest(connection: NWConnection) {
        let manifestXml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>items</key>
            <array>
                <dict>
                    <key>assets</key>
                    <array>
                        <dict>
                            <key>kind</key>
                            <string>software-package</string>
                            <key>url</key>
                            <string>http://127.0.0.1:\(port.rawValue)/app.ipa</string>
                        </dict>
                    </array>
                    <key>metadata</key>
                    <dict>
                        <key>bundle-identifier</key>
                        <string>\(activeBundleId)</string>
                        <key>bundle-version</key>
                        <string>1.0</string>
                        <key>kind</key>
                        <string>software</string>
                        <key>title</key>
                        <string>\(activeAppName)</string>
                    </dict>
                </dict>
            </array>
        </dict>
        </plist>
        """
        
        let manifestData = manifestXml.data(using: .utf8)!
        var response = "HTTP/1.1 200 OK\r\n"
        response += "Content-Type: text/xml; charset=utf-8\r\n"
        response += "Content-Length: \(manifestData.count)\r\n"
        response += "Connection: close\r\n\r\n"
        
        var fullData = response.data(using: .utf8)!
        fullData.append(manifestData)
        
        connection.send(content: fullData, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
    
    private func serveIPA(connection: NWConnection) {
        guard let ipaUrl = activeIpaUrl, let ipaData = try? Data(contentsOf: ipaUrl) else {
            let notFound = "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
            connection.send(content: notFound.data(using: .utf8), completion: .contentProcessed { _ in
                connection.cancel()
            })
            return
        }
        
        var response = "HTTP/1.1 200 OK\r\n"
        response += "Content-Type: application/octet-stream\r\n"
        response += "Content-Length: \(ipaData.count)\r\n"
        response += "Content-Disposition: attachment; filename=\"\(ipaUrl.lastPathComponent)\"\r\n"
        response += "Connection: close\r\n\r\n"
        
        var fullData = response.data(using: .utf8)!
        fullData.append(ipaData)
        
        connection.send(content: fullData, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
