import Foundation

enum AppError: LocalizedError, Equatable {
    case noImageSelected
    case imageResizeFailed
    case claudeVisionFailed(String)
    case claudeCaptionFailed(String)
    case knvbRequestFailed(String)
    case matchNotFound
    case imageUploadFailed(String)
    case instagramContainerFailed(String)
    case instagramPublishTimeout
    case instagramTokenExpired
    case keychainReadFailed(String)
    case keychainWriteFailed(String)
    case noPlayerConfigured
    case htmlGenerationFailed(String)

    var errorDescription: String? {
        switch self {
        case .noImageSelected:             return "No photo selected."
        case .imageResizeFailed:           return "Could not resize the image."
        case .claudeVisionFailed(let m):   return "Vision analysis failed: \(m)"
        case .claudeCaptionFailed(let m):  return "Caption generation failed: \(m)"
        case .knvbRequestFailed(let m):    return "KNVB lookup failed: \(m)"
        case .matchNotFound:               return "No matching fixture found. Enter the details manually."
        case .imageUploadFailed(let m):    return "Image upload failed: \(m)"
        case .instagramContainerFailed(let m): return "Instagram container error: \(m)"
        case .instagramPublishTimeout:     return "Instagram took too long. Tap Retry."
        case .instagramTokenExpired:       return "Instagram session expired. Re-connect in Settings."
        case .keychainReadFailed(let k):   return "Could not read \(k) from Keychain."
        case .keychainWriteFailed(let k):  return "Could not save \(k) to Keychain."
        case .noPlayerConfigured:          return "Set up a player profile first."
        case .htmlGenerationFailed(let m): return "Profile export failed: \(m)"
        }
    }
}
