# Protobuf Tooling — Quick Reference

## Packages to Install

### Linux (apt)
```bash
# Core compiler + C library
sudo apt install protobuf-compiler protobuf-c-compiler libprotobuf-c-dev

# Python runtime (inside venv)
pip install protobuf
```

### Windows (winget / Chocolatey)
```powershell
choco install protoc          # protoc compiler
choco install protobuf        # C++ runtime + dev headers
pip install protobuf          # Python runtime
# protobuf-c for Windows: build from source or use vcpkg
vcpkg install protobuf-c
```

### buf (schema linting + breaking-change detection)
```bash
# Linux
curl -sSL https://github.com/bufbuild/buf/releases/latest/download/buf-Linux-x86_64 \
  -o /usr/local/bin/buf && chmod +x /usr/local/bin/buf

# Windows
choco install buf
# or download buf-Windows-x86_64.exe from github.com/bufbuild/buf/releases
```

---

## Essential Commands

### Compile .proto → language bindings
```bash
# Python
protoc --python_out=. sensor.proto

# C  (requires protoc-gen-c plugin)
protoc --plugin=protoc-gen-c=$(which protoc-gen-c) --c_out=. sensor.proto

# C++
protoc --cpp_out=. sensor.proto

# Multiple outputs at once
protoc --python_out=./server --c_out=./firmware sensor.proto
```

### Inspect a compiled .proto
```bash
protoc --decode_raw < some_file.bin          # decode without .proto (raw fields)
protoc --decode=iot.SensorReading sensor.proto < some_file.bin  # decode with schema
```

### buf — schema linting and breaking-change detection
```bash
buf init                          # create buf.yaml in project root
buf lint                          # lint all .proto files
buf breaking --against .git#tag=v1  # check for breaking changes vs git tag
buf generate                      # generate code using buf.gen.yaml
```

### buf.yaml (minimal)
```yaml
version: v1
lint:
  use: [DEFAULT]
breaking:
  use: [WIRE_JSON]
```

---

## Windows Equivalents

| Linux command            | Windows equivalent                        |
|--------------------------|-------------------------------------------|
| `which protoc-gen-c`     | `where protoc-gen-c`                      |
| `$(which protoc-gen-c)`  | `$(where.exe /f protoc-gen-c)`            |
| `./protobuf_client`      | `protobuf_client.exe`                     |
| `make`                   | `nmake` (MSVC) or `mingw32-make` (MinGW)  |
| `apt install`            | `choco install` or `vcpkg install`        |

On Windows, use **WSL2** to avoid most of these differences when working with C toolchains.

---

## This Project

```
proto_demo/
  sensor.proto          # shared schema — source of truth
  sensor.pb-c.c/.h      # generated C bindings  (make proto)
  sensor_pb2.py         # generated Python bindings  (protoc --python_out)
  protobuf_server.py    # Python TCP server
  protobuf_client.c     # C TCP client
  Makefile
  venv/                 # Python virtualenv
```

### Quick start
```bash
# 1. Install system deps (once)
sudo apt install protobuf-compiler protobuf-c-compiler libprotobuf-c-dev

# 2. Python venv + runtime
python3 -m venv venv && venv/bin/pip install protobuf

# 3. Generate bindings for both sides
protoc --python_out=. sensor.proto
make proto           # generates sensor.pb-c.c/.h

# 4. Build C client
make

# 5. Run (two terminals)
venv/bin/python protobuf_server.py   # terminal 1
./protobuf_client                    # terminal 2
```

## `nanopb`

`nanopb` is an implementation of Google's Protocall Buffers or Protobufs
for embedded systems, designed to have:
1.  *low memory footprint*: both code/ROM and stack/RAM spaces.
2.  *no heap allocation*: using heap is considered problematic in MCUs.

### Why is it "bad"?
1. *Slow access*: due to overhead of the heap algorithm implementation (=allocators, etc).
2. *Memory fragmentation*: due to overuse of the heap resulting in lack of memory to allocate even when 
  cummulatively there might a lot of memory still available! Want to avoid this inefficeint s
3. *Memory Leaks*: with the stack, memory management is abstracted by the compiler (automatic variables); with the heap, its not. *Manual memory management* is the root of human errors resulting in memory leaks. Really bad if your already limited memory is leaking.

### Git submodule
You could just copy some files as and when needed, but it is a
good idea to maintain a git reference to the `nanopb` project so that
it becomes a *versioned dependency* which you can use to *reproduce*
your builds across computers with the *correct version everytime*.

### `nanopb` vs `protoc`: Compatibility?

Note: there is compatibilit involved because `nanopb` has been built to use a specific version of
the Protobuf protocol and thus must be *compatible* with `protoc` (the protobuf compiler).

1. `nanopb` is tied to protobuf 3.x API model; so use `syntax = "proto3";`
2. Stay within safe version range to avoid incompatibility issues: protoc 3.x <-> nanopb 0.4.x

### Step 1: Integrate Nanopb into Build System

To integrate nanopb means to *replace* the standard C "backend": `protoc-gen-c`,
and "plug in" another backend for embedded C (Nanopb): `protoc-gen-nanopb`, ie:

  protoc --plugin=protoc-gen-c=/path/to/protoc-gen-c            --c_out=.       my_schema.proto

to

  protoc --plugin=protoc-gen-nanopb=./path/to/protoc-gen-nanopb --nanopb_out=.  my_schema.proto

Normally you would need to debug till the Makefile successfully builds :/
(look at details in this commmit for reference.)
But I have put all the rules in the Makefile so that it gets started through a simple `make`.

## Step 2: Integrate into source code (new API!)

Switching backends also has the consequence that the generated code (probably) uses a different API!
So now you will need to look at `nanopb`'s documentation to figure out what this new API is
and how it works (what's the framework like compared to the standard Google protobuf implementation?)
