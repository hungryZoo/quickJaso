import QuickJasoCore
import XCTest

final class AppPresencePolicyTests: XCTestCase {
    private func input(
        isUserSession: Bool = false,
        openWindowCount: Int = 0,
        openPanelCount: Int = 0,
        isBusy: Bool = false,
        isLaunchPending: Bool = false,
        isHidden: Bool = false
    ) -> AppPresencePolicy.Input {
        AppPresencePolicy.Input(
            isUserSession: isUserSession,
            openWindowCount: openWindowCount,
            openPanelCount: openPanelCount,
            isBusy: isBusy,
            isLaunchPending: isLaunchPending,
            isHidden: isHidden
        )
    }

    func testServiceSessionNeverShowsDockIcon() {
        XCTAssertFalse(AppPresencePolicy.showsDockIcon(input(openWindowCount: 1, openPanelCount: 1)))
    }

    func testUserSessionShowsDockIconOnlyWhileWindowIsOpen() {
        XCTAssertTrue(AppPresencePolicy.showsDockIcon(input(isUserSession: true, openWindowCount: 1)))
        XCTAssertFalse(AppPresencePolicy.showsDockIcon(input(isUserSession: true, openPanelCount: 1)))
    }

    func testTerminatesWhenIdleWithNothingOpen() {
        XCTAssertTrue(AppPresencePolicy.shouldTerminate(input()))
        XCTAssertTrue(AppPresencePolicy.shouldTerminate(input(isUserSession: true)))
    }

    func testKeepsRunningWhileAnythingIsOpenOrBusy() {
        XCTAssertFalse(AppPresencePolicy.shouldTerminate(input(openWindowCount: 1)))
        XCTAssertFalse(AppPresencePolicy.shouldTerminate(input(openPanelCount: 1)))
        XCTAssertFalse(AppPresencePolicy.shouldTerminate(input(isBusy: true)))
        XCTAssertFalse(AppPresencePolicy.shouldTerminate(input(isLaunchPending: true)))
        XCTAssertFalse(AppPresencePolicy.shouldTerminate(input(isHidden: true)))
    }
}
