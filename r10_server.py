"""TCP 921 OpenConnect / E6 listener for a Garmin R10 bridge."""

from __future__ import annotations

import json
import socket
import threading
from typing import Callable, Optional


def _extract_json_objects(buf: str) -> tuple[list[dict], str]:
    objs: list[dict] = []
    i = 0
    while True:
        start = buf.find("{", i)
        if start < 0:
            return objs, buf[i:]
        depth = 0
        in_str = False
        esc = False
        end = None
        for j, ch in enumerate(buf[start:], start):
            if in_str:
                if esc:
                    esc = False
                elif ch == "\\":
                    esc = True
                elif ch == '"':
                    in_str = False
                continue
            if ch == '"':
                in_str = True
            elif ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    end = j
                    break
        if end is None:
            return objs, buf[start:]
        chunk = buf[start : end + 1]
        try:
            objs.append(json.loads(chunk))
        except json.JSONDecodeError:
            pass
        i = end + 1


def serve_r10(
    host: str,
    port: int,
    on_payload: Callable[[dict], Optional[dict]],
    *,
    stop: threading.Event,
) -> None:
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.bind((host, port))
    sock.listen(8)
    sock.settimeout(0.5)
    try:
        while not stop.is_set():
            try:
                conn, _addr = sock.accept()
            except socket.timeout:
                continue
            threading.Thread(
                target=_handle,
                args=(conn, on_payload, stop),
                daemon=True,
            ).start()
    finally:
        sock.close()


def _handle(conn: socket.socket, on_payload: Callable[[dict], Optional[dict]], stop: threading.Event) -> None:
    conn.settimeout(1.0)
    buf = ""
    e6_ball: Optional[dict] = None
    e6_club: Optional[dict] = None
    try:
        while not stop.is_set():
            try:
                data = conn.recv(4096)
            except socket.timeout:
                continue
            if not data:
                break
            buf += data.decode("utf-8", errors="replace")
            objs, buf = _extract_json_objects(buf)
            for obj in objs:
                t = obj.get("Type")
                if t == "SetBallData" and isinstance(obj.get("BallData"), dict):
                    e6_ball = obj["BallData"]
                    ack = {"Type": "ACK", "SubType": "SetBallData", "Details": "Success."}
                    conn.sendall((json.dumps(ack) + "\n").encode("utf-8"))
                    continue
                if t == "SetClubData" and isinstance(obj.get("ClubData"), dict):
                    e6_club = obj["ClubData"]
                    ack = {"Type": "ACK", "SubType": "SetClubData", "Details": "Success."}
                    conn.sendall((json.dumps(ack) + "\n").encode("utf-8"))
                    continue
                if t in ("SendShot", "ShotComplete") and e6_ball is not None:
                    payload = {"Type": "SendShot", "BallData": e6_ball, "ClubData": e6_club}
                    result = on_payload(payload)
                    e6_ball, e6_club = None, None
                    conn.sendall(
                        (json.dumps({"Code": 200, "Message": "Shot received"}) + "\n").encode("utf-8")
                    )
                    continue
                result = on_payload(obj)
                if result is not None:
                    conn.sendall(
                        (json.dumps({"Code": 200, "Message": "Shot received"}) + "\n").encode("utf-8")
                    )
                elif obj.get("ShotDataOptions", {}).get("IsHeartBeat"):
                    conn.sendall(
                        (json.dumps({"Code": 200, "Message": "Heartbeat"}) + "\n").encode("utf-8")
                    )
    except OSError:
        pass
    finally:
        try:
            conn.close()
        except OSError:
            pass
