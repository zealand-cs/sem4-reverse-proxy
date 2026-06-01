use std::ffi::CStr;

use libloading::Library;

use super::{Extension, HookResult, LoadError, caps, protocol};

/// `#[repr(C)]` buffer returned by plugin hook functions.
/// The plugin allocates this on the heap; the host reads it then calls `plugin_free`.
///
/// `cap` must be the original Vec capacity so that `plugin_free` can reconstruct
/// the Vec with the correct allocator layout. Passing `len` as the capacity is
/// undefined behaviour if the allocator used a larger block.
#[repr(C)]
pub struct FfiPluginBuffer {
    pub ptr: *mut u8,
    pub len: u32,
    pub cap: u32,
}

// Type aliases for the symbols we load from the shared library.
type FnName = unsafe extern "C" fn() -> *const std::os::raw::c_char;
type FnVersion = unsafe extern "C" fn() -> *const std::os::raw::c_char;
type FnCapabilities = unsafe extern "C" fn() -> u32;
type FnOnLoad = unsafe extern "C" fn();
type FnOnUnload = unsafe extern "C" fn();
type FnHook = unsafe extern "C" fn(*const u8, u32) -> FfiPluginBuffer;
type FnFree = unsafe extern "C" fn(*mut u8, u32, u32);

#[allow(dead_code)]
pub struct FfiExtension {
    /// The library the the ffi extension is read from
    ///
    /// Stored here to outlive any references to functions in it.
    _lib: Library,
    name: String,
    version: String,
    capability_mask: u32,
    fn_on_load: unsafe extern "C" fn(),
    fn_on_unload: unsafe extern "C" fn(),
    fn_on_request: Option<unsafe extern "C" fn(*const u8, u32) -> FfiPluginBuffer>,
    fn_on_response: Option<unsafe extern "C" fn(*const u8, u32) -> FfiPluginBuffer>,
    fn_on_error: Option<unsafe extern "C" fn(*const u8, u32) -> FfiPluginBuffer>,
    fn_free: unsafe extern "C" fn(*mut u8, u32, u32),
}

// SAFETY: The library is only ever accessed through the stored function pointers,
// which are all Send. The Mutex in the caller guarantees no concurrent access.
unsafe impl Send for FfiExtension {}
unsafe impl Sync for FfiExtension {}

/// Load a native shared library plugin and return a boxed `Extension`.
pub fn load_ffi_extension(path: &str) -> Result<Box<dyn Extension>, LoadError> {
    // SAFETY: Loading a shared library is inherently unsafe. We trust the path
    // comes from the validated config file.
    let lib = unsafe { Library::new(path) }.map_err(LoadError::Library)?;

    macro_rules! sym {
        ($name:literal, $ty:ty) => {{
            let s = unsafe { lib.get::<$ty>($name) }
                .map_err(|_| LoadError::MissingExport(std::str::from_utf8($name).unwrap_or("?")))?;

            *s
        }};
    }

    let fn_name = sym!(b"plugin_name", FnName);
    let fn_version = sym!(b"plugin_version", FnVersion);
    let fn_capabilities = sym!(b"plugin_capabilities", FnCapabilities);
    let fn_on_load = sym!(b"plugin_on_load", FnOnLoad);
    let fn_on_unload = sym!(b"plugin_on_unload", FnOnUnload);
    let fn_free = sym!(b"plugin_free", FnFree);

    let name = unsafe {
        CStr::from_ptr(fn_name())
            .to_str()
            .map_err(|_| LoadError::InvalidUtf8)?
            .to_string()
    };
    let version = unsafe {
        CStr::from_ptr(fn_version())
            .to_str()
            .map_err(|_| LoadError::InvalidUtf8)?
            .to_string()
    };
    let capability_mask = unsafe { fn_capabilities() };

    let fn_on_request = if caps::has(capability_mask, caps::ON_REQUEST) {
        Some(sym!(b"plugin_on_request", FnHook))
    } else {
        None
    };
    let fn_on_response = if caps::has(capability_mask, caps::ON_RESPONSE) {
        Some(sym!(b"plugin_on_response", FnHook))
    } else {
        None
    };
    let fn_on_error = if caps::has(capability_mask, caps::ON_ERROR) {
        Some(sym!(b"plugin_on_error", FnHook))
    } else {
        None
    };

    unsafe { fn_on_load() };

    Ok(Box::new(FfiExtension {
        _lib: lib,
        name,
        version,
        capability_mask,
        fn_on_load,
        fn_on_unload,
        fn_on_request,
        fn_on_response,
        fn_on_error,
        fn_free,
    }))
}

impl FfiExtension {
    /// Call a hook function with an encoded context buffer, return the decoded result.
    fn call_hook(
        &self,
        hook: unsafe extern "C" fn(*const u8, u32) -> FfiPluginBuffer,
        ctx: &[u8],
    ) -> HookResult {
        let buf = unsafe { hook(ctx.as_ptr(), ctx.len() as u32) };

        if buf.ptr.is_null() || buf.len == 0 {
            return HookResult::Continue {
                extra_headers: vec![],
                body_override: None,
            };
        }

        let result_bytes = unsafe { std::slice::from_raw_parts(buf.ptr, buf.len as usize) };
        let result = protocol::decode_result(result_bytes);

        unsafe { (self.fn_free)(buf.ptr, buf.len, buf.cap) };

        result
    }
}

impl Extension for FfiExtension {
    fn name(&self) -> &str {
        &self.name
    }

    fn version(&self) -> &str {
        &self.version
    }

    fn capabilities(&self) -> u32 {
        self.capability_mask
    }

    fn on_load(&self) {
        unsafe { (self.fn_on_load)() }
    }

    fn on_unload(&self) {
        unsafe { (self.fn_on_unload)() }
    }

    fn on_request(
        &self,
        method: &str,
        uri: &str,
        upstream_url: &str,
        headers: &[(String, String)],
        body: &[u8],
    ) -> HookResult {
        let Some(hook) = self.fn_on_request else {
            return HookResult::Continue {
                extra_headers: vec![],
                body_override: None,
            };
        };
        let ctx = protocol::encode_request_context(method, uri, upstream_url, headers, body);
        self.call_hook(hook, &ctx)
    }

    fn on_response(&self, status: u16, headers: &[(String, String)], body: &[u8]) -> HookResult {
        let Some(hook) = self.fn_on_response else {
            return HookResult::Continue {
                extra_headers: vec![],
                body_override: None,
            };
        };
        let ctx = protocol::encode_response_context(status, headers, body);
        self.call_hook(hook, &ctx)
    }

    fn on_error(&self, status: u16, upstream_url: &str) -> HookResult {
        let Some(hook) = self.fn_on_error else {
            return HookResult::Continue {
                extra_headers: vec![],
                body_override: None,
            };
        };
        let ctx = protocol::encode_error_context(status, upstream_url);
        self.call_hook(hook, &ctx)
    }
}
