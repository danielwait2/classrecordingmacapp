import Foundation
import AuthenticationServices

#if os(macOS)
import AppKit
typealias PlatformViewController = NSViewController
typealias PlatformWindow = NSWindow
#else
import UIKit
typealias PlatformViewController = UIViewController
typealias PlatformWindow = UIWindow
#endif

/// Errors that can occur during Google authentication
enum GoogleAuthError: Error, LocalizedError {
    case notAuthenticated
    case tokenRefreshFailed
    case signInFailed(String)
    case missingClientId
    case userCancelled

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to Google Drive"
        case .tokenRefreshFailed:
            return "Failed to refresh authentication token"
        case .signInFailed(let message):
            return "Sign in failed: \(message)"
        case .missingClientId:
            return "Google Client ID not configured"
        case .userCancelled:
            return "Sign in was cancelled"
        }
    }
}

/// Represents the authenticated Google user
struct GoogleUser: Codable {
    let id: String
    let email: String
    let name: String
    let accessToken: String
    let refreshToken: String?
    let tokenExpiration: Date

    var isTokenExpired: Bool {
        Date() >= tokenExpiration
    }
}

/// Service for handling Google OAuth authentication
/// NOTE: This is a simplified implementation. For production use with the actual
/// GoogleSignIn SDK, you would replace this with the real SDK calls.
class GoogleAuthService: ObservableObject {
    static let shared = GoogleAuthService()

    @Published var isSignedIn: Bool = false
    @Published var currentUser: GoogleUser?
    @Published var error: String?
    @Published var isLoading: Bool = false

    private let userDefaultsKey = "googleUser"

    // Google OAuth configuration
    // TODO: Replace with your actual Google Cloud Console credentials
    private let clientId = "145011317257-k0pijk1c04ihu4qjp4t9a4f6ltd2ndhq.apps.googleusercontent.com"
    private let redirectUri = "com.googleusercontent.apps.145011317257-k0pijk1c04ihu4qjp4t9a4f6ltd2ndhq:/oauth2callback"
    private let driveScope = "https://www.googleapis.com/auth/drive.file"
    private let profileScope = "https://www.googleapis.com/auth/userinfo.profile"
    private let emailScope = "https://www.googleapis.com/auth/userinfo.email"

    private init() {
        restorePreviousSignIn()
    }

    // MARK: - Public Methods

