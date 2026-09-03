//
//  LocalInstallServer.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Liquid Signer Local & Cloud-Assisted OTA Installation Server
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
    public var activeClients: Int = 0
    public var totalBytesServed: Int64 = 0
    public var localIPAddress: String = "127.0.0.1"
    
    private var listener: NWListener?
    private var activeIpaUrl: URL?
    private var activeBundleId: String = "com.liquidsigner.app"
    private var activeAppName: String = "Liquid App"
    private let port: NWEndpoint.Port = 8080
    
    public static let cloudBackendBaseURL = "https://liquidcalc-backend.vercel.app"
    
    public init() {
        self.localIPAddress = resolveWiFiAddress() ?? "127.0.0.1"
    }
    
    // MARK: - Start Server
    
    public func start() {
        guard !isRunning else { return }
        
        self.localIPAddress = resolveWiFiAddress() ?? "127.0.0.1"
        
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
            self.activeClients = 0
        }
    }
    
    // MARK: - 1-Tap On-Device & Network Installation
    
    public func installApp(signedIpaUrl: URL, bundleId: String, appName: String) {
        self.activeIpaUrl = signedIpaUrl
        self.activeBundleId = bundleId
        self.activeAppName = appName
        
        if !isRunning {
            start()
        }
        
        // Wait briefly for server ready, then dispatch itms-services url
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.40) {
            #if canImport(UIKit)
            // Use Cloud-Assisted HTTPS manifest endpoint with local package URL
            let localDownloadUrl = "http://127.0.0.1:\(self.port.rawValue)/app.ipa"
            let encodedBundle = bundleId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? bundleId
            let encodedName = appName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? appName
            let encodedDownload = localDownloadUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? localDownloadUrl
            
            let httpsManifestUrl = "\(Self.cloudBackendBaseURL)/api/ota/manifest?bundleId=\(encodedBundle)&name=\(encodedName)&version=1.0&url=\(encodedDownload)"
            let otaUrlString = "itms-services://?action=download-manifest&url=\(httpsManifestUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? httpsManifestUrl)"
            
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
    
    public func networkInstallURL(for appName: String, bundleId: String) -> String {
        let ip = localIPAddress
        let localDownloadUrl = "http://\(ip):\(port.rawValue)/app.ipa"
        let encodedBundle = bundleId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? bundleId
        let encodedName = appName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? appName
        let encodedDownload = localDownloadUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? localDownloadUrl
        
        let httpsManifestUrl = "\(Self.cloudBackendBaseURL)/api/ota/manifest?bundleId=\(encodedBundle)&name=\(encodedName)&version=1.0&url=\(encodedDownload)"
        return "itms-services://?action=download-manifest&url=\(httpsManifestUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? httpsManifestUrl)"
    }
    
    // MARK: - Connection & HTTP Routing
    
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        
        DispatchQueue.main.async {
            self.activeClients += 1
        }
        
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4096) { [weak self] content, _, isComplete, error in
            guard let self = self, let content = content, error == nil else {
                connection.cancel()
                DispatchQueue.main.async {
                    self?.activeClients = max(0, (self?.activeClients ?? 1) - 1)
                }
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
            serveIPAWithRange(requestString: requestString, connection: connection)
        } else if requestString.contains("GET /status") || requestString.contains("GET /health") {
            serveStatus(connection: connection)
        } else {
            let notFound = "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
            connection.send(content: notFound.data(using: .utf8), completion: .contentProcessed { [weak self] _ in
                connection.cancel()
                DispatchQueue.main.async {
                    self?.activeClients = max(0, (self?.activeClients ?? 1) - 1)
                }
            })
        }
    }
    
    private func serveStatus(connection: NWConnection) {
        let json = """
        {
            "status": "running",
            "port": \(port.rawValue),
            "ip": "\(localIPAddress)",
            "activeApp": "\(activeAppName)",
            "bundleId": "\(activeBundleId)"
        }
        """
        let data = json.data(using: .utf8)!
        var response = "HTTP/1.1 200 OK\r\n"
        response += "Content-Type: application/json; charset=utf-8\r\n"
        response += "Content-Length: \(data.count)\r\n"
        response += "Access-Control-Allow-Origin: *\r\n"
        response += "Connection: close\r\n\r\n"
        
        var fullData = response.data(using: .utf8)!
        fullData.append(data)
        
        connection.send(content: fullData, completion: .contentProcessed { [weak self] _ in
            connection.cancel()
            DispatchQueue.main.async {
                self?.activeClients = max(0, (self?.activeClients ?? 1) - 1)
            }
        })
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
                            <string>http://\(localIPAddress):\(port.rawValue)/app.ipa</string>
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
        response += "Access-Control-Allow-Origin: *\r\n"
        response += "Connection: close\r\n\r\n"
        
        var fullData = response.data(using: .utf8)!
        fullData.append(manifestData)
        
        connection.send(content: fullData, completion: .contentProcessed { [weak self] _ in
            connection.cancel()
            DispatchQueue.main.async {
                self?.activeClients = max(0, (self?.activeClients ?? 1) - 1)
            }
        })
    }
    
    private func serveIPAWithRange(requestString: String, connection: NWConnection) {
        guard let ipaUrl = activeIpaUrl, let fileHandle = try? FileHandle(forReadingFrom: ipaUrl) else {
            let notFound = "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
            connection.send(content: notFound.data(using: .utf8), completion: .contentProcessed { [weak self] _ in
                connection.cancel()
                DispatchQueue.main.async {
                    self?.activeClients = max(0, (self?.activeClients ?? 1) - 1)
                }
            })
            return
        }
        
        defer {
            try? fileHandle.close()
        }
        
        let fileSize: UInt64
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: ipaUrl.path)
            fileSize = (attrs[.size] as? UInt64) ?? 0
        } catch {
            fileSize = 0
        }
        
        var start: UInt64 = 0
        var end: UInt64 = fileSize > 0 ? fileSize - 1 : 0
        var isPartial = false
        
        // Parse HTTP Range header if present
        if let rangeLine = requestString.components(separatedBy: "\r\n").first(where: { $0.lowercased().hasPrefix("range: bytes=") }) {
            let rangeSpec = rangeLine.replacingOccurrences(of: "range: bytes=", with: "", options: .caseInsensitive).trimmingCharacters(in: .whitespaces)
            let parts = rangeSpec.components(separatedBy: "-")
            if let startVal = UInt64(parts[0]) {
                start = startVal
                if parts.count > 1, let endVal = UInt64(parts[1]) {
                    end = min(endVal, fileSize - 1)
                }
                isPartial = true
            }
        }
        
        let contentLength = (end >= start) ? (end - start + 1) : 0
        
        var header = isPartial ? "HTTP/1.1 206 Partial Content\r\n" : "HTTP/1.1 200 OK\r\n"
        header += "Content-Type: application/octet-stream\r\n"
        header += "Content-Length: \(contentLength)\r\n"
        header += "Accept-Ranges: bytes\r\n"
        if isPartial {
            header += "Content-Range: bytes \(start)-\(end)/\(fileSize)\r\n"
        }
        header += "Content-Disposition: attachment; filename=\"\(ipaUrl.lastPathComponent)\"\r\n"
        header += "Access-Control-Allow-Origin: *\r\n"
        header += "Connection: close\r\n\r\n"
        
        guard let headerData = header.data(using: .utf8) else {
            connection.cancel()
            return
        }
        
        // Send header first
        connection.send(content: headerData, completion: .contentProcessed { [weak self] error in
            if error != nil {
                connection.cancel()
                DispatchQueue.main.async {
                    self?.activeClients = max(0, (self?.activeClients ?? 1) - 1)
                }
                return
            }
            
            // Read range payload from file
            do {
                try fileHandle.seek(toOffset: start)
                let chunk = fileHandle.readData(ofLength: Int(contentLength))
                
                connection.send(content: chunk, completion: .contentProcessed { [weak self] _ in
                    connection.cancel()
                    DispatchQueue.main.async {
                        self?.activeClients = max(0, (self?.activeClients ?? 1) - 1)
                        self?.totalBytesServed += Int64(chunk.count)
                    }
                })
            } catch {
                connection.cancel()
            }
        })
    }
    
    // MARK: - Wi-Fi IP Resolution
    
    private func resolveWiFiAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }
        
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" || name == "pdp_ip0" || name == "lo0" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(
                        interface.ifa_addr,
                        socklen_t(interface.ifa_addr.pointee.sa_len),
                        &hostname,
                        socklen_t(hostname.count),
                        nil,
                        socklen_t(0),
                        NI_NUMERICHOST
                    )
                    address = String(cString: hostname)
                    if name == "en0" {
                        break // Prioritize Wi-Fi en0
                    }
                }
            }
        }
        return address
    }
}
