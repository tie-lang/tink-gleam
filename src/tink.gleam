// tink.gleam —— tink data-flow node frame protocol (universal, language-agnostic).
//
// Frame = [len u32 BE][payload][crc u32 BE]; crc = CRC32-IEEE (0xEDB88320).
// Mirrors std/tink.tie (tie standard library) and the other-language tink
// libraries; pure functions over BitArray (bytes), IO (stdin/stdout) left to
// the caller. Gleam, stdlib-only, no dependencies.
//
//   let frame = tink.frame_encode(bit_array.from_string("hi"))
//   let got = tink.frame_next(frame, 0) // Result(Frame, Nil)

import gleam/bit_array
import gleam/int

/// CRC32-IEEE over a byte BitArray (bit-loop).
/// Check vector: crc32(bit_array.from_string("123456789")) == 0xCBF43926
pub fn crc32(data: BitArray) -> Int {
  let crc = go(data, 0xFFFFFFFF)
  int.bitwise_and(int.bitwise_exclusive_or(crc, 0xFFFFFFFF), 0xFFFFFFFF)
}

fn go(bits: BitArray, crc: Int) -> Int {
  case bits {
    <<>> -> crc
    <<b:8, rest:bits>> -> {
      let crc1 = int.bitwise_exclusive_or(crc, b)
      let crc2 = fold_bits(crc1, 0)
      go(rest, crc2)
    }
    _ -> crc
  }
}

fn fold_bits(crc: Int, k: Int) -> Int {
  case k >= 8 {
    True -> int.bitwise_and(crc, 0xFFFFFFFF)
    False ->
      case int.bitwise_and(crc, 1) {
        0 -> fold_bits(int.bitwise_shift_right(crc, 1), k + 1)
        _ ->
          fold_bits(
            int.bitwise_exclusive_or(int.bitwise_shift_right(crc, 1), 0xEDB88320),
            k + 1,
          )
      }
  }
}

/// Frame is the result of parsing a frame: payload (a copy) and the position
/// right after the frame (payload length + 8).
pub type Frame {
  Frame(payload: BitArray, next: Int)
}

fn u32_bits(n: Int) -> BitArray {
  let b0 = int.bitwise_and(int.bitwise_shift_right(n, 24), 0xFF)
  let b1 = int.bitwise_and(int.bitwise_shift_right(n, 16), 0xFF)
  let b2 = int.bitwise_and(int.bitwise_shift_right(n, 8), 0xFF)
  let b3 = int.bitwise_and(n, 0xFF)
  bit_array.concat([byte(b0), byte(b1), byte(b2), byte(b3)])
}

fn byte(n: Int) -> BitArray {
  let bits = int.bitwise_and(n, 0xFF)
  <<bits:8>>
}

/// Encode a payload into a full frame: [len u32 BE][payload][crc u32 BE].
pub fn frame_encode(payload: BitArray) -> BitArray {
  let n = bit_array.byte_size(payload)
  let c = crc32(payload)
  bit_array.concat([u32_bits(n), payload, u32_bits(c)])
}

/// Parse one frame at pos (verifies CRC). Returns Frame or Error(Nil) on
/// out-of-bounds / CRC mismatch. Positions are 0-based byte offsets.
pub fn frame_next(bytes: BitArray, pos: Int) -> Result(Frame, Nil) {
  let total = bit_array.byte_size(bytes)
  case total < pos + 8 {
    True -> Error(Nil)
    False ->
      case slice_u32(bytes, pos) {
        Error(_) -> Error(Nil)
        Ok(len) -> {
          let end = pos + 8 + len
          case total < end {
            True -> Error(Nil)
            False ->
              case bit_array.slice(bytes, at: pos + 4, take: len) {
                Error(_) -> Error(Nil)
                Ok(payload) ->
                  case slice_u32(bytes, end - 4) {
                    Error(_) -> Error(Nil)
                    Ok(want) ->
                      case want == crc32(payload) {
                        True -> Ok(Frame(payload, end))
                        False -> Error(Nil)
                      }
                  }
              }
          }
        }
      }
  }
}

/// Skip one frame at pos without copying or verifying (zero-copy).
/// Returns the position after the frame, or Error(Nil) on out-of-bounds.
pub fn frame_skip(bytes: BitArray, pos: Int) -> Result(Int, Nil) {
  let total = bit_array.byte_size(bytes)
  case total < pos + 8 {
    True -> Error(Nil)
    False ->
      case slice_u32(bytes, pos) {
        Ok(n) -> {
          let end = pos + 8 + n
          case total < end {
            True -> Error(Nil)
            False -> Ok(end)
          }
        }
        Error(_) -> Error(Nil)
      }
  }
}

fn slice_u32(bits: BitArray, from: Int) -> Result(Int, Nil) {
  case bit_array.slice(bits, at: from, take: 4) {
    Error(_) -> Error(Nil)
    Ok(chunk) ->
      case chunk {
        <<b0:8, b1:8, b2:8, b3:8>> ->
          Ok(int.bitwise_exclusive_or(
            int.bitwise_exclusive_or(
              int.bitwise_shift_left(b0, 24),
              int.bitwise_shift_left(b1, 16),
            ),
            int.bitwise_exclusive_or(int.bitwise_shift_left(b2, 8), b3),
          ))
        _ -> Error(Nil)
      }
  }
}