//
//  ProfileView.swift
//  ExAstra
//
//  Created by Mahadik, Amit on 12/22/25.
//

import SwiftUI
import MapKit
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Profile.updatedAt, order: .reverse) private var profiles: [Profile]

    @AppStorage("selectedProfileID") private var selectedProfileID: String = ""

    // Keep AppState as the view-model/service hub for computation + API calls.
    @StateObject private var state = AppState()

    // The active SwiftData profile record we persist into.
    @State private var activeProfile: Profile? = nil

    @State private var isLookingUpSigns: Bool = false
    @State private var signsResult: AstrologySignsAIResult? = nil
    @State private var signsError: String? = nil

    @State private var isValidatingPlace: Bool = false
    @State private var validatedMapItem: MKMapItem? = nil
    @State private var placeValidationError: String? = nil

    @State private var showResetConfirm = false

    // Unified (in-unison) display values for the three signs
    @State private var displayedMoonSign: String = "—"
    @State private var displayedSunSign: String = "—"
    @State private var displayedChineseSign: String = "—"
    @State private var unifiedSignsError: String? = nil

    private var isPlaceValid: Bool {
        // Treat place as valid if we have persisted validated coordinates + timezone.
        state.birthLatitude != nil && state.birthLongitude != nil && state.birthTimeZoneIdentifier != nil
    }

    private var selectedProfile: Profile? {
        profiles.first { $0.id.uuidString == selectedProfileID }
    }

    private var currentProfileTitle: String {
        let name = selectedProfile?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "Profile" : name
    }

    var body: some View {
        Form {
            Section("Profile") {
                HStack {
                    Text("Name")
                    Spacer()
                    TextField("", text: $state.name)
                        .multilineTextAlignment(.trailing)
                        .textContentType(.name)
                        .submitLabel(.done)
                }

                Picker("Gender", selection: $state.gender) {
                    ForEach(Gender.allCases) { g in
                        Text(g.rawValue).tag(g)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Birth Date")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text("Birth Time")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        DatePicker(
                            "Date of Birth",
                            selection: $state.dob,
                            displayedComponents: .date
                        )
                        .labelsHidden()
                        .onChange(of: state.dob) { _, _ in
                            invalidateValidatedPlaceAndDerivedResults()
                        }

                        Spacer()

                        DatePicker(
                            "Time of Birth",
                            selection: Binding(
                                get: { state.timeOfBirthPickerDate },
                                set: { state.timeOfBirthPickerDate = $0 }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                        .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
                        .onChange(of: state.timeOfBirthPickerDate) { _, _ in
                            invalidateValidatedPlaceAndDerivedResults()
                        }
                    }
                    .accessibilityElement(children: .contain)
                }

                HStack(alignment: .center, spacing: 10) {
                    TextField("Place of Birth (City, Country)", text: $state.placeOfBirth)
                        .textContentType(.addressCity)
                        .onChange(of: state.placeOfBirth) { _, _ in
                            invalidateValidatedPlaceAndDerivedResults()
                        }

                    if isValidatingPlace {
                        ProgressView()
                    } else if isPlaceValid {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .accessibilityLabel("Place of birth validated")
                    }

                    Button {
                        validatePlace()
                    } label: {
                        if isValidatingPlace {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text(isPlaceValid ? "Revalidate" : "Validate")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isValidatingPlace)
                }

                if let lat = state.birthLatitude, let lon = state.birthLongitude {
                    HStack(spacing: 8) {
                        Image(systemName: "globe")
                            .symbolRenderingMode(.hierarchical)

                        Text(formatLatLonDM(latitude: lat, longitude: lon))

                        Image(systemName: "clock")
                            .symbolRenderingMode(.hierarchical)

                        Text(state.birthTimeZoneIdentifier ?? "Unknown")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                } else if let placeValidationError, !placeValidationError.isEmpty {
                    Text(placeValidationError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                } else {
                    Text("Tip: Use ‘City, State/Region, Country’ for best results.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                VStack(spacing: 12) {
                    SignCard(
                        title: "Lunar (Ephemeris)",
                        systemImage: "moon.stars.fill",
                        value: displayedMoonSign
                    )

                    SignCard(
                        title: "Sun Sign",
                        systemImage: "sun.max.fill",
                        value: displayedSunSign
                    )

                    SignCard(
                        title: "Chinese Zodiac",
                        systemImage: "sparkles",
                        value: displayedChineseSign
                    )

                    if isLookingUpSigns {
                        StatusCard(
                            systemImage: "hourglass",
                            text: "Calculating signs…",
                            showsProgress: true
                        )
                    } else if !isPlaceValid {
                        StatusCard(
                            systemImage: "location.slash",
                            text: "Validate your place of birth to calculate your signs."
                        )
                    }

                    if let unifiedSignsError, !unifiedSignsError.isEmpty {
                        StatusCard(
                            systemImage: "exclamationmark.triangle.fill",
                            text: unifiedSignsError
                        )
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Signs")
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
        .onChange(of: selectedProfileID) { _, newValue in
            guard !newValue.isEmpty else { return }
            if let match = profiles.first(where: { $0.id.uuidString == newValue }) {
                activeProfile = match
                syncStateFromProfile(match)

                // Refresh displayed values immediately
                displayedMoonSign = (state.lunarSignDeterministic.isEmpty ? "—" : state.lunarSignDeterministic)
                displayedSunSign = state.solarSign.isEmpty ? "—" : state.solarSign
                displayedChineseSign = state.chineseSign.isEmpty ? "—" : state.chineseSign
                unifiedSignsError = nil
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Section("Select Profile") {
                        Picker("Profile", selection: $selectedProfileID) {
                            ForEach(profiles) { profile in
                                Text(profile.name.isEmpty ? "Unnamed Profile" : profile.name)
                                    .tag(profile.id.uuidString)
                            }
                        }
                    }

                    Divider()

                    Button {
                        createNewProfile()
                    } label: {
                        Label("Add Profile", systemImage: "plus")
                    }

                    Button(role: .destructive) {
                        showResetConfirm = true
                    } label: {
                        Label("Delete Profile", systemImage: "trash")
                    }
                    .disabled(profiles.count <= 1)
                } label: {
                    Label(currentProfileTitle, systemImage: "person.crop.circle")
                }
            }
        }
        .confirmationDialog(
            "Delete Profile?",
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteActiveProfile()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete the current profile.")
        }
        .onAppear {
            ensureActiveProfileLoaded()
            if displayedMoonSign == "—" {
                let existingMoon = state.lunarSignDeterministic
                if !existingMoon.isEmpty, existingMoon != "—" { displayedMoonSign = existingMoon }
            }
            if displayedSunSign == "—", let signsResult {
                displayedSunSign = signsResult.solarSign
                displayedChineseSign = signsResult.chineseZodiacDisplay
            }
            // Auto-populate all three signs on app start if we already have a validated place
            // (persisted coordinates + timezone) and nothing is displayed yet.
            if isPlaceValid,
               displayedMoonSign == "—",
               displayedSunSign == "—",
               displayedChineseSign == "—",
               !isLookingUpSigns {
                startUnifiedSignsLookup()
            }

            // API key is provided via Info.plist only; runtime edits are not supported in the Profile screen.
        }
    }

    // MARK: - Helpers

    private func formatCoordinateDM(_ value: Double, positive: String, negative: String) -> String {
        let absValue = abs(value)
        let degrees = Int(absValue)
        let minutes = Int((absValue - Double(degrees)) * 60.0)
        let direction = value >= 0 ? positive : negative
        return "\(degrees)° \(minutes)′ \(direction)"
    }

    private func formatLatLonDM(latitude: Double, longitude: Double) -> String {
        let lat = formatCoordinateDM(latitude, positive: "N", negative: "S")
        let lon = formatCoordinateDM(longitude, positive: "E", negative: "W")
        return "\(lat), \(lon)"
    }

    private func invalidateValidatedPlaceAndDerivedResults() {
        validatedMapItem = nil
        placeValidationError = nil

        state.birthLatitude = nil
        state.birthLongitude = nil
        state.birthTimeZoneIdentifier = nil

        signsResult = nil
        signsError = nil
        isLookingUpSigns = false

        state.lunarSignDeterministic = ""
        state.moonLongitudeDeterministic = nil
        state.lunarSignDeterministicError = nil

        displayedMoonSign = "—"
        displayedSunSign = "—"
        displayedChineseSign = "—"
        unifiedSignsError = nil
    }

    private func validatePlace() {
        isValidatingPlace = true
        placeValidationError = nil
        validatedMapItem = nil

        let query = state.placeOfBirth.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            do {
                guard !query.isEmpty else {
                    throw NSError(
                        domain: "PlaceValidation",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Please enter a city and country (e.g., Pune, India)."]
                    )
                }

                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = query

                let search = MKLocalSearch(request: request)
                let response = try await search.start()

                await MainActor.run {
                    if let first = response.mapItems.first {
                        validatedMapItem = first
                        isValidatingPlace = false

                        let coord = first.location.coordinate
                        state.birthLatitude = coord.latitude
                        state.birthLongitude = coord.longitude
                        state.birthTimeZoneIdentifier = first.timeZone?.identifier

                        let city = first.name?.trimmingCharacters(in: .whitespacesAndNewlines)

                        // iOS 26 deprecates `placemark`; prefer `address` / `addressRepresentations`.
                        let country: String? = {
                            if #available(iOS 26.0, *) {
                                // Best-effort: derive country/region from the full address string.
                                // (MapKit no longer provides structured country fields on MKMapItem.)
                                let full = first.address?.fullAddress
                                let last = full?.split(separator: ",").last.map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                                return (last?.isEmpty == false) ? last : nil
                            } else {
                                return first.placemark.country?.trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                        }()

                        if let city, !city.isEmpty, let country, !country.isEmpty {
                            state.placeOfBirth = "\(city), \(country)"
                        } else if let city, !city.isEmpty {
                            state.placeOfBirth = city
                        } else {
                            state.placeOfBirth = query
                        }

                        startUnifiedSignsLookup()
                    } else {
                        placeValidationError = "No matching location found. Try a more specific format like ‘City, State/Region, Country’."
                        isValidatingPlace = false
                    }
                }
            } catch {
                await MainActor.run {
                    placeValidationError = error.localizedDescription
                    isValidatingPlace = false
                }
            }
        }
    }


    private func startUnifiedSignsLookup() {
        guard isPlaceValid else { return }

        isLookingUpSigns = true
        signsError = nil
        signsResult = nil
        unifiedSignsError = nil

        displayedMoonSign = "—"
        displayedSunSign = "—"
        displayedChineseSign = "—"

        Task {
            do {
                async let moonInfo = state.computeDeterministicMoonInfo()
                async let ai = state.lookupAstrologySignsViaSwiftOpenAI()

                let (moon, aiResult) = try await (moonInfo, ai)

                await MainActor.run {
                    displayedMoonSign = moon.sign
                    displayedSunSign = aiResult.solarSign
                    displayedChineseSign = aiResult.chineseZodiacDisplay

                    // View-local
                    signsResult = aiResult

                    // ✅ COMMIT TO APP STATE
                    state.lunarSignDeterministic = moon.sign
                    state.moonLongitudeDeterministic = moon.longitude
                    state.solarSign = aiResult.solarSign
                    state.chineseSign = aiResult.chineseZodiacDisplay

                    // Persist so it survives app restarts (SwiftData)
                    persistActiveProfile()

                    isLookingUpSigns = false
                }
            } catch {
                await MainActor.run {
                    unifiedSignsError = error.localizedDescription
                    isLookingUpSigns = false
                }
            }
        }
    }

    // MARK: - SwiftData wiring

    private func ensureActiveProfileLoaded() {
        // Try restoring previously selected profile
        if let selected = selectedProfile {
            activeProfile = selected
            syncStateFromProfile(selected)
            return
        }

        // Fallback to most recently updated profile
        if let existing = profiles.first {
            activeProfile = existing
            selectedProfileID = existing.id.uuidString
            syncStateFromProfile(existing)
            return
        }

        // No profiles yet → create default
        let created = Profile(name: state.name.isEmpty ? "" : state.name)
        modelContext.insert(created)
        activeProfile = created
        selectedProfileID = created.id.uuidString
        persistActiveProfile()
    }

    private func persistActiveProfile() {
        guard let activeProfile else { return }
        syncProfileFromState(activeProfile)
        do {
            try modelContext.save()
        } catch {
            // Non-fatal: keep UI responsive; surface error in the view if you want.
            print("SwiftData save failed:", error)
        }
    }

    private func createNewProfile() {
        let newProfile = Profile(name: "")
        modelContext.insert(newProfile)
        activeProfile = newProfile
        selectedProfileID = newProfile.id.uuidString
        syncStateFromProfile(newProfile)
        try? modelContext.save()
    }

    private func deleteActiveProfile() {
        guard let activeProfile else { return }
        modelContext.delete(activeProfile)
        try? modelContext.save()

        // Select a fallback profile
        if let fallback = profiles.first(where: { $0.id != activeProfile.id }) {
            self.activeProfile = fallback
            self.selectedProfileID = fallback.id.uuidString
            syncStateFromProfile(fallback)
        } else {
            self.activeProfile = nil
            self.selectedProfileID = ""
        }
    }

    private func syncStateFromProfile(_ profile: Profile) {
        // Core identity
        state.name = profile.name

        // Demographics
        if let g = Gender(rawValue: profile.genderRawValue) {
            state.gender = g
        }

        // Birth date/time
        state.dob = profile.dob
        state.tobHour = profile.tobHour
        state.tobMinute = profile.tobMinute
        state.tobSecond = profile.tobSecond

        // Location
        state.placeOfBirth = profile.placeOfBirth
        state.birthLatitude = profile.birthLatitude
        state.birthLongitude = profile.birthLongitude
        state.birthTimeZoneIdentifier = profile.birthTimeZoneIdentifier

        // Derived signs
        state.lunarSignDeterministic = profile.lunarSignDeterministic
        state.moonLongitudeDeterministic = profile.moonLongitudeDeterministic
        state.solarSign = profile.solarSign
        state.chineseSign = profile.chineseSign
    }

    private func syncProfileFromState(_ profile: Profile) {
        profile.name = state.name

        profile.genderRawValue = state.gender.rawValue

        profile.dob = state.dob
        profile.tobHour = state.tobHour
        profile.tobMinute = state.tobMinute
        profile.tobSecond = state.tobSecond

        profile.placeOfBirth = state.placeOfBirth
        profile.birthLatitude = state.birthLatitude
        profile.birthLongitude = state.birthLongitude
        profile.birthTimeZoneIdentifier = state.birthTimeZoneIdentifier

        profile.lunarSignDeterministic = state.lunarSignDeterministic
        profile.moonLongitudeDeterministic = state.moonLongitudeDeterministic
        profile.solarSign = state.solarSign
        profile.chineseSign = state.chineseSign

        profile.updatedAt = .now
        selectedProfileID = profile.id.uuidString
    }

    // MARK: - UI Cards

    private struct SignCard: View {
        let title: String
        let systemImage: String
        let value: String

        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .symbolRenderingMode(.hierarchical)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Text(value)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private struct StatusCard: View {
        let systemImage: String
        let text: String
        var showsProgress: Bool = false

        var body: some View {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .symbolRenderingMode(.hierarchical)

                Text(text)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                if showsProgress {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(12)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    // (No runtime API key helpers — app relies on build-time Info.plist configuration.)
}

#Preview("ProfileView") {
    NavigationStack {
        ProfileView()
            .modelContainer(for: [Item.self, Profile.self])
    }
}

private enum ProfileView_Previews {
    static func makePreviewState() -> AppState {
        let s = AppState()
        s.name = "Rahul Mahadik"
        s.gender = .male
        s.dob = AppState.dateFromYMDUTC(year: 2005, month: 1, day: 15)
        s.tobHour = 3
        s.tobMinute = 42
        s.tobSecond = 0
        s.placeOfBirth = "Mountain View, CA"
        s.birthTimeZoneIdentifier = "America/Los_Angeles"
        s.birthLatitude = 37.39261
        s.birthLongitude = -122.07978
        s.lunarSignDeterministic = "Pisces (Meena)"
        s.moonLongitudeDeterministic = 339.6269
        return s
    }
}
