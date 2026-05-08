use std::collections::HashMap;
use std::sync::Arc;

use bytes::Bytes;
use http_body_util::{BodyExt, Full};
use hyper::{Request, Response, StatusCode, body::Incoming, header::HOST};
use hyper_util::{
    client::legacy::{Client, connect::HttpConnector},
    rt::TokioExecutor,
};

use crate::config::HostConfig;
use crate::extensions::{Extension, HookResult, caps};

pub struct ProxyRouter {
    routes: HashMap<String, Vec<(String, String)>>,
    client: Client<HttpConnector, Full<Bytes>>,
    extensions: Arc<Vec<Box<dyn Extension>>>,
}

impl ProxyRouter {
    pub fn new(hosts: Vec<HostConfig>, extensions: Vec<Box<dyn Extension>>) -> Self {
        let client = Client::builder(TokioExecutor::new()).build(HttpConnector::new());

        let mut routes: HashMap<String, Vec<(String, String)>> = HashMap::new();
        for host in hosts {
            let mut rules: Vec<(String, String)> = host
                .rules
                .into_iter()
                .map(|r| (r.path_prefix, format!("http://{}", r.upstream)))
                .collect();
            rules.sort_by_key(|b| std::cmp::Reverse(b.0.len()));
            routes.insert(host.hostname, rules);
        }

        Self {
            routes,
            client,
            extensions: Arc::new(extensions),
        }
    }

