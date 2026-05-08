use kdl::{KdlDocument, KdlError};

use crate::config::{extensions::ExtensionConfig, global::GlobalConfig};

mod extensions;
mod global;

pub struct Config {
    extensions: Option<ExtensionConfig>,
    global: Option<GlobalConfig>,
}

impl Config {
    pub fn from_kdl_string(str: &str) -> Result<Self, KdlError> {
        let doc: KdlDocument = str.parse()?;

        let extensions = doc
            .get("extensions")
            .map(ExtensionConfig::try_from)
            .transpose()?;

        let global_config = doc.get("global").map(GlobalConfig::try_from).transpose()?;

        Ok(Self {
            extensions,
            global: global_config,
        })
    }
}

#[cfg(test)]
mod tests {}
