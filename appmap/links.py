"""Link derivation — the one bit of 'graph' we keep this pass.

Navigability comes from surface->surface links, so we compute exactly what
strengthens that:
  * incoming-edge inversion (backlinks per surface), and
  * dangling-link detection (an edge/entry_point/containment target that names a
    surface id that doesn't exist).

No reachability/orphan/dead-end analysis here — that's deferred.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

from .model import Surface


@dataclass
class Incoming:
    """A derived backlink: `from_id` reaches this surface via `edge`."""

    from_id: str
    edge: dict[str, Any]


@dataclass
class DanglingLink:
    """A reference to a surface id that has no record."""

    from_id: str
    to: str
    kind: str  # "edge" | "entry_point" | "contains"
    ref: str   # edge id / entry-point key / containment target, for locating it


@dataclass
class LinkGraph:
    incoming: dict[str, list[Incoming]] = field(default_factory=dict)
    dangling: list[DanglingLink] = field(default_factory=list)


def build_links(surfaces: list[Surface]) -> LinkGraph:
    ids = {s.id for s in surfaces}
    incoming: dict[str, list[Incoming]] = {s.id: [] for s in surfaces}
    dangling: list[DanglingLink] = []

    for s in surfaces:
        for edge in s.edges:
            to = edge.get("to")
            if not to:
                continue
            if to in ids:
                incoming[to].append(Incoming(from_id=s.id, edge=edge))
            else:
                dangling.append(
                    DanglingLink(from_id=s.id, to=to, kind="edge", ref=edge.get("id", to))
                )

        for child in s.contains:
            if child not in ids:
                dangling.append(
                    DanglingLink(from_id=s.id, to=child, kind="contains", ref=child)
                )

        for ep in s.entry_points:
            to = ep.get("to")
            if to and to not in ids:
                key = f"{ep.get('type', '?')}:{ep.get('value', '')}"
                dangling.append(
                    DanglingLink(from_id=s.id, to=to, kind="entry_point", ref=key)
                )

    return LinkGraph(incoming=incoming, dangling=dangling)
