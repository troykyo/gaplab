import Foundation
import ImageIO
import CoreLocation

struct EXIFData {
    let date: Date?
    let coordinate: CLLocationCoordinate2D?
}

enum EXIFReader {
    static func extract(from data: Data) -> EXIFData {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return EXIFData(date: nil, coordinate: nil)
        }

        let date = extractDate(from: props)
        let coord = extractCoordinate(from: props)
        return EXIFData(date: date, coordinate: coord)
    }

    private static func extractDate(from props: [String: Any]) -> Date? {
        let exif = props[kCGImagePropertyExifDictionary as String] as? [String: Any]
        let tiff = props[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
        let raw = exif?[kCGImagePropertyExifDateTimeOriginal as String] as? String
                ?? tiff?[kCGImagePropertyTIFFDateTime as String] as? String
        guard let raw else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: raw)
    }

    private static func extractCoordinate(from props: [String: Any]) -> CLLocationCoordinate2D? {
        guard let gps = props[kCGImagePropertyGPSDictionary as String] as? [String: Any],
              let lat = gps[kCGImagePropertyGPSLatitude as String] as? Double,
              let lon = gps[kCGImagePropertyGPSLongitude as String] as? Double else { return nil }
        let latRef = gps[kCGImagePropertyGPSLatitudeRef as String] as? String ?? "N"
        let lonRef = gps[kCGImagePropertyGPSLongitudeRef as String] as? String ?? "E"
        return CLLocationCoordinate2D(
            latitude:  latRef == "S" ? -lat : lat,
            longitude: lonRef == "W" ? -lon : lon
        )
    }
}
