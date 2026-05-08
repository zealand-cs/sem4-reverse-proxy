use std::os::raw::c_char;

use serde::{Deserialize, Serialize};

// --- FFI return type ---------------------------------------------------------

/// Must match `FfiPluginBuffer` in `src/extensions/ffi.rs`.
#[repr(C)]
pub struct FfiPluginBuffer {
    pub ptr: *mut u8,
    pub len: u32,
}

// --- Protocol types ----------------------------------------------------------

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

/// # Safety
/// Freeing the pointer is an unsafe operation.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn plugin_free(ptr: *mut u8, len: u32) {
    unsafe { drop(Vec::from_raw_parts(ptr, len as usize, len as usize)) }
}

#[unsafe(no_mangle)]
pub extern "C" fn plugin_name() -> *const c_char {
    c"log-ffi".as_ptr()
}

#[unsafe(no_mangle)]
pub extern "C" fn plugin_version() -> *const c_char {
    c"0.1.0".as_ptr()
}

#[unsafe(no_mangle)]
pub extern "C" fn plugin_capabilities() -> u32 {
    0b001 // ON_REQUEST
}

#[unsafe(no_mangle)]
pub extern "C" fn plugin_on_load() {}

#[unsafe(no_mangle)]
pub extern "C" fn plugin_on_unload() {}

/// # Safety
/// Reading ctx_ptr is an unsafe operation
#[unsafe(no_mangle)]
pub unsafe extern "C" fn plugin_on_request(ctx_ptr: *const u8, ctx_len: u32) -> FfiPluginBuffer {
    let ctx_bytes = unsafe { std::slice::from_raw_parts(ctx_ptr, ctx_len as usize) };

    if let Ok(ctx) = rmp_serde::from_slice::<RequestContext>(ctx_bytes) {
        println!("[log-ffi] {} {}", ctx.method, ctx.uri);
        for (name, value) in &ctx.headers {
            println!("  {name}: {value}");
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

    let mut bytes = rmp_serde::to_vec_named(&result).unwrap_or_default();
    let ptr = bytes.as_mut_ptr();
    let len = bytes.len() as u32;
    std::mem::forget(bytes);
    FfiPluginBuffer { ptr, len }
}
