derivation {
  name = "input-srcs-wasm-builder-test.html";
  builder = "builtin:wasm";
  system = "builtin";
  wat = builtins.readFile ./input_srcs_test.wat;

  html = ./index.html; # TODO: Make a test case for inputSrcs
  css = ./main.css;
  html-again = ./index.html;

  # allowedRequisites = [ basic ]; # TODO: Test
}
