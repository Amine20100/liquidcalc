//
//  CryptoTransport.swift
//  LiquidCalc
//
//  Multi-Layer Transport Obfuscation & Security Engine
//  AES-GCM-256 Payload Encryption + Dynamic Rotating HMAC-SHA256 Signatures + Base64URL Entropy Masking
//  Created for LiquidCalc iOS 18+.
//

import Foundation
import CryptoKit

public enum CryptoTransportError: Error, LocalizedError, Sendable {
    case encryptionFailed(String)
    case decryptionFailed(String)
    case invalidSignature
    case expiredTimestamp
    case invalidResponse(Int, String)
    case serializationError(String)
    case invalidURL
    case networkError(String, isOffline: Bool)

    public var errorDescription: String? {
        switch self {
        case .encryptionFailed(let msg):
            return "Payload encryption failed: \(msg)"
        case .decryptionFailed(let msg):
            return "Transport payload decryption failed: \(msg)"
        case .invalidSignature:
            return "Transport HMAC-SHA256 signature verification failed"
        case .expiredTimestamp:
            return "Transport request timestamp outside valid tolerance window"
        case .invalidResponse(let code, let msg):
            if code == 401 {
                return msg.lowercased().contains("invalid") || msg.lowercased().contains("password") || msg.lowercased().contains("email")
                    ? msg
                    : "Incorrect email or password. Please double check your credentials."
            } else if code == 409 {
                return "An account with this email address already exists. Please sign in instead."
            } else if code == 404 {
                return "Requested service endpoint was not found on the server."
            }
            return "Server responded with error (\(code)): \(msg)"
        case .serializationError(let msg):
            return "Data serialization error: \(msg)"
        case .invalidURL:
            return "Invalid target URL"
        case .networkError(let msg, let isOffline):
            if isOffline {
                return "Network connection offline. LiquidCalc is running in 100% Guest Mode — all calculations and notes are saved locally."
            } else {
                return "Unable to reach server (\(msg)). Offline Guest Mode is active so you can continue using all features uninterrupted."
            }
        }
    }
}

// MARK: - Base64URL Extension for High-Entropy Masking

extension Data {
    public func base64URLEncodedString() -> String {
        return self.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    public init?(base64URLEncoded string: String) {
        var base64 = string
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder == 2 {
            base64.append("==")
        } else if remainder == 3 {
            base64.append("=")
        } else if remainder == 1 {
            return nil
        }
        self.init(base64Encoded: base64, options: .ignoreUnknownCharacters)
    }
}

// MARK: - CryptoTransport

public final class CryptoTransport: @unchecked Sendable {
    public static let shared = CryptoTransport()

    public static let customURLKey = "LiquidCalc_CustomBackendURL"
    public static let defaultProductionURL = "https://liquidcalc-backend.vercel.app"
    public static let defaultLocalURL = "http://127.0.0.1:3000"

    /// Base backend URL for requests with persistent configuration support
    public var baseURL: String {
        get {
            if let custom = UserDefaults.standard.string(forKey: Self.customURLKey), !custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return custom.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if let envURL = ProcessInfo.processInfo.environment["LIQUIDCALC_BACKEND_URL"], !envURL.isEmpty {
                return envURL
            }
            return Self.defaultProductionURL
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.customURLKey)
        }
    }

    /// Master secret seed for transport key derivation
    public let masterSecret: String

    /// 256-bit AES-GCM symmetric key derived via SHA-256
    private let encKey: SymmetricKey

    /// 256-bit HMAC-SHA256 symmetric key derived via SHA-256
    private let hmacKey: SymmetricKey

    /// Freshness window tolerance in seconds (5 minutes)
    public let timestampToleranceSeconds: TimeInterval = 300

    public init(secret: String = "liqidcalc_sec_transport_v2_2026_gcm_hmac_secret_payload_key") {
        self.masterSecret = secret

        // Derive 256-bit AES encryption key
        let encSeed = Data((secret + ":aes256_enc").utf8)
        let encDigest = SHA256.hash(data: encSeed)
        self.encKey = SymmetricKey(data: encDigest)

        // Derive 256-bit HMAC signing key
        let hmacSeed = Data((secret + ":hmac_sha256").utf8)
        let hmacDigest = SHA256.hash(data: hmacSeed)
        self.hmacKey = SymmetricKey(data: hmacDigest)
    }

