import Combine
import Foundation
#if canImport(RevenueCat)
import RevenueCat
#endif

private let contentFontSizeKey = "jot.contentFontSize"
private let defaultContentFontSize: CGFloat = 20
private let minContentFontSize: CGFloat = 12
private let maxContentFontSize: CGFloat = 32
private let revenueCatAPIKeyPlistKey = "REVENUECAT_API_KEY"
private let revenueCatEntitlementIDPlistKey = "REVENUECAT_ENTITLEMENT_ID"
private let revenueCatProxyURLPlistKey = "REVENUECAT_PROXY_URL"
private let revenueCatOfferingIDPlistKey = "REVENUECAT_OFFERING_ID"
private let revenueCatPackageIdentifierPlistKey = "REVENUECAT_PACKAGE_IDENTIFIER"
private let revenueCatProductIDPlistKey = "REVENUECAT_PRODUCT_ID"
private let trialStartDateKey = "jot.trial.startDate"

@MainActor
final class PurchaseStore: NSObject, ObservableObject {
    @Published private(set) var isProUnlocked = false
    @Published private(set) var isConfigured = false
    @Published private(set) var isBusy = false
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var lifetimePriceText: String?
    @Published private(set) var isTrialActive = false
    @Published private(set) var trialDaysRemaining = 0
    @Published var statusMessage: String?

    private let defaultEntitlementID = "pro"
    private let trialLengthDays = 7

#if canImport(RevenueCat)
    private var lifetimePackage: Package?
    private(set) var currentOffering: Offering?
#endif

    var requiredEntitlementID: String {
        let raw = (Bundle.main.object(forInfoDictionaryKey: revenueCatEntitlementIDPlistKey) as? String) ?? ""
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Jott. Pro" : trimmed
    }

    private var entitlementCandidates: [String] {
        let configured = requiredEntitlementID
        let values = [configured, defaultEntitlementID, "Jott. Pro", "Jott.Pro", "jott_pro", "pro"]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        return Array(Set(values))
    }

    override init() {
        super.init()
        refreshTrialStatus()
    }

    var hasPremiumAccess: Bool {
        isProUnlocked || isTrialActive
    }

    var canPurchaseLifetime: Bool {
#if canImport(RevenueCat)
        return lifetimePackage != nil
#else
        return false
#endif
    }

    var isTrialExpired: Bool {
        !isProUnlocked && !isTrialActive
    }

    func configureIfNeeded() {
        refreshTrialStatus()
        guard !isConfigured else { return }

        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: revenueCatAPIKeyPlistKey) as? String,
              !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            statusMessage = "Missing RevenueCat API key in Info.plist."
            return
        }

#if canImport(RevenueCat)
        // Force a stable base host to avoid DNS issues on fallback domains in some environments.
        let proxy = (Bundle.main.object(forInfoDictionaryKey: revenueCatProxyURLPlistKey) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let proxy, let proxyURL = URL(string: proxy), !proxy.isEmpty {
            Purchases.proxyURL = proxyURL
        } else {
            Purchases.proxyURL = URL(string: "https://api.revenuecat.com")
        }
        Purchases.logLevel = .debug
        let config = Configuration.Builder(withAPIKey: apiKey).build()
        Purchases.configure(with: config)
        Purchases.shared.delegate = self
        isConfigured = true
        refresh()
#else
        statusMessage = "RevenueCat SDK is not linked yet."
#endif
    }

    func refresh() {
        Task {
            await refreshAndWait()
        }
    }

    func refreshAndWait() async {
        refreshTrialStatus()
#if canImport(RevenueCat)
        guard isConfigured else { return }
        await refreshRevenueCatState()
#endif
    }

    func purchaseLifetime() {
#if canImport(RevenueCat)
        guard isConfigured else {
            statusMessage = "RevenueCat is not configured."
            return
        }
        guard let package = lifetimePackage else {
            statusMessage = "No lifetime package in current offering."
            Task { await refreshRevenueCatState() }
            return
        }

        isBusy = true
        statusMessage = nil
        Task {
            do {
                let result = try await Purchases.shared.purchase(package: package)
                isBusy = false
                applyCustomerInfo(result.customerInfo)
                refreshTrialStatus()
                statusMessage = isProUnlocked ? "Lifetime unlocked." : "Purchase completed."
            } catch {
                isBusy = false
                statusMessage = error.localizedDescription
            }
        }
#endif
    }

    func restorePurchases() {
#if canImport(RevenueCat)
        guard isConfigured else {
            statusMessage = "RevenueCat is not configured."
            return
        }

        isBusy = true
        statusMessage = nil
        Task {
            do {
                let customerInfo = try await Purchases.shared.restorePurchases()
                isBusy = false
                applyCustomerInfo(customerInfo)
                refreshTrialStatus()
                statusMessage = isProUnlocked ? "Purchases restored." : "No active purchases found."
            } catch {
                isBusy = false
                statusMessage = error.localizedDescription
            }
        }
#endif
    }

    func refreshTrialStatus(now: Date = Date()) {
        let defaults = UserDefaults.standard
        let trialStart: Date

        if let saved = defaults.object(forKey: trialStartDateKey) as? Date {
            trialStart = saved
        } else {
            trialStart = now
            defaults.set(trialStart, forKey: trialStartDateKey)
        }

        let calendar = Calendar.current
        let fromDay = calendar.startOfDay(for: trialStart)
        let toDay = calendar.startOfDay(for: now)
        let elapsedDays = max(0, calendar.dateComponents([.day], from: fromDay, to: toDay).day ?? 0)
        let remaining = max(0, trialLengthDays - elapsedDays)

        trialDaysRemaining = remaining
        isTrialActive = remaining > 0 && !isProUnlocked
    }

