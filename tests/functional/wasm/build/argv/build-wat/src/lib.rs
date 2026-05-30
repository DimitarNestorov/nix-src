use std::env;
use std::fs;

#[no_mangle]
pub extern "C" fn _start() {
    let mut output = String::new();

    for (i, arg) in env::args().enumerate() {
        let arg_formatted = format!("argv[{}] = {}\n", i, arg);
        output.push_str(&arg_formatted);
    }

    let output_path = env::var("out").expect("environment variable 'out' is not set");
    fs::write(output_path, output).expect("could not write out file");
}
