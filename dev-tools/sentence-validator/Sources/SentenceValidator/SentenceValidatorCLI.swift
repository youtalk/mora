import ArgumentParser
import Foundation
import MoraCore
import MoraEngines

@main
struct SentenceValidatorCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sentence-validator",
        abstract: "Validates the bundled decodable-sentence library."
    )

    @Option(name: .long, help: "Path to the SentenceLibrary resource directory.")
    var bundle: String

    func run() throws {
        let bundleURL = URL(fileURLWithPath: bundle, isDirectory: true)
        let curriculum = CurriculumEngine.defaultV1Ladder()
        let sightWords: Set<String> = ["the", "a", "and", "is", "to", "on", "at"]

        var report = ValidationReport()
        let fm = FileManager.default

        for map in PhonemeDirectoryMap.all {
            let phonemeDir = bundleURL.appendingPathComponent(map.directory, isDirectory: true)
            guard
                let entries = try? fm.contentsOfDirectory(
                    at: phonemeDir,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                )
            else {
                continue  // missing phoneme dir is OK before B-2 fills cells in
            }
            for url in entries where url.pathExtension == "json" {
                report.cellsExamined += 1
                do {
                    let data = try Data(contentsOf: url)
                    let cell = try JSONDecoder().decode(CellPayload.self, from: data)
                    report.sentencesExamined += cell.sentences.count
                    for (idx, sentence) in cell.sentences.enumerated() {
                        let violations = Validator.validate(
                            sentence: sentence,
                            map: map,
                            curriculum: curriculum,
                            sightWords: sightWords
                        )
                        for v in violations {
                            report.violations.append(
                                .init(
                                    file: url.path,
                                    sentenceIndex: idx,
                                    sentenceText: sentence.text,
                                    violation: v
                                ))
                        }
                    }
                } catch {
                    report.violations.append(
                        .init(
                            file: url.path,
                            sentenceIndex: -1,
                            sentenceText: "<decode-error>",
                            violation: .undecodableGrapheme(word: "<file>", grapheme: "\(error)")
                        ))
                }
            }
        }

        FileHandle.standardOutput.write(Data(report.render().utf8))
        if !report.violations.isEmpty {
            throw ExitCode(1)
        }
    }
}

struct ValidationReport {
    struct Entry {
        let file: String
        let sentenceIndex: Int
        let sentenceText: String
        let violation: Violation
    }

    var cellsExamined: Int = 0
    var sentencesExamined: Int = 0
    var violations: [Entry] = []

    func render() -> String {
        var out = ""
        out += "sentence-validator: \(cellsExamined) cells, \(sentencesExamined) sentences\n"
        if violations.isEmpty {
            out += "  PASS\n"
        } else {
            out += "  FAIL — \(violations.count) violation(s):\n"
            for entry in violations {
                out += "    \(entry.file)#\(entry.sentenceIndex): \(entry.violation)\n"
                out += "      \"\(entry.sentenceText)\"\n"
            }
        }
        return out
    }
}
