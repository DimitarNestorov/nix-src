{
  pkgs ? import <nixpkgs> { },
}:

pkgs.pkgsCross.wasi32.callPackage (
  {
    fetchFromGitHub,
    rustPlatform,
    lld,
  }:
  rustPlatform.buildRustPackage {
    pname = "nix-wasm-builder-basic-example";
    version = "0.3.0";
    __contentAddressed = true;

    src = ./.;

    cargoHash = "sha256-f7YATzMDpkxc8W2Mu3jToCgWnbNZGOQ6+yhLpb4cNVc=";

    postFixup = ''
      ls -la $out/bin
      ${pkgs.lib.getExe pkgs.wasm-tools} print $out/bin/nix_wasm_builder_basic_example.wasm > $out/basic.wat
    '';

    # these two lines are currently required
    env.RUSTFLAGS = "-C linker=wasm-ld";
    nativeBuildInputs = [ lld ];
  }
) { }
