#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "${BASH_SOURCE[0]%/*}/../.." && pwd)"
cd "$ROOT_DIR"
source "$HOME/.cargo/env"
runner=$(mktemp "$ROOT_DIR/.zap-b2-mutation.XXXXXX.zp")
out=$(mktemp)
expected=$(mktemp)
trap 'rm -f "$runner" "$out" "$expected"' EXIT
cat >"$runner" <<'EOF'
import "bootstrap/b2/typecheck.zp"
let list_ok = from_json(check("let values: list<number> = [10, 20]\nvalues[0] = 30\n", "list-ok.zp"))
let list_bad = from_json(check("let values: list<number> = [10, 20]\nvalues[0] = \"bad\"\n", "list-bad.zp"))
let map_ok = from_json(check("let values: map<text,number> = {\"answer\": 42}\nvalues.answer = 43\n", "map-ok.zp"))
let map_bad = from_json(check("let values: map<text,number> = {\"answer\": 42}\nvalues.answer = \"bad\"\n", "map-bad.zp"))
say list_ok["ok"]
say list_bad["diagnostics"][0]["message"]
say map_ok["ok"]
say map_bad["diagnostics"][0]["message"]
EOF
cat >"$expected" <<'EOF'
true
list assignment expects number, got text
true
map member assignment expects number, got text
EOF
cargo run --quiet --release --locked --manifest-path native/Cargo.toml -- "$runner" >"$out"
cmp "$out" "$expected"
printf 'B2 mutation-target gate passed: list index and map member assignment typing\n'
