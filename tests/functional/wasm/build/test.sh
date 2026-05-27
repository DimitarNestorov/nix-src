# shellcheck shell=bash

# shellcheck disable=SC1091
source common.sh

nix --extra-experimental-features "wasm-builtin ca-derivations" build --debug ./wasm/build/basic # TODO: Check result!!!!