use clap::Parser;

#[derive(clap::Parser, Debug)]
struct Args {
    #[arg(short, long, env)]
    config_file: Option<String>,
}

fn main() {
    let args = Args::parse();
    println!("hewwo");
}