    // MARK: - Dynamic HMAC Signature Generation

    public func signPayload(timestamp: String, nonce: String, payloadString: String) -> String {
        let message = "\(timestamp):\(nonce):\(payloadString)"
        let signature = HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: hmacKey)
        return signature.map { String(format: "%02x", $0) }.joined()
    }

    public func verifySignature(timestamp: String, nonce: String, payloadString: String, signatureHex: String) -> Bool {
        let expected = signPayload(timestamp: timestamp, nonce: nonce, payloadString: payloadString)
        let expBytes = Array(expected.lowercased().utf8)
        let actBytes = Array(signatureHex.lowercased().utf8)
        guard expBytes.count == actBytes.count else { return false }
        var diff: UInt8 = 0
        for i in 0..<expBytes.count {
            diff |= expBytes[i] ^ actBytes[i]
        }
        return diff == 0
    }

    // MARK: - Payload Encryption (AES-256-GCM + Base64URL Masking)

    public func encrypt(data: Data) throws -> (payload: String, timestamp: String, nonce: String, signature: String) {
        do {
            let sealedBox = try AES.GCM.seal(data, using: encKey)
            guard let combined = sealedBox.combined else {
                throw CryptoTransportError.encryptionFailed("Unable to extract combined sealed box data")
            }

            let payload = combined.base64URLEncodedString()
            let timestamp = String(Int64(Date().timeIntervalSince1970))
            let nonce = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
            let signature = signPayload(timestamp: timestamp, nonce: nonce, payloadString: payload)

            return (payload, timestamp, nonce, signature)
        } catch let err as CryptoTransportError {
            throw err
        } catch {
            throw CryptoTransportError.encryptionFailed(error.localizedDescription)
        }
    }

    // MARK: - Payload Decryption

    public func decrypt(base64URLString: String) throws -> Data {
        let trimmed = base64URLString.trimmingCharacters(in: .whitespacesAndNewlines)

        // If wrapped in a JSON envelope like {"data": "..."}
        var cipherText = trimmed
        if trimmed.hasPrefix("{") {
            if let data = trimmed.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let inner = json["data"] as? String {
                    cipherText = inner.trimmingCharacters(in: .whitespacesAndNewlines)
                } else if let inner = json["payload"] as? String {
                    cipherText = inner.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }

        guard let combined = Data(base64URLEncoded: cipherText) else {
            throw CryptoTransportError.decryptionFailed("Malformed Base64URL string")
        }

        guard combined.count >= 28 else {
            throw CryptoTransportError.decryptionFailed("Ciphertext too short (minimum 28 bytes for 12B IV + 16B Tag)")
        }

        do {
            let sealedBox = try AES.GCM.SealedBox(combined: combined)
            return try AES.GCM.open(sealedBox, using: encKey)
        } catch {
            throw CryptoTransportError.decryptionFailed(error.localizedDescription)
        }
    }

    // MARK: - Transparent Encrypted HTTP Request

    public func performEncryptedRequest(
        endpoint: String,
        method: String = "POST",
        jsonPayload: Any? = nil,
        headers: [String: String] = [:]
    ) async throws -> (data: Data, response: HTTPURLResponse) {
        let urlString = endpoint.hasPrefix("http://") || endpoint.hasPrefix("https://")
            ? endpoint
            : "\(baseURL)\(endpoint.hasPrefix("/") ? "" : "/")\(endpoint)"

        guard let url = URL(string: urlString) else {
            throw CryptoTransportError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30

        // Encrypt body if payload provided
        if let jsonPayload = jsonPayload {
            let rawJsonData: Data
            if let directData = jsonPayload as? Data {
                rawJsonData = directData
            } else {
                rawJsonData = try JSONSerialization.data(withJSONObject: jsonPayload)
            }

            let (payload, timestamp, nonce, signature) = try encrypt(data: rawJsonData)
            request.setValue(signature, forHTTPHeaderField: "X-Signature")
            request.setValue(timestamp, forHTTPHeaderField: "X-Timestamp")
            request.setValue(nonce, forHTTPHeaderField: "X-Nonce")
            request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
            request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
            request.httpBody = Data(payload.utf8)
        } else if method == "GET" {
            // For signed GET requests
            let timestamp = String(Int64(Date().timeIntervalSince1970))
            let nonce = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
            let signature = signPayload(timestamp: timestamp, nonce: nonce, payloadString: "")
            request.setValue(signature, forHTTPHeaderField: "X-Signature")
            request.setValue(timestamp, forHTTPHeaderField: "X-Timestamp")
            request.setValue(nonce, forHTTPHeaderField: "X-Nonce")
            request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
        } else {
            // Non-GET with empty payload
            let (payload, timestamp, nonce, signature) = try encrypt(data: Data())
            request.setValue(signature, forHTTPHeaderField: "X-Signature")
            request.setValue(timestamp, forHTTPHeaderField: "X-Timestamp")
            request.setValue(nonce, forHTTPHeaderField: "X-Nonce")
            request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
            request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
            request.httpBody = Data(payload.utf8)
        }

        // Add additional headers
        for (k, v) in headers {
            request.setValue(v, forHTTPHeaderField: k)
        }

        let rawData: Data
        let rawResponse: URLResponse
        do {
            (rawData, rawResponse) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError {
            let isOffline = Self.isOfflineURLError(urlError)
            throw CryptoTransportError.networkError(urlError.localizedDescription, isOffline: isOffline)
        } catch {
            throw CryptoTransportError.networkError(error.localizedDescription, isOffline: false)
        }

        guard let httpResponse = rawResponse as? HTTPURLResponse else {
            throw CryptoTransportError.invalidResponse(-1, "Non-HTTP response")
        }

        // If encrypted request fails with 400, 403, or 415, attempt transparent standard JSON fallback
        if (httpResponse.statusCode == 400 || httpResponse.statusCode == 403 || httpResponse.statusCode == 415) && jsonPayload != nil {
            if let standardResult = try? await performStandardRequest(endpoint: endpoint, method: method, jsonPayload: jsonPayload, headers: headers) {
                return standardResult
            }
        }

        // Check if response has encrypted transport headers
        let isEncrypted = httpResponse.value(forHTTPHeaderField: "X-Encrypted") == "1" ||
            httpResponse.value(forHTTPHeaderField: "x-encrypted") == "1" ||
            httpResponse.value(forHTTPHeaderField: "Content-Type")?.contains("application/octet-stream") == true

        var processedData = rawData
        if let bodyStr = String(data: rawData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
            // Verify mutual signature if response headers are present
            let respSig = httpResponse.value(forHTTPHeaderField: "X-Signature") ?? httpResponse.value(forHTTPHeaderField: "x-signature")
            let respTs = httpResponse.value(forHTTPHeaderField: "X-Timestamp") ?? httpResponse.value(forHTTPHeaderField: "x-timestamp")
            let respNonce = httpResponse.value(forHTTPHeaderField: "X-Nonce") ?? httpResponse.value(forHTTPHeaderField: "x-nonce")

            if let respSig = respSig, let respTs = respTs, let respNonce = respNonce {
                guard verifySignature(timestamp: respTs, nonce: respNonce, payloadString: bodyStr, signatureHex: respSig) else {
                    throw CryptoTransportError.invalidSignature
                }
            }

            // Attempt decryption if encrypted or high-entropy Base64URL
            if isEncrypted || (!bodyStr.hasPrefix("{") && bodyStr.count >= 28) {
                if let decrypted = try? decrypt(base64URLString: bodyStr) {
                    processedData = decrypted
                }
            }
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            var rawError = "Server responded with status \(httpResponse.statusCode)"
            if let json = try? JSONSerialization.jsonObject(with: processedData) as? [String: Any] {
                if let msg = json["error"] as? String {
                    rawError = msg
                } else if let msg = json["message"] as? String {
                    rawError = msg
                }
            } else if let str = String(data: processedData, encoding: .utf8), !str.isEmpty {
                rawError = str
            }
            throw CryptoTransportError.invalidResponse(httpResponse.statusCode, rawError)
        }

        return (processedData, httpResponse)
    }

    // MARK: - Standard JSON HTTP Request (Clear Diagnostics & Direct Transport Fallback)

    public func performStandardRequest(
        endpoint: String,
        method: String = "POST",
        jsonPayload: Any? = nil,
        headers: [String: String] = [:]
    ) async throws -> (data: Data, response: HTTPURLResponse) {
        let urlString = endpoint.hasPrefix("http://") || endpoint.hasPrefix("https://")
            ? endpoint
            : "\(baseURL)\(endpoint.hasPrefix("/") ? "" : "/")\(endpoint)"

        guard let url = URL(string: urlString) else {
            throw CryptoTransportError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let jsonPayload = jsonPayload {
            if let directData = jsonPayload as? Data {
                request.httpBody = directData
            } else {
                request.httpBody = try JSONSerialization.data(withJSONObject: jsonPayload)
            }
        }

        for (k, v) in headers {
            request.setValue(v, forHTTPHeaderField: k)
        }

        let rawData: Data
        let rawResponse: URLResponse
        do {
            (rawData, rawResponse) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError {
            let isOffline = Self.isOfflineURLError(urlError)
            throw CryptoTransportError.networkError(urlError.localizedDescription, isOffline: isOffline)
        } catch {
            throw CryptoTransportError.networkError(error.localizedDescription, isOffline: false)
        }

        guard let httpResponse = rawResponse as? HTTPURLResponse else {
            throw CryptoTransportError.invalidResponse(-1, "Non-HTTP response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            var rawError = "Server responded with status \(httpResponse.statusCode)"
            if let json = try? JSONSerialization.jsonObject(with: rawData) as? [String: Any] {
                if let msg = json["error"] as? String {
                    rawError = msg
                } else if let msg = json["message"] as? String {
                    rawError = msg
                }
            } else if let str = String(data: rawData, encoding: .utf8), !str.isEmpty {
                rawError = str
            }
            throw CryptoTransportError.invalidResponse(httpResponse.statusCode, rawError)
        }

        return (rawData, httpResponse)
    }

    // MARK: - Transparent Encrypted SSE Stream

    public func performEncryptedStream(
        endpoint: String,
        jsonPayload: Any,
        headers: [String: String] = [:]
    ) async throws -> (bytes: URLSession.AsyncBytes, response: HTTPURLResponse) {
        let urlString = endpoint.hasPrefix("http://") || endpoint.hasPrefix("https://")
            ? endpoint
            : "\(baseURL)\(endpoint.hasPrefix("/") ? "" : "/")\(endpoint)"

        guard let url = URL(string: urlString) else {
            throw CryptoTransportError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 45

        let rawJsonData: Data
        if let directData = jsonPayload as? Data {
            rawJsonData = directData
        } else {
            rawJsonData = try JSONSerialization.data(withJSONObject: jsonPayload)
        }

        let (payload, timestamp, nonce, signature) = try encrypt(data: rawJsonData)
        request.setValue(signature, forHTTPHeaderField: "X-Signature")
        request.setValue(timestamp, forHTTPHeaderField: "X-Timestamp")
        request.setValue(nonce, forHTTPHeaderField: "X-Nonce")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.httpBody = Data(payload.utf8)

        for (k, v) in headers {
            request.setValue(v, forHTTPHeaderField: k)
        }

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CryptoTransportError.invalidResponse(-1, "Non-HTTP response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw CryptoTransportError.invalidResponse(httpResponse.statusCode, "SSE streaming failed")
        }

        return (bytes, httpResponse)
    }

    // MARK: - SSE Stream Chunk Decryption

    public func decryptStreamChunk(rawLine: String) -> String? {
        let trimmedLine = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedLine.hasPrefix("data:") else { return nil }
        let rawContent = String(trimmedLine.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
        if rawContent.isEmpty || rawContent == "[DONE]" { return nil }

        // 1. Try decrypting as AES-GCM Base64URL chunk
        if let decryptedData = try? decrypt(base64URLString: rawContent),
           let json = try? JSONSerialization.jsonObject(with: decryptedData) as? [String: Any] {
            return json["text"] as? String
        }

        // 2. Fallback if chunk was plain JSON (e.g. during local tests)
        if let data = rawContent.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return json["text"] as? String
        }

        return nil
    }

    // MARK: - SSE Stream Chunk Encryption (for testing / mocking)

    public func encryptStreamChunk(text: String, done: Bool) throws -> String {
        let chunkPayload: [String: Any] = ["text": text, "done": done]
        let data = try JSONSerialization.data(withJSONObject: chunkPayload)
        let sealed = try AES.GCM.seal(data, using: encKey)
        guard let combined = sealed.combined else {
            throw CryptoTransportError.encryptionFailed("Stream chunk seal failed")
        }
        return combined.base64URLEncodedString()
    }
}
