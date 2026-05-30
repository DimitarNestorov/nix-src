derivation {
  name = "input-srcs-wasm-argv-test";
  builder = "builtin:wasm";
  system = "builtin";
  wat = builtins.readFile ./argv_test.wat;
  args = [
    (-1024)
    "string"
    null
    false
    true
    0.01
    ./argv_test.wat
  ];

  # allowedRequisites = [ basic ]; # TODO: Test
}
