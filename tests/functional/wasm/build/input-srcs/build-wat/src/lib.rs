use std::env;
use std::fs;

#[no_mangle]
pub extern "C" fn _start() {
    let html_path = env::var("html").expect("environment variable 'html' is not set");
    let css_path = env::var("css").expect("environment variable 'css' is not set");

    let html = fs::read_to_string(html_path).expect("could not read html file");
    let css = fs::read_to_string(css_path).expect("could not read css file");

    let style_tag = format!("<style>\n{}\n</style>", css);

    let head_end = html.find("</head>").expect("could not find </head> in given document");
    
    let mut output = String::new();
    output.push_str(&html[..head_end]);
    output.push_str(&style_tag);
    output.push('\n');
    output.push_str(&html[head_end..]);

    let output_path = env::var("out").expect("environment variable 'out' is not set");
    fs::write(output_path, output).expect("could not write HTML file");
}
