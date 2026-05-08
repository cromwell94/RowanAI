import Foundation
import MapKit
import CoreLocation

// MARK: - Location Search Completer
// Thin observable wrapper around MKLocalSearchCompleter. Used by Date Planner
// (search any area) and EditContactView (save where a contact lives).
//
// Usage:
//   1. Bind a TextField to `query` — autocomplete suggestions appear in
//      `suggestions`.
//   2. When the user picks a suggestion, call `resolve(_:)` to convert it
//      into a coordinate + canonical address string via MKLocalSearch.

@MainActor
@Observable
final class LocationSearchCompleter: NSObject, MKLocalSearchCompleterDelegate {
    var query: String = "" {
        didSet { completer.queryFragment = query }
    }
    var suggestions: [MKLocalSearchCompletion] = []
    var isSearching: Bool = false

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    // Resolve a completion to a coordinate and canonical title/subtitle.
    // The canonical title comes back as the completion's title (which is
    // typically the city/neighborhood), with subtitle as further detail.
    struct ResolvedLocation {
        let title: String
        let subtitle: String
        let coordinate: CLLocationCoordinate2D
    }

    func resolve(_ completion: MKLocalSearchCompletion) async -> ResolvedLocation? {
        let request = MKLocalSearch.Request(completion: completion)
        do {
            let response = try await MKLocalSearch(request: request).start()
            guard let item = response.mapItems.first else { return nil }
            return ResolvedLocation(
                title: completion.title,
                subtitle: completion.subtitle,
                coordinate: item.placemark.coordinate
            )
        } catch {
            return nil
        }
    }

    func clear() {
        query = ""
        suggestions = []
    }

    // MARK: MKLocalSearchCompleterDelegate

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results
        Task { @MainActor in
            self.suggestions = results
            self.isSearching = false
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.suggestions = []
            self.isSearching = false
        }
    }
}

// MARK: - Search Location
// Represents a "where are we searching" anchor for Date Planner. Either the
// user's GPS region, an area they searched for, a contact's saved area, or
// the midpoint between user and a contact.

struct SearchLocation: Equatable {
    let title: String
    let subtitle: String?
    let latitude: Double
    let longitude: Double
    let kind: Kind

    enum Kind: Equatable {
        case area               // user-typed location
        case contact(String)    // contact name
        case midpoint(String)   // contact name (other side of the midpoint)
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(title: String,
         subtitle: String? = nil,
         coordinate: CLLocationCoordinate2D,
         kind: Kind) {
        self.title = title
        self.subtitle = subtitle
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.kind = kind
    }

    // Simple lat/lng average — fine for typical metro-area use; would be
    // wrong for points spanning the antimeridian, which is fine to ignore.
    static func midpoint(between a: CLLocationCoordinate2D,
                         and b: CLLocationCoordinate2D,
                         contactName: String,
                         userLabel: String = "you") -> SearchLocation {
        let lat = (a.latitude + b.latitude) / 2.0
        let lng = (a.longitude + b.longitude) / 2.0
        return SearchLocation(
            title: "Midpoint",
            subtitle: "Between \(userLabel) and \(contactName)",
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
            kind: .midpoint(contactName)
        )
    }
}
