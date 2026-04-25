import ArgumentParser
import Foundation

@main
struct SentenceValidatorCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sentence-validator",
        abstract: "Validates the bundled decodable-sentence library."
    )

    @Option(name: .long, help: "Path to the SentenceLibrary resource directory.")
    var bundle: String

    func run() throws {
        FileHandle.standardError.write(
            Data("sentence-validator: not yet wired (Task 6 fills this in)\n".utf8)
        )
        throw ExitCode(2)
    }
}
