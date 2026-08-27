#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "${BASH_SOURCE[0]%/*}/../.." && pwd)"
cd "$ROOT_DIR"
source "$HOME/.cargo/env"
module_dir=$(mktemp -d "$ROOT_DIR/.zap-module-fixture.XXXXXX")
runner=$(mktemp "$ROOT_DIR/.zap-b4-modules.XXXXXX.zp")
out=$(mktemp)
expected=$(mktemp)
trap 'rm -rf "$module_dir"; rm -f "$runner" "$out" "$expected"' EXIT
cat >"$module_dir/lib.zp" <<'EOF'
module demo.lib
export fn greet(value):
    return value + 1
fn hidden(value):
    return value + 2
EOF
cat >"$module_dir/values.zp" <<'EOF'
module demo.values
say "loaded"
let secret = 99
export let answer = 42
export fn value():
    return answer
EOF
cat >"$module_dir/regular.zp" <<'EOF'
module demo.regular
let regular = 7
export let marked = 8
fn regular_fn(value):
    return value + regular
EOF
cat >"$module_dir/leaf-values.zp" <<'EOF'
module demo.leaf_values
export let amount = 10
EOF
cat >"$module_dir/middle-values.zp" <<'EOF'
module demo.middle_values
import "leaf-values.zp"
export fn read_amount():
    return amount + 1
EOF
cat >"$module_dir/collision-a.zp" <<'EOF'
module demo.collision_a
export let shared = 1
EOF
cat >"$module_dir/collision-b.zp" <<'EOF'
module demo.collision_b
export let shared = 2
EOF
cat >"$module_dir/a.zp" <<'EOF'
module demo.a
import "b.zp"
EOF
cat >"$module_dir/b.zp" <<'EOF'
module demo.b
import "a.zp"
EOF
cat >"$module_dir/leaf.zp" <<'EOF'
module demo.leaf
export fn leaf(value):
    return value + 10
EOF
cat >"$module_dir/middle.zp" <<'EOF'
module demo.middle
import "leaf.zp"
export fn middle(value):
    return leaf(value) + 1
EOF
cat >"$module_dir/sibling.zp" <<'EOF'
module demo.sibling
export fn sibling(value):
    return value * 2
