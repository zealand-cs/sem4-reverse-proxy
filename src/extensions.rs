#[cfg(feature = "ffi")]
use crate::extensions::ffi::FfiManager;
#[cfg(feature = "wasm")]
use crate::extensions::wasm::WasmManager;

#[cfg(feature = "ffi")]
mod ffi;
#[cfg(feature = "wasm")]
mod wasm;

pub struct Extensions {
    #[cfg(feature = "ffi")]
    ffi: FfiManager,
    #[cfg(feature = "wasm")]
    wasm: WasmManager,
}

pub trait Extension {
    fn name(&self) -> &'static str;
    fn version(&self) -> String;

    fn on_load(&self);
}
