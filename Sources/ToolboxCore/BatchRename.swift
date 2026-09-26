import Darwin
import Foundation

public struct BatchRenameOptions: Equatable {
    public var prefix: String
    public var suffix: String
    public var searchText: String
    public var replacementText: String
    public var numberingEnabled: Bool
    public var numberStart: Int
    public var numberPadding: Int

    public init(prefix: String = "", suffix: String = "", searchText: String = "", replacementText: String = "", numberingEnabled: Bool = false, numberStart: Int = 1, numberPadding: Int = 1) {
        self.prefix = prefix; self.suffix = suffix
        self.searchText = searchText; self.replacementText = replacementText
        self.numberingEnabled = numberingEnabled; self.numberStart = numberStart; self.numberPadding = numberPadding
    }
}

public struct BatchRenamePreview: Identifiable {
    public let id = UUID()
    public let sourceURL: URL
    public let originalName: String
    public let newName: String
    public var issue: String?
    public var isReady: Bool { issue == nil }
    fileprivate let fingerprint: RenameFingerprint?
}

public struct BatchRenameRecord: Identifiable {
    public let id = UUID()
    public let operationID: UUID
    public let sourceURL: URL
    public let targetURL: URL
    public let succeeded: Bool
    public let message: String
    public let date: Date
    public var canUndo: Bool { succeeded && fingerprint != nil }
    fileprivate var fingerprint: RenameFingerprint?

    public var exportLine: String {
        let formatter = ISO8601DateFormatter()
        return [formatter.string(from: date), succeeded ? "成功" : "失败", sourceURL.path, targetURL.path, message]
            .map { $0.replacingOccurrences(of: "\t", with: " ").replacingOccurrences(of: "\n", with: " ") }
            .joined(separator: "\t")
    }
}

private struct RenameFingerprint: Equatable {
    let device: dev_t
    let inode: ino_t
    let size: off_t
    let modifiedSeconds: Int
    let modifiedNanoseconds: Int
    let changedSeconds: Int
    let changedNanoseconds: Int

    func matchesRenamedOriginal(_ original: RenameFingerprint) -> Bool {
        device == original.device && inode == original.inode && size == original.size &&
        modifiedSeconds == original.modifiedSeconds && modifiedNanoseconds == original.modifiedNanoseconds
    }

    init(_ value: stat) {
        device = value.st_dev; inode = value.st_ino; size = value.st_size
        modifiedSeconds = value.st_mtimespec.tv_sec; modifiedNanoseconds = value.st_mtimespec.tv_nsec
        changedSeconds = value.st_ctimespec.tv_sec; changedNanoseconds = value.st_ctimespec.tv_nsec
    }
}

public enum BatchRename {
    public static func preview(urls: [URL], options: BatchRenameOptions) -> [BatchRenamePreview] {
        var result: [BatchRenamePreview] = []
        var seenSources = Set<String>()
        for (index, input) in urls.enumerated() {
            let name = input.lastPathComponent
            let parent = input.deletingLastPathComponent().standardizedFileURL.resolvingSymlinksInPath()
            let source = parent.appendingPathComponent(name)
            let generatedName = makeName(name, options: options, index: index)
            let targetName = generatedName ?? ""
            let identity = source.path.precomposedStringWithCanonicalMapping.lowercased()
            var issue: String?
            var fingerprint: RenameFingerprint?
            if !input.isFileURL { issue = "只支持本地文件" }
            else if generatedName == nil { issue = "序号超出可用范围" }
            else if !seenSources.insert(identity).inserted { issue = "文件重复选择" }
            else if let invalid = invalidName(targetName) { issue = invalid }
            else if targetName == name { issue = "名称未改变" }
            else {
                var info = stat()
                if lstat(source.path, &info) != 0 { issue = "源文件不存在或无法访问" }
                else if info.st_mode & mode_t(S_IFMT) != mode_t(S_IFREG) { issue = "只支持普通文件，不能重命名目录或符号链接" }
                else { fingerprint = RenameFingerprint(info) }
            }
            result.append(BatchRenamePreview(sourceURL: source, originalName: name, newName: targetName, issue: issue, fingerprint: fingerprint))
        }
        let sourceKeys = Set(result.map { $0.sourceURL.path.precomposedStringWithCanonicalMapping.lowercased() })
        var targets: [String: [Int]] = [:]
        for index in result.indices {
            let row = result[index]
            let target = row.sourceURL.deletingLastPathComponent().appendingPathComponent(row.newName)
            let key = target.path.precomposedStringWithCanonicalMapping.lowercased()
            targets[key, default: []].append(index)
            if result[index].issue == nil {
                if sourceKeys.contains(key) { result[index].issue = "目标被选中的原文件占用；暂不支持循环改名" }
                else if pathExistsWithoutFollowing(target.path) { result[index].issue = "目标已存在" }
            }
        }
        for indices in targets.values where indices.count > 1 {
            for index in indices { result[index].issue = "多个文件生成同一目标名称" }
        }
        return result
    }

