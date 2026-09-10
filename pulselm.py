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
    return p.parse_args(argv)


def main(argv: list[str] | None = None) -> None:
    args = parse_args(argv)
    from api import HOST, PORT, create_app

    app = create_app(demo=args.demo)
    app.run(
        host=args.host or HOST,
        port=args.port or PORT,
        debug=False,
        threaded=True,
        use_reloader=False,
    )


if __name__ == "__main__":
    main()
