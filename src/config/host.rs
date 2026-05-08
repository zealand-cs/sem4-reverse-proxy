use kdl::{KdlError, KdlNode};

#[derive(Debug, Clone)]
pub struct ProxyRule {
    pub path_prefix: String,
    pub upstream: String,
}

#[derive(Debug, Clone)]
pub struct HostConfig {
    pub hostname: String,
    pub rules: Vec<ProxyRule>,
}

impl TryFrom<&KdlNode> for HostConfig {
    type Error = KdlError;

    fn try_from(node: &KdlNode) -> Result<Self, Self::Error> {
        let hostname = node.name().value().to_string();
        let mut rules = Vec::new();

        if let Some(doc) = node.children() {
            for child in doc.nodes() {
                if child.name().value() != "proxy_pass" {
                    continue;
                }

                let Some(path_prefix) = child
                    .entries()
                    .first()
                    .and_then(|e| e.value().as_string())
                    .map(|s| s.to_string())
                else {
                    continue;
                };

                let Some(upstream) = child
                    .get("to")
                    .and_then(|v| v.as_string())
                    .map(|s| s.to_string())
                else {
                    continue;
                };

                rules.push(ProxyRule { path_prefix, upstream });
            }
        }

        Ok(Self { hostname, rules })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use kdl::KdlDocument;

    #[test]
    fn empty_host() {
        let cfg = "myhost { }";
        let kdl: KdlDocument = cfg.parse().unwrap();
        let node = kdl.get("myhost").unwrap();
        let config: HostConfig = node.try_into().unwrap();
        assert_eq!(config.hostname, "myhost");
        assert_eq!(config.rules.len(), 0);
    }

    #[test]
    fn proxy_rules() {
        let cfg = r#"
            localhost {
                proxy_pass "/service1" to="localhost:4050"
                proxy_pass "/service2" to="localhost:4060"
            }
        "#;
        let kdl: KdlDocument = cfg.parse().unwrap();
        let node = kdl.get("localhost").unwrap();
        let config: HostConfig = node.try_into().unwrap();
        assert_eq!(config.hostname, "localhost");
        assert_eq!(config.rules.len(), 2);
        assert_eq!(config.rules[0].path_prefix, "/service1");
        assert_eq!(config.rules[0].upstream, "localhost:4050");
        assert_eq!(config.rules[1].path_prefix, "/service2");
        assert_eq!(config.rules[1].upstream, "localhost:4060");
    }
}
