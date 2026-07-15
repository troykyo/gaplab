import Foundation
import CoreLocation

/// A ground that counts as "home" — any photo taken within `radiusMeters` of it.
struct HomeVenue: Codable, Identifiable, Equatable {
    var name: String
    var latitude: Double
    var longitude: Double
    var radiusMeters: Double = 1_000

    var id: String { name }
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// Decides home vs away from photo GPS coordinates.
enum HomeVenueLocator {
    /// Default home grounds. Coordinates are approximate club locations in Eindhoven —
    /// verify/adjust them in Settings → Home Venues if the 1 km circle misses the pitch.
    static let defaultVenues: [HomeVenue] = [
        HomeVenue(name: "DBS",     latitude: 51.4483, longitude: 5.4416),
        HomeVenue(name: "vv Acht", latitude: 51.4780, longitude: 5.4530),
    ]

    private static let defaultsKey = "homeVenues"

    static var venues: [HomeVenue] {
        get {
            guard let data = UserDefaults.standard.data(forKey: defaultsKey),
                  let decoded = try? JSONDecoder().decode([HomeVenue].self, from: data),
                  !decoded.isEmpty else { return defaultVenues }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: defaultsKey)
            }
        }
    }

    static func reset() { UserDefaults.standard.removeObject(forKey: defaultsKey) }

    /// The home venue containing this coordinate, or nil → away (or unknown ground).
    static func homeVenue(latitude: Double, longitude: Double) -> HomeVenue? {
        guard latitude != 0 || longitude != 0 else { return nil }
        let photo = CLLocation(latitude: latitude, longitude: longitude)
        return venues.first { venue in
            let ground = CLLocation(latitude: venue.latitude, longitude: venue.longitude)
            return photo.distance(from: ground) <= venue.radiusMeters
        }
    }
}
