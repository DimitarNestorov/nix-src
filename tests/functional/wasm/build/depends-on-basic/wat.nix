{
  pkgs ? import <nixpkgs> { },
  runCommand ? pkgs.runCommand,
  llvmPackages ? pkgs.llvmPackages,
  binaryen ? pkgs.binaryen,
  rustPlatform ? pkgs.rustPlatform,
}:
let
  rustSysroot = runCommand "rust-sysroot" { } ''
    mkdir -p $out/lib/rustlib
    cp -r ${pkgs."rustc-unwrapped"}/lib/rustlib/* $out/lib/rustlib/
    mkdir -p $out/lib/rustlib/src
    ln -s ${rustPlatform.rustcSrc} $out/lib/rustlib/src/rust
  '';
  rustcWithSysroot = runCommand "rustc-with-sysroot" { } ''
    mkdir -p $out/bin
    cat > $out/bin/rustc <<'EOF'
    #!/bin/sh
    exec ${pkgs.rustc}/bin/rustc --sysroot ${rustSysroot} "$@"
    EOF
    chmod +x $out/bin/rustc
  '';
  wasiCc = pkgs.pkgsCross.wasi32.stdenv.cc;
  wasiLibc = pkgs.pkgsCross.wasi32.wasilibc;
  wasiLibcDev = wasiLibc.dev;
  wasiSysroot = runCommand "wasi-sysroot" { } ''
    mkdir -p $out/include $out/lib/wasm32-wasip1
    cp -R ${wasiLibcDev}/include/* $out/include/
    echo ${wasiLibc}/lib
    echo $out/lib
    cp -R ${wasiLibc}/lib/*.{a,o,imports} $out/lib/
    # cp -R ${wasiLibc}/lib/* $out/lib/wasm32-wasip1/
  '';
  wasiSdk = runCommand "wasi-sdk-compat" { } ''
    mkdir -p $out/bin $out/lib/clang/19 $out/share

    ln -s ${wasiCc}/bin/wasm32-unknown-wasi-clang $out/bin/clang
    ln -s ${wasiCc}/bin/wasm32-unknown-wasi-clang++ $out/bin/clang++
    ln -s ${wasiCc}/bin/wasm32-unknown-wasi-ar $out/bin/ar
    ln -s ${wasiCc}/bin/wasm32-unknown-wasi-ld.lld $out/bin/ld.lld

    ln -s ${wasiCc}/resource-root/include $out/lib/clang/19/include
    ln -s ${wasiSysroot} $out/share/wasi-sysroot
  '';
  workspaceVendor = rustPlatform.fetchCargoVendor {
    src = ./.;
    hash = "sha256-dnUdwql/7kw058BHVz+FoNzz6wXDY1BMsUjM/2ETvhw=";
  };
  stdlibVendor = rustPlatform.fetchCargoVendor {
    src = rustPlatform.rustcSrc;
    cargoRoot = "library";
    hash = "sha256-5oJ/mtsJW0R3F7jgxafP23+WMLkyMKu10De5WIzb7Ro=";
  };
  cargoVendor = runCommand "cargo-vendor-merged" { } ''
    mkdir -p $out
    cp -R ${workspaceVendor}/* $out/
    mkdir -p $out/.cargo
    cp -R ${workspaceVendor}/.cargo/* $out/.cargo/
    chmod -R u+w $out
    cp -R ${stdlibVendor}/* $out/
    cp ${workspaceVendor}/Cargo.lock $out/Cargo.lock
    cp ${workspaceVendor}/.cargo/config.toml $out/.cargo/config.toml
  '';
in

rustPlatform.buildRustPackage {
  pname = "nix-wasm-builder-depends-on-basic-example";
  version = "0.3.0";
  __contentAddressed = true;

  cargoLock.lockFile = ./Cargo.lock;
  cargoDeps = cargoVendor;

  src = ./.;

  buildPhase = ''
    RUSTFLAGS="-L ${wasiSdk}/share/wasi-sysroot/lib/wasm32-wasip1" \
      cargo build --release -p nix-wasm-builder-depends-on-basic-example \
      --target wasm32-wasip1 -Z build-std=std,panic_abort
  '';

  installPhase = ''
    mkdir -p $out
    for i in target/wasm32-wasip1/release/*.wasm; do
      wasm-opt -O3 --enable-bulk-memory --enable-nontrapping-float-to-int --enable-simd -o "$out/$(basename "$i")" "$i"
    done
    ${pkgs.lib.getExe pkgs.wasm-tools} print $out/nix_wasm_builder_depends_on_basic_example.wasm > $out/depends_on_basic.wat
  '';

  nativeBuildInputs = [
    pkgs.rustc.llvmPackages.lld
    binaryen
    llvmPackages.clang
    llvmPackages.libclang
  ];

  WASI_SDK = "${wasiSdk}";
  LIBCLANG_PATH = "${llvmPackages.libclang.lib}/lib";
  RUSTC = "${rustcWithSysroot}/bin/rustc";
  CC_wasm32_wasip1 = "${wasiSdk}/bin/clang";
  AR_wasm32_wasip1 = "${wasiSdk}/bin/ar";
  CFLAGS_wasm32_wasip1 = "--sysroot=${wasiSdk}/share/wasi-sysroot -isystem ${wasiSdk}/lib/clang/19/include";
  BINDGEN_EXTRA_CLANG_ARGS_wasm32_wasip1 = "-fvisibility=default --sysroot=${wasiSdk}/share/wasi-sysroot -isystem ${wasiSdk}/lib/clang/19/include -resource-dir ${wasiSdk}/lib/clang/19";
  CARGO_TARGET_WASM32_WASIP1_LINKER = "${wasiSdk}/bin/ld.lld";
  RUSTC_BOOTSTRAP = "1";
  doCheck = false;
}
