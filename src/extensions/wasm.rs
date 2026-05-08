use std::sync::Mutex;

use wasmtime::{Caller, Engine, Instance, Linker, Memory, Module, Store, TypedFunc};

use super::{Extension, HookResult, LoadError, caps, protocol};

/// Host data stored in the wasmtime Store. Empty for now; can hold future state
/// (e.g. a tokio handle for async host imports).
struct HostData;

#[allow(dead_code)]
struct WasmExtensionInstance {
    store: Store<HostData>,
    memory: Memory,
    capability_mask: u32,
    fn_alloc: TypedFunc<i32, i32>,
    fn_free: TypedFunc<(i32, i32), ()>,
    fn_on_load: TypedFunc<(), ()>,
    fn_on_unload: TypedFunc<(), ()>,
    fn_on_request: Option<TypedFunc<(i32, i32), i64>>,
    fn_on_response: Option<TypedFunc<(i32, i32), i64>>,
    fn_on_error: Option<TypedFunc<(i32, i32), i64>>,
}

/// Public adapter. Wraps the instance in a Mutex because wasmtime's Store is !Sync.
/// `name`, `version`, and `capability_mask` are stored outside the Mutex so they
/// can be read without locking.
pub struct WasmPlugin {
    name: String,
    version: String,
    capability_mask: u32,
    inner: Mutex<WasmExtensionInstance>,
}

// SAFETY: We serialize all mutable access through the Mutex.
unsafe impl Send for WasmPlugin {}
unsafe impl Sync for WasmPlugin {}

/// Load a WASM plugin from disk and return a boxed `Extension`.
pub fn load_wasm_extension(path: &str) -> Result<Box<dyn Extension>, LoadError> {
    let engine = Engine::default();
    let module = Module::from_file(&engine, path).map_err(LoadError::Wasm)?;

    let mut linker: Linker<HostData> = Linker::new(&engine);
    linker
        .func_wrap(
            "env",
            "log",
            |mut caller: Caller<HostData>, ptr: i32, len: i32| {
                let memory = caller
                    .get_export("memory")
                    .and_then(|e| e.into_memory())
                    .unwrap();
                let data = memory.data(&caller);
                let bytes = &data[ptr as usize..(ptr + len) as usize];
                if let Ok(s) = std::str::from_utf8(bytes) {
                    print!("{s}");
                }
            },
        )
        .map_err(LoadError::Wasm)?;
    let mut store = Store::new(&engine, HostData);

    let instance = linker
        .instantiate(&mut store, &module)
        .map_err(LoadError::Wasm)?;

    let memory = get_memory(&instance, &mut store)?;

    let fn_alloc: TypedFunc<i32, i32> = get_typed_func(&instance, &mut store, "plugin_alloc")?;
    let fn_free: TypedFunc<(i32, i32), ()> = get_typed_func(&instance, &mut store, "plugin_free")?;
    let fn_name_func: TypedFunc<(), i32> = get_typed_func(&instance, &mut store, "plugin_name")?;
    let fn_version_func: TypedFunc<(), i32> =
        get_typed_func(&instance, &mut store, "plugin_version")?;
    let fn_capabilities: TypedFunc<(), i32> =
        get_typed_func(&instance, &mut store, "plugin_capabilities")?;
    let fn_on_load: TypedFunc<(), ()> = get_typed_func(&instance, &mut store, "plugin_on_load")?;
    let fn_on_unload: TypedFunc<(), ()> =
        get_typed_func(&instance, &mut store, "plugin_on_unload")?;

    let name_ptr = fn_name_func.call(&mut store, ()).map_err(LoadError::Wasm)?;
    let name = wasm_read_cstr(&store, &memory, name_ptr)?;

    let version_ptr = fn_version_func
        .call(&mut store, ())
        .map_err(LoadError::Wasm)?;
    let version = wasm_read_cstr(&store, &memory, version_ptr)?;

    let capability_mask = fn_capabilities
        .call(&mut store, ())
        .map_err(LoadError::Wasm)? as u32;

    let fn_on_request = if caps::has(capability_mask, caps::ON_REQUEST) {
        Some(get_typed_func::<(i32, i32), i64>(
            &instance,
            &mut store,
            "plugin_on_request",
        )?)
    } else {
        None
    };
    let fn_on_response = if caps::has(capability_mask, caps::ON_RESPONSE) {
        Some(get_typed_func::<(i32, i32), i64>(
            &instance,
            &mut store,
            "plugin_on_response",
        )?)
    } else {
        None
    };
    let fn_on_error = if caps::has(capability_mask, caps::ON_ERROR) {
        Some(get_typed_func::<(i32, i32), i64>(
            &instance,
            &mut store,
            "plugin_on_error",
        )?)
    } else {
        None
    };

    fn_on_load.call(&mut store, ()).map_err(LoadError::Wasm)?;

    let plugin = WasmPlugin {
        name,
        version,
        capability_mask,
        inner: Mutex::new(WasmExtensionInstance {
            store,
            memory,
            capability_mask,
            fn_alloc,
            fn_free,
            fn_on_load,
            fn_on_unload,
            fn_on_request,
            fn_on_response,
            fn_on_error,
        }),
    };

    Ok(Box::new(plugin))
}

