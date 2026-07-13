// Link derivation: incoming-edge inversion (backlinks) and dangling-link
// detection. Incoming is never stored in records — always derived here.

import Foundation

public struct Incoming {
    public let fromID: String
    public let edge: [String: Any]
}

public struct DanglingLink {
    public let fromID: String
    public let to: String
    public let kind: String  // "edge" | "entry_point" | "contains"
    public let ref: String   // edge id / entry-point key / containment target
}

public struct LinkGraph {
    public var incoming: [String: [Incoming]] = [:]
    public var dangling: [DanglingLink] = []
}

public func buildLinks(_ surfaces: [SurfaceRecord]) -> LinkGraph {
    let ids = Set(surfaces.map(\.id))
    var graph = LinkGraph()
    for s in surfaces { graph.incoming[s.id] = [] }

    for s in surfaces {
        for edge in s.edges {
            guard let to = edge["to"] as? String, !to.isEmpty else { continue }
            if ids.contains(to) {
                graph.incoming[to, default: []].append(Incoming(fromID: s.id, edge: edge))
            } else {
                graph.dangling.append(DanglingLink(
                    fromID: s.id, to: to, kind: "edge",
                    ref: edge["id"] as? String ?? to
                ))
            }
        }
        for child in s.contains where !ids.contains(child) {
            graph.dangling.append(DanglingLink(
                fromID: s.id, to: child, kind: "contains", ref: child
            ))
        }
        for ep in s.entryPoints {
            guard let to = ep["to"] as? String, !to.isEmpty, !ids.contains(to) else { continue }
            let key = "\(ep["type"] as? String ?? "?"):\(ep["value"] as? String ?? "")"
            graph.dangling.append(DanglingLink(
                fromID: s.id, to: to, kind: "entry_point", ref: key
            ))
        }
    }
    return graph
}
