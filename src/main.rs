use std::{net::SocketAddr, sync::Arc};

use clap::Parser;
use hyper::server::conn::http1;
use hyper::service::service_fn;
use hyper_util::rt::TokioIo;
use tokio::net::TcpListener;

mod config;
mod extensions;
mod router;

use config::{Config, extensions::ExtensionKind};
use extensions::Extensions;
use router::ProxyRouter;

#[derive(clap::Parser, Debug)]
struct Args {
    /// Path to KDL config file
    #[arg(short, long = "config", env)]
    config_file: Option<String>,
    /// Port to host on
    #[arg(short, long, env, default_value_t = 80)]
    port: u16,
}

#[tokio::main]
async fn main() {
    dotenvy::dotenv().ok();

    let args = Args::parse();

    let config_file = args.config_file.unwrap();

    let Ok(file) = std::fs::read_to_string(&config_file) else {
        panic!("{} file not found", &config_file);
    };
    let cfg = Config::from_kdl_string(&file).unwrap();

    let mut exts = Extensions::new();
    if let Some(ext_cfg) = cfg.extensions {
        for ext in ext_cfg.extensions {
            let result = match ext.kind {
                #[cfg(feature = "ffi")]
                ExtensionKind::Ffi => exts.load_ffi(&ext.file),
                #[cfg(feature = "wasm")]
                ExtensionKind::Wasm => exts.load_wasm(&ext.file),
                ExtensionKind::Unknown => {
                    eprintln!("Unknown extension kind for {}", ext.file);
                    continue;
                }
                #[allow(unreachable_patterns)]
                _ => {
                    eprintln!("Extension kind not supported in this build: {}", ext.file);
                    continue;
                }
            };
            if let Err(e) = result {
                eprintln!("Failed to load extension {}: {e}", ext.file);
            }
        }
    }

    let proxy = Arc::new(ProxyRouter::new(cfg.hosts, exts.plugins));

    let addr = SocketAddr::from(([0, 0, 0, 0], args.port));
    let listener = TcpListener::bind(addr).await.unwrap();

    println!("Listening on {}", listener.local_addr().unwrap());

    loop {
        let (stream, _) = listener.accept().await.unwrap();
        let io = TokioIo::new(stream);
        let proxy = proxy.clone();

        tokio::spawn(async move {
            http1::Builder::new()
                .serve_connection(
                    io,
                    service_fn(move |req| {
                        let proxy = proxy.clone();
                        async move { proxy.proxy(req).await }
                    }),
                )
                .await
                .ok();
        });
    }
}
