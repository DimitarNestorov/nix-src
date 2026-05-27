use std::env;
use std::fs;
use std::io::Write;
use std::path::Path;

#[no_mangle]
pub extern "C" fn _start() {
    {
        let out = env::var("out")
            .expect("environment variable 'out' is not set");

        let bin_path = Path::new(&out).join("bin");
        fs::create_dir_all(&bin_path)
            .expect("failed to create directories");

        let hello_path = bin_path.join("hello.sh");
        let mut file = fs::File::create(&hello_path)
            .expect("failed to create hello.sh");

        file.write_all(
            b"#!/usr/bin/env bash\n\necho \"Hello world\"\n",
        )
        .expect("failed to write hello.sh");
    }

    {
        let dev = env::var("dev")
            .expect("environment variable 'dev' is not set");

        let devPath = Path::new(&dev);
        fs::create_dir_all(&devPath)
            .expect("failed to create dev directory");

        let testHeaderPath = devPath.join("test.h");
        let mut file = fs::File::create(&testHeaderPath)
            .expect("failed to create test.h");

        file.write_all(
            b"#include <stdio.h>\n\nvoid test(int hello);\n",
        )
        .expect("failed to write test.h");
    }
}