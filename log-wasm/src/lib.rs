use serde::{Deserialize, Serialize};

// --- Host imports ------------------------------------------------------------

#[link(wasm_import_module = "env")]
unsafe extern "C" {
    fn log(ptr: *const u8, len: usize);
}

fn host_log(msg: &str) {
    unsafe { log(msg.as_ptr(), msg.len()) }
}

#[derive(Deserialize)]
struct RequestContext {
    method: String,
    uri: String,
    headers: Vec<(String, String)>,
    #[allow(dead_code)]
    upstream_url: String,
    #[serde(with = "serde_bytes")]
    #[allow(dead_code)]
    body: Vec<u8>,
}

#[derive(Serialize)]
struct PluginResult {
    action: u8,
    #[serde(default)]
    extra_headers: Vec<(String, String)>,
    body_override: Option<Vec<u8>>,
    status: Option<u16>,
    #[serde(default)]
    headers: Vec<(String, String)>,
    #[serde(with = "serde_bytes")]
    body: Vec<u8>,
    message: String,
}

#[unsafe(no_mangle)]
pub extern "C" fn plugin_alloc(size: i32) -> i32 {
    let layout = std::alloc::Layout::from_size_align(size as usize, 1).unwrap();
    unsafe { std::alloc::alloc(layout) as i32 }
}

#[unsafe(no_mangle)]
pub extern "C" fn plugin_free(ptr: i32, len: i32) {
    let layout = std::alloc::Layout::from_size_align(len as usize, 1).unwrap();
    unsafe { std::alloc::dealloc(ptr as *mut u8, layout) }
}

#[unsafe(no_mangle)]
pub extern "C" fn plugin_name() -> i32 {
    c"log-wasm".as_ptr() as i32
}

#[unsafe(no_mangle)]
pub extern "C" fn plugin_version() -> i32 {
    c"0.1.0".as_ptr() as i32
}

#[unsafe(no_mangle)]
pub extern "C" fn plugin_capabilities() -> i32 {
    0b001 // ON_REQUEST
}

#[unsafe(no_mangle)]
pub extern "C" fn plugin_on_load() {}

#[unsafe(no_mangle)]
pub extern "C" fn plugin_on_unload() {}

#[unsafe(no_mangle)]
pub extern "C" fn plugin_on_request(ctx_ptr: i32, ctx_len: i32) -> i64 {
    let ctx_bytes = unsafe { std::slice::from_raw_parts(ctx_ptr as *const u8, ctx_len as usize) };

    if let Ok(ctx) = rmp_serde::from_slice::<RequestContext>(ctx_bytes) {
        host_log(&format!("[log-wasm] {} {}\n", ctx.method, ctx.uri));
        for (name, value) in &ctx.headers {
            host_log(&format!("  {name}: {value}\n"));
        }
    }

    let result = PluginResult {
        action: 0, // CONTINUE
        extra_headers: vec![],
        body_override: None,
        status: None,
        headers: vec![],
        body: vec![],
        message: String::new(),
    };

    let bytes = rmp_serde::to_vec_named(&result).unwrap_or_default();
    let len = bytes.len() as i32;
    let layout = std::alloc::Layout::from_size_align(bytes.len(), 1).unwrap();
    let ptr = unsafe { std::alloc::alloc(layout) } as i32;
    unsafe { std::ptr::copy_nonoverlapping(bytes.as_ptr(), ptr as *mut u8, bytes.len()) };
    // pack: low 32 bits = ptr, high 32 bits = len
    (ptr as i64) | ((len as i64) << 32)
}
