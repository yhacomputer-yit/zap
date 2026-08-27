#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "${BASH_SOURCE[0]%/*}/../.." && pwd)"
cd "$ROOT_DIR"
source "$HOME/.cargo/env"
runner=$(mktemp "$ROOT_DIR/.zap-b4-expressions.XXXXXX.zp")
out=$(mktemp)
expected=$(mktemp)
trap 'rm -f "$runner" "$out" "$expected"' EXIT
cat >"$runner" <<'EOF'
import "bootstrap/b4/native_independent.zp"
import "bootstrap/b3/vm.zp"
let conditional_program = seed_compile_ast_source("let answer = if true then 7 else 9\nsay answer\n", "conditional-expression.zp")
let await_program = seed_compile_ast_source("say await identity(7)\n", "await-expression.zp")
let propagate_program = seed_compile_ast_source("say {\"ok\": true, \"value\": 9}?\n", "propagate-expression.zp")
let conditional_state = vm_run(conditional_program["instructions"])
let await_state = vm_run(await_program["instructions"])
let propagate_state = vm_run(propagate_program["instructions"])
say conditional_state["output"][0]
say await_state["output"][0]
say propagate_state["output"][0]
say conditional_state["error"]
say await_state["error"]
say propagate_state["error"]
EOF
cat >"$expected" <<'EOF'
7
7
9
none
none
none
EOF
cargo run --quiet --release --locked --manifest-path native/Cargo.toml -- "$runner" >"$out"
cmp "$out" "$expected"
printf 'B4 expression gate passed: conditional, await, and propagate canonical AST execution\n'
