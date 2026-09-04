import XCTest
@testable import QuickJasoCore

final class FilenameNormalizerTests: XCTestCase {
    func testNFCStringIsAlreadyNFC() {
        XCTAssertEqual(FilenameNormalizer.classify("한글.txt"), .alreadyNFC)
    }

    func testNFDHangulNeedsRenameAndNormalizes() {
        let input = "\u{1112}\u{1161}\u{11AB}\u{1100}\u{1173}\u{11AF}.txt"
        XCTAssertEqual(FilenameNormalizer.classify(input), .needsRename)
        XCTAssertEqual(FilenameNormalizer.normalizedNFC(input), "한글.txt")
    }

    func testNormalizationIsIdempotent() {
        let once = FilenameNormalizer.normalizedNFC("e\u{0301}-\u{1112}\u{1161}\u{11AB}")
        XCTAssertEqual(FilenameNormalizer.normalizedNFC(once), once)
    }

    func testCombiningAccentNormalizes() {
        XCTAssertEqual(FilenameNormalizer.normalizedNFC("e\u{0301}"), "é")
    }

    func testWholeFilenamePreservesExtensionCharacters() {
        let input = "\u{1111}\u{1161}\u{110B}\u{1175}\u{11AF}.tar.gz"
        XCTAssertEqual(FilenameNormalizer.normalizedNFC(input), "파일.tar.gz")
    }
}
