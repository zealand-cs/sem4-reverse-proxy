use kdl::{KdlError, KdlNode};

pub struct GlobalConfig {
    h: Option<String>,
}

impl TryFrom<&KdlNode> for GlobalConfig {
    type Error = KdlError;

    fn try_from(node: &KdlNode) -> Result<Self, Self::Error> {
        Ok(Self {
            h: Some("".to_string()),
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    use kdl::KdlDocument;

    #[test]
    fn emtpy_global() {
        let cfg = "global { }";

        let kdl: KdlDocument = cfg.parse().unwrap();
        let cfg = kdl.get("global").unwrap();

        let _config: GlobalConfig = cfg.try_into().unwrap();
    }

    #[test]
    fn full_global() {
        let cfg = r#"
            global { }
        "#;

        let kdl: KdlDocument = cfg.parse().unwrap();
        let cfg = kdl.get("global").unwrap();

        let _config: GlobalConfig = cfg.try_into().unwrap();
    }
}
