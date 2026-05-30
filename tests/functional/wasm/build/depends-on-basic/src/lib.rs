use std::env;
use std::fs;
use std::io::Write;
use std::path::Path;

#[no_mangle]
pub extern "C" fn _start() {
    println!("current working directory: {:?}", env::current_dir());
    let pwd = env::var("PWD")
        .expect("environment variable 'PWD' is not set");
    env::set_current_dir(Path::new(&pwd))
        .expect("current directory could not be changed");
    println!("current working directory: {:?}", env::current_dir());

    for (key, value) in env::vars_os() {
        println!("env {:?} = {:?}", key, value);
    }

    let build_inputs = env::var("buildInputs")
        .expect("environment variable 'buildInputs' is not set");
    eprintln!("buildInputs: {}", build_inputs);

    let out = env::var("out")
        .expect("environment variable 'out' is not set");

    let bin_path = Path::new(&out).join("bin");
    fs::create_dir_all(&bin_path)
        .expect("failed to create directories");

    let hello_world_path = bin_path.join("hello_world.sh");
    let mut file = fs::File::create(&hello_world_path)
        .expect("failed to create hello_world.sh");

    // TODO: Write in TMP

    let content = format!(
        "#!/usr/bin/env bash\n\nsource \"{}/hello.sh\"\n",
        build_inputs,
    );

    file.write_all(content.as_bytes()).expect("failed to write hello_world.sh");
}