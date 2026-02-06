import Foundation

enum AssetLocator {
    static let assetDirectoryName = "assets"
    static let appsDirectoryName = "app"
    static let operatorConfigFilename = "epconfig.json"

    static func documentsURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    static func assetsRoot() -> URL? {
        let documents = documentsURL().appendingPathComponent(assetDirectoryName, isDirectory: true)
        if FileManager.default.fileExists(atPath: documents.path) {
            return documents
        }
        return Bundle.main.resourceURL?.appendingPathComponent(assetDirectoryName, isDirectory: true)
    }

    static func appsRoot() -> URL? {
        let documents = documentsURL().appendingPathComponent(appsDirectoryName, isDirectory: true)
        if FileManager.default.fileExists(atPath: documents.path) {
            return documents
        }
        return Bundle.main.resourceURL?.appendingPathComponent(appsDirectoryName, isDirectory: true)
    }

    static func resourceRoot() -> URL? {
        let documents = documentsURL()
        if FileManager.default.fileExists(atPath: documents.path) {
            return documents
        }
        return Bundle.main.resourceURL
    }
}

enum AssetPathResolver {
    static func resolve(_ rawPath: String?, baseURL: URL) -> URL? {
        guard let rawPath, !rawPath.isEmpty else { return nil }
        if rawPath.hasPrefix("A:") {
            let trimmed = rawPath.dropFirst(2)
            let cleaned = trimmed.hasPrefix("/") ? String(trimmed.dropFirst()) : String(trimmed)
            if let root = AssetLocator.resourceRoot() {
                return root.appendingPathComponent(cleaned)
            }
            return nil
        }
        if rawPath.hasPrefix("/") {
            return URL(fileURLWithPath: rawPath)
        }
        return baseURL.appendingPathComponent(rawPath)
    }
}

enum AssetRepository {
    static func loadOperators() -> [OperatorAsset] {
        guard let assetsRoot = AssetLocator.assetsRoot() else { return [] }
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: assetsRoot, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return []
        }
        let decoder = JSONDecoder()
        return entries.compactMap { entry in
            let isDirectory = (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            guard isDirectory else { return nil }
            let configURL = entry.appendingPathComponent(AssetLocator.operatorConfigFilename)
            guard let data = try? Data(contentsOf: configURL),
                  let config = try? decoder.decode(OperatorConfig.self, from: data) else {
                return nil
            }
            return OperatorAsset(config: config, baseURL: entry)
        }
    }
}

enum AssetImportError: Error {
    case invalidSelection
}

struct AssetImportResult {
    let assetsURL: URL?
    let appsURL: URL?
}

enum AssetImporter {
    static func importAssets(from url: URL) throws -> AssetImportResult {
        let fm = FileManager.default
        let docs = AssetLocator.documentsURL()
        let selection = url
        let isDirectory = (try? selection.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        guard isDirectory else { throw AssetImportError.invalidSelection }

        let assetsURL = resolveCandidate(named: AssetLocator.assetDirectoryName, in: selection)
        let appsURL = resolveCandidate(named: AssetLocator.appsDirectoryName, in: selection)

        if assetsURL == nil && appsURL == nil {
            throw AssetImportError.invalidSelection
        }

        let importedAssets = try assetsURL.map { source in
            let destination = docs.appendingPathComponent(AssetLocator.assetDirectoryName, isDirectory: true)
            try replaceDirectory(at: destination, with: source, fm: fm)
            return destination
        }

        let importedApps = try appsURL.map { source in
            let destination = docs.appendingPathComponent(AssetLocator.appsDirectoryName, isDirectory: true)
            try replaceDirectory(at: destination, with: source, fm: fm)
            return destination
        }

        return AssetImportResult(assetsURL: importedAssets, appsURL: importedApps)
    }

    private static func resolveCandidate(named name: String, in selection: URL) -> URL? {
        if selection.lastPathComponent == name {
            return selection
        }
        let candidate = selection.appendingPathComponent(name, isDirectory: true)
        return FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
    }

    private static func replaceDirectory(at destination: URL, with source: URL, fm: FileManager) throws {
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        try fm.copyItem(at: source, to: destination)
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var currentScreen: Screen = .mainScreen
    @Published var operators: [OperatorAsset] = []
    @Published var selectedOperator: OperatorAsset?
    @Published var warningInfo = WarningInfo(
        title: "电池电量严重不足",
        description: "请尽快将您的通行认证终端连接至电源适配器。",
        accentColor: AppColors.error
    )
    @Published var importStatus: String?

    func refreshAssets() {
        let assets = AssetRepository.loadOperators()
        operators = assets
        if selectedOperator == nil {
            selectedOperator = assets.first
        }
    }

    func importAssets(from url: URL) {
        do {
            let result = try AssetImporter.importAssets(from: url)
            let assetsResult = result.assetsURL?.lastPathComponent ?? "assets"
            let appsResult = result.appsURL?.lastPathComponent ?? "app"
            importStatus = "已导入 \(assetsResult) / \(appsResult)"
            refreshAssets()
        } catch {
            importStatus = "导入失败：\(error.localizedDescription)"
        }
    }
}
