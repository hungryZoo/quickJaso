import QuickJasoCore
import XCTest

final class UpdateCheckTests: TemporaryDirectoryTestCase {
    func testSemanticVersionParsing() {
        XCTAssertEqual(SemanticVersion("1.2.3"), SemanticVersion(major: 1, minor: 2, patch: 3))
        XCTAssertEqual(SemanticVersion("v1.0.10"), SemanticVersion(major: 1, minor: 0, patch: 10))
        XCTAssertNil(SemanticVersion("1.2"))
        XCTAssertNil(SemanticVersion("1.2.3-rc1"))
        XCTAssertNil(SemanticVersion("1.+2.3"))
        XCTAssertNil(SemanticVersion(""))
    }

    func testSemanticVersionOrdering() {
        XCTAssertLessThan(SemanticVersion("1.0.9")!, SemanticVersion("1.0.10")!)
        XCTAssertLessThan(SemanticVersion("1.9.9")!, SemanticVersion("2.0.0")!)
        XCTAssertFalse(SemanticVersion("1.0.0")! < SemanticVersion("1.0.0")!)
    }

    func testShouldCheckOncePerDay() {
        XCTAssertTrue(UpdatePolicy.shouldCheck(now: 1_000, checkedAt: 0))
        XCTAssertFalse(UpdatePolicy.shouldCheck(now: 100_000, checkedAt: 100_000 - 3_600))
        XCTAssertTrue(UpdatePolicy.shouldCheck(now: 200_000, checkedAt: 200_000 - 86_400))
        XCTAssertTrue(UpdatePolicy.shouldCheck(now: 1_000, checkedAt: 5_000))
    }

    func testPendingUpdateRespectsCurrentAndSkippedVersion() {
        let current = SemanticVersion("1.0.0")!
        let cache = UpdateCache(checkedAt: 1, latestVersion: "1.0.1")
        XCTAssertEqual(UpdatePolicy.pendingUpdate(current: current, cache: cache, skippedVersion: nil), SemanticVersion("1.0.1"))
        XCTAssertNil(UpdatePolicy.pendingUpdate(current: current, cache: cache, skippedVersion: "1.0.1"))
        XCTAssertEqual(UpdatePolicy.pendingUpdate(current: current, cache: cache, skippedVersion: "1.0.0"), SemanticVersion("1.0.1"))
        XCTAssertNil(UpdatePolicy.pendingUpdate(current: SemanticVersion("1.0.1")!, cache: cache, skippedVersion: nil))
        XCTAssertNil(UpdatePolicy.pendingUpdate(current: current, cache: UpdateCache(), skippedVersion: nil))
    }

    func testCacheRoundTripAndCorruptFile() throws {
        let directory = try makeTemporaryDirectory()
        let store = UpdateCacheStore(fileURL: directory.appendingPathComponent("nested/update-check.json"))
        XCTAssertEqual(store.load(), UpdateCache())

        let cache = UpdateCache(checkedAt: 42, latestVersion: "1.0.1", releaseNotes: "줄 1\n줄 2", releaseURL: "https://example.com")
        try store.save(cache)
        XCTAssertEqual(store.load(), cache)

        try Data("not json".utf8).write(to: store.fileURL)
        XCTAssertEqual(store.load(), UpdateCache())
    }

    func testLatestReleaseParser() {
        let json = """
        {"tag_name":"v1.0.1","body":"## 변경\\n- 항목","html_url":"https://github.com/o/r/releases/tag/v1.0.1","draft":false,"prerelease":false}
        """
        let release = LatestReleaseParser.parse(Data(json.utf8))
        XCTAssertEqual(release?.version, SemanticVersion("1.0.1"))
        XCTAssertEqual(release?.notes, "## 변경\n- 항목")
        XCTAssertEqual(release?.url.absoluteString, "https://github.com/o/r/releases/tag/v1.0.1")

        let prerelease = json.replacingOccurrences(of: "\"prerelease\":false", with: "\"prerelease\":true")
        XCTAssertNil(LatestReleaseParser.parse(Data(prerelease.utf8)))
        XCTAssertNil(LatestReleaseParser.parse(Data("{\"message\":\"API rate limit exceeded\"}".utf8)))
    }

    func testReleaseNotesFormatter() {
        let body = """
        첫 문장.

        ## What's new

        - **변경 하나.** 설명
          - 하위 항목


        ```bash
        brew install x
        ```
        """
        XCTAssertEqual(
            ReleaseNotesFormatter.inlineMarkdown(body),
            "첫 문장.\n\n**What's new**\n\n• **변경 하나.** 설명\n    • 하위 항목\n\nbrew install x"
        )
    }

    func testInstallMethodClassification() {
        let caskAppleSilicon: Set<String> = ["/opt/homebrew/Caskroom/quickjaso", "/opt/homebrew/bin/brew"]
        XCTAssertEqual(
            InstallMethod.classify(appPath: "/Applications/quickJaso.app", homeDirectory: "/Users/u", fileExists: caskAppleSilicon.contains),
            .homebrew(brewPath: "/opt/homebrew/bin/brew")
        )
        let caskIntel: Set<String> = ["/usr/local/Caskroom/quickjaso", "/usr/local/bin/brew"]
        XCTAssertEqual(
            InstallMethod.classify(appPath: "/Users/u/Applications/quickJaso.app", homeDirectory: "/Users/u/", fileExists: caskIntel.contains),
            .homebrew(brewPath: "/usr/local/bin/brew")
        )
        XCTAssertEqual(
            InstallMethod.classify(appPath: "/Applications/quickJaso.app", homeDirectory: "/Users/u", fileExists: { _ in false }),
            .manual
        )
        XCTAssertEqual(
            InstallMethod.classify(appPath: "/Users/u/dev/quickJaso/build/quickJaso.app", homeDirectory: "/Users/u", fileExists: caskAppleSilicon.contains),
            .manual
        )
    }

    func testHomebrewScriptQuotesPathsAndWaitsForProcess() {
        let script = UpdateScript.homebrew(brewPath: "/opt/homebrew/bin/brew", appPath: "/Users/o'neil/Applications/quickJaso.app", waitForPID: 123)
        XCTAssertTrue(script.hasPrefix("#!/bin/zsh\n"))
        XCTAssertTrue(script.contains("while kill -0 123 2>/dev/null"))
        XCTAssertTrue(script.contains("'/opt/homebrew/bin/brew' upgrade hungryZoo/tap/quickjaso"))
        XCTAssertTrue(script.contains("open '/Users/o'\\''neil/Applications/quickJaso.app'"))
    }
}
