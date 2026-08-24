import Foundation
import SwiftData

@Model
final class Detector {
    var location: String
    var type: String
    var manufacturer: String
    var model: String
    var manufactureDate: Date?
    var installationDate: Date?
    var batteryType: String
    var isHardwired: Bool
    var replacementDate: Date?
    var notes: String

    init(location: String, type: String = "Combination", manufacturer: String = "", model: String = "", manufactureDate: Date? = nil, installationDate: Date? = nil, batteryType: String = "", isHardwired: Bool = false, replacementDate: Date? = nil, notes: String = "") {
        self.location = location
        self.type = type
        self.manufacturer = manufacturer
        self.model = model
        self.manufactureDate = manufactureDate
        self.installationDate = installationDate
        self.batteryType = batteryType
        self.isHardwired = isHardwired
        self.replacementDate = replacementDate ?? Self.calculateReplacementDate(manufactureDate: manufactureDate, installationDate: installationDate)
        self.notes = notes
    }

    static func calculateReplacementDate(manufactureDate: Date?, installationDate: Date?) -> Date? {
        let base = manufactureDate ?? installationDate
        guard let base else { return nil }
        return Calendar.current.date(byAdding: .year, value: 10, to: base)
    }
}

@Model
final class Consumable {
    var name: String
    var type: String
    var size: String
    var manufacturer: String
    var modelPartNumber: String
    var purchaseLink: String
    var replacementIntervalMonths: Int?
    var lastReplaced: Date?
    var nextReplacement: Date?
    var notes: String

    init(name: String, type: String = "", size: String = "", manufacturer: String = "", modelPartNumber: String = "", purchaseLink: String = "", replacementIntervalMonths: Int? = nil, lastReplaced: Date? = nil, nextReplacement: Date? = nil, notes: String = "") {
        self.name = name
        self.type = type
        self.size = size
        self.manufacturer = manufacturer
        self.modelPartNumber = modelPartNumber
        self.purchaseLink = purchaseLink
        self.replacementIntervalMonths = replacementIntervalMonths
        self.lastReplaced = lastReplaced
        if let nextReplacement {
            self.nextReplacement = nextReplacement
        } else if let months = replacementIntervalMonths, let lastReplaced {
            self.nextReplacement = Calendar.current.date(byAdding: .month, value: months, to: lastReplaced)
        } else {
            self.nextReplacement = nil
        }
        self.notes = notes
    }
}
