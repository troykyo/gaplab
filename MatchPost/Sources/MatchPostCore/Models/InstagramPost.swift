import Foundation

struct InstagramPost {
    var caption: String
    var hashtags: [String]
    var score: String
    var hostedImageURL: URL?
    var containerID: String?
    var publishedPostID: String?

    var fullCaption: String {
        let tags = hashtags.map { "#\($0)" }.joined(separator: " ")
        return "\(caption)\n\n\(tags)"
    }

    var characterCount: Int { fullCaption.count }
    var isOverLimit: Bool { characterCount > 2_200 }
}
