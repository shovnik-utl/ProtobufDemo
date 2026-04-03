#!/usr/bin/env python3
"""
TCP server: receives framed protobuf SensorReading messages and pretty-prints them.
Frame format: 4-byte big-endian length prefix + protobuf payload.
Run inside the venv:  venv/bin/python protobuf_server.py
"""

import socket
import struct
import datetime
from sensor_pb2 import SensorReading, SensorStatus
import asyncio
import uvloop

uvloop.install() # C-based event loop for better performance (comparable to Go or Nodejs).

HOST = "127.0.0.1"
PORT = 5555

STATUS_LABEL = {
    SensorStatus.OK:      "\033[92mOK\033[0m",
    SensorStatus.WARNING: "\033[93mWARNING\033[0m",
    SensorStatus.FAULT:   "\033[91mFAULT\033[0m",
}

def recv_exact(sock, n):
    buf = b""
    while len(buf) < n:
        chunk = sock.recv(n - len(buf))
        if not chunk:
            raise ConnectionResetError("client disconnected")
        buf += chunk
    return buf

def pretty_print(msg: SensorReading):
    ts = datetime.datetime.fromtimestamp(msg.timestamp_ms / 1000).strftime("%H:%M:%S.%f")[:-3]
    a = msg.accelerometer
    print(f"""
┌─ SensorReading ─────────────────────────────
│  device_id   : {msg.device_id}
│  timestamp   : {ts}
│  temperature : {msg.temperature:.2f} °C
│  humidity    : {msg.humidity:.1f} % RH
│  pressure    : {msg.pressure:.2f} hPa
│  accel (g)   : x={a.x:.3f}  y={a.y:.3f}  z={a.z:.3f}
│  uptime      : {msg.uptime_s} s
│  status      : {STATUS_LABEL.get(msg.status, msg.status)}
└─────────────────────────────────────────────""")
    return msg.device_id


# Note: asyncio.server works at the TCP layer.
async def serve(reader: asyncio.StreamReader, writer: asyncio.StreamWriter):
    global log
    addr = writer.get_extra_info('peername')
    print(f"Connected: {addr}")
    try:
        while True:
            header = await reader.readexactly(4)
            length = struct.unpack(">I", header)[0]
            payload = await reader.readexactly(length)
            msg = SensorReading()
            msg.ParseFromString(payload)
            devid = pretty_print(msg)
            log.append(devid)
    except (asyncio.IncompleteReadError, ConnectionResetError):
        print(f"Disconnected: {addr}")
    finally:
        writer.close()
        await writer.wait_closed()


async def main():
    global log
    server = await asyncio.start_server(serve, HOST, PORT)
    print(f"Server listening on {HOST}:{PORT}...")
    async with server:
        try:
            await server.serve_forever()
        except asyncio.CancelledError:
            print("Server shutting down...")
            print(f"{len(log)} messages received during session:", *log, sep='\n')
            # print(f"Devices seen during this session: {set(log)}") # de-duplicate (unique devices)

if __name__ == "__main__":
    log = []
    uvloop.run(main())


"""
Note: another advantage of the asyncio.server encapsulation is that the logic for cleanly handling
a client disconnection has been written already and gives the correct behavior unlike with raw
socket programming before: which is that for some reason I did not look into, whenever there was a client
side termination / disconnection, the server would crash too! Which is completely opposite behavior to 
what is expected of a server - it should be completely detached from client influence!
"""
