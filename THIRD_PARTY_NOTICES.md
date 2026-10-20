# Sources and licensing

JoinWitness's domain implementation, fixtures, independent oracles and presentation were developed for this independent project with AI assistance. It is not a port and does not reuse the business implementation of orbitcron, robopolicy, AgentCanary or TideWeave. Generic build/publishing infrastructure follows the same MoonBit toolchain conventions.

The MoonBit standard library `moonbitlang/core` is a toolchain dependency, distributed under Apache-2.0 with LLVM exceptions. Compiled CLI/browser distributions may contain standard-library routines. Their license and notice are included under `third_party/` and copied into compiled distributions.

Conceptual references:

- [PostgreSQL table expressions and join multiplicity](https://www.postgresql.org/docs/current/queries-table-expressions.html).
- [PostgreSQL comparison and NULL semantics](https://www.postgresql.org/docs/current/functions-comparison.html).

SQL equality, outer joins, join cardinality and counterexamples are established concepts. This project does not claim to invent joins. Its independent deliverable combines exact bounded preflight, constructive three-row evidence, complete-input absence verification, guarded materialization and exact lost/gained identity-pair analysis.

All fixtures are synthetic. No private customer or contact data is redistributed. Original code: MIT.
