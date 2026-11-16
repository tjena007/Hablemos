import Foundation

/// Which words of a target phrase have been heard so far.
public struct PhraseProgress: Equatable, Sendable {
    public let words: [String]
    public let recognized: [Bool]

    public var fraction: Double {
        words.isEmpty ? 0 : Double(recognized.filter { $0 }.count) / Double(words.count)
    }

    public var isComplete: Bool { !words.isEmpty && !recognized.contains(false) }
    public var missedWords: [String] { zip(words, recognized).filter { !$0.1 }.map(\.0) }
}

/// Word-by-word speech grading, after Duolingo's recognizer: each heard word marks a target word
/// as said, so progress shows live and order or fillers don't matter. Words must match exactly once
/// case, punctuation and accents are removed. The recognizer outputs real words, so edit-distance
/// tolerance would only forgive grammar ("quiere" for "quiero"), never typos.
public enum PhraseMatcher {
    public static func matches(heard: String, target: String) -> Bool {
        progress(heard: [heard], target: target).isComplete
    }

    /// Pass the previous result to keep words already recognized, so progress never goes backwards
    /// as partial transcripts change.
    public static func progress(heard transcripts: [String], target: String, previous: PhraseProgress? = nil) -> PhraseProgress {
        let words = target.split(whereSeparator: \.isWhitespace).map(String.init).filter { !normalized($0).isEmpty }
        let keys = words.map(normalized)
        var recognized = previous?.words == words ? previous!.recognized : Array(repeating: false, count: words.count)
        for transcript in transcripts {
            let heardWords = transcript.split(whereSeparator: \.isWhitespace).map { normalized(String($0)) }.filter { !$0.isEmpty }
            for (position, heardWord) in heardWords.enumerated() {
                // A repeated word ("un ... un") counts for the occurrence nearest where it was said.
                let nearest = keys.indices
                    .filter { keys[$0] == heardWord }
                    .min { abs($0 - position) < abs($1 - position) }
                if let nearest { recognized[nearest] = true }
            }
        }
        return PhraseProgress(words: words, recognized: recognized)
    }

    private static func normalized(_ word: String) -> String {
        let key = String(word.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).filter { $0.isLetter || $0.isNumber })
        // The recognizer writes "diez" as "10"; lessons spell numbers out.
        return numberWords[key] ?? key
    }

    private static let numberWords: [String: String] = [
        "0": "cero", "1": "uno", "2": "dos", "3": "tres", "4": "cuatro", "5": "cinco", "6": "seis", "7": "siete",
        "8": "ocho", "9": "nueve", "10": "diez", "11": "once", "12": "doce", "13": "trece", "14": "catorce", "15": "quince",
        "20": "veinte", "30": "treinta", "40": "cuarenta", "50": "cincuenta", "60": "sesenta", "70": "setenta",
        "80": "ochenta", "90": "noventa", "100": "cien",
    ]
}
