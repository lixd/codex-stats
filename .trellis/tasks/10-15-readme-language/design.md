# Repository presentation design

Follow CodexBar's product-first overview/install/docs organization, adapting to this project's actual source-only publication. No copied branding, unsupported Homebrew/Release links or new product features. Split existing README prose into docs/usage.md, docs/development.md and docs/statistics.md; use existing design/UI/data docs as canonical contracts. Keep root VERIFICATION.md stable to avoid unrelated link churn.

Use path-specific linguist-vendored for .trellis/scripts/** and .codex/hooks/** only: upstream development tooling, not linked to App. Use linguist-documentation for docs/** previews. Keep original Swift and shell tests/scripts counted normally. GitHub reclassification is asynchronous; distinguish attribute verification from live language totals.

Verify local links, README length, content preservation, git attributes for tool and product samples, product SHA256 unchanged, whitespace. No new App build needed for docs-only work.
