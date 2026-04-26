import MoraEngines

extension YokaiCutscene {
    /// `true` only when this cutscene is the per-week Monday intro. The
    /// session UI uses this to render the dedicated `WeeklyIntroView`
    /// instead of `YokaiCutsceneOverlay`'s default overlay treatment, so
    /// the warmup TTS does not play under a hovering yokai panel.
    var isMondayIntro: Bool {
        if case .mondayIntro = self { return true }
        return false
    }
}
