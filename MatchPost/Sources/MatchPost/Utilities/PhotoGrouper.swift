import Foundation

/// A photo candidate ready to be grouped and staged.
public struct StagingCandidate {
    public let id: String          // phAssetLocalIdentifier, or UUID string for file imports
    public let exifDate: Date?
    public let thumbnailData: Data?
    public let imageData: Data?    // nil for PHAsset staging (fetched on demand later)
    public let latitude: Double    // 0 when the photo has no GPS data
    public let longitude: Double

    public init(id: String, exifDate: Date?, thumbnailData: Data?, imageData: Data? = nil,
                latitude: Double = 0, longitude: Double = 0) {
        self.id            = id
        self.exifDate      = exifDate
        self.thumbnailData = thumbnailData
        self.imageData     = imageData
        self.latitude      = latitude
        self.longitude     = longitude
    }
}

public enum PhotoGrouper {
    /// Group candidates whose consecutive EXIF dates fall within `windowHours` of each other.
    ///
    /// Uses a sliding window: each photo is compared to the previous one, so a match session
    /// that lasts 85 minutes (photos spread across the game) lands in one group even though
    /// first-to-last is more than half the window.
    ///
    /// Photos with no EXIF date each become their own solo group, sorted to the end of the
    /// queue (consistent with `StagedPhoto.pendingRequest` nil-last ordering).
    public static func group(
        _ candidates: [StagingCandidate],
        windowHours: Double = 2.0
    ) -> [[StagingCandidate]] {
        let windowSeconds = windowHours * 3_600

        let dated   = candidates.filter { $0.exifDate != nil }
                                .sorted { $0.exifDate! < $1.exifDate! }
        let undated = candidates.filter { $0.exifDate == nil }

        var groups: [[StagingCandidate]] = []
        var current: [StagingCandidate]  = []

        for candidate in dated {
            if current.isEmpty {
                current.append(candidate)
            } else if candidate.exifDate!.timeIntervalSince(current.last!.exifDate!) <= windowSeconds {
                current.append(candidate)
            } else {
                groups.append(current)
                current = [candidate]
            }
        }
        if !current.isEmpty { groups.append(current) }

        // Each undated photo is its own group (we can't know if they share a session).
        for u in undated { groups.append([u]) }

        return groups
    }
}
