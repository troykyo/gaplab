import SwiftUI
import AuthenticationServices

struct SettingsView: View {
    @State private var anthropicKey  = ""
    @State private var knvbKey       = ""
    @State private var cloudName     = ""
    @State private var uploadPreset  = ""
    @State private var igAppID       = ""
    @State private var igAppSecret   = ""
    @State private var savedMessage  = ""
    @State private var showSaved     = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Settings").font(.title.bold())

                apiSection("Claude (Anthropic)", icon: "brain") {
                    SecureRow("API Key", text: $anthropicKey, key: .anthropicAPIKey)
                }

                apiSection("KNVB Match Data", icon: "sportscourt") {
                    SecureRow("API Key (optional)", text: $knvbKey, key: .knvbAPIKey)
                    Text("Used to look up official Dutch youth match records. Leave blank to use voetbal.nl scraping.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                apiSection("Cloudinary (Image Hosting)", icon: "cloud.fill") {
                    SecureRow("Cloud Name", text: $cloudName, key: .cloudinaryCloudName)
                    SecureRow("Upload Preset", text: $uploadPreset, key: .cloudinaryUploadPreset)
                    Text("Create a free account at cloudinary.com and add an unsigned upload preset.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                apiSection("Instagram", icon: "camera.fill") {
                    SecureRow("App ID", text: $igAppID, key: .instagramAppID)
                    SecureRow("App Secret", text: $igAppSecret, key: .instagramAppSecret)
                    Button("Connect Instagram Account") { startInstagramOAuth() }
                        .buttonStyle(.bordered)
                    if KeychainManager.exists(.instagramAccessToken) {
                        Label("Instagram connected", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green).font(.caption)
                    }
                    Text("Requires a Creator or Business account. Convert free in Instagram → Settings → Account → Switch to Professional.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                HStack {
                    Spacer()
                    Button("Save All") { saveAll() }.buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .overlay(alignment: .top) {
            if showSaved {
                Text(savedMessage)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Color.green.opacity(0.9)).foregroundStyle(.white)
                    .clipShape(Capsule())
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
            }
        }
        .onAppear { loadExisting() }
    }

    private func apiSection<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) { content() }
                .padding(.top, 4)
        } label: {
            Label(title, systemImage: icon).font(.headline)
        }
    }

    private func loadExisting() {
        anthropicKey = (try? KeychainManager.load(.anthropicAPIKey)) ?? ""
        knvbKey      = (try? KeychainManager.load(.knvbAPIKey))      ?? ""
        cloudName    = (try? KeychainManager.load(.cloudinaryCloudName)) ?? ""
        uploadPreset = (try? KeychainManager.load(.cloudinaryUploadPreset)) ?? ""
        igAppID      = (try? KeychainManager.load(.instagramAppID))   ?? ""
        igAppSecret  = (try? KeychainManager.load(.instagramAppSecret)) ?? ""
    }

    private func saveAll() {
        let pairs: [(String, KeychainKey)] = [
            (anthropicKey, .anthropicAPIKey), (knvbKey, .knvbAPIKey),
            (cloudName, .cloudinaryCloudName), (uploadPreset, .cloudinaryUploadPreset),
            (igAppID, .instagramAppID), (igAppSecret, .instagramAppSecret),
        ]
        for (value, key) in pairs where !value.isEmpty {
            try? KeychainManager.save(value, for: key)
        }
        savedMessage = "Settings saved"
        withAnimation { showSaved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation { showSaved = false } }
    }

    private func startInstagramOAuth() {
        guard let appID = try? KeychainManager.load(.instagramAppID) else { return }
        var comps = URLComponents(string: "https://www.instagram.com/oauth/authorize")!
        comps.queryItems = [
            URLQueryItem(name: "client_id",     value: appID),
            URLQueryItem(name: "redirect_uri",  value: "matchpost://oauth"),
            URLQueryItem(name: "scope",         value: "instagram_business_basic,instagram_business_content_publish"),
            URLQueryItem(name: "response_type", value: "code"),
        ]
        guard let authURL = comps.url else { return }

        let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: "matchpost") { callbackURL, error in
            guard let url = callbackURL,
                  let code = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "code" })?.value else { return }
            Task { await exchangeCodeForToken(code: code) }
        }
        session.prefersEphemeralWebBrowserSession = false
        session.start()
    }

    private func exchangeCodeForToken(code: String) async {
        guard let appID     = try? KeychainManager.load(.instagramAppID),
              let appSecret = try? KeychainManager.load(.instagramAppSecret) else { return }

        var req = URLRequest(url: URL(string: "https://api.instagram.com/oauth/access_token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = "client_id=\(appID)&client_secret=\(appSecret)&grant_type=authorization_code&redirect_uri=matchpost://oauth&code=\(code)".data(using: .utf8)

        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let shortToken = json["access_token"] as? String,
              let userID = json["user_id"] as? Int else { return }

        // Exchange for long-lived token
        guard let longURL = URL(string: "https://graph.instagram.com/access_token?grant_type=ig_exchange_token&client_secret=\(appSecret)&access_token=\(shortToken)"),
              let (longData, _) = try? await URLSession.shared.data(from: longURL),
              let longJSON = try? JSONSerialization.jsonObject(with: longData) as? [String: Any],
              let longToken = longJSON["access_token"] as? String else { return }

        try? KeychainManager.save(longToken, for: .instagramAccessToken)
        try? KeychainManager.save("\(userID)", for: .instagramUserID)

        await MainActor.run {
            savedMessage = "Instagram connected!"
            withAnimation { showSaved = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation { showSaved = false } }
        }
    }
}

struct SecureRow: View {
    let label: String
    @Binding var text: String
    let key: KeychainKey

    init(_ label: String, text: Binding<String>, key: KeychainKey) {
        self.label = label
        self._text = text
        self.key   = key
    }

    var body: some View {
        HStack {
            Text(label).frame(width: 130, alignment: .leading).foregroundStyle(.secondary)
            SecureField(label, text: $text).textFieldStyle(.roundedBorder)
        }
    }
}
