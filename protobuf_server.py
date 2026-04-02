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


def serve(log: [int]):
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as srv:
        srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        srv.bind((HOST, PORT))
        srv.listen(1)
        print(f"Listening on {HOST}:{PORT} ...")
        conn, addr = srv.accept()
        print(f"Connected: {addr}")
        with conn:
            while True:
                header = recv_exact(conn, 4)
                length = struct.unpack(">I", header)[0]
                payload = recv_exact(conn, length)
                msg = SensorReading()
                msg.ParseFromString(payload)
                devid = pretty_print(msg)
                log.append(devid)

if __name__ == "__main__":
    log = []
    try:
        serve(log)
    except KeyboardInterrupt:
        print(f"{len(log)} messages received: ", *log, sep='\n')
