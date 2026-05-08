use std::{any::Any, sync::Arc};

pub struct FfiManager {
    extensions: Vec<Arc<Box<String>>>,
}

impl FfiManager {
    pub fn new() -> Self {
        Self {
            extensions: Vec::new(),
        }
    }
}

pub trait FfiExtension: Any + Send + Sync {
    fn name(&self) -> &'static str;
    fn version(&self) -> String;

    fn on_load(&self);
}
