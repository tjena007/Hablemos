import Foundation
import Testing
@testable import HablemosCore

struct ReplyParserTests {
    @Test func splitsCorrectionFromSpokenText() {
        let raw = "¡Me alegro! Son cuatro euros.\nCORRECTION: es muy rico => está muy rico | Use estar for how food tastes."
        let parsed = ReplyParser.parse(raw)
        #expect(parsed.spoken == "¡Me alegro! Son cuatro euros.")
        #expect(parsed.correction == Correction(wrong: "es muy rico", right: "está muy rico", explanation: "Use estar for how food tastes."))
    }

    @Test func replyWithoutCorrection() {
        let parsed = ReplyParser.parse("¿Algo más?")
        #expect(parsed.spoken == "¿Algo más?")
        #expect(parsed.correction == nil)
    }

    @Test func malformedCorrectionIsStrippedFromSpeech() {
        let parsed = ReplyParser.parse("Hola.\nCORRECTION: no arrow here")
        #expect(parsed.spoken == "Hola.")
        #expect(parsed.correction == nil)
    }

    @Test func missingExplanationYieldsEmptyExplanation() {
        let parsed = ReplyParser.parse("Hola.\nCORRECTION: una café => un café")
        #expect(parsed.correction?.explanation == "")
    }
}

struct MetricsTests {
    @Test func computesAverages() {
        let turns = [
            UserTurn(text: "Para aquí por favor", pauseBeforeSeconds: 2),
            UserTurn(text: "Un café con leche y un cruasán", pauseBeforeSeconds: 4),
        ]
        let metrics = MetricsCalculator.compute(userTurns: turns, mistakeCount: 1)
        #expect(metrics.turns == 2)
        #expect(metrics.wordsPerTurn == 5.5)
        #expect(metrics.errorsPerTurn == 0.5)
        #expect(metrics.averagePauseSeconds == 3)
    }

    @Test func countsEnglishSwitches() {
        let turns = [
            UserTurn(text: "I want the coffee please", pauseBeforeSeconds: 1),
            UserTurn(text: "Quiero un café", pauseBeforeSeconds: 1),
        ]
        #expect(MetricsCalculator.compute(userTurns: turns, mistakeCount: 0).englishSwitches == 1)
    }

    @Test func emptySessionIsAllZero() {
        let metrics = MetricsCalculator.compute(userTurns: [], mistakeCount: 3)
        #expect(metrics.turns == 0)
        #expect(metrics.errorsPerTurn == 0)
    }
}

struct PromotionTests {
    private func metrics(errors: Double, words: Double, turns: Int = 10) -> SessionMetrics {
        SessionMetrics(turns: turns, wordsPerTurn: words, errorsPerTurn: errors, englishSwitches: 0, averagePauseSeconds: 2)
    }

    @Test func strongSessionThresholds() {
        let rule = PromotionRule()
        #expect(rule.isStrong(metrics(errors: 1.9, words: 8)))
        #expect(!rule.isStrong(metrics(errors: 2, words: 8)))
        #expect(!rule.isStrong(metrics(errors: 1, words: 7.9)))
        #expect(!rule.isStrong(metrics(errors: 0, words: 20, turns: 0)))
    }

    @Test func threeStrongSessionsUnlockNextLevel() {
        let rule = PromotionRule()
        let strong = metrics(errors: 1, words: 9)
        let first = rule.apply(streak: 0, session: strong)
        let second = rule.apply(streak: first.streak, session: strong)
        let third = rule.apply(streak: second.streak, session: strong)
        #expect(second.streak == 2 && !second.unlocksNextLevel)
        #expect(third.unlocksNextLevel)
        #expect(third.streak == 0)
    }

    @Test func weakSessionResetsStreak() {
        let outcome = PromotionRule().apply(streak: 2, session: metrics(errors: 3, words: 9))
        #expect(outcome.streak == 0 && !outcome.unlocksNextLevel)
    }

    @Test func thresholdsAreConfigurable() {
        let rule = PromotionRule(maxErrorsPerTurn: 1, minWordsPerTurn: 12, strongSessionsRequired: 2)
        #expect(!rule.isStrong(metrics(errors: 1.5, words: 12)))
        #expect(rule.apply(streak: 1, session: metrics(errors: 0.5, words: 12)).unlocksNextLevel)
    }

    @Test func levelLadder() {
        #expect(CEFRLevel.a1.next == .a2)
        #expect(CEFRLevel.b2.next == nil)
    }
}

struct PhraseMatcherTests {
    @Test func ignoresCaseAndPunctuation() {
        #expect(PhraseMatcher.matches(heard: "el cruasán está muy rico", target: "El cruasán está muy rico."))
    }

    @Test func accentsAreIgnored() {
        #expect(PhraseMatcher.matches(heard: "el cruasan esta muy rico", target: "El cruasán está muy rico."))
    }

    @Test func differentWordsDoNotMatch() {
        #expect(!PhraseMatcher.matches(heard: "el cruasán es muy rico", target: "El cruasán está muy rico."))
        #expect(!PhraseMatcher.matches(heard: "el sábado fue al parque", target: "El sábado fui al parque."))
    }

    @Test(arguments: [("quiere", "quiero"), ("como", "comí"), ("llama", "llamo"), ("trabaja", "trabajo")])
    func wrongVerbEndingDoesNotMatch(heard: String, target: String) {
        #expect(!PhraseMatcher.matches(heard: heard, target: target))
    }

    @Test func repeatedWordCountsForNearestOccurrence() {
        let progress = PhraseMatcher.progress(heard: ["un café"], target: "Un café y un cruasán")
        #expect(progress.recognized == [true, true, false, false, false])
    }

    @Test func partialTranscriptReportsMissedWords() {
        let progress = PhraseMatcher.progress(heard: ["quiero un café"], target: "Quiero un café, por favor.")
        #expect(!progress.isComplete)
        #expect(progress.missedWords == ["por", "favor."])
        #expect(progress.fraction == 0.6)
    }

    @Test func progressKeepsEarlierWords() {
        let first = PhraseMatcher.progress(heard: ["quiero un café"], target: "Quiero un café, por favor.")
        let second = PhraseMatcher.progress(heard: ["por favor"], target: "Quiero un café, por favor.", previous: first)
        #expect(second.isComplete)
    }

    @Test func anyAlternativeCanSupplyAWord() {
        let progress = PhraseMatcher.progress(heard: ["me lo yevo", "me lo llevo"], target: "Me lo llevo")
        #expect(progress.isComplete)
    }

    @Test func digitsMatchSpelledOutNumbers() {
        #expect(PhraseMatcher.matches(heard: "son 10 pesos", target: "Son diez pesos."))
        #expect(PhraseMatcher.matches(heard: "2 cafés por favor", target: "Dos cafés, por favor."))
        #expect(!PhraseMatcher.matches(heard: "son 5 pesos", target: "Son diez pesos."))
    }

    @Test func emptyTranscriptRecognizesNothing() {
        #expect(PhraseMatcher.progress(heard: [""], target: "Vi una película.").fraction == 0)
    }
}
