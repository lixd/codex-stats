# Backend Development Guidelines

> Best practices for backend development in this project.

---

## Overview

This directory contains guidelines for backend development. Fill in each file with your project's specific conventions.

---

## Guidelines Index

| Guide | Description | Status |
|-------|-------------|--------|
| [Directory Structure](./directory-structure.md) | Module organization and file layout | To fill |
| [Database Guidelines](./database-guidelines.md) | ORM patterns, queries, migrations | To fill |
| [Error Handling](./error-handling.md) | Error types, handling strategies | To fill |
| [Quality Guidelines](./quality-guidelines.md) | Code standards, forbidden patterns | To fill |
| [Logging Guidelines](./logging-guidelines.md) | Structured logging, log levels | To fill |
| [Overview Query](./overview-query.md) | Scalar model/period summaries, same-query valuation and bounded overview cache | R21/T15; independent model selection and explicit new default prices |
| [Derived Usage](./derived-usage.md) | Weighted cache ratio, Decimal reference USD, atomic scalar index and explicit coverage | v0.2.17; local catalog, all-history candidates, guarded deletion and Store/formatter/native/CLI oracles |
| [Local Token Accounting](./token-accounting.md) | Physical history, response ownership, deduplication and typed diagnostics | v0.2.11; 133 Core tests, accounting oracles and native build |
| [Scan and Filter Performance](./scan-performance.md) | Operation-local calendar bounds, timestamp precision and fixed-input benchmarking | v0.2.11; paired snapshots and Turn/session scale benchmark |
| [Turn Performance](./turn-performance.md) | Explicit complete lifecycle, whole-Turn output coverage and truthful rate scope | Retained; distinct from request estimates |
| [Request Estimates](./request-estimates.md) | Native response/event boundaries, eligibility and explicit uncertainty | v0.2.7; 114 Core tests |
| [Safe Local Delivery](./local-delivery.md) | Staged validation, atomic publication and running-instance refusal | v0.2.11; current evidence in VERIFICATION.md |

## Token Accounting Changes

Read Local Token Accounting before changing Core decoding or report contracts. Run Core tests and a native build, checking exact sum invariants and fixed-input accounting. Other guides remain bootstrap placeholders; this entry does not complete the bootstrap task.

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