    pub async fn proxy(
        &self,
        req: Request<Incoming>,
    ) -> Result<Response<Full<Bytes>>, hyper::Error> {
        let err = |status: StatusCode| {
            Ok(Response::builder()
                .status(status)
                .body(Full::new(Bytes::new()))
                .unwrap())
        };

        let host = req
            .headers()
            .get(HOST)
            .and_then(|v| v.to_str().ok())
            .map(|h| h.split(':').next().unwrap_or(h).to_string());

        let Some(host) = host else {
            return err(StatusCode::BAD_REQUEST);
        };
        let Some(rules) = self.routes.get(&host) else {
            return err(StatusCode::NOT_FOUND);
        };

        let path = req.uri().path().to_string();
        let Some((_, upstream_base)) = rules.iter().find(|(p, _)| path.starts_with(p.as_str()))
        else {
            return err(StatusCode::NOT_FOUND);
        };

        let path_and_query = req
            .uri()
            .path_and_query()
            .map(|p| p.as_str())
            .unwrap_or("/");
        let upstream_url = format!("{}{}", upstream_base, path_and_query);

        let (mut parts, body) = req.into_parts();
        let body_bytes = body.collect().await?.to_bytes();

        // Collect headers as (String, String) pairs for plugin consumption.
        let req_headers: Vec<(String, String)> = parts
            .headers
            .iter()
            .filter_map(|(k, v)| v.to_str().ok().map(|v| (k.to_string(), v.to_string())))
            .collect();

        let method = parts.method.as_str().to_string();
        let uri = parts.uri.to_string();
        let mut working_body = body_bytes.to_vec();
        let mut extra_headers: Vec<(String, String)> = Vec::new();

        for ext in self.extensions.iter() {
            if !caps::has(ext.capabilities(), caps::ON_REQUEST) {
                continue;
            }
            let result = tokio::task::block_in_place(|| {
                ext.on_request(&method, &uri, &upstream_url, &req_headers, &working_body)
            });
            match result {
                HookResult::Replace {
                    status,
                    headers,
                    body,
                } => {
                    return Ok(build_response(status, headers, body));
                }
                HookResult::Continue {
                    extra_headers: h,
                    body_override,
                } => {
                    extra_headers.extend(h);
                    if let Some(b) = body_override {
                        working_body = b;
                    }
                }
                HookResult::Error(msg) => {
                    eprintln!("plugin on_request error: {msg}");
                    return err(StatusCode::INTERNAL_SERVER_ERROR);
                }
            }
        }

        // Apply extra headers from plugins to the outgoing request.
        for (name, value) in &extra_headers {
            if let (Ok(name), Ok(value)) = (
                name.parse::<hyper::header::HeaderName>(),
                value.parse::<hyper::header::HeaderValue>(),
            ) {
                parts.headers.insert(name, value);
            }
        }

        parts.uri = upstream_url.parse().unwrap();
        parts.headers.remove(HOST);

        let upstream_req = Request::from_parts(parts, Full::new(Bytes::from(working_body)));

        let upstream_resp = match self.client.request(upstream_req).await {
            Ok(r) => r,
            Err(_) => {
                // --- on_error hooks ---
                let result = self.run_on_error(502, &upstream_url);
                return match result {
                    HookResult::Replace {
                        status,
                        headers,
                        body,
                    } => Ok(build_response(status, headers, body)),
                    _ => err(StatusCode::BAD_GATEWAY),
                };
            }
        };

        let (resp_parts, resp_body) = upstream_resp.into_parts();
        let resp_body_bytes = resp_body.collect().await?.to_bytes();
        let status = resp_parts.status.as_u16();

        // Run on_error for 5xx responses.
        if status >= 500 {
            let result = self.run_on_error(status, &upstream_url);
            if let HookResult::Replace {
                status,
                headers,
                body,
            } = result
            {
                return Ok(build_response(status, headers, body));
            }
        }

        let resp_headers: Vec<(String, String)> = resp_parts
            .headers
            .iter()
            .filter_map(|(k, v)| v.to_str().ok().map(|v| (k.to_string(), v.to_string())))
            .collect();
        let mut resp_body_vec = resp_body_bytes.to_vec();
        let mut resp_extra_headers: Vec<(String, String)> = Vec::new();

        // --- on_response hooks ---
        for ext in self.extensions.iter() {
            if !caps::has(ext.capabilities(), caps::ON_RESPONSE) {
                continue;
            }
            let result = tokio::task::block_in_place(|| {
                ext.on_response(status, &resp_headers, &resp_body_vec)
            });
            match result {
                HookResult::Replace {
                    status,
                    headers,
                    body,
                } => {
                    return Ok(build_response(status, headers, body));
                }
                HookResult::Continue {
                    extra_headers: h,
                    body_override,
                } => {
                    resp_extra_headers.extend(h);
                    if let Some(b) = body_override {
                        resp_body_vec = b;
                    }
                }
                HookResult::Error(msg) => {
                    eprintln!("plugin on_response error: {msg}");
                    return err(StatusCode::INTERNAL_SERVER_ERROR);
                }
            }
        }

        // Rebuild response with any plugin-added headers and possibly modified body.
        let mut final_resp =
            Response::from_parts(resp_parts, Full::new(Bytes::from(resp_body_vec)));
        for (name, value) in resp_extra_headers {
            if let (Ok(name), Ok(value)) = (
                name.parse::<hyper::header::HeaderName>(),
                value.parse::<hyper::header::HeaderValue>(),
            ) {
                final_resp.headers_mut().insert(name, value);
            }
        }
        Ok(final_resp)
    }

    fn run_on_error(&self, status: u16, upstream_url: &str) -> HookResult {
        for ext in self.extensions.iter() {
            if !caps::has(ext.capabilities(), caps::ON_ERROR) {
                continue;
            }
            let result = tokio::task::block_in_place(|| ext.on_error(status, upstream_url));
            if !matches!(result, HookResult::Continue { .. }) {
                return result;
            }
        }
        HookResult::Continue {
            extra_headers: vec![],
            body_override: None,
        }
    }
}

fn build_response(
    status: u16,
    headers: Vec<(String, String)>,
    body: Vec<u8>,
) -> Response<Full<Bytes>> {
    let mut builder = Response::builder().status(status);
    for (name, value) in headers {
        if let (Ok(name), Ok(value)) = (
            name.parse::<hyper::header::HeaderName>(),
            value.parse::<hyper::header::HeaderValue>(),
        ) {
            builder = builder.header(name, value);
        }
    }
    builder.body(Full::new(Bytes::from(body))).unwrap()
}
