import ArgumentParser
import Foundation
import MoraEngines

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
        let fixturesURL = URL(fileURLWithPath: fixturesDirectory)
        let outputURL = URL(fileURLWithPath: outputPath)
        let pairs = FixtureLoader.enumerate(directory: fixturesURL)
        guard !pairs.isEmpty else {
            FileHandle.standardError.write(
                Data("no fixtures found in \(fixturesDirectory)\n".utf8)
            )
            throw ExitCode(1)
        }

        let apiKey = ProcessInfo.processInfo.environment["SPEECHACE_API_KEY"] ?? ""
        if !noSpeechace && apiKey.isEmpty {
            FileHandle.standardError.write(Data(
                "SPEECHACE_API_KEY not set. Export it or pass --no-speechace.\n".utf8
            ))
            throw ExitCode(2)
        }

        let client: SpeechAceClient? = noSpeechace ? nil : SpeechAceClient(apiKey: apiKey)
        let runner = EngineARunner()
        let writer = try CSVWriter.create(at: outputURL)
        defer { writer.close() }

        for pair in pairs {
            let loaded: LoadedFixture
            do {
                loaded = try FixtureLoader.load(pair)
            } catch {
                FileHandle.standardError.write(Data(
                    "skip \(pair.basename): \(error)\n".utf8
                ))
                continue
            }

            let assessment = await runner.evaluate(loaded)

            var speechaceScore: String = ""
            var speechaceRaw: String = ""
            if let client {
                let wavData = (try? Data(contentsOf: pair.wavURL)) ?? Data()
                let r = await client.score(audio: wavData, text: loaded.metadata.wordSurface)
                if let s = r.score { speechaceScore = String(s) }
                speechaceRaw = r.rawJSON ?? ""
            }

            let labelJSON = (try? String(
                data: JSONEncoder().encode(assessment.label), encoding: .utf8
            )) ?? ""
            let featuresJSON = (try? String(
                data: JSONEncoder().encode(assessment.features), encoding: .utf8
            )) ?? ""
            let isoTimestamp = ISO8601DateFormatter().string(from: loaded.metadata.capturedAt)

            try writer.write(row: [
                pair.basename,
                isoTimestamp,
                loaded.metadata.targetPhonemeIPA,
                loaded.metadata.expectedLabel.rawValue,
                loaded.metadata.substitutePhonemeIPA ?? "",
                loaded.metadata.wordSurface,
                loaded.metadata.speakerTag.rawValue,
                labelJSON,
                assessment.score.map { "\($0)" } ?? "",
                "\(assessment.isReliable)",
                featuresJSON,
                speechaceScore,
                speechaceRaw,
            ])
        }
        print("wrote \(outputURL.path)")
    }
}
