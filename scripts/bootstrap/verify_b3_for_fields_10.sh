#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$ROOT_DIR"
source "$HOME/.cargo/env"
runner=$(mktemp "$ROOT_DIR/.zap-b3-for-fields.XXXXXX.zp")
out=$(mktemp)
expected=$(mktemp)
trap 'rm -f "$runner" "$out" "$expected"' EXIT
cat >"$runner" <<'ZP'
import "bootstrap/b2/typed_ir.zp"
import "bootstrap/b3/lower.zp"
import "bootstrap/b3/vm.zp"
let for_ir = from_json(emit("let items = [1, 2]\nfor item in items:\n    say item\n", "b3-for.zp"))
let for_bytecode = lower_typed_ir(for_ir)
let for_state = vm_run(for_bytecode["instructions"])
let class_ir = from_json(emit("class Counter:\n    private let value: number = 7\n    public fn read(self):\n        return self.value\n", "b3-field.zp"))
let class_bytecode = lower_typed_ir(class_ir)
let class_state = vm_run(class_bytecode["instructions"])
say for_ir["schema_version"]
say for_bytecode["error"]
say json(for_state["output"])
say class_ir["ir"]["nodes"][0]["body"]["statements"][0]["kind"]
say class_ir["ir"]["nodes"][0]["body"]["statements"][0]["visibility"]
say class_bytecode["error"]
ZP
cat >"$expected" <<'EOF'
2
none
[1,2]
field
private
none
EOF
export PATH="$HOME/.cargo/bin:$PATH" RUSTUP_TOOLCHAIN=1.88.0
cargo run --quiet --release --locked --manifest-path native/Cargo.toml -- "$runner" >"$out"
cat "$out"
cmp "$out" "$expected"
printf 'B3 for/fields gate passed: typed-IR schema, global loop rebasing, and field metadata\n'
