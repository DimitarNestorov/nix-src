{ basic }:

derivation {
  name = "depends-on-basic";
  builder = "builtin:wasm";
  system = "builtin";
  buildInputs = [ basic.out ];
  wat = builtins.readFile ./depends_on_basic.wat;
}
