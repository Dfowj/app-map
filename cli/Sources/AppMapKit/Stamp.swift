// Drift detection (`appmap stamp`) — run from a pre-commit hook, exit 0
// unconditionally. Deterministic detection; agentic resolution happens later,
// when a skill session works the review queue.
//
//   1. Re-stamp `last_verified` (sha + date) on records staged in this commit.
//   2. If a surface's `code_anchor.file` or any `watches` entry is staged but
//      its record is not, set `needs_review: true` and warn visibly.
//   3. Rebuild the manifest so `review_queue` reflects the flags.
//
// Records are patched line-surgically: only the tier-1 `last_verified` /
// `needs_review` lines change; every other byte of frontmatter and body —
// hand-authored formatting included — is preserved exactly.

import Foundation

// ── frontmatter line surgery ─────────────────────────────────────────────────

/// Replace (or append) the tier-1 fields inside a record's frontmatter without
/// re-emitting YAML. Returns nil when the file has no frontmatter to patch.
func patchRecordText(
    _ text: String, lastVerified: (sha: String, date: String)? = nil, needsReview: Bool? = nil
) -> String? {
    guard let firstFence = text.range(of: fence) else { return nil }
    let afterFirst = text[firstFence.upperBound...]
    guard let secondFence = afterFirst.range(of: fence) else { return nil }
    let prefix = String(text[..<firstFence.lowerBound])
    let fmText = String(afterFirst[..<secondFence.lowerBound])
    let rest = String(afterFirst[secondFence.lowerBound...])  // closing fence + body, untouched

    var lines = fmText.components(separatedBy: "\n")

    /// Replace the block starting at a top-level `key:` line (the line plus any
    /// following indented/empty continuation lines) with `replacement`; append
    /// before the trailing blank component when the key is absent.
    func setBlock(key: String, replacement: [String]) {
        var start: Int? = nil
        for (i, line) in lines.enumerated()
        where line.hasPrefix("\(key):") {
            start = i
            break
        }
        if let start {
            var end = start + 1
            while end < lines.count {
                let line = lines[end]
                let continues = line.first.map { $0 == " " || $0 == "\t" } ?? false
                // interior blank lines continue the block only if more block follows
                if continues { end += 1; continue }
                break
            }
            lines.replaceSubrange(start..<end, with: replacement)
        } else {
            // frontmatter text ends with "\n", so the final component is "";
            // insert just before it to keep the closing fence on its own line.
            let insertAt = lines.last == "" ? lines.count - 1 : lines.count
            lines.insert(contentsOf: replacement, at: insertAt)
        }
    }

    if let lv = lastVerified {
        setBlock(key: "last_verified", replacement: [
            "last_verified:", "  sha: \(yamlScalar(lv.sha))", "  date: \(yamlScalar(lv.date))",
        ])
    }
    if let nr = needsReview {
        setBlock(key: "needs_review", replacement: ["needs_review: \(nr)"])
    }

    return prefix + fence + lines.joined(separator: "\n") + rest
}

// ── stamp core (git-free, for testability) ───────────────────────────────────

public struct StampResult {
    /// Record ids whose `last_verified` was re-stamped.
    public var stamped: [String] = []
    /// Record ids newly flagged `needs_review` (anchor changed, record didn't).
    public var flagged: [String] = []
    /// Project-root-relative paths of files this run modified (for `git add`).
    public var touchedPaths: [String] = []
    public var notes: [String] = []
}

