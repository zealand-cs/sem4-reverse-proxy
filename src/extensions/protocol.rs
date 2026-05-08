use super::HookResult;

/// Tags for context buffers sent from the host to a plugin.
pub mod context_tag {
    pub const METHOD: u8 = 0x01;
    pub const URI: u8 = 0x02;
    pub const STATUS: u8 = 0x03;
    pub const HEADER: u8 = 0x04;
    pub const BODY: u8 = 0x05;
    pub const UPSTREAM_URL: u8 = 0x06;
}

/// Tags for result buffers sent from a plugin back to the host.
pub mod result_tag {
    pub const ACTION: u8 = 0x10;
    pub const STATUS: u8 = 0x11;
    pub const HEADER: u8 = 0x12;
    pub const BODY: u8 = 0x13;
}

/// Action byte values within a result buffer.
pub mod action {
    pub const CONTINUE: u8 = 0;
    pub const REPLACE: u8 = 1;
    pub const ERROR: u8 = 2;
}

fn write_section(out: &mut Vec<u8>, tag: u8, data: &[u8]) {
    out.push(tag);
    out.extend_from_slice(&(data.len() as u32).to_be_bytes());
    out.extend_from_slice(data);
}

fn begin_with_count(out: &mut Vec<u8>, count: u32) {
    out.extend_from_slice(&count.to_be_bytes());
}

/// Encodes a request context buffer to pass to a plugin's `on_request` hook.
pub fn encode_request_context(
    method: &str,
    uri: &str,
    upstream_url: &str,
    headers: &[(String, String)],
    body: &[u8],
) -> Vec<u8> {
    let section_count = 3 + headers.len() as u32 + if body.is_empty() { 0 } else { 1 };
    let mut out = Vec::new();
    begin_with_count(&mut out, section_count);
    write_section(&mut out, context_tag::METHOD, method.as_bytes());
    write_section(&mut out, context_tag::URI, uri.as_bytes());
    write_section(&mut out, context_tag::UPSTREAM_URL, upstream_url.as_bytes());
    for (name, value) in headers {
        let header_line = format!("{}: {}", name, value);
        write_section(&mut out, context_tag::HEADER, header_line.as_bytes());
    }
    if !body.is_empty() {
        write_section(&mut out, context_tag::BODY, body);
    }
    out
}

/// Encodes a response context buffer to pass to a plugin's `on_response` hook.
pub fn encode_response_context(status: u16, headers: &[(String, String)], body: &[u8]) -> Vec<u8> {
    let section_count = 1 + headers.len() as u32 + if body.is_empty() { 0 } else { 1 };
    let mut out = Vec::new();
    begin_with_count(&mut out, section_count);
    write_section(&mut out, context_tag::STATUS, &status.to_be_bytes());
    for (name, value) in headers {
        let header_line = format!("{}: {}", name, value);
        write_section(&mut out, context_tag::HEADER, header_line.as_bytes());
    }
    if !body.is_empty() {
        write_section(&mut out, context_tag::BODY, body);
    }
    out
}

/// Encodes an error context buffer to pass to a plugin's `on_error` hook.
pub fn encode_error_context(status: u16, upstream_url: &str) -> Vec<u8> {
    let mut out = Vec::new();
    begin_with_count(&mut out, 2);
    write_section(&mut out, context_tag::STATUS, &status.to_be_bytes());
    write_section(&mut out, context_tag::UPSTREAM_URL, upstream_url.as_bytes());
    out
}

/// Decodes a result buffer returned by a plugin into a [`HookResult`].
/// Returns `HookResult::Continue` with no modifications if the buffer is malformed.
pub fn decode_result(buf: &[u8]) -> HookResult {
    if buf.len() < 4 {
        return HookResult::Continue {
            extra_headers: vec![],
            body_override: None,
        };
    }

    let section_count = u32::from_be_bytes([buf[0], buf[1], buf[2], buf[3]]) as usize;
    let mut pos = 4;

    let mut action = action::CONTINUE;
    let mut status_override: Option<u16> = None;
    let mut extra_headers: Vec<(String, String)> = Vec::new();
    let mut body_override: Option<Vec<u8>> = None;
    let mut error_msg = String::new();

    for _ in 0..section_count {
        if pos + 5 > buf.len() {
            break;
        }
        let tag = buf[pos];
        let len =
            u32::from_be_bytes([buf[pos + 1], buf[pos + 2], buf[pos + 3], buf[pos + 4]]) as usize;
        pos += 5;
        if pos + len > buf.len() {
            break;
        }
        let data = &buf[pos..pos + len];
        pos += len;

        match tag {
            result_tag::ACTION if !data.is_empty() => {
                action = data[0];
            }
            result_tag::STATUS if data.len() >= 2 => {
                status_override = Some(u16::from_be_bytes([data[0], data[1]]));
            }
            result_tag::HEADER => {
                if let Ok(s) = std::str::from_utf8(data)
                    && let Some((name, value)) = s.split_once(": ")
                {
                    extra_headers.push((name.to_string(), value.to_string()));
                }
            }
            result_tag::BODY => {
                body_override = Some(data.to_vec());
            }
            _ => {}
        }
    }

    match action {
        action::REPLACE => HookResult::Replace {
            status: status_override.unwrap_or(200),
            headers: extra_headers,
            body: body_override.unwrap_or_default(),
        },
        action::ERROR => {
            if let Some(body) = body_override {
                error_msg = String::from_utf8_lossy(&body).into_owned();
            }
            HookResult::Error(error_msg)
        }
        _ => HookResult::Continue {
            extra_headers,
            body_override,
        },
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn round_trip_continue() {
        // Encode a minimal "continue with no changes" result
        let mut buf = Vec::new();
        begin_with_count(&mut buf, 1);
        write_section(&mut buf, result_tag::ACTION, &[action::CONTINUE]);

        let result = decode_result(&buf);
        assert!(matches!(
            result,
            HookResult::Continue {
                extra_headers,
                body_override: None
            } if extra_headers.is_empty()
        ));
    }

    #[test]
    fn round_trip_replace() {
        let mut buf = Vec::new();
        begin_with_count(&mut buf, 3);
        write_section(&mut buf, result_tag::ACTION, &[action::REPLACE]);
        write_section(&mut buf, result_tag::STATUS, &418u16.to_be_bytes());
        write_section(&mut buf, result_tag::BODY, b"I'm a teapot");

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
        let buf = encode_request_context("GET", "/foo", "http://upstream/foo", &[], &[]);
        // section_count = 3
        let count = u32::from_be_bytes([buf[0], buf[1], buf[2], buf[3]]);
        assert_eq!(count, 3);
        // first section tag must be METHOD
        assert_eq!(buf[4], context_tag::METHOD);
    }
}
