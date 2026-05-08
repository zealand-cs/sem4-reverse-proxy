use wasmtime::{Engine, Linker, Module, Store};

pub struct WasmManager {
    engine: Engine,
    linker: Linker<String>,
    modules: Vec<Module>,
    instances: Vec<WasmExtensionInstance>,
}

impl WasmManager {
    pub fn new() -> Self {
        let engine = Engine::default();

        Self {
            modules: Vec::new(),
            linker: Linker::new(&engine),
            engine,
            instances: Vec::new(),
        }
    }

    pub fn load_module(&mut self, bytes: impl AsRef<[u8]>) -> Result<(), wasmtime::Error> {
        let module = Module::new(&self.engine, bytes)?;
        self.modules.push(module);
        Ok(())
    }
}

pub struct WasmExtensionInstance {
    store: Store<String>,
    module: Module,
}
