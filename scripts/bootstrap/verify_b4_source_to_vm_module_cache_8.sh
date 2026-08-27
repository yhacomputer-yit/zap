#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "${BASH_SOURCE[0]%/*}/../.." && pwd)"
cd "$ROOT_DIR"
source "$HOME/.cargo/env"
module_dir=$(mktemp -d "$ROOT_DIR/.zap-module-cache.XXXXXX")
runner=$(mktemp "$ROOT_DIR/.zap-b4-module-cache.XXXXXX.zp")
out=$(mktemp)
expected=$(mktemp)
trap 'rm -rf "$module_dir"; rm -f "$runner" "$out" "$expected"' EXIT
cat >"$module_dir/lib.zp" <<'EOF'
module demo.lib
export fn greet(value):
    return value + 1
EOF
cat >"$module_dir/main.zp" <<'EOF'
import "lib.zp" as library
say library.greet(5)
EOF
cat >"$runner" <<EOF
import "bootstrap/b4/native_independent.zp"
import "bootstrap/b3/vm.zp"
let source = read_text("$module_dir/main.zp")
let first = seed_compile_ast_source_with_cache(source, "$module_dir/main-a.zp", [])
let second = seed_compile_ast_source_with_cache(source, "$module_dir/main-b.zp", first["cache"])
say first["status"]
say first["error"]
say second["status"]
say second["error"]
say len(first["cache"])
say len(second["cache"])
say json(vm_run(first["instructions"])["output"])
say json(vm_run(second["instructions"])["output"])
EOF
cat >"$expected" <<'EOF'
compiled_ast_slice
none
compiled_ast_slice
none
1
1
[6]
[6]
EOF
export PATH="$HOME/.cargo/bin:$PATH" RUSTUP_TOOLCHAIN=1.88.0
cargo run --quiet --release --locked --manifest-path native/Cargo.toml -- "$runner" >"$out"
cmp "$out" "$expected"
printf 'B4 module-cache gate passed: reusable cache, single artifact entry, prefix-safe reuse, and stable output\n'
