#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "${BASH_SOURCE[0]%/*}/../.." && pwd)"
cd "$ROOT_DIR"
source "$HOME/.cargo/env"
runner=$(mktemp "$ROOT_DIR/.zap-b2-explicit.XXXXXX.zp")
out=$(mktemp)
expected=$(mktemp)
trap 'rm -f "$runner" "$out" "$expected"' EXIT
cat >"$runner" <<'EOF'
import "bootstrap/b2/typecheck.zp"
let valid = from_json(check("fn identity<T>(value: T) -> T:\n    return value\nlet answer: number = identity<number>(1)\n", "explicit-valid.zp"))
let multi = from_json(check("fn pair<T, U>(left: T, right: U) -> T:\n    return left\nlet answer: number = pair<number, text>(1, \"zap\")\n", "explicit-multi.zp"))
let arity = from_json(check("fn pair<T, U>(left: T, right: U) -> T:\n    return left\nlet answer = pair<number>(1, 2)\n", "explicit-arity.zp"))
let bound = from_json(check("trait Printable:\n    fn format(self) -> text\nfn bounded<T: Printable>(value: T) -> T:\n    return value\nlet answer = bounded<number>(1)\n", "explicit-bound.zp"))
say valid["ok"]
say multi["ok"]
say arity["diagnostics"][0]["message"]
say bound["diagnostics"][0]["message"]
EOF
cat >"$expected" <<'EOF'
true
true
function 'pair' expects 2 explicit type arguments, got 1
explicit type argument 'number' does not satisfy bound Printable
EOF
cargo run --quiet --release --locked --manifest-path native/Cargo.toml -- "$runner" >"$out"
cmp "$out" "$expected"
printf 'B2 explicit-generic gate passed: valid multi-parameter calls, arity, and bound diagnostics\n'
