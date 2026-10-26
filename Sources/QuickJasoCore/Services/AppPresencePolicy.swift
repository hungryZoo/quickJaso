import Foundation

/// Dock 아이콘 표시와 자동 종료 판정. 앱은 LSUIElement로 시작하므로 기본 상태는 Dock 없음.
public enum AppPresencePolicy {
    public struct Input: Equatable {
        /// 사용자가 앱을 직접 실행한 세션인지 (서비스, URL, 문서 열기 실행이 아님).
        public var isUserSession: Bool
        /// 화면에 열려 있는 일반 창 수 (메인, 상세, 설정, 권한 안내 창). 최소화된 창 포함.
        public var openWindowCount: Int
        /// 화면에 열려 있는 패널 수 (결과 패널, 경고창, 열기/저장 패널).
        public var openPanelCount: Int
        /// 검사, 변환, 모달 확인 창이 진행 중인지.
        public var isBusy: Bool
        /// 실행 직후 서비스 요청을 기다리는 중인지.
        public var isLaunchPending: Bool
        /// 사용자가 앱을 가렸는지 (가린 앱의 창은 보이지 않는 것으로 집계됨).
        public var isHidden: Bool

        public init(
            isUserSession: Bool,
            openWindowCount: Int,
            openPanelCount: Int,
            isBusy: Bool,
            isLaunchPending: Bool,
            isHidden: Bool
        ) {
            self.isUserSession = isUserSession
            self.openWindowCount = openWindowCount
            self.openPanelCount = openPanelCount
            self.isBusy = isBusy
            self.isLaunchPending = isLaunchPending
            self.isHidden = isHidden
        }
    }

    /// 직접 실행한 세션에서 창이 열려 있을 때만 Dock 아이콘을 표시한다.
    public static func showsDockIcon(_ input: Input) -> Bool {
        input.isUserSession && input.openWindowCount > 0
    }

    /// 작업이 끝나고 패널과 창이 모두 닫혔으면 종료한다.
    public static func shouldTerminate(_ input: Input) -> Bool {
        !input.isHidden
            && !input.isBusy
            && !input.isLaunchPending
            && input.openWindowCount == 0
            && input.openPanelCount == 0
    }
}
