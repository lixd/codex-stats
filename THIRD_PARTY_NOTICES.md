# Third-party notices

## Original Codex Stats application

The original Codex Stats application code, tests, assets and project-specific documentation are provided under the [MIT License](LICENSE), copyright 2026 lixd. The root MIT license does not replace the licenses of third-party material in this repository.

The application is built from `Sources/` with Apple's system frameworks. The Trellis development tooling described below is not linked into the application and is not a third-party application runtime dependency.

## Trellis development tooling and templates

This repository includes development tooling and generated templates from **@mindfoldhq/trellis 0.6.17**. The installed upstream package declares **AGPL-3.0-only**; its complete license is preserved, without modification, in [licenses/Trellis-AGPL-3.0.txt](licenses/Trellis-AGPL-3.0.txt).

Upstream provenance:

- Package: [@mindfoldhq/trellis 0.6.17](https://www.npmjs.com/package/@mindfoldhq/trellis/v/0.6.17)
- Source project: [mindfold-ai/Trellis](https://github.com/mindfold-ai/Trellis)
- This notice records the installed package used to initialize this project, rather than claiming that every local generated file is an unchanged upstream release file.

The upstream tooling and template portions, including locally modified portions of those materials, retain their upstream AGPL terms. They include:

- `.trellis/scripts/` and `.trellis/agents/`;
- `.agents/skills/` and `.codex/` development agents, hooks and skills;
- `.trellis/workflow.md` and the generated Trellis configuration/template boilerplate under `.trellis/`;
- the Trellis-managed block between `TRELLIS:START` and `TRELLIS:END` in `AGENTS.md`;
- upstream template text retained in generated development instructions and specification documents.

Original project-specific requirements, designs, task content and specifications written for Codex Stats use MIT, to the extent they are original project material. When a file combines original project text with retained upstream template text, the root MIT grant applies only to the original project contribution; the upstream portions remain subject to AGPL-3.0-only. A generated file's presence in this repository does not by itself change its license.

Keep the upstream license and applicable notices when redistributing the Trellis materials, and comply with their AGPL source and modification obligations. Keeping the development tools separate from the App build describes the current engineering boundary; it is not a guarantee that every future combination or redistribution has the same licensing consequences. Review upstream provenance and the relevant license terms for your intended reuse.
