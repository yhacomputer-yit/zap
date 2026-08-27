#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "${BASH_SOURCE[0]%/*}/../.." && pwd)"
cd "$ROOT_DIR"
source "$HOME/.cargo/env"
runner=$(mktemp "$ROOT_DIR/.zap-typed-ir-arbitrary.XXXXXX.zp")
out=$(mktemp)
expected=$(mktemp)
trap 'rm -f "$runner" "$out" "$expected"' EXIT
cat > "$runner" <<'EOF'
import "bootstrap/b2/typed_ir.zp"
let output = from_json(emit("if ready:\n    say \"yes\"\nwhile running:\n    return\nfor item in values:\n    say item\n", "control.zp"))
let nodes = output["ir"]["nodes"]
say len(nodes)
say nodes[0]["kind"]
say nodes[0]["then_branch"]["statements"][0]["kind"]
say nodes[1]["kind"]
say nodes[1]["body"]["statements"][0]["kind"]
say nodes[2]["kind"]
say nodes[2]["body"]["statements"][0]["kind"]
EOF
cat > "$expected" <<'EOF'
3
if
say
while
return
for
say
EOF
cargo run --quiet --release --locked --manifest-path native/Cargo.toml -- "$runner" > "$out"
cmp "$out" "$expected"
printf 'B2 arbitrary typed-IR gate passed: 10 control-statement emission cases\n'