    public static func execute(preview: [BatchRenamePreview]) -> [BatchRenameRecord] {
        preview.map { row in
            let target = row.sourceURL.deletingLastPathComponent().appendingPathComponent(row.newName)
            guard row.isReady, let original = row.fingerprint else {
                return record(row.id, row.sourceURL, target, false, row.issue ?? "预览无效", nil)
            }
            do {
                let folder = row.sourceURL.deletingLastPathComponent()
                let descriptor = try openDirectory(folder)
                defer { close(descriptor) }
                guard try fingerprint(name: row.originalName, directory: descriptor) == original else {
                    return record(row.id, row.sourceURL, target, false, "源文件已被外部修改或替换，请重新预览", nil)
                }
                guard try fingerprint(name: row.newName, directory: descriptor) == nil else {
                    return record(row.id, row.sourceURL, target, false, "目标已存在，请重新预览", nil)
                }
                guard renameatx_np(descriptor, row.originalName, descriptor, row.newName, UInt32(RENAME_EXCL)) == 0 else {
                    return record(row.id, row.sourceURL, target, false, "重命名失败：\(String(cString: strerror(errno)))", nil)
                }
                let observed = try? fingerprint(name: row.newName, directory: descriptor)
                let updated = observed.flatMap { $0.matchesRenamedOriginal(original) ? $0 : nil }
                return record(row.id, row.sourceURL, target, true,
                              updated == nil ? "重命名成功；文件随后发生变化，无法安全撤销" : "重命名成功", updated)
            } catch {
                return record(row.id, row.sourceURL, target, false, error.localizedDescription, nil)
            }
        }
    }

    public static func undo(records: [BatchRenameRecord]) -> [BatchRenameRecord] {
        var pending = records
        return undo(records: &pending)
    }

    /// Removes successful undos from `records` and refreshes the previous step of a rename chain.
    public static func undo(records: inout [BatchRenameRecord]) -> [BatchRenameRecord] {
        var results: [BatchRenameRecord] = []
        for index in records.indices.reversed() {
            let prior = records[index]
            guard prior.succeeded, let expected = prior.fingerprint else { continue }
            let result: BatchRenameRecord
            do {
                let descriptor = try openDirectory(prior.targetURL.deletingLastPathComponent())
                defer { close(descriptor) }
                if try fingerprint(name: prior.targetURL.lastPathComponent, directory: descriptor) != expected {
                    result = record(prior.operationID, prior.targetURL, prior.sourceURL, false, "撤销失败：文件已被修改或替换", nil)
                } else if try fingerprint(name: prior.sourceURL.lastPathComponent, directory: descriptor) != nil {
                    result = record(prior.operationID, prior.targetURL, prior.sourceURL, false, "撤销失败：原名称已被占用", nil)
                } else if renameatx_np(descriptor, prior.targetURL.lastPathComponent, descriptor, prior.sourceURL.lastPathComponent, UInt32(RENAME_EXCL)) != 0 {
                    result = record(prior.operationID, prior.targetURL, prior.sourceURL, false, "撤销失败：\(String(cString: strerror(errno)))", nil)
                } else {
                    let restored = try? fingerprint(name: prior.sourceURL.lastPathComponent, directory: descriptor)
                    if index > 0, let restored {
                        for earlier in 0..<index where records[earlier].targetURL == prior.sourceURL {
                            if let priorIdentity = records[earlier].fingerprint,
                               restored.matchesRenamedOriginal(priorIdentity) {
                                records[earlier].fingerprint = restored
                            }
                        }
                    }
                    result = record(prior.operationID, prior.targetURL, prior.sourceURL, true, "已撤销", nil)
                }
            } catch {
                result = record(prior.operationID, prior.targetURL, prior.sourceURL, false, "撤销失败：\(error.localizedDescription)", nil)
            }
            results.append(result)
            if result.succeeded { records.remove(at: index) }
        }
        return results
    }

    private static func makeName(_ name: String, options: BatchRenameOptions, index: Int) -> String? {
        let characters = Array(name)
        let dot = characters.lastIndex(of: ".")
        let split = (dot != nil && dot! > 0) ? dot! : characters.count
        let stem = String(characters[..<split])
        let ext = split == characters.count ? "" : String(characters[split...])
        let replaced = options.searchText.isEmpty ? stem : stem.replacingOccurrences(of: options.searchText, with: options.replacementText)
        let number: String
        if options.numberingEnabled {
            let value = options.numberStart.addingReportingOverflow(index)
            guard !value.overflow, value.partialValue >= 0, (1...12).contains(options.numberPadding) else { return nil }
            let digits = String(value.partialValue)
            number = String(repeating: "0", count: max(0, options.numberPadding - digits.count)) + digits
        } else { number = "" }
        return options.prefix + replaced + options.suffix + number + ext
    }

    private static func invalidName(_ name: String) -> String? {
        if name.isEmpty || name == "." || name == ".." || name.hasPrefix(".") && name.dropFirst().first == "." { return "文件名无效" }
        if name.utf8.count > 255 { return "文件名超过 255 字节" }
        if name.contains("/") || name.contains(":") || name.contains("\0") { return "文件名不能包含路径分隔符、冒号或空字符" }
        return nil
    }

    private static func pathExistsWithoutFollowing(_ path: String) -> Bool {
        var info = stat()
        return lstat(path, &info) == 0 || errno != ENOENT
    }

    private static func openDirectory(_ url: URL) throws -> Int32 {
        let descriptor = open(url.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
        guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        return descriptor
    }

    private static func fingerprint(name: String, directory: Int32) throws -> RenameFingerprint? {
        var info = stat()
        if fstatat(directory, name, &info, AT_SYMLINK_NOFOLLOW) == 0 {
            guard info.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG) else { return RenameFingerprint(info) }
            return RenameFingerprint(info)
        }
        if errno == ENOENT { return nil }
        throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }

    private static func record(_ id: UUID, _ source: URL, _ target: URL, _ succeeded: Bool, _ message: String, _ fingerprint: RenameFingerprint?) -> BatchRenameRecord {
        BatchRenameRecord(operationID: id, sourceURL: source, targetURL: target, succeeded: succeeded, message: message, date: Date(), fingerprint: fingerprint)
    }
}