    /// Restores the previous sign-in state from storage
    func restorePreviousSignIn() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let user = try? JSONDecoder().decode(GoogleUser.self, from: data) {
            self.currentUser = user
            self.isSignedIn = true

            // Check if token needs refresh
            if user.isTokenExpired {
                Task {
                    try? await refreshTokenIfNeeded()
                }
            }
        }
    }

    /// Initiates the Google Sign-In flow
    @MainActor
    func signIn() async throws {
        isLoading = true
        error = nil

        defer { isLoading = false }

        guard clientId != "YOUR_CLIENT_ID.apps.googleusercontent.com" else {
            throw GoogleAuthError.missingClientId
        }

        // Build the authorization URL
        let authURL = buildAuthorizationURL()

        // Present the sign-in web view
        let authCode = try await presentAuthenticationSession(url: authURL)

        // Exchange the authorization code for tokens
        let user = try await exchangeCodeForTokens(authCode)

        // Save the user
        self.currentUser = user
        self.isSignedIn = true
        saveUser(user)
    }

    /// Signs out the current user
    func signOut() {
        currentUser = nil
        isSignedIn = false
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }

    /// Gets a valid access token, refreshing if necessary
    func getAccessToken() async throws -> String {
        guard let user = currentUser else {
            throw GoogleAuthError.notAuthenticated
        }

        if user.isTokenExpired {
            try await refreshTokenIfNeeded()
        }

        guard let currentUser = self.currentUser else {
            throw GoogleAuthError.notAuthenticated
        }

        return currentUser.accessToken
    }

    // MARK: - Private Methods

    private func buildAuthorizationURL() -> URL {
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!

        let scopes = [driveScope, profileScope, emailScope].joined(separator: " ")

        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]

        return components.url!
    }

    @MainActor
    private func presentAuthenticationSession(url: URL) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            // Extract the scheme from redirectUri (everything before ":/")
            let callbackScheme = self.redirectUri.components(separatedBy: ":/").first ?? ""

            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                if let error = error {
                    if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: GoogleAuthError.userCancelled)
                    } else {
                        continuation.resume(throwing: GoogleAuthError.signInFailed(error.localizedDescription))
                    }
                    return
                }

                guard let callbackURL = callbackURL,
                      let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: GoogleAuthError.signInFailed("No authorization code received"))
                    return
                }

                continuation.resume(returning: code)
            }

            #if os(macOS)
            session.presentationContextProvider = MacOSPresentationContextProvider.shared
            #else
            session.presentationContextProvider = iOSPresentationContextProvider.shared
            #endif

            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
    }

    private func exchangeCodeForTokens(_ code: String) async throws -> GoogleUser {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        // URL encode each parameter value
        let params = [
            ("client_id", clientId),
            ("code", code),
            ("grant_type", "authorization_code"),
            ("redirect_uri", redirectUri),
            ("code_verifier", "") // Empty for native apps without PKCE
        ]

        let bodyString = params
            .filter { !$0.1.isEmpty || $0.0 != "code_verifier" } // Remove empty code_verifier
            .map { key, value in
                let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
                return "\(key)=\(encodedValue)"
            }
            .joined(separator: "&")

        request.httpBody = bodyString.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleAuthError.signInFailed("Invalid response")
        }

        if httpResponse.statusCode != 200 {
            // Log the error for debugging
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorDesc = errorJson["error_description"] as? String {
                print("Google OAuth Error: \(errorDesc)")
                throw GoogleAuthError.signInFailed(errorDesc)
            } else if let errorString = String(data: data, encoding: .utf8) {
                print("Google OAuth Error Response: \(errorString)")
            }
            throw GoogleAuthError.signInFailed("Token exchange failed (status: \(httpResponse.statusCode))")
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)

        // Get user info
        let userInfo = try await fetchUserInfo(accessToken: tokenResponse.accessToken)

        return GoogleUser(
            id: userInfo.id,
            email: userInfo.email,
            name: userInfo.name,
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            tokenExpiration: Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
        )
    }

    private func fetchUserInfo(accessToken: String) async throws -> UserInfoResponse {
        var request = URLRequest(url: URL(string: "https://www.googleapis.com/oauth2/v2/userinfo")!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(UserInfoResponse.self, from: data)
    }

    private func refreshTokenIfNeeded() async throws {
        guard let user = currentUser, let refreshToken = user.refreshToken else {
            throw GoogleAuthError.tokenRefreshFailed
        }

        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "client_id": clientId,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]

        request.httpBody = body.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw GoogleAuthError.tokenRefreshFailed
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)

        let updatedUser = GoogleUser(
            id: user.id,
            email: user.email,
            name: user.name,
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken ?? user.refreshToken,
            tokenExpiration: Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
        )

        await MainActor.run {
            self.currentUser = updatedUser
            self.saveUser(updatedUser)
        }
    }

    private func saveUser(_ user: GoogleUser) {
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
}

// MARK: - Response Types

private struct TokenResponse: Codable {
    let accessToken: String
    let expiresIn: Int
    let refreshToken: String?
    let scope: String?
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
        case tokenType = "token_type"
    }
}

private struct UserInfoResponse: Codable {
    let id: String
    let email: String
    let name: String
    let picture: String?
}

// MARK: - Presentation Context Providers

#if os(macOS)
class MacOSPresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = MacOSPresentationContextProvider()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApplication.shared.keyWindow ?? NSWindow()
    }
}
#else
class iOSPresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = iOSPresentationContextProvider()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return UIWindow()
        }
        return window
    }
}
#endif
