import Testing
@testable import HablemosCore

struct SentenceChunkerTests {
    func run(_ tokens: [String]) -> [String] {
        var chunker = SentenceChunker()
        var out = tokens.flatMap { chunker.feed($0) }
        if let rest = chunker.flush() { out.append(rest) }
        return out
    }

    @Test func splitsSentencesAcrossTokensMidWord() {
        #expect(run(["¡Ho", "la! ¿Qué", " ta", "l? Muy bi", "en."]) == ["¡Hola!", "¿Qué tal?", "Muy bien."])
    }

    @Test func emitsOnlyOnceBoundaryIsKnown() {
        var chunker = SentenceChunker()
        #expect(chunker.feed("Hola.") == [])
        #expect(chunker.feed(" Qué") == ["Hola."])
        #expect(chunker.flush() == "Qué")
    }

    @Test func doesNotSplitOnAbbreviations() {
        #expect(run(["Hable con el Sr. Pérez y la Sra. López. Gracias."]) == ["Hable con el Sr. Pérez y la Sra. López.", "Gracias."])
    }

    @Test func doesNotSplitOnDecimals() {
        #expect(run(["Son 4", ".", "50 euros. ¿Algo más?"]) == ["Son 4.50 euros.", "¿Algo más?"])
    }

    @Test func handlesEllipsisAndRepeatedMarks() {
        #expect(run(["Bueno… vale. ¡¿Qué?! Nada."]) == ["Bueno…", "vale.", "¡¿Qué?!", "Nada."])
    }

    @Test func stopsAtCorrectionLine() {
        let out = run(["Muy bien. ¿Y tú?\n", "CORR", "ECTION: es rico => está rico | Use estar.", " Otra frase. Más."])
        #expect(out == ["Muy bien.", "¿Y tú?"])
    }

    @Test func correctionSplitAcrossTokensAtLineStart() {
        var chunker = SentenceChunker()
        #expect(chunker.feed("Hola.\nCOR") == ["Hola."])
        #expect(chunker.feed("RECTION: a => b | c") == [])
        #expect(chunker.flush() == nil)
    }

    @Test func flushReturnsTrailingTextWithoutTerminator() {
        #expect(run(["Hola, ¿cómo estás"]) == ["Hola, ¿cómo estás"])
    }

    @Test func lineStartingLikeMarkerButDifferentIsSpoken() {
        #expect(run(["Hola.\nCORREO es útil. Sí."]) == ["Hola.", "CORREO es útil.", "Sí."])
    }
}