/// Apply drift rules given the set of project-root-relative changed paths.
public func stamp(
    cfg: Config, changedFiles: Set<String>, sha: String, date: String
) throws -> StampResult {
    var result = StampResult()

    for surface in loadSurfaces(in: cfg.surfacesDir) {
        let recordRel = relativePath(of: surface.path, under: cfg.projectRoot)
        let recordChanged = recordRel.map { changedFiles.contains($0) } ?? false
        // The anchor file is always watched; `watches` extends the net to the
        // files that carry the surface's logic (view models, services).
        var watchedSources: [String] = []
        if let anchorFile = surface.codeAnchor["file"] as? String {
            watchedSources.append(anchorFile)
        }
        watchedSources += surface.watches
        let changedSources = watchedSources.filter { changedFiles.contains($0) }

        var patched: String? = nil
        let original = (try? String(contentsOf: surface.path, encoding: .utf8)) ?? ""
        if recordChanged {
            patched = patchRecordText(original, lastVerified: (sha: sha, date: date))
            if patched != nil { result.stamped.append(surface.id) }
        } else if !changedSources.isEmpty && !surface.needsReview {
            patched = patchRecordText(original, needsReview: true)
            if patched != nil {
                result.flagged.append(surface.id)
                result.notes.append(
                    "\(surface.id): \(changedSources.joined(separator: ", ")) changed but its"
                    + " record didn't — flagged needs_review")
            }
        }
        if let patched, patched != original {
            try patched.write(to: surface.path, atomically: true, encoding: .utf8)
            if let rel = recordRel { result.touchedPaths.append(rel) }
        }
    }

    // Rebuild the manifest so review_queue reflects the new flags.
    let surfaces = loadSurfaces(in: cfg.surfacesDir)
    let manifest = buildManifestYAML(surfaces: surfaces, links: buildLinks(surfaces), cfg: cfg)
    let existing = try? String(contentsOf: cfg.manifestPath, encoding: .utf8)
    if manifest != existing {
        try manifest.write(to: cfg.manifestPath, atomically: true, encoding: .utf8)
        if let rel = relativePath(of: cfg.manifestPath, under: cfg.projectRoot) {
            result.touchedPaths.append(rel)
        }
    }
    return result
}

func relativePath(of file: URL, under root: URL) -> String? {
    let filePath = file.standardizedFileURL.path
    let rootPath = root.standardizedFileURL.path + "/"
    guard filePath.hasPrefix(rootPath) else { return nil }
    return String(filePath.dropFirst(rootPath.count))
}

// ── git plumbing ─────────────────────────────────────────────────────────────

public func gitOutput(_ args: [String], cwd: URL) -> String? {
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    proc.arguments = ["git"] + args
    proc.currentDirectoryURL = cwd
    let pipe = Pipe()
    proc.standardOutput = pipe
    proc.standardError = Pipe()
    do {
        try proc.run()
    } catch {
        return nil
    }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    proc.waitUntilExit()
    guard proc.terminationStatus == 0 else { return nil }
    return String(data: data, encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

/// Staged paths (relative to the git toplevel) mapped to project-root-relative
/// paths; entries outside the project root are dropped.
public func stagedProjectFiles(cfg: Config) -> Set<String>? {
    guard let toplevel = gitOutput(["rev-parse", "--show-toplevel"], cwd: cfg.projectRoot)
    else { return nil }
    let topURL = URL(fileURLWithPath: toplevel).standardizedFileURL
    let prefix = relativePath(of: cfg.projectRoot, under: topURL).map { $0 + "/" } ?? ""
    // Before the first commit there is no HEAD; diff the index against the
    // constant empty tree instead.
    let emptyTree = "4b825dc642cb6eb9a060e54bf8d69288fbee4904"
    let hasHEAD = gitOutput(["rev-parse", "--verify", "HEAD"], cwd: cfg.projectRoot) != nil
    let base = hasHEAD ? [] : [emptyTree]
    guard let staged = gitOutput(
        ["diff", "--cached", "--name-only", "--diff-filter=ACMR"] + base, cwd: cfg.projectRoot)
    else { return nil }
    var out = Set<String>()
    for line in staged.components(separatedBy: "\n") where !line.isEmpty {
        if prefix.isEmpty {
            out.insert(line)
        } else if line.hasPrefix(prefix) {
            out.insert(String(line.dropFirst(prefix.count)))
        }
    }
    return out
}
