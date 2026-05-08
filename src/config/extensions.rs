use kdl::{KdlError, KdlNode};

#[derive(Debug, PartialEq)]
pub enum ExtensionKind {
    Ffi,
    Wasm,
    Unknown,
}

impl From<&str> for ExtensionKind {
    fn from(value: &str) -> Self {
        match value {
            "ffi" => Self::Ffi,
            "wasm" => Self::Wasm,
            _ => Self::Unknown,
        }
    }
}

#[derive(Debug)]
pub struct Extension {
    pub file: String,
    pub kind: ExtensionKind,
}

#[derive(Debug)]
pub struct ExtensionConfig {
    pub extensions: Vec<Extension>,
}

impl TryFrom<&KdlNode> for ExtensionConfig {
    type Error = KdlError;

    fn try_from(node: &KdlNode) -> Result<Self, Self::Error> {
        let extension_config = node.children().map(|doc| {
            doc.nodes()
                .iter()
                .map(|ext| Extension {
                    file: ext.name().value().to_string(),
                    kind: ext
                        .get("kind")
                        .and_then(|kind_prop| kind_prop.as_string())
                        .map(|kind_str| kind_str.into())
                        .unwrap_or(ExtensionKind::Unknown),
                })
                .collect()
        });

        Ok(Self {
            extensions: extension_config.unwrap_or_default(),
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    use kdl::KdlDocument;

    #[test]
    fn emtpy_extensions() {
        let cfg = "extensions { }";

        let kdl: KdlDocument = cfg.parse().unwrap();
        let extensions_cfg = kdl.get("extensions").unwrap();

        let config: ExtensionConfig = extensions_cfg.try_into().unwrap();
        assert_eq!(config.extensions.len(), 0);
    }

    #[test]
    fn full_extensions() {
        let cfg = r#"
            extensions {
                "./test.so" kind=ffi
                "./test2.wasm" kind=wasm
            }
        "#;

        let kdl: KdlDocument = cfg.parse().unwrap();
        let extensions_cfg = kdl.get("extensions").unwrap();

        let config: ExtensionConfig = extensions_cfg.try_into().unwrap();

        assert_eq!(config.extensions.len(), 2);

        assert_eq!(config.extensions[0].file, "./test.so");
        assert_eq!(config.extensions[0].kind, ExtensionKind::Ffi);

        assert_eq!(config.extensions[1].file, "./test2.wasm");
        assert_eq!(config.extensions[1].kind, ExtensionKind::Wasm);
    }
}
