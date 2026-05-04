pub struct Cfg {
    domains: Vec<String>,
}

impl Cfg {
    pub fn from_kdl_string(str: String) -> Result<Self, ()> {
        Ok(Self {
            domains: Vec::new(),
        })
    }
}
