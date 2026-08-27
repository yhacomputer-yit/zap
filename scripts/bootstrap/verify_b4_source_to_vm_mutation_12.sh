#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "${BASH_SOURCE[0]%/*}/../.." && pwd)"
cd "$ROOT_DIR"
source "$HOME/.cargo/env"
runner=$(mktemp "$ROOT_DIR/.zap-b4-mutation.XXXXXX.zp")
out=$(mktemp)
expected=$(mktemp)
trap 'rm -f "$runner" "$out" "$expected"' EXIT
cat >"$runner" <<'EOF'
import "bootstrap/b4/native_independent.zp"
import "bootstrap/b3/vm.zp"
let list_program = seed_compile_ast_source("let values = [10, 20]\nvalues[0] = 30\nsay values[0]\n", "list-mutation.zp")
let map_program = seed_compile_ast_source("let values = {\"answer\": 42}\nvalues.answer = 43\nsay values.answer\n", "map-mutation.zp")
let bad_program = seed_compile_ast_source("let values = [10]\nvalues[2] = 99\n", "bad-mutation.zp")
let list_state = vm_run(list_program["instructions"])
let map_state = vm_run(map_program["instructions"])
let bad_state = vm_run(bad_program["instructions"])
say list_state["output"][0]
say map_state["output"][0]
say bad_state["error"]
EOF
cat >"$expected" <<'EOF'
30
43
list_index_out_of_bounds
EOF
cargo run --quiet --release --locked --manifest-path native/Cargo.toml -- "$runner" >"$out"
cmp "$out" "$expected"
printf 'B4 mutation source-to-VM gate passed: list index store, map member store, and bounds errors\n'
