import Foundation
import QuickJasoCore

@MainActor
final class AppSettings: ObservableObject {
    private enum Key {
        static let skipConversionConfirmation = "skipConversionConfirmation"
        static let renameSymlinkItself = "renameSymlinkItself"
        static let recurseIntoPackages = "recurseIntoPackages"
        static let includeHiddenFiles = "includeHiddenFiles"
        static let hasDismissedFullDiskAccessOnboarding = "hasDismissedFullDiskAccessOnboarding"
    }

    private let defaults: UserDefaults

    @Published var skipConversionConfirmation: Bool {
        didSet { defaults.set(skipConversionConfirmation, forKey: Key.skipConversionConfirmation) }
    }
    @Published var renameSymlinkItself: Bool {
        didSet { defaults.set(renameSymlinkItself, forKey: Key.renameSymlinkItself) }
    }
    @Published var recurseIntoPackages: Bool {
        didSet { defaults.set(recurseIntoPackages, forKey: Key.recurseIntoPackages) }
    }
    @Published var includeHiddenFiles: Bool {
        didSet { defaults.set(includeHiddenFiles, forKey: Key.includeHiddenFiles) }
    }
    @Published var hasDismissedFullDiskAccessOnboarding: Bool {
        didSet {
            defaults.set(
                hasDismissedFullDiskAccessOnboarding,
                forKey: Key.hasDismissedFullDiskAccessOnboarding
            )
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.skipConversionConfirmation: false,
            Key.renameSymlinkItself: false,
            Key.recurseIntoPackages: false,
            Key.includeHiddenFiles: true,
            Key.hasDismissedFullDiskAccessOnboarding: false
        ])
        skipConversionConfirmation = defaults.bool(forKey: Key.skipConversionConfirmation)
        renameSymlinkItself = defaults.bool(forKey: Key.renameSymlinkItself)
        recurseIntoPackages = defaults.bool(forKey: Key.recurseIntoPackages)
        includeHiddenFiles = defaults.bool(forKey: Key.includeHiddenFiles)
        hasDismissedFullDiskAccessOnboarding = defaults.bool(
            forKey: Key.hasDismissedFullDiskAccessOnboarding
        )
    }

    var scanOptions: ScanOptions {
        ScanOptions(
            followSymlinks: false,
            renameSymlinkItself: renameSymlinkItself,
            recurseIntoPackages: recurseIntoPackages,
            includeHidden: includeHiddenFiles,
            skipSystemFiles: true
        )
    }
}