#if canImport(RevenueCat)
    private func refreshRevenueCatState() async {
        isLoadingProducts = true
        do {
            let offerings = try await Purchases.shared.offerings()
            let configuredOfferingID = (Bundle.main.object(forInfoDictionaryKey: revenueCatOfferingIDPlistKey) as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let targetOffering = offerings.offering(identifier: configuredOfferingID) ?? offerings.current
            currentOffering = targetOffering

            let configuredPackageID = (Bundle.main.object(forInfoDictionaryKey: revenueCatPackageIdentifierPlistKey) as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let configuredProductID = (Bundle.main.object(forInfoDictionaryKey: revenueCatProductIDPlistKey) as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let packages = targetOffering?.availablePackages ?? []
            lifetimePackage =
                packages.first(where: { $0.identifier == configuredPackageID }) ??
                packages.first(where: { $0.storeProduct.productIdentifier == configuredProductID }) ??
                packages.first(where: { $0.packageType == .lifetime }) ??
                packages.first
            lifetimePriceText = lifetimePackage?.storeProduct.localizedPriceString

            let customerInfo = try await Purchases.shared.customerInfo()
            applyCustomerInfo(customerInfo)
            isLoadingProducts = false
        } catch {
            isLoadingProducts = false
            lifetimePriceText = nil
            statusMessage = error.localizedDescription
        }
    }

    private func applyCustomerInfo(_ customerInfo: CustomerInfo?) {
        guard let customerInfo else { return }
        isProUnlocked = entitlementCandidates.contains {
            customerInfo.entitlements.activeInCurrentEnvironment[$0] != nil
        }
        refreshTrialStatus()
    }
#endif
}

#if canImport(RevenueCat)
extension PurchaseStore: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            applyCustomerInfo(customerInfo)
        }
    }
}
#endif

@MainActor
final class JotStore: ObservableObject {
    @Published private(set) var notes: [Note] = []
    @Published var contentFontSize: CGFloat = defaultContentFontSize {
        didSet {
            let clamped = min(max(contentFontSize, minContentFontSize), maxContentFontSize)
            if clamped != contentFontSize { contentFontSize = clamped; return }
            UserDefaults.standard.set(Double(contentFontSize), forKey: contentFontSizeKey)
        }
    }

    private var saveTask: Task<Void, Never>?
    private let persistence = Persistence()
    private let notifications = NotificationScheduler.shared

    init() {
        notes = (try? persistence.load()) ?? [Note(title: Note.defaultTitle, blocks: [])]
        migrateLegacyStickyTitles()
        normalize()
        if let s = UserDefaults.standard.object(forKey: contentFontSizeKey) as? Double {
            contentFontSize = min(max(CGFloat(s), minContentFontSize), maxContentFontSize)
        }
    }

    func increaseContentFontSize() {
        contentFontSize = min(contentFontSize + 2, maxContentFontSize)
    }

    func decreaseContentFontSize() {
        contentFontSize = max(contentFontSize - 2, minContentFontSize)
    }

    /// 收纳列表中显示的便签（仅用户关闭时选「Save」的便签）。
    var notesInList: [Note] { notes.filter { $0.isInList } }

    func note(id: Note.ID) -> Note? {
        notes.first(where: { $0.id == id })
    }

