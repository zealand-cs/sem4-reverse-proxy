use kdl::{KdlError, KdlNode};

#[derive(Debug)]
pub struct GlobalConfig {}

impl TryFrom<&KdlNode> for GlobalConfig {
    type Error = KdlError;

    fn try_from(_node: &KdlNode) -> Result<Self, Self::Error> {
        Ok(Self {})
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
