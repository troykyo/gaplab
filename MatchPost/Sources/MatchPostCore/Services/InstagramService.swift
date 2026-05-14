import Foundation

final class InstagramService {
    private let base = URL(string: "https://graph.instagram.com/v22.0")!

    private var token: String  { get throws { try KeychainManager.load(.instagramAccessToken) } }
    private var userID: String { get throws { try KeychainManager.load(.instagramUserID) } }

    // MARK: - Public API

    func publish(imageURL: URL, caption: String) async throws -> String {
        let containerID = try await createContainer(imageURL: imageURL, caption: caption)
        try await pollUntilFinished(containerID: containerID)
        return try await publishContainer(id: containerID)
    }

    // MARK: - Steps

    func createContainer(imageURL: URL, caption: String) async throws -> String {
        let uid   = try userID
        let token = try token
        let url   = base.appendingPathComponent("\(uid)/media")
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "image_url",    value: imageURL.absoluteString),
            URLQueryItem(name: "caption",      value: caption),
            URLQueryItem(name: "access_token", value: token),
        ]

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = comps.query?.data(using: .utf8)
        // Re-build as form body
        req = buildPOST(url: url, params: [
            "image_url": imageURL.absoluteString,
            "caption":   caption,
            "access_token": token,
        ])

        let data = try await send(req)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = json["id"] as? String else {
            throw AppError.instagramContainerFailed("No container ID returned")
        }
        return id
    }

    private func pollUntilFinished(containerID: String) async throws {
        let token = try token
        let url = base.appendingPathComponent(containerID)
        let statusURL = url.appending(queryItems: [
            URLQueryItem(name: "fields",       value: "status_code"),
            URLQueryItem(name: "access_token", value: token),
        ])

        for _ in 0..<20 {
            try await Task.sleep(for: .seconds(3))
            let (data, _) = try await URLSession.shared.data(from: statusURL)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let status = json["status_code"] as? String {
                if status == "FINISHED" { return }
                if status == "ERROR"    { throw AppError.instagramContainerFailed("Container error") }
            }
        }
        throw AppError.instagramPublishTimeout
    }

    private func publishContainer(id: String) async throws -> String {
        let uid   = try userID
        let token = try token
        let url   = base.appendingPathComponent("\(uid)/media_publish")
        let req = buildPOST(url: url, params: [
            "creation_id":  id,
            "access_token": token,
        ])
        let data = try await send(req)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let postID = json["id"] as? String else {
            throw AppError.instagramContainerFailed("No post ID returned")
        }
        return postID
    }

    // MARK: - Helpers

    private func buildPOST(url: URL, params: [String: String]) -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = params
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        return req
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "request failed"
            throw AppError.instagramContainerFailed(msg)
        }
        return data
    }
}
