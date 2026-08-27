# Zap Bootstrap Parser, Inference, and Runtime Status

The checked branch is `master` at reference head `5d597be` (`v2.11.17`). [PR #17](https://github.com/hidecard/zap/pull/17) is already merged. This continuation is **uncommitted** locally and no new pull request has been opened.

## Verified implementation

**B1 parser.** `parse_canonical(source, source_name)` is the rich canonical AST route for runtime and type-check consumers. `parse_general` and `parse_or_diagnostics` expose a deterministic compatibility view over the canonical result. The production parser handles sibling and nested functions/classes/traits/interfaces, mixed blocks, loops, try/catch, imports, quoted module `use`, member/index/call chains, maps, named arguments, conditional expressions, await, postfix propagation, structured assignment targets, function modifiers/default parameters, and visibility-qualified class fields. Import aliases and optional class metadata now survive span rebasing in native-compatible form. The current exact valid differential corpus is 38 cases; the diagnostic corpus is 14 cases.

**B2 type ownership.** The integrated checker consumes the canonical AST and performs recursive expression inference for nested collections and wrappers. It validates generic substitution, explicit multi-parameter calls, bounds, aliases and alias-of-alias expansion, recursive-alias diagnostics, imported generic cases covered by the matrix, branch/loop/short-circuit flow, reassignment invalidation, member calls, concrete map-member value types, structured mutation targets, class-field defaults, and trait obligations. Class methods retain owner metadata, inherited methods are materialized through base chains, child overrides win, and object receivers do not fall back to unrelated global method names. The standalone engine mirrors the owner-aware method behavior and the focused structured inference cases.

**Typed-IR ownership.** `bootstrap/b2/typed_ir.zp` implements `emit()` as a recursive direct canonical-AST adapter. It preserves canonical spans, nested bodies, fields, dynamic `for` nodes, generic call metadata, trait metadata, and structured mutation targets. Class serialization is optional-safe for native-compatible base-only nodes. Owned output uses `candidate_only: false` and schema version `2`; legacy schema-v1 artifacts remain supported through compatibility paths.

**B3/B4 runtime.** The canonical AST-to-VM route covers conditional/await/propagate expressions, collections, list/map index and member access, object fields, arbitrary call arity, closures, classes, constructors, inheritance, `super`, traits, C3 MRO, loops, try/catch, raise/return, and break/continue. Dynamic list/map/text iteration uses VM `iter_length`/`iter_get`. Map index/member stores now call the structural native `map_set` builtin rather than reconstructing JSON strings. Non-foldable class field defaults are lowered to runtime instructions and evaluated at construction with caller locals and `self`, inherited fields first.

**Modules.** Relative imports resolve recursively with prefix-safe offsets and cycle/path diagnostics. Imported artifacts retain module-qualified function definitions, module-qualified top-level value stores, and module-local import records; module function frames receive the namespaced state, preventing plain-name leakage into importer locals. Explicit imports expose exported top-level functions/declarations/values, while quoted module `use` exposes non-exported regular symbols. Aliases use the same allowlist, duplicate imports preserve the composed prefix, and later unaliased imports win same-name collisions. An opt-in compiler-session API reuses completed module artifacts across calls, and the VM rejects disallowed alias members with `module_symbol_not_exported:<name>`.

## Final verification results

| Verification | Result |
|---|---:|
| Current Rust-reference B1 valid differential batch | **38/38** |
| B1 diagnostics batch | **14/14** |
| Bootstrap shell verifier scripts | **112/112 pass** |
| Native Rust test targets | **275 passed** and **259 passed**, 0 failures |
| B2 inherited/override/missing-method gate | pass |
| B4 runtime-dependent field-default gate | pass |
| B4 module export/alias/use gate | pass |
| B4 structural map mutation gate | pass |
| `git diff --check` | pass |
| Clean-clone reproduction | **112/112 verifiers, 38/38 valid, 14/14 diagnostics; native targets 275 and 259 passed** |

## Boundary statement

These results establish a verified implementation over the current corpus and repository acceptance matrix. They do not claim exhaustive coverage of every possible Zap grammar construct. The bootstrap source-to-VM iteration extension intentionally defines non-list behavior broader than the current native evaluator's list-only `for` behavior. Top-level `break`/`continue` remain compile errors while loop-nested forms are supported.

Module parity remains incremental. The composed bytecode stream is retained for the current bootstrap architecture, but imported module declarations/stores are no longer plain root bindings: top-level values use canonical module-qualified keys, module imports use module-local records, and module function frames receive the namespaced state. Explicit imports expose exports only; quoted paths select non-exported regular symbols for module `use`; duplicate imports preserve earlier artifacts and later imports win collisions. The default compiler entry point uses a per-compilation `seen` set; callers can explicitly thread the opt-in artifact-cache API across compiler-session calls. Alias allowlists protect qualified calls and value access, while unqualified syntax remains governed by the import records. Unquoted dotted `use Trait.method as local` remains trait-use syntax.

Runtime field defaults and inherited method inference now pass focused behavior gates, but broader constructor argument/capture/error matrices and complete native differential coverage remain future work. Structural map mutation avoids JSON text replacement through a native host-builtin boundary; portability and exhaustive map-key/value corpus coverage remain to be expanded. The generated parser corpus is stronger at 38 valid and 14 diagnostic cases but is finite, so absolute arbitrary-source span and multi-diagnostic ordering parity is not claimed.

The latest working-tree and clean-clone validations passed 112/112 shell verifiers, the B1 batches passed 38/38 valid and 14/14 diagnostics, native test targets passed 275 and 259, and `git diff --check` passed in both trees.
Temporary probes were removed. Commit, push, and a new pull request remain intentionally deferred until the user explicitly requests them.
