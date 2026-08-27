#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "${BASH_SOURCE[0]%/*}/../.." && pwd)"
cd "$ROOT_DIR"
source "$HOME/.cargo/env"
runner=$(mktemp "$ROOT_DIR/.zap-b2-member-call.XXXXXX.zp")
out=$(mktemp)
expected=$(mktemp)
trap 'rm -f "$runner" "$out" "$expected"' EXIT
cat >"$runner" <<'EOF'
import "bootstrap/b2/typecheck.zp"
let valid = from_json(check("class Counter:\n    fn set(self, value: number) -> number:\n        return value\nlet c = none\nlet value: number = c.set(7)\n", "member-valid.zp"))
let arity = from_json(check("class Counter:\n    fn set(self, value: number) -> number:\n        return value\nlet c = none\nlet value = c.set()\n", "member-arity.zp"))
let unknown = from_json(check("let c = none\nlet value = c.missing()\n", "member-unknown.zp"))
say valid["ok"]
say arity["diagnostics"][0]["message"]
say unknown["diagnostics"][0]["message"]
EOF
cat >"$expected" <<'EOF'
true
function 'set' expects 2 to 2 arguments, got 1
unknown method 'missing'
EOF
cargo run --quiet --release --locked --manifest-path native/Cargo.toml -- "$runner" >"$out"
cmp "$out" "$expected"
printf 'B2 member-call gate passed: receiver typing, method arity, and unknown-method diagnostics\n'
