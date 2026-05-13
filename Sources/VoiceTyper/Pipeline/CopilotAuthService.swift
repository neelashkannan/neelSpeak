import Foundation
import os

private let copilotLog = Logger(subsystem: "com.neelspeak.app", category: "copilot-auth")

/// GitHub Copilot authentication via OAuth device flow.
///
/// Flow:
///  1. `requestDeviceCode()` → returns user code + verification URL. User opens
///     the URL in a browser, signs in, and enters the user code.
///  2. `pollForOAuthToken(deviceCode:interval:)` → poll until the user
///     authorizes; returns a long-lived OAuth token (`ghu_...`).
///  3. `fetchSessionToken(oauthToken:)` → exchange OAuth token for a
///     short-lived (~30 min) Copilot session token usable against
///     `api.githubcopilot.com`.
///
/// Steps 1-2 happen once per user, then we persist the OAuth token.
/// Step 3 runs whenever the session token is missing or near expiry.
enum CopilotAuthService {

    /// The well-known GitHub OAuth client ID used by the official Copilot CLI
    /// and editor extensions. Not a secret.
    static let clientID = "Iv1.b507a08c87ecfe98"

    struct DeviceCode {
        let deviceCode: String
        let userCode: String
        let verificationURL: String
        let pollIntervalSeconds: Int
        let expiresAt: Date
    }

    struct SessionToken {
        let token: String
        let expiresAt: Date
    }

    enum Error: Swift.Error, CustomStringConvertible {
        case http(Int, String)
        case decoding(String)
        case authorizationPending
        case slowDown
        case expired
        case denied
        case other(String)

        var description: String {
            switch self {
            case .http(let code, let body): return "HTTP \(code): \(body.prefix(200))"
            case .decoding(let msg): return "Decode: \(msg)"
            case .authorizationPending: return "Waiting for user to authorize in browser"
            case .slowDown: return "Polling too fast"
            case .expired: return "Device code expired — start over"
            case .denied: return "Access denied"
            case .other(let msg): return msg
            }
        }
    }

    // MARK: - Step 1: device code request

    static func requestDeviceCode() async throws -> DeviceCode {
        guard let url = URL(string: "https://github.com/login/device/code") else {
            throw Error.other("Bad URL")
        }
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = "client_id=\(clientID)&scope=read%3Auser"
        req.httpBody = body.data(using: .utf8)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw Error.other("Non-HTTP response") }
        guard (200..<300).contains(http.statusCode) else {
            throw Error.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let deviceCode = json["device_code"] as? String,
              let userCode = json["user_code"] as? String,
              let verificationURI = json["verification_uri"] as? String,
              let interval = json["interval"] as? Int,
              let expiresIn = json["expires_in"] as? Int
        else {
            throw Error.decoding(String(data: data, encoding: .utf8) ?? "")
        }
        return DeviceCode(
            deviceCode: deviceCode,
            userCode: userCode,
            verificationURL: verificationURI,
            pollIntervalSeconds: interval,
            expiresAt: Date().addingTimeInterval(TimeInterval(expiresIn))
        )
    }

    // MARK: - Step 2: poll for OAuth token

    /// Polls `/login/oauth/access_token` at the rate hinted by the device
    /// response. Throws `.authorizationPending` while user hasn't approved.
    /// Returns the `ghu_...` access token once approved.
    static func pollForOAuthToken(deviceCode: DeviceCode) async throws -> String {
        var interval = TimeInterval(deviceCode.pollIntervalSeconds)
        while Date() < deviceCode.expiresAt {
            try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            do {
                if let token = try await pollOnce(deviceCode: deviceCode.deviceCode) {
                    return token
                }
            } catch Error.slowDown {
                // Back off by 5 seconds per spec
                interval += 5
            } catch Error.authorizationPending {
                continue
            }
        }
        throw Error.expired
    }

    private static func pollOnce(deviceCode: String) async throws -> String? {
        guard let url = URL(string: "https://github.com/login/oauth/access_token") else {
            throw Error.other("Bad URL")
        }
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = "client_id=\(clientID)&device_code=\(deviceCode)&grant_type=urn:ietf:params:oauth:grant-type:device_code"
        req.httpBody = body.data(using: .utf8)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw Error.other("Non-HTTP response") }
        guard (200..<300).contains(http.statusCode) else {
            throw Error.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw Error.decoding(String(data: data, encoding: .utf8) ?? "")
        }
        if let token = json["access_token"] as? String {
            return token
        }
        if let err = json["error"] as? String {
            switch err {
            case "authorization_pending": throw Error.authorizationPending
            case "slow_down": throw Error.slowDown
            case "expired_token": throw Error.expired
            case "access_denied": throw Error.denied
            default: throw Error.other(err)
            }
        }
        return nil
    }

    // MARK: - Step 3: exchange OAuth token for Copilot session token

    static func fetchSessionToken(oauthToken: String) async throws -> SessionToken {
        guard let url = URL(string: "https://api.github.com/copilot_internal/v2/token") else {
            throw Error.other("Bad URL")
        }
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = "GET"
        req.setValue("Bearer \(oauthToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("GithubCopilot/1.155.0", forHTTPHeaderField: "User-Agent")
        req.setValue("vscode/1.95.0", forHTTPHeaderField: "Editor-Version")
        req.setValue("copilot/1.155.0", forHTTPHeaderField: "Editor-Plugin-Version")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw Error.other("Non-HTTP response") }
        guard (200..<300).contains(http.statusCode) else {
            throw Error.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["token"] as? String,
              let expiresAt = json["expires_at"] as? TimeInterval
        else {
            throw Error.decoding(String(data: data, encoding: .utf8) ?? "")
        }
        copilotLog.info("Fetched Copilot session token (expires_at=\(expiresAt, privacy: .public))")
        return SessionToken(
            token: token,
            expiresAt: Date(timeIntervalSince1970: expiresAt)
        )
    }
}
