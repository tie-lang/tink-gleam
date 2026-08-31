import gleeunit
import gleam/bit_array
import tink

pub fn main() -> Nil {
  gleeunit.main()
}

// crc32 check vector
pub fn crc32_vector_test() {
  let data = bit_array.from_string("123456789")
  assert tink.crc32(data) == 0xCBF43926
}

// frame roundtrip
pub fn frame_roundtrip_test() {
  let p = <<1, 2, 3>>
  let frame = tink.frame_encode(p)
  assert bit_array.byte_size(frame) == 3 + 8

  case tink.frame_next(frame, 0) {
    Ok(got) -> {
      assert got.next == bit_array.byte_size(frame)
      assert got.payload == p
    }
    Error(_) -> panic as "frame should parse"
  }
}

// empty frame roundtrip
pub fn empty_frame_roundtrip_test() {
  let fe = tink.frame_encode(<<>>)
  case tink.frame_next(fe, 0) {
    Ok(got) -> {
      assert got.next == 8
      assert got.payload == <<>>
    }
    Error(_) -> panic as "empty frame should parse"
  }
}

// CRC tamper rejected
pub fn crc_tamper_rejected_test() {
  let ft = tink.frame_encode(<<1, 2, 3>>)
  // tamper payload[0]: bytes at offset 4
  let assert <<a:8, b:8, c:8, d:8, e:8, rest:bits>> = ft
  let e2 = e + 1
  let tampered = <<a, b, c, d, e2, rest:bits>>
  assert tink.frame_next(tampered, 0) == Error(Nil)
}

// frameSkip matches length
pub fn frame_skip_matches_len_test() {
  let fs = tink.frame_encode(<<1, 2, 3>>)
  assert tink.frame_skip(fs, 0) == Ok(bit_array.byte_size(fs))
}

// out of bounds
pub fn out_of_bounds_test() {
  let f = tink.frame_encode(<<1, 2, 3>>)
  assert tink.frame_next(f, bit_array.byte_size(f)) == Error(Nil)
  assert tink.frame_skip(f, bit_array.byte_size(f)) == Error(Nil)
  assert tink.frame_next(<<>>, 0) == Error(Nil)
}