// --- Helper functions -------------------------------------------------------

fn get_memory(instance: &Instance, store: &mut Store<HostData>) -> Result<Memory, LoadError> {
    instance
        .get_memory(store, "memory")
        .ok_or(LoadError::MissingExport("memory"))
}

fn get_typed_func<Params, Results>(
    instance: &Instance,
    store: &mut Store<HostData>,
    name: &'static str,
) -> Result<TypedFunc<Params, Results>, LoadError>
where
    Params: wasmtime::WasmParams,
    Results: wasmtime::WasmResults,
{
    instance
        .get_typed_func::<Params, Results>(store, name)
        .map_err(|_| LoadError::MissingExport(name))
}

/// Read a null-terminated UTF-8 string from WASM linear memory.
fn wasm_read_cstr(store: &Store<HostData>, memory: &Memory, ptr: i32) -> Result<String, LoadError> {
    let data = memory.data(store);
    let start = ptr as usize;
    let end = data[start..]
        .iter()
        .position(|&b| b == 0)
        .map(|i| start + i)
        .unwrap_or(data.len());
    std::str::from_utf8(&data[start..end])
        .map(|s| s.to_string())
        .map_err(|_| LoadError::InvalidUtf8)
}

/// Read `len` bytes from WASM linear memory at `ptr`.
fn wasm_read(store: &Store<HostData>, memory: &Memory, ptr: i32, len: i32) -> Vec<u8> {
    let data = memory.data(store);
    let start = ptr as usize;
    let end = (ptr + len) as usize;
    data[start..end].to_vec()
}

/// Write `data` into WASM linear memory at `ptr`.
fn wasm_write(store: &mut Store<HostData>, memory: &Memory, ptr: i32, data: &[u8]) {
    let mem = memory.data_mut(store);
    let start = ptr as usize;
    mem[start..start + data.len()].copy_from_slice(data);
}

// --- WasmExtensionInstance hook dispatcher ----------------------------------

impl WasmExtensionInstance {
    fn call_hook(&mut self, hook: TypedFunc<(i32, i32), i64>, ctx: &[u8]) -> HookResult {
        let ctx_len = ctx.len() as i32;

        // allocate space in WASM linear memory for the context buffer.
        let wasm_ptr = match self.fn_alloc.call(&mut self.store, ctx_len) {
            Ok(p) => p,
            Err(_) => return HookResult::Error("plugin_alloc failed".to_string()),
        };

        // write context bytes into WASM memory.
        wasm_write(&mut self.store, &self.memory, wasm_ptr, ctx);

        // call the hook function.
        let packed = match hook.call(&mut self.store, (wasm_ptr, ctx_len)) {
            Ok(r) => r,
            Err(e) => return HookResult::Error(format!("hook call failed: {e}")),
        };
        let result_ptr = (packed & 0xFFFFFFFF) as i32;
        let result_len = ((packed >> 32) & 0xFFFFFFFF) as i32;

        // read result bytes from WASM memory.
        let result_bytes = wasm_read(&self.store, &self.memory, result_ptr, result_len);

        // free the result buffer inside WASM memory.
        let _ = self.fn_free.call(&mut self.store, (result_ptr, result_len));

        // decode the result.
        protocol::decode_result(&result_bytes)
    }
}

// --- Extension trait impl ---------------------------------------------------

impl Extension for WasmPlugin {
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
        // Already called during load_wasm_extension.
    }

    fn on_unload(&self) {
        let mut inner = self.inner.lock().unwrap();
        // Clone the TypedFunc handle before borrowing store mutably.
        let fn_unload = inner.fn_on_unload.clone();
        let _ = fn_unload.call(&mut inner.store, ());
    }

    fn on_request(
        &self,
        method: &str,
        uri: &str,
        upstream_url: &str,
        headers: &[(String, String)],
        body: &[u8],
    ) -> HookResult {
        let mut inner = self.inner.lock().unwrap();
        let Some(hook) = inner.fn_on_request.clone() else {
            return HookResult::Continue {
                extra_headers: vec![],
                body_override: None,
            };
        };
        let ctx = protocol::encode_request_context(method, uri, upstream_url, headers, body);
        inner.call_hook(hook, &ctx)
    }

    fn on_response(&self, status: u16, headers: &[(String, String)], body: &[u8]) -> HookResult {
        let mut inner = self.inner.lock().unwrap();
        let Some(hook) = inner.fn_on_response.clone() else {
            return HookResult::Continue {
                extra_headers: vec![],
                body_override: None,
            };
        };
        let ctx = protocol::encode_response_context(status, headers, body);
        inner.call_hook(hook, &ctx)
    }

    fn on_error(&self, status: u16, upstream_url: &str) -> HookResult {
        let mut inner = self.inner.lock().unwrap();
        let Some(hook) = inner.fn_on_error.clone() else {
            return HookResult::Continue {
                extra_headers: vec![],
                body_override: None,
            };
        };
        let ctx = protocol::encode_error_context(status, upstream_url);
        inner.call_hook(hook, &ctx)
    }
}
