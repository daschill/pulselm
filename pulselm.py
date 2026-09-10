#!/usr/bin/env python3
"""PulseLM entry point.

  python pulselm.py --demo     # fixtures, no GPIO (Windows / CI)
  python pulselm.py            # Pi 3 live OV9281 + GPIO14/15 strobe
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    p = argparse.ArgumentParser(description="PulseLM indoor dual-strobe launch monitor")
    p.add_argument(
        "--demo",
        action="store_true",
        help="Serve fixtures/sample_result.json; do not import or use GPIO",
    )
    p.add_argument("--host", default=None, help="Bind host (default 0.0.0.0)")
    p.add_argument("--port", type=int, default=None, help="Bind port (default 8080)")
    p.add_argument(
        "--r10",
        action="store_true",
        help="Accept Garmin Approach R10 shots (OpenConnect TCP :921 + POST /api/v1/r10)",
    )
    p.add_argument("--r10-port", type=int, default=921, help="OpenConnect listen port (default 921)")
    return p.parse_args(argv)


def serve(app, host: str, port: int) -> None:
    """Bind Flask. Default product bind is 0.0.0.0:8080 (Pi 3 / iPhone display)."""
    try:
        app.run(
            host=host,
            port=port,
            debug=False,
            threaded=True,
            use_reloader=False,
        )
    except OSError as exc:
        print(
            f"PulseLM could not bind {host}:{port}: {exc}",
            file=sys.stderr,
        )
        print(
            "Default is 0.0.0.0:8080 for the Pi. If this workstation already "
            "holds 8080 (Windows IP Helper portproxy is a common case), retry "
            "with: python pulselm.py --demo --host 0.0.0.0 --port 18080",
            file=sys.stderr,
        )
        raise SystemExit(1) from exc


def main(argv: list[str] | None = None) -> None:
    args = parse_args(argv)
    from api import HOST, PORT, create_app

    app = create_app(demo=args.demo, r10=args.r10, r10_port=args.r10_port)
    if args.r10:
        import threading

        import r10
        from r10_server import serve_r10

        stop = threading.Event()
        shots = app.config["PULSELM_SHOTS"]

        def on_payload(obj):
            return r10.ingest_shot(obj, shots)

        threading.Thread(
            target=serve_r10,
            kwargs={
                "host": args.host or HOST,
                "port": args.r10_port,
                "on_payload": on_payload,
                "stop": stop,
            },
            daemon=True,
        ).start()
        print(
            f"R10 OpenConnect listening on {(args.host or HOST)}:{args.r10_port}",
            file=sys.stderr,
        )
    serve(app, args.host or HOST, args.port or PORT)


if __name__ == "__main__":
    main()
