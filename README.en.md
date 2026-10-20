# JoinWitness

Preflight equality joins with exact cardinality, constructive three-row counterexamples, complete-input coverage checks and exact identity-pair changes under alternative keys. Written in MoonBit by the `JQ-ai-nb` project (蒋琦), with AI assistance disclosed.

[Live workbench](https://jq-ai-nb.github.io/JoinWitness/) · [Chinese README](README.md) · [Semantics](docs/SEMANTICS.md) · [Protocol](docs/FORMAT.md)

A missing tenant key turns four orders into seven joined rows. A three-row excerpt demonstrates the multiplicity violation. Adding the tenant key yields four rows, but reduced counts alone cannot establish a business-correct key. Another fixture keeps two output rows while losing every original match and gaining two different matches.

The library supports inner/left/right/full joins, composite key mappings, exact typed primitives, ordinary versus null-safe equality, matched-group cardinality contracts, independent coverage contracts, exact output budgets, independently verifiable evidence, guarded pair materialization and retained/lost/gained pair analysis without enumerating large products.

Published on Mooncakes as `JQ-ai-nb/joinwitness@0.1.0`. Install with `moon add JQ-ai-nb/joinwitness@0.1.0` and import `"JQ-ai-nb/joinwitness" @join`. A new consumer with an empty registry cache and no credentials downloaded the package and ran the typed example on wasm-gc and JavaScript. See the [registry verification record](docs/REGISTRY.md).

Build from source with MoonBit compiler 0.10.16+ and Node 22+:

```sh
moon check --target all --deny-warn
moon test --target all --deny-warn
moon build --target all --deny-warn
moon run cmd/demo
node scripts/build.mjs
node --test tests/cli.test.mjs
node scripts/serve.mjs
```

The browser is at `http://127.0.0.1:4175`. No third-party npm dependencies. Native targets require a platform C toolchain. Optional tests include Python SQLite 3.39+ (`python tests/sqlite_oracle.py`) and Playwright/Chromium (`python tests/browser.py`). CI covers three operating systems and four compilation targets.

This is a bounded in-memory component, not an arbitrary SQL parser or database connector. Maximum 10000 rows/table, 64 columns, 8 public key pairs, 20000 materialized identity pairs, 128 returned witnesses, exact totals, 8 Mi JSON input units. Host applications own IO, trusted data, persistence and business interpretation. Absence claims require the complete opposite table; small excerpts prove only constructive multiplicity violations. Evidence is not authenticated provenance.

Original domain code: MIT. The redistributed MoonBit standard library has separate license/notice files. All fixtures are synthetic; no third-party business implementation is ported. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and [release status](docs/RELEASE.md).
