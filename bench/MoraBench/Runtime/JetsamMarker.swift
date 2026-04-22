import Foundation

enum JetsamMarker {
    private static var fileURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return support.appending(path: "endurance-in-progress.json")
    }

    struct Marker: Codable {
        let startedAt: Date
        let modelID: String
        let promptID: String
    }

    static func arm(modelID: String, promptID: String) {
        let marker = Marker(startedAt: Date(), modelID: modelID, promptID: promptID)
        if let data = try? JSONEncoder().encode(marker) {
            try? data.write(to: fileURL)
        }
    }

    static func disarm() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    static func detectPreviousKill() -> Marker? {
        guard let data = try? Data(contentsOf: fileURL),
              let marker = try? JSONDecoder().decode(Marker.self, from: data) else {
            return nil
        }
        return marker
    }
}
