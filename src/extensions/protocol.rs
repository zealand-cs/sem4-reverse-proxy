use serde::{Deserialize, Serialize};

use super::HookResult;

#[derive(Serialize)]
pub struct RequestContext<'a> {
    pub method: &'a str,
    pub uri: &'a str,
    pub upstream_url: &'a str,
    pub headers: &'a [(String, String)],
    #[serde(with = "serde_bytes")]
    pub body: &'a [u8],
}

#[derive(Serialize)]
pub struct ResponseContext<'a> {
    pub status: u16,
    pub headers: &'a [(String, String)],
    #[serde(with = "serde_bytes")]
    pub body: &'a [u8],
}

#[derive(Serialize)]
pub struct ErrorContext<'a> {
    pub status: u16,
    pub upstream_url: &'a str,
}

pub mod action {
    pub const CONTINUE: u8 = 0;
    pub const REPLACE: u8 = 1;
    pub const ERROR: u8 = 2;
}

#[derive(Deserialize)]
struct PluginResult {
    action: u8,
    #[serde(default)]
    extra_headers: Vec<(String, String)>,
    body_override: Option<Vec<u8>>,
    status: Option<u16>,
    #[serde(default)]
    headers: Vec<(String, String)>,
    #[serde(default, with = "serde_bytes")]
    body: Vec<u8>,
    #[serde(default)]
    message: String,
}

/// Encodes a request context buffer to pass to a plugin's `on_request` hook.
pub fn encode_request_context(
    method: &str,
    uri: &str,
    upstream_url: &str,
    headers: &[(String, String)],
    body: &[u8],
) -> Vec<u8> {
    rmp_serde::to_vec_named(&RequestContext {
        method,
        uri,
        upstream_url,
        headers,
        body,
    })
    .expect("msgpack encode request context")
}

/// Encodes a response context buffer to pass to a plugin's `on_response` hook.
pub fn encode_response_context(status: u16, headers: &[(String, String)], body: &[u8]) -> Vec<u8> {
    rmp_serde::to_vec_named(&ResponseContext {
        status,
        headers,
        body,
    })
    .expect("msgpack encode response context")
}

/// Encodes an error context buffer to pass to a plugin's `on_error` hook.
pub fn encode_error_context(status: u16, upstream_url: &str) -> Vec<u8> {
    rmp_serde::to_vec_named(&ErrorContext {
        status,
        upstream_url,
    })
    .expect("msgpack encode error context")
}

/// Decodes a result buffer returned by a plugin into a [`HookResult`].
/// Returns `HookResult::Continue` with no modifications if the buffer is malformed.
pub fn decode_result(buf: &[u8]) -> HookResult {
    let Ok(result) = rmp_serde::from_slice::<PluginResult>(buf) else {
        return HookResult::Continue {
            extra_headers: vec![],
            body_override: None,
        };
    };
    match result.action {
        action::REPLACE => HookResult::Replace {
            status: result.status.unwrap_or(200),
            headers: result.headers,
            body: result.body,
        },
        action::ERROR => HookResult::Error(result.message),
        _ => HookResult::Continue {
            extra_headers: result.extra_headers,
            body_override: result.body_override,
        },
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn make_continue() -> Vec<u8> {
        #[derive(Serialize)]
        struct R {
            action: u8,
        }
        rmp_serde::to_vec_named(&R {
            action: action::CONTINUE,
        })
        .unwrap()
    }

    fn make_replace(status: u16, body: &[u8]) -> Vec<u8> {
        #[derive(Serialize)]
        struct R<'a> {
            action: u8,
            status: u16,
            #[serde(with = "serde_bytes")]
            body: &'a [u8],
        }
        rmp_serde::to_vec_named(&R {
            action: action::REPLACE,
            status,
            body,
        })
        .unwrap()
    }

    #[test]
    fn round_trip_continue() {
        let buf = make_continue();
        let result = decode_result(&buf);
        assert!(matches!(
            result,
            HookResult::Continue { extra_headers, body_override: None } if extra_headers.is_empty()
        ));
    }

    #[test]
    fn round_trip_replace() {
        let buf = make_replace(418, b"I'm a teapot");
        let result = decode_result(&buf);
        match result {
            HookResult::Replace { status, body, .. } => {
                assert_eq!(status, 418);
                assert_eq!(body, b"I'm a teapot");
            }
            _ => panic!("expected Replace"),
        }
    }

    #[test]
    fn encode_request_has_method_and_uri() {
        #[derive(Deserialize)]
        struct OwnedRequestContext {
            method: String,
            uri: String,
        }

        let buf = encode_request_context("GET", "/foo", "http://upstream/foo", &[], &[]);
        let ctx: OwnedRequestContext = rmp_serde::from_slice(&buf).unwrap();
        assert_eq!(ctx.method, "GET");
        assert_eq!(ctx.uri, "/foo");
    }
}
