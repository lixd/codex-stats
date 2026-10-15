# Frontend Development Guidelines

> Best practices for frontend development in this project.

---

## Overview

This directory contains guidelines for frontend development. Fill in each file with your project's specific conventions.

---

## Guidelines Index

| Guide | Description | Status |
|-------|-------------|--------|
| [Directory Structure](./directory-structure.md) | Module organization and file layout | To fill |
| [Component Guidelines](./component-guidelines.md) | Component patterns, props, composition | To fill |
| [Hook Guidelines](./hook-guidelines.md) | Custom hooks, data fetching patterns | To fill |
| [State Management](./state-management.md) | Local state, global state, server state | To fill |
| [Quality Guidelines](./quality-guidelines.md) | Code standards, forbidden patterns | To fill |
| [Type Safety](./type-safety.md) | Type patterns, validation | To fill |
| [Menu Lifecycle](./menu-lifecycle.md) | Exact menu-window dismissal, compact layout and resident termination policy | v0.2.10 B menu |
| [Token Display](./token-display.md) | Native K/M formatting, exact values and locale checks | Verified v0.2.10; semantic card captions |

## Token Display Changes

Before modifying Token amounts, read Token Display and search for the shared `abbreviated`, `detailedNumber` and `TokenDetails` implementations. Quality checks: `./Scripts/test-token-display.sh`, `./Scripts/test.sh`, native build and affected light/dark previews. Other guides above remain bootstrap placeholders; this entry does not complete the bootstrap task.

---

## How to Fill These Guidelines

For each guideline file:

1. Document your project's **actual conventions** (not ideals)
2. Include **code examples** from your codebase
3. List **forbidden patterns** and why
4. Add **common mistakes** your team has made

The goal is to help AI assistants and new team members understand how YOUR project works.

---

**Language**: All documentation should be written in **English**.
