import Foundation

public enum YokaiCutscene: Equatable, Sendable {
    case mondayIntro(yokaiID: String)
    case sessionStart(yokaiID: String)  // 3–4s cameo at start of Tue–Fri
    case fridayClimax(yokaiID: String)
    case srsCameo(yokaiID: String)
}
