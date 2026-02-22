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
    private static let maxProfiles = 5

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Profile.updatedAt, order: .reverse) private var profiles: [Profile]

    @AppStorage("selectedProfileID") private var selectedProfileID: String = ""

    // Use the shared app-level state so Profile/Focus/Chat stay in sync.
    @EnvironmentObject private var state: AppState

    // The active SwiftData profile record we persist into.
    @State private var activeProfile: Profile? = nil

    @State private var isLookingUpSigns: Bool = false
    @State private var signsResult: AstrologySignsAIResult? = nil
    @State private var signsError: String? = nil

    @State private var isValidatingPlace: Bool = false
    @State private var validatedMapItem: MKMapItem? = nil
    @State private var placeValidationError: String? = nil
    @State private var hasValidatedPlace: Bool = false
    @State private var derivedInvalidationSuppressionCount: Int = 0

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
    
    private var isDerivedInvalidationSuppressed: Bool {
        derivedInvalidationSuppressionCount > 0
    }

    private var selectedProfile: Profile? {
        profiles.first { $0.id.uuidString == selectedProfileID }
    }

    private var currentProfileTitle: String {
        let name = selectedProfile?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "Profile" : name
    }
    
    private var canAddProfile: Bool {
        profiles.count < Self.maxProfiles
    }

    var body: some View {
        ZStack {
            CosmicBackgroundView(variant: .profile)

            ScrollView {
                VStack(spacing: 14) {
                    glassCard(title: "PROFILE") {
                        HStack {
                            Text("Name")
                            Spacer()
                            TextField("", text: $state.name)
                                .multilineTextAlignment(.trailing)
                                .textContentType(.name)
                                .submitLabel(.done)
                        }

                        Divider().opacity(0.25)

                        HStack {
                            Text("Gender")
                            Spacer()
                            Menu {
                                ForEach(Gender.allCases) { g in
                                    Button {
                                        state.gender = g
                                    } label: {
                                        if state.gender == g {
                                            Label(g.rawValue, systemImage: "checkmark")
                                        } else {
                                            Text(g.rawValue)
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Text(state.gender.rawValue)
                                        .foregroundStyle(CosmicTheme.Colors.moonSilver.opacity(0.92))
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(CosmicTheme.Colors.moonSilver.opacity(0.60))
                                }
                            }
                        }

                        Divider().opacity(0.25)

                        VStack(alignment: .leading, spacing: 8) {
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
                                    guard !isDerivedInvalidationSuppressed else { return }
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
                                    guard !isDerivedInvalidationSuppressed else { return }
                                    invalidateValidatedPlaceAndDerivedResults()
                                }
                            }
                            .accessibilityElement(children: .contain)
                        }

                        Divider().opacity(0.25)

                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .center, spacing: 10) {
                                TextField("Place of Birth (City, Country)", text: $state.placeOfBirth)
                                    .textContentType(.addressCity)
                                    .onChange(of: state.placeOfBirth) { _, _ in
                                        guard !isDerivedInvalidationSuppressed else { return }
                                        invalidateValidatedPlaceAndDerivedResults()
                                    }

                                if isValidatingPlace {
                                    ProgressView()
                                }

                                Button {
                                    validatePlace()
                                } label: {
                                    Image(systemName: isPlaceValid ? "checkmark.circle.fill" : "questionmark.circle.fill")
                                        .symbolRenderingMode(.hierarchical)
                                        .foregroundStyle(isPlaceValid ? .green : CosmicTheme.Colors.moonSilver.opacity(0.85))
                                        .font(.system(size: 18, weight: .semibold))
                                }
                                .buttonStyle(.plain)
                                .frame(width: 34, height: 34)
                                .background {
                                    Circle()
                                        .fill(.thinMaterial)
                                        .overlay {
                                            Circle()
                                                .stroke(CosmicTheme.Colors.accentGlow.opacity(0.12), lineWidth: 1)
                                        }
                                }
                                .disabled(isValidatingPlace)
                                .accessibilityLabel(isPlaceValid ? "Revalidate place of birth" : "Validate place of birth")
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
                    }

                    VStack(spacing: 10) {
                        CosmicSnapshotCard(summary: snapshotSummaryForProfile())

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
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            if showResetConfirm {
                // Custom confirmation UI to match the cosmic visual style.
                Color.black
                    .opacity(0.42)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showResetConfirm = false
                    }

                CosmicConfirmDialog(
                    title: "Delete Profile?",
                    message: "This will permanently delete the current profile.",
                    confirmTitle: "Delete",
                    cancelTitle: "Cancel",
                    onConfirm: {
                        showResetConfirm = false
                        deleteActiveProfile()
                    },
                    onCancel: {
                        showResetConfirm = false
                    }
                )
                .padding(.horizontal, 24)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                .zIndex(50)
            }
        }
        .animation(.easeOut(duration: 0.18), value: showResetConfirm)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        // Cosmic UI is designed for a dark backdrop; enforce for readability in system Light Mode.
        .preferredColorScheme(.dark)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onChange(of: selectedProfileID) { _, newValue in
            guard !newValue.isEmpty else { return }
            if let match = profiles.first(where: { $0.id.uuidString == newValue }) {
                activeProfile = match
                syncStateFromProfile(match)
                unifiedSignsError = nil
                hasValidatedPlace = isPlaceValid
                syncDisplayedSignsFromState()
                autoFetchSignsIfNeeded()
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                CosmicHeaderView(showsDivider: false)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Section("Select Profile") {
                        ForEach(profiles) { profile in
                            let profileID = profile.id.uuidString
                            let profileName = profile.name.isEmpty ? "Unnamed Profile" : profile.name
                            Button {
                                selectedProfileID = profileID
                            } label: {
                                if selectedProfileID == profileID {
                                    Label(profileName, systemImage: "checkmark")
                                } else {
                                    Text(profileName)
                                }
                            }
                        }
                    }

                    Divider()

                    Button {
                        createNewProfile()
                    } label: {
                        Label("Add Profile", systemImage: "plus")
                    }
                    .disabled(!canAddProfile)

                    Button(role: .destructive) {
                        showResetConfirm = true
                    } label: {
                        Label("Delete Profile", systemImage: "trash")
                    }
                    .disabled(profiles.count <= 1)
                } label: {
                    Image(systemName: "person.crop.circle")
                        .symbolRenderingMode(.hierarchical)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(CosmicTheme.Colors.moonSilver.opacity(0.92))
                }
            }
        }
        .onAppear {
            ensureActiveProfileLoaded()
            hasValidatedPlace = isPlaceValid
            syncDisplayedSignsFromState()
            autoFetchSignsIfNeeded()

            // API key is provided via Info.plist only; runtime edits are not supported in the Profile screen.
        }
    }

    // MARK: - Helpers

    private func glassCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(CosmicTheme.Typography.smallCaps)
                .tracking(1.4)
                .foregroundStyle(CosmicTheme.Colors.moonSilver.opacity(0.70))

            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: CosmicTheme.Constants.CornerRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: CosmicTheme.Constants.CornerRadius.card, style: .continuous)
                .stroke(CosmicTheme.Colors.accentGlow.opacity(0.14), lineWidth: 1)
        }
        .shadow(color: CosmicTheme.Constants.Glow.color.opacity(0.14), radius: 18, x: 0, y: 8)
    }

    private func snapshotSummaryForProfile() -> CosmicSnapshotCard.ProfileSummary {
        let birthMomentUTC = (try? state.birthMomentUTC()) ?? state.dob
        let zodiac = ChineseZodiac.zodiac(for: birthMomentUTC)

        return CosmicSnapshotCard.ProfileSummary(
            sunSign: displayedSunSign,
            moonSign: displayedMoonSign,
            chineseAnimal: zodiac.animal,
            chineseElement: zodiac.element
        )
    }

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
        hasValidatedPlace = false
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

                        let coord: CLLocationCoordinate2D? = {
                            if #available(iOS 26.0, *) {
                                return first.location.coordinate
                            } else {
                                return first.placemark.location?.coordinate
                            }
                        }()
                        if let coord {
                            state.birthLatitude = coord.latitude
                            state.birthLongitude = coord.longitude
                        }
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

                        withSuppressedDerivedInvalidation {
                            if let city, !city.isEmpty, let country, !country.isEmpty {
                                state.placeOfBirth = "\(city), \(country)"
                            } else if let city, !city.isEmpty {
                                state.placeOfBirth = city
                            } else {
                                state.placeOfBirth = query
                            }
                        }

                        hasValidatedPlace = true
                        autoFetchSignsIfNeeded()
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

    private var hasPreviouslyFetchedSigns: Bool {
        func hasValue(_ value: String) -> Bool {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmed.isEmpty && trimmed != "—"
        }
        return hasValue(state.lunarSignDeterministic)
            && hasValue(state.solarSign)
            && hasValue(state.chineseSign)
    }

    private func syncDisplayedSignsFromState() {
        func displayValue(from value: String) -> String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "—" : trimmed
        }

        displayedMoonSign = displayValue(from: state.lunarSignDeterministic)
        displayedSunSign = displayValue(from: state.solarSign)
        displayedChineseSign = displayValue(from: state.chineseSign)
    }

    private func autoFetchSignsIfNeeded() {
        hasValidatedPlace = isPlaceValid
        guard hasValidatedPlace, !isLookingUpSigns else { return }

        if hasPreviouslyFetchedSigns {
            // Signs already exist for this validated profile: show persisted values as-is.
            syncDisplayedSignsFromState()
            return
        }

        startUnifiedSignsLookup()
    }

    private func withSuppressedDerivedInvalidation(_ action: () -> Void) {
        derivedInvalidationSuppressionCount += 1
        action()
        // Keep suppression active through the current UI update cycle so `onChange`
        // handlers triggered by programmatic state restoration do not invalidate.
        DispatchQueue.main.async {
            derivedInvalidationSuppressionCount = max(0, derivedInvalidationSuppressionCount - 1)
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
        guard canAddProfile else { return }

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
        withSuppressedDerivedInvalidation {
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
            .environmentObject(ProfileView_Previews.makePreviewState())
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
