import Foundation
import SwiftData

@Model
final class Home {
    var name: String
    var address: String
    var yearBuilt: Int?
    var purchaseDate: Date?
    var squareFeet: Int?
    var notes: String

    init(name: String = "My Home", address: String = "", yearBuilt: Int? = nil, purchaseDate: Date? = nil, squareFeet: Int? = nil, notes: String = "") {
        self.name = name
        self.address = address
        self.yearBuilt = yearBuilt
        self.purchaseDate = purchaseDate
        self.squareFeet = squareFeet
        self.notes = notes
    }
}

@Model
final class Room {
    var name: String
    var notes: String
    var isFavorite: Bool
    // Optional for lightweight migration of homes created before exterior/property areas existed.
    var areaTypeRaw: String?

    init(name: String, notes: String = "", isFavorite: Bool = false, areaType: HomeAreaType = .interior) {
        self.name = name
        self.notes = notes
        self.isFavorite = isFavorite
        self.areaTypeRaw = areaType.rawValue
    }

    var areaType: HomeAreaType {
        get { HomeAreaType(rawValue: areaTypeRaw ?? "") ?? .interior }
        set { areaTypeRaw = newValue.rawValue }
    }
}

@Model
final class Vendor {
    var businessName: String
    var contactName: String
    var category: String
    var phone: String
    var email: String
    var website: String
    var address: String
    var notes: String
    var isFavorite: Bool

    init(businessName: String, contactName: String = "", category: String = "", phone: String = "", email: String = "", website: String = "", address: String = "", notes: String = "", isFavorite: Bool = false) {
        self.businessName = businessName
        self.contactName = contactName
        self.category = category
        self.phone = phone
        self.email = email
        self.website = website
        self.address = address
        self.notes = notes
        self.isFavorite = isFavorite
    }
}

@Model
final class HomeSystem {
    var name: String
    var type: String
    var manufacturer: String
    var model: String
    var serialNumber: String
    var installationDate: Date?
    var purchaseCost: Double?
    var warrantyExpiration: Date?
    var expectedServiceLifeYears: Int?
    var location: String
    var notes: String
    var website: String
    var vendor: Vendor?
    var room: Room?
    var sourceProject: Project?

    init(name: String, type: String, manufacturer: String = "", model: String = "", serialNumber: String = "", installationDate: Date? = nil, purchaseCost: Double? = nil, warrantyExpiration: Date? = nil, expectedServiceLifeYears: Int? = nil, location: String = "", notes: String = "", website: String = "", vendor: Vendor? = nil, room: Room? = nil, sourceProject: Project? = nil) {
        self.name = name
        self.type = type
        self.manufacturer = manufacturer
        self.model = model
        self.serialNumber = serialNumber
        self.installationDate = installationDate
        self.purchaseCost = purchaseCost
        self.warrantyExpiration = warrantyExpiration
        self.expectedServiceLifeYears = expectedServiceLifeYears
        self.location = location
        self.notes = notes
        self.website = website
        self.vendor = vendor
        self.room = room
        self.sourceProject = sourceProject
    }

    var locationName: String { room?.name ?? location }
}

@Model
final class Appliance {
    var name: String
    var category: String
    var manufacturer: String
    var model: String
    var serialNumber: String
    var purchaseDate: Date?
    var purchasePrice: Double?
    var purchasedFrom: String
    var warrantyExpiration: Date?
    var manufacturerWebsite: String
    var productRegistrationLink: String
    var notes: String
    var room: Room?
    var sourceProject: Project?

    init(name: String, category: String, manufacturer: String = "", model: String = "", serialNumber: String = "", purchaseDate: Date? = nil, purchasePrice: Double? = nil, purchasedFrom: String = "", warrantyExpiration: Date? = nil, manufacturerWebsite: String = "", productRegistrationLink: String = "", notes: String = "", room: Room? = nil, sourceProject: Project? = nil) {
        self.name = name
        self.category = category
        self.manufacturer = manufacturer
        self.model = model
        self.serialNumber = serialNumber
        self.purchaseDate = purchaseDate
        self.purchasePrice = purchasePrice
        self.purchasedFrom = purchasedFrom
        self.warrantyExpiration = warrantyExpiration
        self.manufacturerWebsite = manufacturerWebsite
        self.productRegistrationLink = productRegistrationLink
        self.notes = notes
        self.room = room
        self.sourceProject = sourceProject
    }
}

@Model
final class PaintFinish {
    // roomName is retained for compatibility with paint records created before linked rooms/areas.
    var roomName: String
    var room: Room?
    var surface: String
    var brand: String
    var productLine: String
    var colorName: String
    var colorCode: String
    var sheen: String
    var store: String
    var purchaseDate: Date?
    var quantity: Double?
    var containerSize: String
    var cost: Double?
    var notes: String
    var productLink: String
    var sourceProject: Project?

    init(roomName: String = "", room: Room? = nil, surface: String, brand: String = "", productLine: String = "", colorName: String = "", colorCode: String = "", sheen: String = "", store: String = "", purchaseDate: Date? = nil, quantity: Double? = nil, containerSize: String = "", cost: Double? = nil, notes: String = "", productLink: String = "", sourceProject: Project? = nil) {
        self.roomName = room?.name ?? roomName
        self.room = room
        self.surface = surface
        self.brand = brand
        self.productLine = productLine
        self.colorName = colorName
        self.colorCode = colorCode
        self.sheen = sheen
        self.store = store
        self.purchaseDate = purchaseDate
        self.quantity = quantity
        self.containerSize = containerSize
        self.cost = cost
        self.notes = notes
        self.productLink = productLink
        self.sourceProject = sourceProject
    }

    var locationName: String {
        room?.name ?? roomName
    }
}


@Model
final class Fixture {
    var name: String
    var category: String
    var manufacturer: String
    var model: String
    var partNumber: String
    var finishColor: String
    var installationDate: Date?
    var purchaseDate: Date?
    var purchasePrice: Double?
    var purchasedFrom: String
    var warrantyExpiration: Date?
    var productLink: String
    var notes: String
    var room: Room?
    var vendor: Vendor?
    var sourceProject: Project?

    init(name: String, category: String = "", manufacturer: String = "", model: String = "", partNumber: String = "", finishColor: String = "", installationDate: Date? = nil, purchaseDate: Date? = nil, purchasePrice: Double? = nil, purchasedFrom: String = "", warrantyExpiration: Date? = nil, productLink: String = "", notes: String = "", room: Room? = nil, vendor: Vendor? = nil, sourceProject: Project? = nil) {
        self.name = name
        self.category = category
        self.manufacturer = manufacturer
        self.model = model
        self.partNumber = partNumber
        self.finishColor = finishColor
        self.installationDate = installationDate
        self.purchaseDate = purchaseDate
        self.purchasePrice = purchasePrice
        self.purchasedFrom = purchasedFrom
        self.warrantyExpiration = warrantyExpiration
        self.productLink = productLink
        self.notes = notes
        self.room = room
        self.vendor = vendor
        self.sourceProject = sourceProject
    }
}
