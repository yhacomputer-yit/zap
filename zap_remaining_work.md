# Zap Bootstrap Ownership Status

The checked branch is `master` at upstream reference head `5d597be` (`v2.11.17`). The earlier parser/canonical-lowering change was merged as [PR #17](https://github.com/hidecard/zap/pull/17). This continuation remains **uncommitted** locally; no new pull request has been opened.

## Verified implementation state

The bootstrap separates the rich `parse_canonical` AST used by B2/B3/B4 from the deterministic Rust-parity `parse_general` compatibility view. B2 checking consumes the canonical AST, typed-IR emission is a direct recursive canonical adapter, and B3/B4 lower the canonical AST directly into VM instructions.

| Area | Verified result |
|---|---|
| B1 current-reference valid differential | Fresh native reference comparison passes **38/38** fixtures, including generated postfix, sibling/multiple-method, UTF-8 string/nested collection spans, try/catch, import aliases, modifiers/defaults, and quoted module-`use` cases |
| B1 diagnostics differential | Lexer, delimiter, indentation, numeric-literal, malformed-source, malformed-class-header, missing-block, missing-delimiter, and multiline missing-assignment cases pass **14/14** |
| B1 parser ownership | Production class/function helpers support arbitrary sibling/nested declarations, mixed control flow, member/index/call suffixes, conditional expressions, structured assignment targets, modifiers, default parameters, fields, import aliases, and quoted module `use`; unquoted dotted `use Trait.method as local` remains trait-use syntax |
| B1 spans | Unicode declaration spans use Rust-compatible UTF-8 byte lengths; generated postfix and inheritance fixtures now compare exactly against the native AST |
| B2 integrated and standalone checking | Recursive expressions, aliases, generic substitution/bounds, branch/loop/short-circuit flow, mutation targets, class fields, map-member values, and owner-aware inherited/overridden object methods are covered by focused gates |
| B2 inherited method registry | Class methods retain an owner; inherited methods are materialized through the base chain; child overrides take precedence; object receivers no longer fall back to unrelated global method names |
| B2 typed-IR | `emit()` consumes `parse_canonical()` through a recursive direct AST adapter; class metadata is optional-safe for native-compatible base-only class nodes; owned output uses `candidate_only: false` and schema version `2` |
| B3/B4 runtime | Conditional/await/propagate expressions, collections, structured mutation, arbitrary calls, closures, classes, fields, constructors, inheritance, C3 MRO, loops, try/catch, and VM error propagation remain covered |
| B3 structural map mutation | Native `map_set(map, key, value)` clones and updates a map structurally; bootstrap VM map index/member stores use this path rather than JSON text replacement, preserving nested values and key contents |
| B4 runtime field defaults | Class field metadata carries runtime default instructions when constant folding is not possible; construction evaluates inherited fields first with caller locals and object-local `self` |
| B4 modules | Relative resolver, nested/sibling composition, isolated module-local top-level values/import records, cycle/path diagnostics, explicit alias export allowlists, quoted non-explicit `use` regular-symbol semantics, duplicate-import preservation, later-import collision precedence, and opt-in reusable compiler-session artifact caching are covered |

## Acceptance evidence

| Suite | Result |
|---|---:|
| Current Rust-reference B1 valid differential corpus | **38/38** |
| Known B1 invalid diagnostics | **14/14** |
| Bootstrap shell verifiers in working tree | **112/112 pass** |
| Clean-clone bootstrap verifier reproduction | **112/112 pass** |
| Clean-clone B1 reference differential | **38/38 pass** |
| Clean-clone B1 diagnostics differential | **14/14 pass** |
| Native Rust test targets | **275 passed** and **259 passed**, 0 failures |
| B2 inherited/override/missing-method gate | pass |
| B4 runtime-field default gate | pass |
| B4 module import/export/use alias gate | pass |
| B4 structural mutation gate | pass |

The B1 batch runner regenerates a fresh native `bootstrap ast` reference for every fixture and compares Zap `parse_general` output directly against that result. The current 38/38 result is therefore a current-reference compatibility result, not only a comparison against stale expected JSON. The diagnostics runner now covers 14 parser/lexer error cases against exact expected records, including a line-2 missing-assignment case.

## Remaining boundaries

The verified result covers the current corpus and acceptance matrix; it does not prove exhaustive coverage of every possible Zap grammar construct. The bootstrap source-to-VM `for` extension is intentionally broader than the current native evaluator, which still accepts list iterables only. Top-level `break`/`continue` remain compile errors while loop-nested forms are supported.

Module work is incremental rather than full native parity. Imported artifacts retain module-qualified function definitions, module-local top-level value stores, and module-local import records; VM function frames receive the namespaced module state, so imported variables do not enter importer locals under their plain names. Explicit imports expose exported functions/declarations only, quoted module `use` exposes non-exported regular symbols, aliases use the same allowlist, duplicate imports preserve the composed prefix, and later unaliased imports win same-name collisions. The default compiler entry point still uses a per-compilation `seen` set; callers must explicitly thread the opt-in artifact cache API to reuse completed modules across compiler-session calls.
Alias allowlists cover qualified calls, not every possible global lookup path. Trait-use syntax and module-use syntax are intentionally disambiguated by using quoted paths for module `use`.

Runtime-dependent field defaults and inherited method typing are now implemented for the covered AST/VM paths. They still need broader constructor-argument/capture/error corpus coverage and a full native differential matrix for every supported field expression kind. Structural map mutation now avoids JSON reconstruction through the native structural `map_set` path, but its host-builtin boundary still requires broader VM-independent portability coverage.

The generated differential corpus now extends the accepted valid set to 38 cases and diagnostics to 14 cases. This is stronger evidence than the former matrix but remains a finite corpus; exhaustive arbitrary AST span, malformed-header, delimiter, and multi-diagnostic ordering parity has not been claimed.

These boundaries are documented rather than hidden. Temporary probes were removed and `git diff --check` passed. The working tree remains intentionally uncommitted, and commit, push, and a new pull request remain deferred until explicit user authorization.
