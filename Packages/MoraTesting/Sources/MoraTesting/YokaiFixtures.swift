import Foundation
import MoraCore

public enum YokaiFixtures {
    public static let shDefinition = YokaiDefinition(
        id: "sh", grapheme: "sh", ipa: "/ʃ/",
        personality: "mischievous whisper",
        soundGesture: "finger to lips",
        wordDecor: ["sailor hat", "seashell ears", "fin tail"],
        palette: ["teal", "cream"],
        expression: "smirk",
        voice: .init(
            characterDescription: "young whispery",
            clips: [
                .phoneme: "Shhh",
                .example1: "ship", .example2: "shop", .example3: "shell",
                .greet: "Hello", .encourage: "Nice",
                .gentleRetry: "Again", .fridayAcknowledge: "Yours",
            ]
        )
    )

    public static let smallCatalog: [YokaiDefinition] = [shDefinition]
}
