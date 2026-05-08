#[cfg(feature = "ffi")]
mod ffi;
#[cfg(feature = "wasm")]
mod wasm;
pub mod protocol;

/// Capability bitmasks plugins can OR together to declare which hooks they implement.
pub mod caps {
    pub const ON_REQUEST: u32 = 0b001;
    pub const ON_RESPONSE: u32 = 0b010;
    pub const ON_ERROR: u32 = 0b100;

    /// Returns true if `mask` includes the given capability bit.
    pub fn has(mask: u32, cap: u32) -> bool {
        mask & cap != 0
    }
}

/// The result a plugin returns from any hook.
pub enum HookResult {
    /// Let the request/response continue. Optionally add/override headers or replace body.
    Continue {
        extra_headers: Vec<(String, String)>,
        body_override: Option<Vec<u8>>,
    },
    /// Abort forwarding and send this response directly to the client.
    Replace {
        status: u16,
        headers: Vec<(String, String)>,
        body: Vec<u8>,
    },
    /// Signal an internal error; the proxy will return 500.
    Error(String),
}

/// Common interface for all loaded plugins. Implemented by the FFI and WASM adapters.
pub trait Extension: Send + Sync {
    fn name(&self) -> &str;
    fn version(&self) -> &str;

    /// Bitmask of `caps::ON_*` flags. Queried once after load; used to skip hook calls.
    fn capabilities(&self) -> u32;

    /// Returns true if this plugin supports the given capability bit.
    fn has_capability(&self, cap: u32) -> bool {
        caps::has(self.capabilities(), cap)
    }

    /// Called once at startup.
    fn on_load(&self);

    /// Called once at shutdown.
    fn on_unload(&self);

    fn on_request(
        &self,
        method: &str,
        uri: &str,
        upstream_url: &str,
        headers: &[(String, String)],
        body: &[u8],
    ) -> HookResult;

    fn on_response(
        &self,
        status: u16,
        headers: &[(String, String)],
        body: &[u8],
    ) -> HookResult;

    fn on_error(&self, status: u16, upstream_url: &str) -> HookResult;
}

/// Error type for plugin loading failures.
#[derive(Debug)]
pub enum LoadError {
    Io(std::io::Error),
    #[cfg(feature = "ffi")]
    Library(libloading::Error),
    #[cfg(feature = "wasm")]
    Wasm(wasmtime::Error),
    MissingExport(&'static str),
    InvalidUtf8,
}

impl std::fmt::Display for LoadError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            LoadError::Io(e) => write!(f, "IO error: {e}"),
            #[cfg(feature = "ffi")]
            LoadError::Library(e) => write!(f, "library error: {e}"),
            #[cfg(feature = "wasm")]
            LoadError::Wasm(e) => write!(f, "wasm error: {e}"),
            LoadError::MissingExport(s) => write!(f, "missing export: {s}"),
            LoadError::InvalidUtf8 => write!(f, "invalid UTF-8 in plugin string"),
        }
    }
}

impl std::error::Error for LoadError {}

/// Manages all loaded plugins, regardless of backend.
pub struct Extensions {
    pub plugins: Vec<Box<dyn Extension>>,
}

impl Extensions {
    pub fn new() -> Self {
        Self {
            plugins: Vec::new(),
        }
    }

    /// Returns true if any loaded plugin supports the given capability bit.
    pub fn has_capability(&self, cap: u32) -> bool {
        self.plugins.iter().any(|p| p.has_capability(cap))
    }

    /// Load a native shared library plugin.
    #[cfg(feature = "ffi")]
    pub fn load_ffi(&mut self, path: &str) -> Result<(), LoadError> {
        let ext = ffi::load_ffi_extension(path)?;
        self.plugins.push(ext);
        Ok(())
    }

    /// Load a WebAssembly plugin.
    #[cfg(feature = "wasm")]
    pub fn load_wasm(&mut self, path: &str) -> Result<(), LoadError> {
        let ext = wasm::load_wasm_extension(path)?;
        self.plugins.push(ext);
        Ok(())
    }
}
