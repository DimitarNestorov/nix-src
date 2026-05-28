{
  outputs =
    {
      ...
    }@inputs:
    let
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
    in
    {
      packages.aarch64-darwin.default = default;
      packages.x86_64-linux.default = default;
      packages.aarch64-linux.default = default;
    };
}
