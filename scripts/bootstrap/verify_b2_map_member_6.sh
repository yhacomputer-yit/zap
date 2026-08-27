#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$ROOT_DIR"
source "$HOME/.cargo/env"
integrated_runner=$(mktemp "$ROOT_DIR/.zap-b2-map-member-integrated.XXXXXX.zp")
standalone_runner=$(mktemp "$ROOT_DIR/.zap-b2-map-member-standalone.XXXXXX.zp")
integrated_out=$(mktemp)
standalone_out=$(mktemp)
expected=$(mktemp)
trap 'rm -f "$integrated_runner" "$standalone_runner" "$integrated_out" "$standalone_out" "$expected"' EXIT
cat >"$integrated_runner" <<'ZP'
import "bootstrap/b2/typecheck.zp"
let good = from_json(check("let values: map<text,number> = {\"count\": 7}\nlet result: number = values.count\n", "map-member.zp"))
let bad = from_json(check("let values: map<text,number> = {\"count\": 7}\nlet result: text = values.count\n", "map-member-bad.zp"))
say good["ok"]
say bad["ok"]
say bad["diagnostics"][0]["message"]
ZP
cat >"$standalone_runner" <<'ZP'
import "bootstrap/b1/parser.zp"
import "bootstrap/b2/typecheck_engine.zp"
let good_ast = from_json(parse_canonical("let values: map<text,number> = {\"count\": 7}\nlet result: number = values.count\n", "map-member.zp"))
let bad_ast = from_json(parse_canonical("let values: map<text,number> = {\"count\": 7}\nlet result: text = values.count\n", "map-member-bad.zp"))
let good = b2c_check_program(good_ast["ast"], "map-member.zp")
let bad = b2c_check_program(bad_ast["ast"], "map-member-bad.zp")
say good["ok"]
say bad["ok"]
say bad["diagnostics"][0]["message"]
ZP
cat >"$expected" <<'EOF'
true
false
variable 'result' expects text, got number
EOF
export PATH="$HOME/.cargo/bin:$PATH" RUSTUP_TOOLCHAIN=1.88.0
cargo run --quiet --release --locked --manifest-path native/Cargo.toml -- "$integrated_runner" >"$integrated_out"
cargo run --quiet --release --locked --manifest-path native/Cargo.toml -- "$standalone_runner" >"$standalone_out"
cat "$integrated_out"
cat "$standalone_out"
diff -u "$integrated_out" "$standalone_out"
diff -u "$expected" "$integrated_out"
printf 'B2 map-member gate passed: map value member inference parity\n'
