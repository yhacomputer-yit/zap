#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "${BASH_SOURCE[0]%/*}/../.." && pwd)"
cd "$ROOT_DIR"
source "$HOME/.cargo/env"
runner=$(mktemp "$ROOT_DIR/.zap-source-vm-ast.XXXXXX.zp")
out=$(mktemp)
expected=$(mktemp)
trap 'rm -f "$runner" "$out" "$expected"' EXIT
cat > "$runner" <<'EOF'
import "bootstrap/b4/native_independent.zp"
import "bootstrap/b3/vm.zp"
let add = seed_compile_ast_source("fn add(a, b):\n    return a + b\nsay add(2, 3)", "ast_add.zp")
let class_value = seed_compile_ast_source("class Counter:\n    fn get(self):\n        return self\nlet counter = Counter()\nsay counter.get()", "ast_class.zp")
let return_none = seed_compile_ast_source("fn no_value():\n    return\nsay no_value()", "ast_none.zp")
let fields = seed_compile_ast_source("class Counter:\n    fn set(self, value):\n        self.count = value\n        return self\nlet counter = Counter()\nlet updated = counter.set(7)\nsay updated.count", "ast_fields.zp")
let field_default = seed_compile_ast_source("class Counter:\n    private let value: number = 1 + 2\n    public fn read(self):\n        return self.value\nlet counter = Counter()\nsay counter.read()", "ast_field_default.zp")
let inherited_fields = seed_compile_ast_source("class Base:\n    public let base: number = 2\nclass Child extends Base:\n    public let own = [3, 4]\nlet child = Child()\nsay child.base\nsay child.own[1]", "ast_inherited_fields.zp")
let malformed = seed_compile_ast_source("break", "ast_bad.zp")
let add_result = vm_run(add["instructions"])
let class_result = vm_run(class_value["instructions"])
let none_result = vm_run(return_none["instructions"])
let fields_result = vm_run(fields["instructions"])
let field_default_result = vm_run(field_default["instructions"])
let inherited_fields_result = vm_run(inherited_fields["instructions"])
say add["status"]
say add_result["error"]
say add_result["output"][0]
say class_value["status"]
say class_result["error"]
say json(class_result["output"][0])
say none_result["output"][0]
say fields["status"]
say fields_result["output"][0]
say field_default["status"]
say field_default_result["output"][0]
say inherited_fields["status"]
say json(inherited_fields_result["output"])
say inherited_fields_result["error"]
say malformed["status"]
say malformed["error"]
EOF
cat > "$expected" <<'EOF'
compiled_ast_slice
none
5
compiled_ast_slice
none
{"class_name":"Counter","fields":[],"object":true}
none
compiled_ast_slice
7
compiled_ast_slice
3
compiled_ast_slice
[2,4]
none
compile_error
unsupported_ast_statement:break
EOF
cargo run --quiet --release --locked --manifest-path native/Cargo.toml -- "$runner" > "$out"
cat "$out"; printf '%s\n' '--- expected ---'; cat "$expected"
printf 'B4 AST gate passed: functions, class methods, inherited field defaults, dotted calls, and unsupported-node diagnostics\n'
