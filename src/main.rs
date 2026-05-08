use clap::Parser;

mod config;
mod extensions;

use config::Config;

#[derive(clap::Parser, Debug)]
struct Args {
    #[arg(short, long, env)]
    config_file: Option<String>,
}

fn main() {
    dotenvy::dotenv().ok();

    let args = Args::parse();

    let file = std::fs::read_to_string(args.config_file.unwrap()).unwrap();
    let cfg = Config::from_kdl_string(&file);

    println!("hewwo");
}
