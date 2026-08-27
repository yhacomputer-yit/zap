#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"
source "$HOME/.cargo/env"
runner=$(mktemp "$ROOT_DIR/.zap-alias-resolution.XXXXXX.zp")
out=$(mktemp)
expected=$(mktemp)
trap 'rm -f "$runner" "$out" "$expected"' EXIT
cat > "$runner" <<'EOF'
import "bootstrap/b2/typecheck.zp"
let scalar = from_json(check("type Count = number\nlet value: Count = 1\n", "scalar-alias.zp"))
let nested = from_json(check("type Box<T> = option<T>\nlet value: Box<number> = some(1)\n", "nested-alias.zp"))
let chain = from_json(check("type Inner<T> = list<T>\ntype Outer<U> = option<Inner<U>>\nlet value: Outer<number> = some([1])\n", "chain-alias.zp"))
let recursive = from_json(check("type A = B\ntype B = A\n", "recursive-alias.zp"))
say scalar["ok"]
say len(scalar["diagnostics"])
say nested["ok"]
say len(nested["diagnostics"])
say chain["ok"]
say len(chain["diagnostics"])
say recursive["ok"]
say len(recursive["diagnostics"])
say recursive["diagnostics"][0]["code"]
EOF
cat > "$expected" <<'EOF'
true
0
true
0
true
0
false
2
ZAP-TYPE-009
EOF
cargo run --quiet --release --locked --manifest-path native/Cargo.toml -- "$runner" > "$out"
cmp "$out" "$expected"
printf 'B2 alias-resolution gate passed: scalar, nested, chained, and recursive alias cases\n'
