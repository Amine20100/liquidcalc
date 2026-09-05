//
//  CryptoTransportTests.swift
//  LiquidCalcTests
//
//  Unit Test Suite for Multi-Layer Transport Obfuscation & Security
//  Validates AES-GCM-256 encryption, dynamic HMAC-SHA256 signatures,
//  Base64URL entropy masking, tamper detection, and SSE chunk decryption.
//

import XCTest
import CryptoKit
#if canImport(LiquidCalc)
@testable import LiquidCalc
#elseif canImport(LiquidCalcCore)
@testable import LiquidCalcCore
#endif

final class CryptoTransportTests: XCTestCase {

    var transport: CryptoTransport!

    override func setUp() {
        super.setUp()
        transport = CryptoTransport()
    }

    override func tearDown() {
        transport = nil
        super.tearDown()
    }

    // =========================================================================
    // MARK: - 1. Key Derivation & Initialization
    // =========================================================================

    func testKeyDerivationConsistency() {
        let t1 = CryptoTransport(secret: "test_secret_123")
        let t2 = CryptoTransport(secret: "test_secret_123")
        let data = Data("Secret payload message".utf8)

        let enc1 = try? t1.encrypt(data: data)
        XCTAssertNotNil(enc1)

        // Decrypt using second instance with identical secret
        let dec2 = try? t2.decrypt(base64URLString: enc1!.payload)
        XCTAssertNotNil(dec2)
        XCTAssertEqual(String(data: dec2!, encoding: .utf8), "Secret payload message")
    }

    // =========================================================================
    // MARK: - 2. Encryption & Decryption Roundtrip
    // =========================================================================

    func testEncryptionDecryptionRoundtrip() throws {
        let originalText = "{\"expression\":\"sin(pi / 4)\",\"mode\":\"calculus\"}"
        guard let originalData = originalText.data(using: .utf8) else {
            XCTFail("Failed to convert text to Data")
            return
        }

        let (payload, timestamp, nonce, signature) = try transport.encrypt(data: originalData)

        // Verify Base64URL entropy masking
        XCTAssertFalse(payload.contains("sin"), "Payload must not contain plaintext keywords")
        XCTAssertFalse(payload.contains("calculus"), "Payload must not contain plaintext keywords")
        XCTAssertFalse(payload.contains("+"), "Payload must be URL-safe (no '+')")
        XCTAssertFalse(payload.contains("/"), "Payload must be URL-safe (no '/')")
        XCTAssertFalse(payload.contains("="), "Payload must omit padding ('=')")
        XCTAssertFalse(timestamp.isEmpty)
        XCTAssertFalse(nonce.isEmpty)
        XCTAssertEqual(signature.count, 64, "HMAC-SHA256 signature must be 64 hex characters")

        // Decrypt payload
        let decryptedData = try transport.decrypt(base64URLString: payload)
        let decryptedText = String(data: decryptedData, encoding: .utf8)
        XCTAssertEqual(decryptedText, originalText, "Decrypted text must match original plaintext")
    }

    // =========================================================================
    // MARK: - 3. Nonce Uniqueness & Ciphertext Randomization
    // =========================================================================

    func testCiphertextRandomization() throws {
        let data = Data("Identical plaintext input".utf8)

        let (payload1, _, nonce1, _) = try transport.encrypt(data: data)
        let (payload2, _, nonce2, _) = try transport.encrypt(data: data)

        XCTAssertNotEqual(nonce1, nonce2, "Nonces must be randomly generated and unique per request")
        XCTAssertNotEqual(payload1, payload2, "Identical plaintexts must produce distinct ciphertexts due to distinct IVs")
    }

    // =========================================================================
    // MARK: - 4. HMAC-SHA256 Dynamic Signature Verification
    // =========================================================================

    func testSignatureVerification() throws {
        let data = Data("{\"prompt\":\"2 + 2\"}".utf8)
        let (payload, timestamp, nonce, signature) = try transport.encrypt(data: data)

        let isValid = transport.verifySignature(
            timestamp: timestamp,
            nonce: nonce,
            payloadString: payload,
            signatureHex: signature
        )
        XCTAssertTrue(isValid, "Valid signature must pass verification")

        // Tamper with signature
        let tamperedSig = "0" + String(signature.dropFirst())
        let isTamperedValid = transport.verifySignature(
            timestamp: timestamp,
            nonce: nonce,
            payloadString: payload,
            signatureHex: tamperedSig
        )
        XCTAssertFalse(isTamperedValid, "Tampered signature must be rejected")
    }

    // =========================================================================
    // MARK: - 5. Tampered Ciphertext Authentication Rejection
    // =========================================================================

