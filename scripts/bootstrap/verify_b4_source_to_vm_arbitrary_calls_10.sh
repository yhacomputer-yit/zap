#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "${BASH_SOURCE[0]%/*}/../.." && pwd)"
cd "$ROOT_DIR"
source "$HOME/.cargo/env"
runner=$(mktemp "$ROOT_DIR/.zap-b4-arbitrary-call.XXXXXX.zp")
out=$(mktemp)
expected=$(mktemp)
trap 'rm -f "$runner" "$out" "$expected"' EXIT
cat >"$runner" <<'EOF'
import "bootstrap/b4/native_independent.zp"
import "bootstrap/b3/vm.zp"
let program = seed_compile_ast_source("fn pick(a, b, c, d, e):\n    return e\nsay pick(1, 2, 3, 4, 5)\n", "five-call.zp")
let state = vm_run(program["instructions"])
say state["output"][0]
say state["error"]
EOF
cat >"$expected" <<'EOF'
5
none
EOF
cargo run --quiet --release --locked --manifest-path native/Cargo.toml -- "$runner" >"$out"
cmp "$out" "$expected"
printf 'B4 arbitrary-call gate passed: five-argument canonical AST call and VM frame binding\n'
