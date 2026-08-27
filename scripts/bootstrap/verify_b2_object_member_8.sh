#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$ROOT_DIR"
source "$HOME/.cargo/env"
integrated_runner=$(mktemp "$ROOT_DIR/.zap-b2-object-member-integrated.XXXXXX.zp")
standalone_runner=$(mktemp "$ROOT_DIR/.zap-b2-object-member-standalone.XXXXXX.zp")
integrated_out=$(mktemp)
standalone_out=$(mktemp)
expected=$(mktemp)
trap 'rm -f "$integrated_runner" "$standalone_runner" "$integrated_out" "$standalone_out" "$expected"' EXIT
cat >"$integrated_runner" <<'ZP'
import "bootstrap/b2/typecheck.zp"
let result = from_json(check("class Counter:\n    public fn get(self) -> number:\n        return 7\nlet value: number = new(Counter).get()\n", "object-member.zp"))
say result["ok"]
say len(result["diagnostics"])
ZP
cat >"$standalone_runner" <<'ZP'
import "bootstrap/b1/parser.zp"
import "bootstrap/b2/typecheck_engine.zp"
let parsed = from_json(parse_canonical("class Counter:\n    public fn get(self) -> number:\n        return 7\nlet value: number = new(Counter).get()\n", "object-member.zp"))
let result = b2c_check_program(parsed["ast"], "object-member.zp")
say result["ok"]
say len(result["diagnostics"])
ZP
cat >"$expected" <<'EOF'
true
0
EOF
export PATH="$HOME/.cargo/bin:$PATH" RUSTUP_TOOLCHAIN=1.88.0
cargo run --quiet --release --locked --manifest-path native/Cargo.toml -- "$integrated_runner" >"$integrated_out"
cargo run --quiet --release --locked --manifest-path native/Cargo.toml -- "$standalone_runner" >"$standalone_out"
cat "$integrated_out"
cat "$standalone_out"
diff -u "$expected" "$integrated_out"
diff -u "$expected" "$standalone_out"
printf 'B2 object-member gate passed: call-result suffix and receiver-aware method inference\n'
