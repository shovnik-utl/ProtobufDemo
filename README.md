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