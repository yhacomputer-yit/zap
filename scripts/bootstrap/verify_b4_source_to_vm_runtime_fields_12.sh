#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "${BASH_SOURCE[0]%/*}/../.." && pwd)"
cd "$ROOT_DIR"
source "$HOME/.cargo/env"
runner=$(mktemp "$ROOT_DIR/.zap-runtime-fields.XXXXXX.zp")
out=$(mktemp)
expected=$(mktemp)
trap 'rm -f "$runner" "$out" "$expected"' EXIT
cat > "$runner" <<'ZP'
import "bootstrap/b4/native_independent.zp"
import "bootstrap/b3/vm.zp"
let compiled = seed_compile_ast_source("let input = 7\nclass Base:\n    public let base: number = input\nclass Child(Base):\n    public let total: number = self.base + 1\nclass Local:\n    public let base: number = 2\n    public let doubled: number = self.base + input\n    public let selected: number = if input > 5 then self.doubled else 0\nlet child = Child()\nlet local = Local()\nsay child.base\nsay child.total\nsay local.doubled\nsay local.selected\n", "runtime-fields.zp")
say compiled["status"]
let result = vm_run(compiled["instructions"])
say result["output"]
say result["error"]
ZP
cat > "$expected" <<'EOF'
compiled_ast_slice
[7, 8, 9, 9]
none
EOF
export PATH="$HOME/.cargo/bin:$PATH" RUSTUP_TOOLCHAIN=1.88.0
cargo run --quiet --release --locked --manifest-path native/Cargo.toml -- "$runner" > "$out"
cmp "$out" "$expected"
printf 'B4 runtime-field gate passed: captured defaults, inherited ordering, self member access, and object construction\n'
