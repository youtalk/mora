import MoraCore
import MoraEngines
import OSLog
import SwiftData
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

#if DEBUG
private let debugBarLog = Logger(subsystem: "tech.reenable.Mora", category: "DebugBar")
#endif

public struct HomeView: View {
    // Sort by createdAt so if duplicate rows ever appear (migration bug, test
    // seed leaking into prod store), the oldest profile wins deterministically.
    @Query(sort: \LearnerProfile.createdAt, order: .forward)
    private var profiles: [LearnerProfile]

    // DailyStreak is a singleton; sort by lastCompletedOn so the most recent
    // one surfaces even if a stale row exists.
    @Query(sort: \DailyStreak.lastCompletedOn, order: .reverse)
    private var streaks: [DailyStreak]

    // Open encounters (active or carryover) — the hero reads the latest one
    // so the home screen shows the yokai the learner is currently working
    // with rather than a fixed week-0 fallback.
    //
    // Raw strings are used directly because `#Predicate` cannot form a key
    // path into an enum case (`\.active`), so `YokaiEncounterState.active`
    // .rawValue doesn't compile inside the macro. `YokaiEncounterStateRawValuesTests`
    // pins these strings to the enum cases so a rename breaks CI, not prod.
    @Query(
        filter: #Predicate<YokaiEncounterEntity> {
            $0.stateRaw == "active" || $0.stateRaw == "carryover"
        },
        sort: \YokaiEncounterEntity.weekStart,
        order: .reverse
    )
    private var openEncounters: [YokaiEncounterEntity]

    // Bestiary entries unlock as each yokai is befriended. Once all five
    // are in the register and no open encounters remain, the home CTA
    // flips to the curriculum-complete terminal screen.
    @Query private var bestiary: [BestiaryEntryEntity]

    // Bundled yokai catalog cached as @State so the portrait-corner doesn't
    // re-parse the JSON catalog on every body invalidation. `try?` lets the
    // view still render if the bundle is somehow malformed — the corner just
    // doesn't appear, which matches the pre-cache behavior.
    @State private var yokaiStore: BundledYokaiStore? = try? BundledYokaiStore()

    // `needsEnhancedVoice` walks the installed-voice list; keep the result in
    // @State so the scan runs at most once per appearance / scene activation
    // rather than on every body invalidation (which fires on every @Query
    // update). Recomputed on scenePhase → .active so returning from Settings
    // after downloading a premium voice flips the gate off immediately.
    @State private var needsBetterVoice: Bool = AppleTTSEngine.needsEnhancedVoice
    @State private var installedVoices: [String] = AppleTTSEngine.installedEnglishVoiceSummaries()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.moraStrings) private var strings
    #if DEBUG
    @Environment(\.modelContext) private var debugContext
    #endif

    public init() {}

    public var body: some View {
        ZStack {
            MoraTheme.Background.page.ignoresSafeArea()

            VStack(spacing: MoraTheme.Space.lg) {
                header
                Spacer()
                if needsBetterVoice {
                    voiceGate
                } else {
                    hero
                }
                Spacer()
            }

            #if DEBUG
            debugTimeTravelBar
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, MoraTheme.Space.md)
                .padding(.bottom, MoraTheme.Space.xxl)
            #endif
        }
        .onAppear { refreshVoiceState() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshVoiceState() }
        }
        #if os(iOS)
        .navigationBarHidden(true)
        #endif
    }

    private var header: some View {
        HStack {
            wordmark
            Spacer()
            StreakChip(count: streaks.first?.currentCount ?? 0)
        }
        .padding(MoraTheme.Space.md)
    }

    private var wordmark: some View {
        Text("Mora")
            .font(MoraType.heading())
            .foregroundStyle(MoraTheme.Accent.orange)
    }

    /// True once every yokai has an entry in the bestiary and no open
    /// encounters remain. Drives the home CTA to the terminal screen.
    ///
    /// Counts *distinct* yokaiIDs rather than raw bestiary rows so a
    /// duplicate entry (from a retry path that didn't dedup) doesn't
    /// prematurely route to the terminal screen.
    private var isCurriculumComplete: Bool {
        openEncounters.isEmpty && Set(bestiary.map(\.yokaiID)).count >= 5
    }

    /// Primary home CTA. Branches to the curriculum-complete destination
    /// once the learner has befriended all five yokai; otherwise renders
    /// the regular session-start button. The button is always enabled —
    /// the Engine B (wav2vec2 CoreML) warmup runs in the background from
    /// app launch; if the first tap beats it, the session runs Engine A
    /// alone and the next session picks up Engine B from the warm cache.
    @ViewBuilder
    private var startCTA: some View {
        if isCurriculumComplete {
            NavigationLink(value: "curriculumComplete") {
                Text("All befriended — view your Register")
                    .font(MoraType.cta())
                    .foregroundStyle(.white)
                    .padding(.horizontal, MoraTheme.Space.xl)
                    .padding(.vertical, MoraTheme.Space.md)
                    .frame(minHeight: 88)
                    .background(MoraTheme.Accent.orange, in: .capsule)
            }
            .buttonStyle(.plain)
            .padding(.top, MoraTheme.Space.md)
        } else {
            NavigationLink(value: "session") {
                Text(strings.homeStart)
                    .font(MoraType.cta())
                    .foregroundStyle(.white)
                    .padding(.horizontal, MoraTheme.Space.xl)
                    .padding(.vertical, MoraTheme.Space.md)
                    .frame(minHeight: 88)
                    .background(MoraTheme.Accent.orange, in: .capsule)
            }
            .buttonStyle(.plain)
            .padding(.top, MoraTheme.Space.md)
            .accessibilityLabel(Text(strings.homeStart))
        }
    }

    private var hero: some View {
        VStack(spacing: MoraTheme.Space.lg) {
            heroHeader
            startCTA
            heroFooter
        }
    }

    /// Target word flanked by the week's yokai on the left, so the two
    /// read as a pair ("this friend brings today's sound"). Pairing the
    /// yokai with the hero word — rather than stacking it below — saves
    /// the ~230pt of vertical height the previous circle-plinth occupied
    /// and stops the CTA + pills + register link from overflowing the
    /// bottom of the iPad screen.
    private var heroHeader: some View {
        VStack(spacing: MoraTheme.Space.md) {
            Text(strings.homeTodayQuest)
                .font(MoraType.label())
                .foregroundStyle(MoraTheme.Ink.muted)

            HStack(alignment: .center, spacing: MoraTheme.Space.xl) {
                yokaiCompanion
                Text(target.letters ?? "—")
                    .font(MoraType.heroWord())
                    .foregroundStyle(MoraTheme.Ink.primary)
            }

            Text(ipaLine)
                .font(MoraType.subtitle())
                .foregroundStyle(MoraTheme.Ink.secondary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var yokaiCompanion: some View {
        if let enc = openEncounters.first,
            let yokai = yokaiStore?.catalog().first(where: { $0.id == enc.yokaiID })
        {
            YokaiPortraitCorner(yokai: yokai, sparkleTrigger: nil)
                .frame(width: 160, height: 160)
                .padding(MoraTheme.Space.sm)
                .background(Circle().fill(MoraTheme.Background.cream))
                .accessibilityLabel("This week's sound-friend: \(enc.yokaiID)")
        }
    }

    private var heroFooter: some View {
        NavigationLink(value: "bestiary") {
            Label(strings.bestiaryLinkLabel, systemImage: "book.closed.fill")
                .font(MoraType.label())
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .padding(.top, MoraTheme.Space.sm)
    }

    /// Blocking setup card shown when no `.enhanced` / `.premium` English
    /// voice is installed. The system default compact voice at any rate below
    /// 0.5 turns "ship" into unintelligible noise on device, so we refuse to
    /// start a session until the parent installs a usable voice. The Recheck
    /// button re-runs the voice scan immediately after the user returns from
    /// Settings — scenePhase → .active also triggers a re-scan, but an
    /// explicit button makes the flow obvious.
    private var voiceGate: some View {
        VStack(spacing: MoraTheme.Space.md) {
            Text(strings.voiceGateTitle)
                .font(MoraType.heading())
                .foregroundStyle(MoraTheme.Ink.primary)
                .multilineTextAlignment(.center)

            Text(strings.voiceGateBody)
                .font(MoraType.bodyReading())
                .foregroundStyle(MoraTheme.Ink.secondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            // List what AVSpeechSynthesizer actually sees on this device —
            // lets the parent tell at a glance whether their Settings
            // download produced an Enhanced/Premium entry or left them
            // stuck on Default (compact).
            installedVoicesSection

            Button(action: openVoiceSettings) {
                Text(strings.voiceGateOpenSettings)
                    .font(MoraType.cta())
                    .foregroundStyle(.white)
                    .padding(.horizontal, MoraTheme.Space.xl)
                    .padding(.vertical, MoraTheme.Space.md)
                    .frame(minHeight: 72)
                    .background(MoraTheme.Accent.orange, in: .capsule)
            }
            .buttonStyle(.plain)
            .padding(.top, MoraTheme.Space.sm)

            Button(action: refreshVoiceState) {
                Text(strings.voiceGateRecheck)
                    .font(MoraType.label())
                    .foregroundStyle(MoraTheme.Accent.teal)
                    .padding(.vertical, MoraTheme.Space.sm)
                    .padding(.horizontal, MoraTheme.Space.md)
            }
            .buttonStyle(.plain)
        }
        .padding(MoraTheme.Space.lg)
        .background(MoraTheme.Background.cream, in: .rect(cornerRadius: MoraTheme.Radius.card))
        .padding(.horizontal, MoraTheme.Space.xl)
    }

    private var installedVoicesSection: some View {
        VStack(alignment: .leading, spacing: MoraTheme.Space.xs) {
            Text(strings.voiceGateInstalledVoicesTitle)
                .font(MoraType.label())
                .foregroundStyle(MoraTheme.Ink.muted)
            if installedVoices.isEmpty {
                Text(strings.voiceGateNoVoicesPlaceholder)
                    .font(MoraType.label())
                    .foregroundStyle(MoraTheme.Ink.secondary)
            } else {
                ForEach(installedVoices, id: \.self) { row in
                    Text("• \(row)")
                        .font(MoraType.label())
                        .foregroundStyle(MoraTheme.Ink.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(MoraTheme.Space.md)
        .background(.white, in: .rect(cornerRadius: MoraTheme.Radius.tile))
    }

    private func refreshVoiceState() {
        needsBetterVoice = AppleTTSEngine.needsEnhancedVoice
        installedVoices = AppleTTSEngine.installedEnglishVoiceSummaries()
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(MoraType.pill())
            .foregroundStyle(MoraTheme.Ink.secondary)
            .padding(.horizontal, MoraTheme.Space.md)
            .padding(.vertical, MoraTheme.Space.sm)
            .background(MoraTheme.Background.cream, in: .capsule)
    }

    private var target: Target {
        let ladder = CurriculumEngine.sharedV1
        if let enc = openEncounters.first,
            let skill = ladder.skills.first(where: { $0.yokaiID == enc.yokaiID })
        {
            return Target(weekStart: enc.weekStart, skill: skill)
        }
        return ladder.currentTarget(forWeekIndex: weekIndex)
    }

    /// Weeks elapsed since the learner's profile was created, clamped into the
    /// curriculum. When no profile exists (pre-onboarding state in PR 3 before
    /// PR 4 lands), default to week 0 so the hero renders something.
    private var weekIndex: Int {
        guard let profile = profiles.first else { return 0 }
        let seconds = Date().timeIntervalSince(profile.createdAt)
        return Int(seconds / (60 * 60 * 24 * 7))
    }

    private var ipaLine: String {
        guard let ipa = target.ipa else { return "" }
        guard let phoneme = target.phoneme else { return "/\(ipa)/" }
        let examples = JapaneseL1Profile().exemplars(for: phoneme)
        guard !examples.isEmpty else { return "/\(ipa)/" }
        return "/\(ipa)/ · as in \(examples.joined(separator: ", "))"
    }

    private func openVoiceSettings() {
        #if canImport(UIKit)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }

    #if DEBUG
    private var debugTimeTravelBar: some View {
        VStack(spacing: 4) {
            Button("+1 Day") { advanceDay() }
            Button("+1 Week") { advanceWeek() }
            Button("Reset") { resetCurriculum() }
                .tint(.red)
        }
        .buttonStyle(.bordered)
        .controlSize(.mini)
        .tint(.orange)
        .font(.caption2)
        .fixedSize()
    }

    /// Simulates one day's session completion: bumps the open encounter's
    /// `sessionCompletionCount` (clamped at 4 so the next real session enters
    /// Friday mode) and records a streak completion. The curriculum's
    /// "day-in-week" branching is driven by `sessionCompletionCount`, not the
    /// calendar — `==4` flips `SessionContainerView` into Friday/climax mode
    /// (SessionContainerView.swift:340).
    private func advanceDay() {
        debugBarLog.info(
            "advanceDay: openEncounters=\(openEncounters.count, privacy: .public) firstYokai=\(openEncounters.first?.yokaiID ?? "nil", privacy: .public) firstSessionCount=\(openEncounters.first?.sessionCompletionCount ?? -1, privacy: .public)"
        )
        if let encounter = openEncounters.first, encounter.sessionCompletionCount < 4 {
            encounter.sessionCompletionCount += 1
        }
        let streak: DailyStreak
        if let existing = streaks.first {
            streak = existing
        } else {
            streak = DailyStreak()
            debugContext.insert(streak)
        }
        // Route through the real DailyStreak rules instead of mutating fields
        // directly: simulate "the next day" so each tap counts as one more
        // day in the streak rather than a same-day no-op.
        let simulatedCompletionDate =
            streak.lastCompletedOn
            .flatMap { Calendar.current.date(byAdding: .day, value: 1, to: $0) }
            ?? Date()
        streak.recordCompletion(on: simulatedCompletionDate)
        persistDebugChanges()
    }

    /// Simulates befriending the current yokai and advancing to the next one
    /// in the ladder. Mirrors `YokaiOrchestrator.finalizeFridayIfNeeded`'s
    /// success branch but also works from a fresh state (no encounter yet) by
    /// treating the `weekIndex`-fallback yokai as the one being befriended.
    /// All currently-open encounters are befriended so a stale duplicate from
    /// earlier testing can't outvote the freshly inserted next-yokai row in
    /// `openEncounters.first`.
    private func advanceWeek() {
        let ladder = CurriculumEngine.sharedV1
        let now = Date()

        let currentYokaiID: String? =
            openEncounters.first?.yokaiID
            ?? ladder.currentTarget(forWeekIndex: weekIndex).skill.yokaiID

        debugBarLog.info(
            "advanceWeek begin: openEncounters=\(openEncounters.count, privacy: .public) currentYokai=\(currentYokaiID ?? "nil", privacy: .public) bestiary=\(self.bestiary.map(\.yokaiID).joined(separator: ","), privacy: .public)"
        )

        for enc in openEncounters {
            enc.state = .befriended
            enc.befriendedAt = now
            enc.friendshipPercent = 1.0
        }

        var befriendedIDs = Set(bestiary.map(\.yokaiID))
        if let id = currentYokaiID, !befriendedIDs.contains(id) {
            debugContext.insert(BestiaryEntryEntity(yokaiID: id, befriendedAt: now))
            befriendedIDs.insert(id)
        }

        let nextID = ladder.skills.lazy.compactMap(\.yokaiID).first(where: {
            !befriendedIDs.contains($0)
        })
        if let nextID {
            debugContext.insert(
                YokaiEncounterEntity(
                    yokaiID: nextID,
                    weekStart: now,
                    state: .active,
                    friendshipPercent: 0
                )
            )
        }
        debugBarLog.info(
            "advanceWeek end: nextYokai=\(nextID ?? "nil", privacy: .public) befriendedIDs=\(befriendedIDs.sorted().joined(separator: ","), privacy: .public)"
        )
        persistDebugChanges()
    }

    /// Wipes curriculum-progress state so the next launch behaves like a
    /// fresh install: deletes every yokai encounter, bestiary entry, and
    /// cameo row, zeroes the streak, and rewinds `profile.createdAt` to
    /// now so `weekIndex` collapses to 0.
    private func resetCurriculum() {
        debugBarLog.info("resetCurriculum: wiping encounters, bestiary, cameos, streak, profile.createdAt")
        do {
            try debugContext.delete(model: YokaiEncounterEntity.self)
            try debugContext.delete(model: BestiaryEntryEntity.self)
            try debugContext.delete(model: YokaiCameoEntity.self)
        } catch {
            assertionFailure("Failed to delete debug models: \(error)")
        }
        if let streak = streaks.first {
            streak.currentCount = 0
            streak.longestCount = 0
            streak.lastCompletedOn = nil
        }
        if let profile = profiles.first {
            profile.createdAt = Date()
        }
        persistDebugChanges()
    }

    private func persistDebugChanges() {
        do {
            try debugContext.save()
        } catch {
            assertionFailure("Failed to persist debug change: \(error)")
        }
    }
    #endif
}
