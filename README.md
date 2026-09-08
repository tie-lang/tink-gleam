# tink-gleam

tink data-flow node frame protocol — Gleam 库（stdlib-only，无额外依赖）。
通用且语言无关：任何遵守帧协议语言/组件都能接入 tink 管道。

```
帧 = [ len: u32 BE ][ payload: len 字节 ][ crc: u32 BE ]
len = payload 字节数
crc = CRC32-IEEE(payload)（多项式 0xEDB88320）
```

与 `std/tink.tie`（tie 标准库）及 Rust / C / Python / JS / C++ / Java / C# /
Go / Zig / Lua 等 tink 库语义一致；纯函数处理 `BitArray`（字节向量），IO
（stdin/stdout）由调用方负责。运行于 Erlang/BEAM 与 JavaScript 目标。

## API（`tink` module）

| function | description |
| --- | --- |
| `crc32(data: BitArray) -> Int` | CRC32-IEEE over a BitArray. Check vector: `crc32(<<..."123456789"...>>) == 0xCBF43926` |
| `frame_encode(payload: BitArray) -> BitArray` | encode a payload into a full frame `[len][payload][crc]` |
| `frame_next(bytes: BitArray, pos: Int) -> Result(Frame, Nil)` | parse one frame at 0-based `pos`, verify CRC; `Error(Nil)` on out-of-bounds / mismatch. `Frame` = `{ payload: BitArray, next: Int }` |
| `frame_skip(bytes: BitArray, pos: Int) -> Result(Int, Nil)` | skip one frame at 0-based `pos` without copying or verifying; `Error(Nil)` on out-of-bounds |

Positions are 0-based byte offsets. The returned payload is a copy.

## Usage

```gleam
import tink
import gleam/bit_array

pub fn main() {
  let frame = tink.frame_encode(bit_array.from_string("hi"))
  // frame = [len][payload]["hi" crc]
}
```

## Test

```bash
gleam test
```

## Cross-language

tink 帧协议各语言实现（API 语义与校验向量一致）：

| language | library |
| --- | --- |
| tie | `std/tink.tie` |
| Rust | `tink-rust`（tink crate） |
| C | `tink-c`（`tink.h` + `tink.c`） |
| Python | `tink-python`（`tink.py`） |
| JavaScript | `tink-js`（`tink.js` + `tink.d.ts`） |
| C++ | `tink-cpp`（`tink.hpp`） |
| Java | `tink-java`（`org.tielang.tink`） |
| C# | `tink-csharp`（namespace `Tink`） |
| Go | `tink-go`（package `tink`） |
| Zig | `tink-zig`（`tink.zig`） |
| Lua | this module（`tink-lua`） |
| Gleam | this module（`tink-gleam`） |

## License

本仓库使用 **Tie Public License v2.0 (TPL 2.0)**，完整文本见 [LICENSE](LICENSE)。
This repository is distributed under the **Tie Public License v2.0 (TPL 2.0)** — see [LICENSE](LICENSE) for the full text.