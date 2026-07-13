// Locate a project's `app-map/` directory and read its config.

import Foundation
import Yams

public let mapDirName = "app-map"
public let configName = "app-map.config.yaml"

public struct Config {
    public let mapDir: URL       // the app-map/ directory
    public let projectRoot: URL  // its parent (where source lives)
    public var launchSurface: String?
    public var sourceGlobs: [String]
    public var screenshotDirs: [String]
    public var ignore: [String]

    public var surfacesDir: URL { mapDir.appendingPathComponent("surfaces") }
    public var schemaPath: URL {
        mapDir.appendingPathComponent("schema/surface.schema.json")
    }
    public var renderedDir: URL { mapDir.appendingPathComponent("rendered") }
    public var manifestPath: URL { mapDir.appendingPathComponent("manifest.yaml") }

    public init(
        mapDir: URL,
        launchSurface: String? = nil,
        sourceGlobs: [String] = ["**/*"],
        screenshotDirs: [String] = [],
        ignore: [String] = []
    ) {
        self.mapDir = mapDir
        self.projectRoot = mapDir.deletingLastPathComponent()
        self.launchSurface = launchSurface
        self.sourceGlobs = sourceGlobs
        self.screenshotDirs = screenshotDirs
        self.ignore = ignore
    }
}

/// Find the nearest `app-map/` directory: `<start>/app-map`, then `start`
/// itself if it *is* app-map/, then walking up parents.
public func findMapDir(from start: URL? = nil) -> URL? {
    let fm = FileManager.default
    let origin = (start ?? URL(fileURLWithPath: fm.currentDirectoryPath)).standardizedFileURL

    func qualifies(_ cand: URL) -> Bool {
        if fm.fileExists(atPath: cand.appendingPathComponent(configName).path) { return true }
        var isDir: ObjCBool = false
        return cand.lastPathComponent == mapDirName
            && fm.fileExists(atPath: cand.path, isDirectory: &isDir) && isDir.boolValue
    }

    for cand in [origin.appendingPathComponent(mapDirName), origin] where qualifies(cand) {
        return cand
    }
    var parent = origin.deletingLastPathComponent()
    while parent.path != "/" {
        let cand = parent.appendingPathComponent(mapDirName)
        if fm.fileExists(atPath: cand.appendingPathComponent(configName).path) { return cand }
        let next = parent.deletingLastPathComponent()
        if next.path == parent.path { break }
        parent = next
    }
    return nil
}

public func loadConfig(mapDir: URL) -> Config {
    let cfgPath = mapDir.appendingPathComponent(configName)
    var raw: [String: Any] = [:]
    if let text = try? String(contentsOf: cfgPath, encoding: .utf8),
       let loaded = try? Yams.load(yaml: text), let dict = asStringDict(loaded) {
        raw = dict
    }
    func strings(_ key: String) -> [String]? {
        (raw[key] as? [Any])?.compactMap { $0 as? String }
    }
    return Config(
        mapDir: mapDir.standardizedFileURL,
        launchSurface: raw["launch_surface"] as? String,
        sourceGlobs: strings("source_globs") ?? ["**/*"],
        screenshotDirs: strings("screenshot_dirs") ?? [],
        ignore: strings("ignore") ?? []
    )
}
