#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$ROOT_DIR"
source "$HOME/.cargo/env"
integrated_runner=$(mktemp "$ROOT_DIR/.zap-b2-fields-integrated.XXXXXX.zp")
standalone_runner=$(mktemp "$ROOT_DIR/.zap-b2-fields-standalone.XXXXXX.zp")
integrated_out=$(mktemp)
standalone_out=$(mktemp)
trap 'rm -f "$integrated_runner" "$standalone_runner" "$integrated_out" "$standalone_out"' EXIT
cat >"$integrated_runner" <<'ZP'
import "bootstrap/b2/typecheck.zp"
let good = from_json(check("class Counter:\n    private let value: number = 7\n", "field-good.zp"))
let bad = from_json(check("class Counter:\n    private let value: number = \"bad\"\n", "field-bad.zp"))
say good["ok"]
say bad["ok"]
say bad["diagnostics"][0]["message"]
ZP
cat >"$standalone_runner" <<'ZP'
import "bootstrap/b1/parser.zp"
import "bootstrap/b2/typecheck_engine.zp"
let good_ast = from_json(parse_canonical("class Counter:\n    private let value: number = 7\n", "field-good.zp"))
let bad_ast = from_json(parse_canonical("class Counter:\n    private let value: number = \"bad\"\n", "field-bad.zp"))
let good = b2c_check_program(good_ast["ast"], "field-good.zp")
let bad = b2c_check_program(bad_ast["ast"], "field-bad.zp")
say good["ok"]
say bad["ok"]
say bad["diagnostics"][0]["message"]
ZP
export PATH="$HOME/.cargo/bin:$PATH" RUSTUP_TOOLCHAIN=1.88.0
cargo run --quiet --release --locked --manifest-path native/Cargo.toml -- "$integrated_runner" >"$integrated_out"
cargo run --quiet --release --locked --manifest-path native/Cargo.toml -- "$standalone_runner" >"$standalone_out"
cat "$integrated_out"
cat "$standalone_out"
diff -u "$integrated_out" "$standalone_out"
cat > /tmp/zap-b2-fields-expected <<'EOF'
true
false
field 'value' expects number, got text
EOF
diff -u /tmp/zap-b2-fields-expected "$integrated_out"
printf 'B2 class-field gate passed: integrated and standalone validation parity\n'
