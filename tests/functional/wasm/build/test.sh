# shellcheck shell=bash

# shellcheck disable=SC1091
source common.sh

nix --extra-experimental-features "wasm-builtin ca-derivations" build --debug ./wasm/build#depends-on-basic # TODO: Check result!!!!
nix-store --gc # TODO: Check that both basic and depends-on-basic are there

nix --extra-experimental-features "wasm-builtin ca-derivations" build --debug ./wasm/build#input-srcs # TODO: Check result!!!!

nix --extra-experimental-features "wasm-builtin ca-derivations" build --debug ./wasm/build#argv # TODO: Check result!!!!