    func testTamperedCiphertextRejection() throws {
        let data = Data("Critical mathematical transaction data".utf8)
        let (payload, _, _, _) = try transport.encrypt(data: data)

        // Corrupt single character in payload
        var chars = Array(payload)
        chars[10] = chars[10] == "a" ? "b" : "a"
        let corruptedPayload = String(chars)

        XCTAssertThrowsError(try transport.decrypt(base64URLString: corruptedPayload)) { error in
            guard let cryptoError = error as? CryptoTransportError else {
                XCTFail("Expected CryptoTransportError, got \(error)")
                return
            }
            if case .decryptionFailed = cryptoError {
                // Passed
            } else {
                XCTFail("Expected decryptionFailed, got \(cryptoError)")
            }
        }
    }

    // =========================================================================
    // MARK: - 6. Short / Malformed Ciphertext Rejection
    // =========================================================================

    func testShortCiphertextRejection() {
        let shortPayload = "AQIDBA==" // 4 bytes, far below the 28 byte minimum (12B IV + 16B Tag)
        XCTAssertThrowsError(try transport.decrypt(base64URLString: shortPayload))
    }

    // =========================================================================
    // MARK: - 7. Base64URL Encoding & Decoding Extension
    // =========================================================================

    func testBase64URLExtension() {
        // Data containing bytes that typically produce '+' and '/' in standard Base64
        let testBytes: [UInt8] = [251, 255, 254, 240, 245, 128]
        let data = Data(testBytes)

        let urlEncoded = data.base64URLEncodedString()
        XCTAssertFalse(urlEncoded.contains("+"))
        XCTAssertFalse(urlEncoded.contains("/"))
        XCTAssertFalse(urlEncoded.contains("="))

        let recoveredData = Data(base64URLEncoded: urlEncoded)
        XCTAssertEqual(recoveredData, data, "Base64URL roundtrip must restore original bytes")
    }

    // =========================================================================
    // MARK: - 8. SSE Streaming Chunk Obfuscation
    // =========================================================================

    func testSSEChunkDecryption() throws {
        let chunkText = "Step 1: Expand binomial (x + 1)^2"
        let encChunk = try transport.encryptStreamChunk(text: chunkText, done: false)

        XCTAssertFalse(encChunk.contains("binomial"), "SSE chunk must be obfuscated")

        let sseLine = "data: \(encChunk)"
        let decryptedText = transport.decryptStreamChunk(rawLine: sseLine)
        XCTAssertEqual(decryptedText, chunkText, "Decrypted stream chunk text must match")

        // Test [DONE] line returns nil
        let doneLine = "data: [DONE]"
        XCTAssertNil(transport.decryptStreamChunk(rawLine: doneLine))
    }

    // =========================================================================
    // MARK: - 9. Device Sync Manager Identity
    // =========================================================================

    func testDeviceSyncManagerIdentity() {
        let deviceManager = DeviceSyncManager.shared
        XCTAssertFalse(deviceManager.deviceId.isEmpty, "Device ID must not be empty")
        XCTAssertTrue(deviceManager.deviceId.hasPrefix("ios_"), "Device ID must have ios_ prefix")
    }

    // =========================================================================
    // MARK: - 10. Telemetry Breadcrumb Recording
    // =========================================================================

    func testTelemetryBreadcrumbs() {
        let telemetry = TelemetryManager.shared
        telemetry.addBreadcrumb("User tapped Scientific Calculator mode")
        telemetry.addBreadcrumb("Calculated factorial of 10")
        XCTAssertTrue(telemetry.isEnabled)
    }

    // =========================================================================
    // MARK: - 11. Malformed Base64URL Remainder Rejection
    // =========================================================================

    func testBase64URLMalformedRemainderRejection() {
        // Remainder of 1 modulo 4 is mathematically impossible for valid Base64
        let malformed = "abcde" // 5 characters (5 % 4 = 1)
        XCTAssertNil(Data(base64URLEncoded: malformed), "Base64URL with invalid remainder must return nil")
    }

    // =========================================================================
    // MARK: - 12. Mutual Signature & Replay Tolerance
    // =========================================================================

    func testMutualSignatureVerification() throws {
        let data = Data("Server authenticated response".utf8)
        let (payload, timestamp, nonce, signature) = try transport.encrypt(data: data)

        // Valid signature passes
        XCTAssertTrue(transport.verifySignature(timestamp: timestamp, nonce: nonce, payloadString: payload, signatureHex: signature))

        // Tampered signature fails
        let tamperedSig = signature.dropLast() + "0"
        XCTAssertFalse(transport.verifySignature(timestamp: timestamp, nonce: nonce, payloadString: payload, signatureHex: String(tamperedSig)))

        // Nonce mismatch fails
        XCTAssertFalse(transport.verifySignature(timestamp: timestamp, nonce: "wrong_nonce", payloadString: payload, signatureHex: signature))
    }
}
