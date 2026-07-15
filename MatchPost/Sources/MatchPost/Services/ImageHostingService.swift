import Foundation

final class ImageHostingService {
    func upload(_ jpegData: Data) async throws -> URL {
        let cloudName   = try KeychainManager.load(.cloudinaryCloudName)
        let uploadPreset = try KeychainManager.load(.cloudinaryUploadPreset)

        guard let uploadURL = URL(string: "https://api.cloudinary.com/v1_1/\(cloudName)/image/upload") else {
            throw AppError.imageUploadFailed("Invalid Cloudinary URL")
        }

        let boundary = "MatchPost-\(UUID().uuidString)"
        var body = Data()

        func append(_ string: String) { body.append(Data(string.utf8)) }
        func field(_ name: String, _ value: String) {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            append("\(value)\r\n")
        }

        field("upload_preset", uploadPreset)
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"match.jpg\"\r\n")
        append("Content-Type: image/jpeg\r\n\r\n")
        body.append(jpegData)
        append("\r\n--\(boundary)--\r\n")

        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "upload failed"
            throw AppError.imageUploadFailed(msg)
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let urlStr = json["secure_url"] as? String,
              let url = URL(string: urlStr) else {
            throw AppError.imageUploadFailed("No URL in response")
        }
        return url
    }
}
