import Darwin
import Foundation

enum FullDiskAccessChecker {
    enum Status: Equatable {
        case granted
        case denied
        case unknown
    }

    /// This is a heuristic: listing a TCC-protected directory suggests that
    /// Full Disk Access is granted, but it is not an authoritative TCC query.
    static func status(fileManager: FileManager = .default) -> Status {
        let homeDirectory = fileManager.homeDirectoryForCurrentUser
        let candidates = [
            "Library/Safari",
            "Library/Mail",
            "Library/Messages"
        ].map { homeDirectory.appendingPathComponent($0, isDirectory: true) }

        for candidate in candidates {
            do {
                _ = try fileManager.contentsOfDirectory(atPath: candidate.path)
                return .granted
            } catch {
                switch classify(error) {
                case .denied:
                    return .denied
                case .missing, .other:
                    continue
                }
            }
        }
        return .unknown
    }

    private enum FailureKind {
        case denied
        case missing
        case other
    }

    private static func classify(_ error: Error) -> FailureKind {
        let nsError = error as NSError
        if nsError.domain == NSPOSIXErrorDomain {
            if nsError.code == Int(EACCES) || nsError.code == Int(EPERM) {
                return .denied
            }
            if nsError.code == Int(ENOENT) {
                return .missing
            }
        }

        if nsError.domain == NSCocoaErrorDomain {
            if nsError.code == CocoaError.Code.fileReadNoPermission.rawValue {
                return .denied
            }
            if nsError.code == CocoaError.Code.fileNoSuchFile.rawValue
                || nsError.code == CocoaError.Code.fileReadNoSuchFile.rawValue {
                return .missing
            }
        }

        if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            return classify(underlyingError)
        }
        return .other
    }
}
