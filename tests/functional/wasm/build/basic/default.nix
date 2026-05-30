derivation {
  name = "basic";
  builder = "builtin:wasm";
  system = "builtin";
  outputs = [
    "dev"
    "out"
  ];
  wat = builtins.readFile ./basic.wat;
}
