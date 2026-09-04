import Foundation

public struct VolumeRiskAnalyzer {
    private let gitDetector: GitRepositoryDetector

    public init(gitDetector: GitRepositoryDetector = GitRepositoryDetector()) {
        self.gitDetector = gitDetector
    }

    public func assess(plan: RenamePlan, options: ScanOptions = .default) -> RiskAssessment {
        var reasons: [RiskReason] = []
        if plan.items.count >= 100 { reasons.append(.manyItems) }
        if plan.operations.count >= 50 { reasons.append(.manyRenames) }
        if plan.summary.collisions >= 1 { reasons.append(.hasCollisions) }
        if plan.rootURLs.contains(where: isSyncedLocation) { reasons.append(.syncedLocation) }
        if plan.rootURLs.contains(where: isExternalOrNetworkVolume) { reasons.append(.externalOrNetworkVolume) }
        if plan.rootURLs.contains(where: gitDetector.isInsideGitRepository) { reasons.append(.gitRepository) }
        if options.recurseIntoPackages { reasons.append(.packageRecursionEnabled) }

        let keepCount = plan.summary.alreadyNFC
        let skipCount = plan.items.count - keepCount - plan.operations.count
        return RiskAssessment(
            reasons: reasons,
            plannedRenameCount: plan.operations.count,
            keepCount: keepCount,
            skipCount: max(0, skipCount),
            totalCount: plan.items.count
        )
    }

    private func isSyncedLocation(_ url: URL) -> Bool {
        do {
            if try url.resourceValues(forKeys: [.isUbiquitousItemKey]).isUbiquitousItem == true {
                return true
            }
        } catch {
            // Path components remain a conservative fallback for provider-managed locations.
        }
        let markers = ["Mobile Documents", "Dropbox", "OneDrive", "Google Drive", "CloudStorage"]
        return url.pathComponents.contains { component in
            markers.contains { marker in component.localizedCaseInsensitiveContains(marker) }
        }
    }

    private func isExternalOrNetworkVolume(_ url: URL) -> Bool {
        do {
            let values = try url.resourceValues(forKeys: [
                .volumeIsInternalKey, .volumeIsLocalKey, .volumeIsRemovableKey
            ])
            return values.volumeIsInternal == false || values.volumeIsLocal == false || values.volumeIsRemovable == true
        } catch {
            // Unknown volume properties do not add a warning without affirmative evidence.
            return false
        }
    }
}
