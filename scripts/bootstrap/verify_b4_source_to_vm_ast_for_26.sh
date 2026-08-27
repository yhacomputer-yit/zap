#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$ROOT_DIR"
source "$HOME/.cargo/env"
runner=$(mktemp "$ROOT_DIR/.zap-b4-ast-for.XXXXXX.zp")
out=$(mktemp)
trap 'rm -f "$runner" "$out"' EXIT
cat >"$runner" <<'ZP'
import "bootstrap/b4/native_independent.zp"
import "bootstrap/b3/vm.zp"
let compiled = seed_compile_ast_source("let total = 0\nfor item in [1, 2, 3]:\n    let total = total + item\nsay total", "ast-for.zp")
let state = vm_run(compiled["instructions"])
say compiled["status"]
say state["error"]
say state["output"][0]
let text_program = seed_compile_ast_source("for item in \"ab\":\n    say item", "ast-for-text.zp")
let text_state = vm_run(text_program["instructions"])
say json(text_state["output"])
let map_program = seed_compile_ast_source("for item in {\"a\": 1, \"b\": 2}:\n    say item", "ast-for-map.zp")
let map_state = vm_run(map_program["instructions"])
say json(map_state["output"])
ZP
cargo run --quiet --release --locked --manifest-path native/Cargo.toml -- "$runner" >"$out"
python3 - "$out" <<'PY'
import pathlib, sys
lines = [line.strip() for line in pathlib.Path(sys.argv[1]).read_text().splitlines() if line.strip()]
if lines != ["compiled_ast_slice", "none", "6", "[\"a\",\"b\"]", "[\"a\",\"b\"]"]:
    raise SystemExit(f"unexpected AST for output: {lines!r}")
PY
printf 'B4 canonical AST for gate passed: list, text, and map iterable lowering\n'
