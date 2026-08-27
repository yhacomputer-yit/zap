#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "${BASH_SOURCE[0]%/*}/../.." && pwd)"
cd "$ROOT_DIR"
source "$HOME/.cargo/env"
runner=$(mktemp "$ROOT_DIR/.zap-b2-inherited.XXXXXX.zp")
out=$(mktemp)
expected=$(mktemp)
trap 'rm -f "$runner" "$out" "$expected"' EXIT
cat > "$runner" <<'ZP'
import "bootstrap/b1/parser.zp"
import "bootstrap/b2/typecheck.zp"
import "bootstrap/b2/typecheck_engine.zp"
let inherited_ast = from_json(parse_canonical("class Parent:\n    public fn get(self) -> number:\n        return 7\nclass Child(Parent):\n    public fn own(self) -> text:\n        return \"child\"\nlet value: number = new(Child).get()\n", "inherited.zp"))
let inherited_integrated = b2c_check_program(inherited_ast["ast"], "inherited.zp")
say inherited_integrated["ok"]
say len(inherited_integrated["diagnostics"])
let override_ast = from_json(parse_canonical("class Parent:\n    public fn get(self) -> number:\n        return 7\nclass Child(Parent):\n    public fn get(self) -> text:\n        return \"child\"\nlet value: text = new(Child).get()\n", "override.zp"))
let override_standalone = b2c_check_program(override_ast["ast"], "override.zp")
say override_standalone["ok"]
say len(override_standalone["diagnostics"])
let missing_ast = from_json(parse_canonical("class Parent:\n    public fn get(self) -> number:\n        return 7\nclass Child(Parent):\n    public fn own(self) -> number:\n        return 1\nlet value: number = new(Child).missing()\n", "missing.zp"))
let missing_result = b2c_check_program(missing_ast["ast"], "missing.zp")
say missing_result["ok"]
say len(missing_result["diagnostics"])
ZP
cat > "$expected" <<'EOF'
true
0
true
0
false
1
EOF
export PATH="$HOME/.cargo/bin:$PATH" RUSTUP_TOOLCHAIN=1.88.0
cargo run --quiet --release --locked --manifest-path native/Cargo.toml -- "$runner" > "$out"
cmp "$out" "$expected"
printf 'B2 inherited-method gate passed: inherited resolution, override precedence, and missing-method diagnostics\n'
