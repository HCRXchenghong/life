use bytes::{Buf, BufMut, BytesMut};
use serde::{Serialize, de::DeserializeOwned};
use thiserror::Error;

pub const MAX_FRAME_BYTES: usize = 8 * 1024 * 1024;

#[derive(Debug, Error)]
pub enum FrameError {
    #[error("frame exceeds the {MAX_FRAME_BYTES} byte limit")]
    TooLarge,
    #[error("invalid CBOR payload: {0}")]
    InvalidPayload(String),
}

pub struct FrameCodec;

impl FrameCodec {
    pub fn encode<T: Serialize>(value: &T) -> Result<BytesMut, FrameError> {
        let mut payload = Vec::new();
        ciborium::into_writer(value, &mut payload)
            .map_err(|error| FrameError::InvalidPayload(error.to_string()))?;
        if payload.len() > MAX_FRAME_BYTES {
            return Err(FrameError::TooLarge);
        }

        let mut frame = BytesMut::with_capacity(4 + payload.len());
        #[allow(clippy::cast_possible_truncation)]
        frame.put_u32(payload.len() as u32);
        frame.extend_from_slice(&payload);
        Ok(frame)
    }

    pub fn decode<T: DeserializeOwned>(buffer: &mut BytesMut) -> Result<Option<T>, FrameError> {
        if buffer.len() < 4 {
            return Ok(None);
        }
        let length = u32::from_be_bytes(buffer[..4].try_into().expect("four-byte prefix")) as usize;
        if length > MAX_FRAME_BYTES {
            return Err(FrameError::TooLarge);
        }
        if buffer.len() < 4 + length {
            return Ok(None);
        }

        buffer.advance(4);
        let payload = buffer.split_to(length);
        ciborium::from_reader(payload.as_ref())
            .map(Some)
            .map_err(|error| FrameError::InvalidPayload(error.to_string()))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde::{Deserialize, Serialize};

    #[derive(Debug, PartialEq, Serialize, Deserialize)]
    struct Sample {
        value: String,
    }

    #[test]
    fn round_trips_and_waits_for_complete_frames() {
        let sample = Sample {
            value: "daylink".into(),
        };
        let encoded = FrameCodec::encode(&sample).expect("encode");
        let split = encoded.len() - 1;
        let mut input = BytesMut::from(&encoded[..split]);
        assert!(
            FrameCodec::decode::<Sample>(&mut input)
                .expect("decode")
                .is_none()
        );
        input.extend_from_slice(&encoded[split..]);
        assert_eq!(
            FrameCodec::decode::<Sample>(&mut input)
                .expect("decode")
                .expect("complete"),
            sample
        );
        assert!(input.is_empty());
    }
}
