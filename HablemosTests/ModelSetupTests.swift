import Testing
@testable import Hablemos

struct ModelSetupTests {
    private let expected = ModelVariant.e4b.expectedBytes

    @Test func acceptsExactAndNearSizes() {
        #expect(ModelFileValidation.isAcceptableSize(expected, expected: expected))
        #expect(ModelFileValidation.isAcceptableSize(expected * 98 / 100, expected: expected))
    }

    @Test func rejectsTooSmall() {
        #expect(!ModelFileValidation.isAcceptableSize(expected * 98 / 100 - 1, expected: expected))
        #expect(throws: ModelSetupError.self) {
            try ModelFileValidation.validateImport(size: 1_000, expected: expected)
        }
    }

    @Test func downloadMustMatchServerLength() throws {
        try ModelFileValidation.validateDownload(size: expected, serverLength: expected, expected: expected)
        try ModelFileValidation.validateDownload(size: expected, serverLength: nil, expected: expected)
        #expect(throws: ModelSetupError.truncatedDownload(received: expected - 1, serverLength: expected)) {
            try ModelFileValidation.validateDownload(size: expected - 1, serverLength: expected, expected: expected)
        }
    }
}