EOF
cat >"$module_dir/broken.zp" <<'EOF'
@
EOF
printf '%s\n' \
'import "bootstrap/b4/native_independent.zp"' \
'import "bootstrap/b3/vm.zp"' \
"let compiled = seed_compile_ast_source(\"import \\\"lib.zp\\\"\\nsay greet(5)\\n\", \"$module_dir/main.zp\")" \
'say compiled["status"]' \
'let state = vm_run(compiled["instructions"])' \
'say state["output"][0]' \
'say state["error"]' \
"let composed = seed_compile_ast_source(\"import \\\"middle.zp\\\"\\nimport \\\"sibling.zp\\\"\\nsay middle(1)\\nsay sibling(3)\\n\", \"$module_dir/main-composed.zp\")" \
'say composed["status"]' \
'let composed_state = vm_run(composed["instructions"])' \
'say json(composed_state["output"])' \
'say composed_state["error"]' \
"let aliased = seed_compile_ast_source(\"import \\\"lib.zp\\\" as library\\nsay library.greet(5)\\n\", \"$module_dir/main-alias.zp\")" \
'say aliased["status"]' \
'let aliased_state = vm_run(aliased["instructions"])' \
    'say json(aliased_state["output"])' \
    'say aliased_state["error"]' \
    "let denied = seed_compile_ast_source(\"import \\\"lib.zp\\\" as library\\nsay library.hidden(5)\\n\", \"$module_dir/main-denied.zp\")" \
    'say denied["status"]' \
    'let denied_state = vm_run(denied["instructions"])' \
    'say denied_state["error"]' \
    "let values = seed_compile_ast_source(\"import \\\"values.zp\\\"\\nimport \\\"values.zp\\\"\\nsay answer\\nsay secret\\n\", \"$module_dir/main-values.zp\")" \
    'say values["status"]' \
    'let values_state = vm_run(values["instructions"])' \
    'say json(values_state["output"])' \
    'say values_state["error"]' \
    "let value_alias = seed_compile_ast_source(\"import \\\"values.zp\\\" as values\\nsay values.answer\\nsay values.secret\\n\", \"$module_dir/main-values-alias.zp\")" \
    'let value_alias_state = vm_run(value_alias["instructions"])' \
    'say json(value_alias_state["output"])' \
    'say value_alias_state["error"]' \
    "let used_values = seed_compile_ast_source(\"use \\\"values.zp\\\"\\nsay secret\\nsay answer\\n\", \"$module_dir/main-use-values.zp\")" \
    'let used_values_state = vm_run(used_values["instructions"])' \
    'say json(used_values_state["output"])' \
    'say used_values_state["error"]' \
    "let used_regular = seed_compile_ast_source(\"use \\\"regular.zp\\\" as regular\\nsay regular.regular_fn(5)\\nsay regular.marked\\n\", \"$module_dir/main-use-regular.zp\")" \
    'let used_regular_state = vm_run(used_regular["instructions"])' \
    'say json(used_regular_state["output"])' \
    'say used_regular_state["error"]' \
    "let nested_values = seed_compile_ast_source(\"import \\\"middle-values.zp\\\"\\nsay read_amount()\\n\", \"$module_dir/main-nested-values.zp\")" \
    'let nested_values_state = vm_run(nested_values["instructions"])' \
    'say json(nested_values_state["output"])' \
    'say nested_values_state["error"]' \
    "let collision = seed_compile_ast_source(\"import \\\"collision-a.zp\\\"\\nimport \\\"collision-b.zp\\\"\\nsay shared\\n\", \"$module_dir/main-collision.zp\")" \
    'let collision_state = vm_run(collision["instructions"])' \
    'say json(collision_state["output"])' \
    'say collision_state["error"]' \
    "let used = seed_compile_ast_source(\"use \\\"lib.zp\\\" as library\\nsay library.hidden(5)\\n\", \"$module_dir/main-use.zp\")" \
    'say used["status"]' \
    'let used_state = vm_run(used["instructions"])' \
    'say json(used_state["output"])' \
    'say used_state["error"]' \
    "let missing = seed_compile_ast_source(\"import \\\"missing.zp\\\"\\nsay 1\\n\", \"$module_dir/main-missing.zp\")" \
'say missing["status"]' \
'say missing["error"]' \
"let malformed = seed_compile_ast_source(\"import \\\"broken.zp\\\"\\nsay 1\\n\", \"$module_dir/main-malformed.zp\")" \
'say malformed["status"]' \
'say malformed["error"] != none' \
"let absolute = seed_compile_ast_source(\"import \\\"/tmp/blocked.zp\\\"\\nsay 1\\n\", \"$module_dir/main-absolute.zp\")" \
'say absolute["status"]' \
'say absolute["error"]' \
"let traversal = seed_compile_ast_source(\"import \\\"../blocked.zp\\\"\\nsay 1\\n\", \"$module_dir/main-traversal.zp\")" \
'say traversal["status"]' \
'say traversal["error"]' \
"let cycle = seed_compile_ast_source(\"import \\\"a.zp\\\"\\nsay 1\\n\", \"$module_dir/main-cycle.zp\")" \
'say cycle["status"]' \
'say contains(cycle["error"], "circular import detected")' \
'say contains(cycle["error"], "a.zp")' \
'say contains(cycle["error"], "b.zp")' > "$runner"
cat >"$expected" <<'EOF'
compiled_ast_slice
6
none
compiled_ast_slice
[12,6]
none
compiled_ast_slice
[6]
none
compiled_ast_slice
module_symbol_not_exported:hidden
compiled_ast_slice
["loaded",42]
unknown_local:secret
["loaded",42]
module_symbol_not_exported:secret
["loaded",99]
unknown_local:answer
[12]
module_symbol_not_exported:marked
[11]
none
[2]
none
compiled_ast_slice
[7]
none
compile_error
module not found: missing.zp
compile_error
true
compile_error
invalid module path: /tmp/blocked.zp
compile_error
invalid module path: ../blocked.zp
compile_error
true
true
true
EOF
cargo run --quiet --release --locked --manifest-path native/Cargo.toml -- "$runner" >"$out"
cmp "$out" "$expected"
printf 'B4 module gate passed: relative resolution, alias calls, recursive compilation, missing-module errors, and cycle detection\n'
