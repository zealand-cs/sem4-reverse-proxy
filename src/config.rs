use kdl::{KdlDocument, KdlError};

use extensions::ExtensionConfig;
use global::GlobalConfig;

pub mod extensions;
mod global;
mod host;

pub use host::HostConfig;

#[derive(Debug)]
pub struct Config {
    pub extensions: Option<ExtensionConfig>,
    pub global: Option<GlobalConfig>,
    pub hosts: Vec<HostConfig>,
}

impl Config {
    pub fn from_kdl_string(str: &str) -> Result<Self, KdlError> {
        let doc: KdlDocument = str.parse()?;

        let extensions = doc
            .get("extensions")
            .map(ExtensionConfig::try_from)
            .transpose()?;

        let global_config = doc.get("global").map(GlobalConfig::try_from).transpose()?;

        let known = ["extensions", "global"];
        let hosts = doc
            .nodes()
            .iter()
            .filter(|n| !known.contains(&n.name().value()))
            .map(HostConfig::try_from)
            .collect::<Result<Vec<_>, _>>()?;

        Ok(Self {
            extensions,
            global: global_config,
            hosts,
        })
    }
}

#[cfg(test)]
mod tests {}
