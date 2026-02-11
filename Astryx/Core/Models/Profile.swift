//
//  Profile.swift
//  Astryx
//
//  Created by Mahadik, Amit on 2/5/26.
//



import Foundation
import SwiftData

@Model
final class Profile {
    // MARK: - Identity
    @Attribute(.unique) var id: UUID
    var name: String

    // MARK: - Demographics
    /// Raw value storage to stay SwiftData-compatible
    var genderRawValue: String

    // MARK: - Birth date & time
    var dob: Date
    var tobHour: Int
    var tobMinute: Int
    var tobSecond: Int

    // MARK: - Birth location
    var placeOfBirth: String
    var birthLatitude: Double?
    var birthLongitude: Double?
    var birthTimeZoneIdentifier: String?

    // MARK: - Derived astrology results
    var lunarSignDeterministic: String
    var moonLongitudeDeterministic: Double?
    var solarSign: String
    var chineseSign: String

    // MARK: - Metadata
    var notes: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String = "",
        genderRawValue: String = "unspecified",
        dob: Date = .now,
        tobHour: Int = 0,
        tobMinute: Int = 0,
        tobSecond: Int = 0,
        placeOfBirth: String = "",
        birthLatitude: Double? = nil,
        birthLongitude: Double? = nil,
        birthTimeZoneIdentifier: String? = nil,
        lunarSignDeterministic: String = "",
        moonLongitudeDeterministic: Double? = nil,
        solarSign: String = "",
        chineseSign: String = "",
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.genderRawValue = genderRawValue
        self.dob = dob
        self.tobHour = tobHour
        self.tobMinute = tobMinute
        self.tobSecond = tobSecond
        self.placeOfBirth = placeOfBirth
        self.birthLatitude = birthLatitude
        self.birthLongitude = birthLongitude
        self.birthTimeZoneIdentifier = birthTimeZoneIdentifier
        self.lunarSignDeterministic = lunarSignDeterministic
        self.moonLongitudeDeterministic = moonLongitudeDeterministic
        self.solarSign = solarSign
        self.chineseSign = chineseSign
        self.notes = notes
        self.createdAt = .now
        self.updatedAt = .now
    }
}
