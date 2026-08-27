#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"
source "$HOME/.cargo/env"
runner=$(mktemp "$ROOT_DIR/.zap-b4-collections.XXXXXX.zp")
out=$(mktemp)
expected=$(mktemp)
trap 'rm -f "$runner" "$out" "$expected"' EXIT
cat > "$runner" <<'EOF'
import "bootstrap/b4/native_independent.zp"
import "bootstrap/b3/vm.zp"
let list_program = seed_compile_ast_source("let values = [10, 20]\nsay values[1]\n", "list-index.zp")
let map_program = seed_compile_ast_source("let values = {\"answer\": 42}\nsay values.answer\n", "map-member.zp")
let bad_program = seed_compile_ast_source("let values = [10]\nsay values[2]\n", "bad-index.zp")
let list_state = vm_run(list_program["instructions"])
let map_state = vm_run(map_program["instructions"])
let bad_state = vm_run(bad_program["instructions"])
say list_state["output"][0]
say map_state["output"][0]
say bad_state["error"]
EOF
cat > "$expected" <<'EOF'
20
42
list_index_out_of_bounds
EOF
cargo run --quiet --release --locked --manifest-path native/Cargo.toml -- "$runner" > "$out"
cmp "$out" "$expected"
printf 'B4 collection source-to-VM gate passed: list/map literals, index/member access, and bounds errors\n'
