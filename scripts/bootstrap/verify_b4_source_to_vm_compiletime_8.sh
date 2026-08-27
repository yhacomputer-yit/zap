#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "${BASH_SOURCE[0]%/*}/../.." && pwd)"
cd "$ROOT_DIR"
source "$HOME/.cargo/env"
runner=$(mktemp "$ROOT_DIR/.zap-b4-compiletime.XXXXXX.zp")
out=$(mktemp)
expected=$(mktemp)
trap 'rm -f "$runner" "$out" "$expected"' EXIT
cat >"$runner" <<'EOF'
import "bootstrap/b4/native_independent.zp"
import "bootstrap/b3/vm.zp"
let compiled = seed_compile_ast_source("type Score = number\nuse Printable.format as format\nlet value: Score = 7\nsay value\n", "compiletime.zp")
say compiled["status"]
let state = vm_run(compiled["instructions"])
say state["output"][0]
say state["error"]
EOF
cat >"$expected" <<'EOF'
compiled_ast_slice
7
none
EOF
cargo run --quiet --release --locked --manifest-path native/Cargo.toml -- "$runner" >"$out"
cmp "$out" "$expected"
printf 'B4 compile-time gate passed: type aliases and trait-use nodes are AST-owned no-ops\n'
