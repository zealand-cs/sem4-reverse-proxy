use clap::Parser;

mod config;

use config::Cfg;

#[derive(clap::Parser, Debug)]
struct Args {
    #[arg(short, long, env)]
    config_file: Option<String>,
}

fn main() {
    dotenvy::dotenv().ok();

    let args = Args::parse();

    let file = std::fs::read_to_string(args.config_file.unwrap()).unwrap();
    let cfg = Cfg::from_kdl_string(file);

    println!("hewwo");
}
