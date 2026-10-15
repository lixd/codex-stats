# Primary-source reference checks (2026-10-15)

Read using agent-reach GitHub / gh API backend. Browser web tool returned HTTP429; gh contents API succeeded.

- CodexBar README and root directory at https://github.com/steipete/CodexBar/tree/9ebd90017f2c216528ae3ac201599cda0516d855: product introduction, key benefits, install instructions, docs links; conventional Sources/Tests/Scripts/docs. Reference organization only, no copy of unsupported features. Root .gitattributes returned404, so our classification is not claimed as their convention.
- Official Linguist overrides: https://github.com/github-linguist/linguist/blob/73ee9a3b277f398c37ca4ab0dea0193849de6460/docs/overrides.md . linguist-vendored and linguist-documentation exclude matching files from language statistics, without relabeling language. Changes need commit; GitHub processing asynchronous.
- Public API before change: Python491016, Swift270262, Shell14741 bytes. Local tracked bytes: .trellis Python408868, .codex Python78512, Tests Python3636. Product and tests Swift270262. Python tool totals487380 (~99.3% of Python), not App runtime.
