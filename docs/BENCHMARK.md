# Reproducible synthetic benchmark

Run `node scripts/build.mjs` then `node scripts/benchmark.mjs`. Raw output is written to ignored `artifacts/benchmark.json` and correctness cardinalities are asserted before reporting results.

2026-10-20; Windows x64; Intel Core i7-14650HX; Node v24.19.0; MoonBit v0.10.16+b1a0e846e, release JavaScript build. Each workload has 3 warmups and 10 timed samples.

| Workload | Input | Exact outcome | Median | Max |
| --- | --- | --- | --- | --- |
| Dense single-key guard | 10000 rows on each side, 706035 input bytes | 100000000 matched/output pairs, budget admission fails without constructing them | 30.76215 ms | 32.47360 ms |
| Composite candidate comparison | 5000 rows each, 360178 input bytes | baseline 250000 pairs, candidate/retained 5000, lost 245000, gained 0 | 42.55650 ms | 54.38600 ms |

Each sample includes strict JSON parsing, table/schema validation, key buckets, complete preflight, bounded evidence, optional candidate comparison and **complete JSON serialization**. Dense report output is 248610 bytes, comparison output 698069 bytes. Materialization of the dense product is deliberately excluded because it is refused; these are preflight timings, not execution of 100 million output rows.

The samples are synthetic and only represent these key distributions on this machine. Timing includes allocation/garbage collection and will vary by platform and load. It does not measure database access, network traffic, storage, actual business transformations or arbitrary production throughput. Correctness is separately checked by nested-loop oracles and real SQLite result sets.
