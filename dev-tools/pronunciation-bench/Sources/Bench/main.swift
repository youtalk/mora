import ArgumentParser
import Foundation

@main
struct BenchCLI: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "bench",
        abstract: "Compare Engine A against SpeechAce for a directory of fixtures."
    )

    @Argument(help: "Directory containing WAV + sidecar JSON pairs.")
    var fixturesDirectory: String

    @Argument(help: "Output CSV path.")
    var outputPath: String = "bench-out.csv"

    @Flag(name: .long, help: "Skip SpeechAce; Engine A only.")
    var noSpeechace: Bool = false

    mutating func run() async throws {
        print("bench stub — fixtures=\(fixturesDirectory) out=\(outputPath) noSpeechace=\(noSpeechace)")
    }
}
