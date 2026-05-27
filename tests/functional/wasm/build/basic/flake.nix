{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    {
      nixpkgs,
      ...
    }@inputs:
    let
      forEachPlatform = nixpkgs.lib.genAttrs nixpkgs.lib.platforms.darwin;
    in
    {
      packages = forEachPlatform (
        platform:
        let
          pkgs = import inputs.nixpkgs {
            system = platform;
          };

          wat = pkgs.callPackage ./wat.nix { };
        in
        {
          inherit wat;
          default = derivation {
            name = "test-wasm-builder";
            builder = "builtin:wasm";
            system = "builtin";
            outputs = [
              "dev"
              "out"
            ];
            # wat = builtins.readFile "${wat}/basic.wat";
            wat = builtins.readFile ./basic.wat;
            # RUST_BACKTRACE = 1;
          };
        }
      );
    };
}
