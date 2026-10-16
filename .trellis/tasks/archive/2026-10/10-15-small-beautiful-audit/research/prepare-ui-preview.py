#!/usr/bin/env python3
"""Prepare supplemental native previews outside product paths; does not execute them.

Usage: python3 prepare-ui-preview.py REPO OUTPUT_WORK_DIRECTORY
Then: bash OUTPUT_WORK_DIRECTORY/render.sh OUTPUT_IMAGE_DIRECTORY
The copied renderer creates/removes only its own synthetic fixture. No real logs.
"""
from pathlib import Path
import shlex
import sys

EXTRA = r'''                for (name, scheme) in [("light", ColorScheme.light), ("dark", ColorScheme.dark)] {
                    for width in [950.0, 1120.0] {
                        try await capture(DashboardView(initialSection: .sessions).environmentObject(store).environment(\.colorScheme, scheme),
                            size: NSSize(width: width, height: 630), path: output.appendingPathComponent("audit-sessions-\(Int(width))-\(name).png"), scheme: scheme)
                    }
                    try await capture(DashboardView().environmentObject(store).environment(\.colorScheme, scheme),
                        size: NSSize(width: 950, height: 630), path: output.appendingPathComponent("audit-overview-950-\(name).png"), scheme: scheme)
                }
                // This source is invoked only by the copied synthetic-fixture script.
                let auditFixture = URL(fileURLWithPath: store.rootPath)
                let hiddenFixture = auditFixture.appendingPathExtension("audit-hidden")
                guard auditFixture.lastPathComponent.hasPrefix("codexstats-preview.") else { throw NSError(domain: "Audit", code: 1) }
                try FileManager.default.moveItem(at: auditFixture, to: hiddenFixture)
                defer { try? FileManager.default.moveItem(at: hiddenFixture, to: auditFixture) }
                store.refresh()
                while store.loading { try await Task.sleep(nanoseconds: 10_000_000) }
                guard store.hasReport, store.errorMessage != nil else { throw NSError(domain: "Audit", code: 2) }
                for (name, scheme) in [("light", ColorScheme.light), ("dark", ColorScheme.dark)] {
                    for (page, section) in [("models", DashboardSection.models), ("sessions", DashboardSection.sessions)] {
                        try await capture(DashboardView(initialSection: section).environmentObject(store).environment(\.colorScheme, scheme),
                            size: NSSize(width: 950, height: 630), path: output.appendingPathComponent("audit-failed-refresh-\(page)-\(name).png"), scheme: scheme)
                    }
                }
                try FileManager.default.moveItem(at: hiddenFixture, to: auditFixture)
                store.refresh()
                while store.loading { try await Task.sleep(nanoseconds: 10_000_000) }
'''


def main():
    repo = Path(sys.argv[1]).resolve()
    work = Path(sys.argv[2]).resolve()
    work.mkdir(parents=True, exist_ok=True)
    marker = "                let originalRoot = store.rootPath\n"
    source = (repo / "Tests/UIPreview/main.swift").read_text()
    if source.count(marker) != 1:
        raise RuntimeError("Preview insertion marker changed; review before adapting")
    (work / "main.swift").write_text(source.replace(marker, EXTRA + marker))
    script = (repo / "Scripts/render-ui-previews.sh").read_text()
    root_line = 'ROOT="$(cd "$(dirname "$0")/.." && pwd)"'
    source_arg = '"$ROOT/Tests/UIPreview/main.swift"'
    if script.count(root_line) != 1 or script.count(source_arg) != 1:
        raise RuntimeError("Preview runner changed; review before adapting")
    script = script.replace(root_line, "ROOT=" + shlex.quote(str(repo)))
    script = script.replace(source_arg, shlex.quote(str(work / "main.swift")))
    (work / "render.sh").write_text(script)
    print(work)


if __name__ == "__main__":
    main()
