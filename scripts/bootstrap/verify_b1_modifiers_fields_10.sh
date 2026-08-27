#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$ROOT_DIR"
source "$HOME/.cargo/env"
fixture=$(mktemp "$ROOT_DIR/.zap-b1-modifiers.XXXXXX.zp")
runner=$(mktemp "$ROOT_DIR/.zap-b1-modifiers-runner.XXXXXX.zp")
native=$(mktemp)
candidate=$(mktemp)
trap 'rm -f "$fixture" "$runner" "$native" "$candidate"' EXIT
cat >"$fixture" <<'ZP'
export async fn load(value = 1) -> number:
    return value
class Counter:
    private let value: number = 7
    public fn read(offset = 1) -> number:
        return value + offset
ZP
cat >"$runner" <<'ZP'
import "bootstrap/b1/parser.zp"
let source = read_text("FIXTURE")
say parse_general(source, "FIXTURE")
ZP
sed -i "s#FIXTURE#$fixture#g" "$runner"
export PATH="$HOME/.cargo/bin:$PATH" RUSTUP_TOOLCHAIN=1.88.0
cargo run --quiet --release --locked --manifest-path native/Cargo.toml -- bootstrap ast "$fixture" >"$native"
cargo run --quiet --release --locked --manifest-path native/Cargo.toml -- "$runner" >"$candidate"
cmp "$native" "$candidate"
python3 - "$native" <<'PY'
import json
import pathlib
import sys
payload = json.loads(pathlib.Path(sys.argv[1]).read_text())
statements = payload["ast"]["statements"]
function, klass = statements
assert function["exported"] is True
assert function["is_async"] is True
assert function["params"][0]["default"] == "1"
assert function["return_type"] == "number"
field, method = klass["body"]["statements"]
assert field["kind"] == "field" and field["visibility"] == "private"
assert method["visibility"] == "public"
assert method["params"][0]["default"] == "1"
print("B1 modifiers/fields gate passed: exact native differential and metadata checks")
PY