    func setNoteInList(id: Note.ID, inList: Bool) {
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[idx].isInList = inList
        notes[idx].updatedAt = Date()
        scheduleSave()
    }

    func createNote() -> Note.ID {
        var note = Note()
        note.title = Note.defaultTitle
        notes.insert(note, at: 0)
        scheduleSave()
        return note.id
    }

    func noteIDForLaunch() -> Note.ID {
        if let id = notes.first?.id {
            return id
        }
        return createNote()
    }

    func deleteNotes(ids: Set<Note.ID>) {
        notes.removeAll { ids.contains($0.id) }
        if notes.isEmpty { notes = [Note(title: Note.defaultTitle, blocks: [])] }
        scheduleSave()
    }

    func renameNote(id: Note.ID, title: String) {
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[idx].title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Note.defaultTitle : title
        notes[idx].updatedAt = Date()
        scheduleSave()
    }

    func setNoteColor(id: Note.ID, color: NoteColor) {
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[idx].color = color
        notes[idx].updatedAt = Date()
        scheduleSave()
    }

    func togglePinned(id: Note.ID) {
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[idx].isPinned.toggle()
        notes[idx].updatedAt = Date()
        scheduleSave()
    }

    func addBlock(to noteID: Note.ID, block: Block) {
        guard let idx = notes.firstIndex(where: { $0.id == noteID }) else { return }
        notes[idx].blocks.append(block)
        notes[idx].updatedAt = Date()
        scheduleSave()

        scheduleNotificationsIfNeeded(note: notes[idx], block: block)
    }

    func addChecklist(to noteID: Note.ID, items: [String]) {
        for item in items {
            let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            addBlock(to: noteID, block: .todo(trimmed, dueAt: nil))
        }
    }

    func updateBlock(noteID: Note.ID, block: Block) {
        guard let idx = notes.firstIndex(where: { $0.id == noteID }) else { return }
        notes[idx].blocks.replace(id: block.id, with: block)
        notes[idx].updatedAt = Date()
        scheduleSave()

        scheduleNotificationsIfNeeded(note: notes[idx], block: block)
    }

    func deleteBlock(noteID: Note.ID, blockID: Block.ID) {
        guard let idx = notes.firstIndex(where: { $0.id == noteID }) else { return }
        notes[idx].blocks.removeAll { $0.id == blockID }
        notes[idx].updatedAt = Date()
        scheduleSave()

        Task { await notifications.cancelTodo(id: blockID) }
    }

    func saveNow() {
        saveTask?.cancel()
        let snapshot = notes
        try? (persistence as Persistence).save(snapshot)
    }

    func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [persistence] in
            try? await Task.sleep(for: .milliseconds(250))
            let snapshot = notes
            try? persistence.save(snapshot)
        }
    }

    private func normalize() {
        notes.sort { $0.updatedAt > $1.updatedAt }
        scheduleSave()
    }

    private func migrateLegacyStickyTitles() {
        var didChange = false
        for idx in notes.indices {
            let normalized = notes[idx].title.trimmingCharacters(in: .whitespacesAndNewlines)
            if isLegacyStickyTitle(normalized) {
                notes[idx].title = Note.defaultTitle
                notes[idx].updatedAt = Date()
                didChange = true
            }
        }
        if didChange {
            scheduleSave()
        }
    }

    private func isLegacyStickyTitle(_ title: String) -> Bool {
        if title == "Sticky" { return true }
        guard title.hasPrefix("Sticky ") else { return false }
        let number = title.dropFirst("Sticky ".count)
        return !number.isEmpty && number.allSatisfy(\.isNumber)
    }

    private func scheduleNotificationsIfNeeded(note: Note, block: Block) {
        guard block.kind == .todo else { return }

        if (block.isDone ?? false) || block.dueAt == nil {
            Task { await notifications.cancelTodo(id: block.id) }
            return
        }

        guard let dueAt = block.dueAt else { return }
        Task { await notifications.scheduleTodo(id: block.id, noteTitle: note.title, text: block.text, dueAt: dueAt) }
    }
}

struct Persistence {
    private let fileManager = FileManager.default

    func load() throws -> [Note] {
        let url = try fileURL()
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([Note].self, from: data)
    }

    func save(_ notes: [Note]) throws {
        let url = try fileURL()
        let folder = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(notes)
        try data.write(to: url, options: [.atomic])
    }

    private func fileURL() throws -> URL {
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return base.appendingPathComponent("Jot", isDirectory: true).appendingPathComponent("notes.json")
    }
}
