import Foundation
import MoraCore

public protocol TTSEngine: Sendable {
    func speak(_ text: String) async
    func speak(phoneme: Phoneme) async
}
