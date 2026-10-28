#!/usr/bin/env python3
"""Send DMX to ChromaPulse over Art-Net or sACN (E1.31).

  tool/dmx_send.py artnet 192.168.1.20 255 0 0
  tool/dmx_send.py sacn 192.168.1.20 0 0 255 --priority 150
  tool/dmx_send.py sacn multicast 0 255 0 --universe 2

Universes count from 1, as in the app's settings.
"""

import argparse
import socket
import struct
import time
import uuid


def artnet(universe, dmx):
    return (
        b"Art-Net\0"
        + struct.pack("<H", 0x5000)
        + struct.pack(">H", 14)
        + bytes([0, 0])
        + struct.pack("<H", universe - 1)
        + struct.pack(">H", len(dmx))
        + dmx
    )


def sacn(universe, dmx, cid, priority, sequence, terminate=False):
    slots = b"\0" + dmx
    dmp = struct.pack(
        ">HBBHHH", 0x7000 | (10 + len(slots)), 0x02, 0xA1, 0, 1, len(slots)
    ) + slots
    framing = (
        struct.pack(">HI", 0x7000 | (77 + len(dmp)), 0x00000002)
        + b"dmx_send.py".ljust(64, b"\0")
        + struct.pack(">BHBBH", priority, 0, sequence, 0x40 if terminate else 0, universe)
        + dmp
    )
    root = struct.pack(">HI", 0x7000 | (22 + len(framing)), 0x00000004) + cid + framing
    return struct.pack(">HH", 0x0010, 0) + b"ASC-E1.17\0\0\0" + root


def main():
    p = argparse.ArgumentParser()
    p.add_argument("protocol", choices=["artnet", "sacn"])
    p.add_argument("target", help="device IP, or 'multicast' for sACN")
    p.add_argument("values", type=int, nargs="+", help="DMX values from --start")
    p.add_argument("--universe", type=int, default=1)
    p.add_argument("--start", type=int, default=1, help="first DMX channel")
    p.add_argument("--priority", type=int, default=100)
    p.add_argument("--seconds", type=float, default=3)
    p.add_argument("--fps", type=float, default=20)
    a = p.parse_args()
    if not 1 <= a.universe <= 63999:
        p.error("--universe must be between 1 and 63999")
    if a.start < 1 or a.start - 1 + len(a.values) > 512:
        p.error("values run past channel 512")

    dmx = bytearray(512)
    dmx[a.start - 1 : a.start - 1 + len(a.values)] = bytes(a.values)
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, 4)

    if a.protocol == "artnet":
        dest = (a.target, 6454)
        packet = lambda seq: artnet(a.universe, bytes(dmx))
    else:
        host = a.target
        if host == "multicast":
            host = f"239.255.{a.universe >> 8}.{a.universe & 0xFF}"
        dest = (host, 5568)
        cid = uuid.uuid4().bytes
        packet = lambda seq: sacn(a.universe, bytes(dmx), cid, a.priority, seq % 256)

    end = time.time() + a.seconds
    seq = 0
    while time.time() < end:
        sock.sendto(packet(seq), dest)
        seq += 1
        time.sleep(1 / a.fps)
    if a.protocol == "sacn":
        for i in range(3):
            sock.sendto(sacn(a.universe, bytes(dmx), cid, a.priority, (seq + i) % 256, True), dest)
    print(f"sent {seq} {a.protocol} packets to {dest[0]}:{dest[1]}")


if __name__ == "__main__":
    main()
