import Foundation

public enum FileAccessService {
    public static func withSecurityScopedAccess<T>(
        _ url: URL,
        _ body: () throws -> T
    ) rethrows -> T {
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try body()
    }

    public static func isWritableParent(of url: URL) -> Bool {
        FileManager.default.isWritableFile(atPath: url.deletingLastPathComponent().path)
    }

    public static func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    public static func resourceIdentifier(of url: URL) -> Data? {
        do {
            let values = try url.resourceValues(forKeys: [.fileResourceIdentifierKey])
            return dataRepresentation(of: values.fileResourceIdentifier)
        } catch {
            // Identity is optional; callers handle nil as a fail-safe inability to compare.
            return nil
        }
    }

    static func dataRepresentation(of identifier: Any?) -> Data? {
        guard let identifier else { return nil }
        if let data = identifier as? Data {
            return data
        }
        if let data = identifier as? NSData {
            return Data(referencing: data)
        }
        if let object = identifier as? NSObject {
            do {
                return try NSKeyedArchiver.archivedData(
                    withRootObject: object,
                    requiringSecureCoding: false
                )
            } catch {
                // Some file systems expose an opaque, non-archivable identifier.
                return String(describing: object).data(using: .utf8)
            }
        }
        return String(describing: identifier).data(using: .utf8)
    }

    static func opaqueResourceIdentifier(of url: URL) -> Any? {
        do {
            return try url.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier
        } catch {
            // The caller treats a missing identifier conservatively.
            return nil
        }
    }

    static func identifiersEqual(_ lhs: Any, _ rhs: Any) -> Bool {
        if let leftObject = lhs as? NSObject, let rightObject = rhs as? NSObject {
            return leftObject.isEqual(rightObject)
        }
        let left = dataRepresentation(of: lhs)
        let right = dataRepresentation(of: rhs)
        return left != nil && left == right
    }
}
