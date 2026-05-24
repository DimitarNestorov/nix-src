#!/usr/bin/env bash

source common.sh

if [[ $(nix eval --extra-experimental-features wasm-builtin --expr 'builtins ? wasm') = false ]]; then
    skipTest "builtins.wasm not available"
fi

# Test running a WebAssembly module in text format (WAT).
[[ $(nix eval --json --impure \
    --extra-experimental-features wasm-builtin \
    --expr "builtins.wasm { wat = builtins.readFile ./fib.wat; function = \"fib\"; } 40") = 165580141 ]]

# Test running a WebAssembly module in binary format (.wasm).
[[ $(nix eval --json --impure \
    --extra-experimental-features wasm-builtin \
    --expr "builtins.wasm { path = ./fib.wasm; function = \"fib\"; } 40") = 165580141 ]]

testWasmBuilderDerivation=$(cat <<'EOF'
derivation {
    name = "test-wasm-builder";
    builder = "builtin:wasm";
    system = "builtin";
    wat = builtins.readFile ./wasm-builder.wat;
}
EOF
)

nix build --impure --debug --expr "$testWasmBuilderDerivation"


testWasmFibBuilderDerivation=$(cat <<'EOF'
derivation {
    name = "test-wasm-builder";
    builder = "builtin:wasm";
    system = "builtin";
    wat = builtins.readFile ./wasm-fib-builder.wat;
}
EOF
)

nix build --impure --debug --expr "$testWasmFibBuilderDerivation"