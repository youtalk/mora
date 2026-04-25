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

        // Fix #4: Fail with exit code 2 (configuration error) when the bundle
        // path does not resolve to an existing directory. Without this guard,
        // a mistyped path silently produces a zero-cell PASS in CI.
        var isDir: ObjCBool = false
        guard
            FileManager.default.fileExists(
                atPath: bundleURL.path, isDirectory: &isDir
            ) && isDir.boolValue
        else {
            FileHandle.standardError.write(
                Data(
                    "sentence-validator: error: bundle path does not exist or is not a directory: \(bundle)\n"
                        .utf8))
            throw ExitCode(2)
        }

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

                // Fix #1: Parse the filename to derive expected (interest, ageBand).
                // Split on the LAST underscore so interest names with internal
                // underscores (e.g. "space_travel") are preserved on the left side.
                let stem = url.deletingPathExtension().lastPathComponent
                let filenamePhoneme = map.directory
                let (filenameInterest, filenameAgeBand) = Self.parseFileStem(stem)

                do {
                    let data = try Data(contentsOf: url)
                    let cell = try JSONDecoder().decode(CellPayload.self, from: data)

                    // Fix #1: Cross-check payload identity against the file path.
                    if let interest = filenameInterest, let ageBand = filenameAgeBand {
                        for (field, payloadValue, filenameValue) in [
                            ("phoneme", cell.phoneme, filenamePhoneme),
                            ("interest", cell.interest, interest),
                            ("ageBand", cell.ageBand, ageBand),
                        ] where payloadValue != filenameValue {
                            report.violations.append(
                                .init(
                                    file: url.path,
                                    sentenceIndex: -1,
                                    sentenceText: "<identity-mismatch>",
                                    violation: .payloadFilenameMismatch(
                                        field: field,
                                        payloadValue: payloadValue,
                                        filenameValue: filenameValue
                                    )))
                        }
                    }

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
                    // Fix #5: Use .decodeError instead of abusing .undecodableGrapheme.
                    report.violations.append(
                        .init(
                            file: url.path,
                            sentenceIndex: -1,
                            sentenceText: "<decode-error>",
                            violation: .decodeError(message: String(describing: error))
                        ))
                }
            }
        }

        FileHandle.standardOutput.write(Data(report.render().utf8))
        if !report.violations.isEmpty {
            throw ExitCode(1)
        }
    }

    /// Splits `<interest>_<ageBand>` on the last underscore.
    /// Returns `(nil, nil)` when the stem contains no underscore (malformed filename).
    private static func parseFileStem(_ stem: String) -> (interest: String?, ageBand: String?) {
        guard let lastUnderscore = stem.lastIndex(of: "_") else {
            return (nil, nil)
        }
        let interest = String(stem[stem.startIndex..<lastUnderscore])
        let ageBand = String(stem[stem.index(after: lastUnderscore)...])
        return (interest.isEmpty ? nil : interest, ageBand.isEmpty ? nil : ageBand)
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
