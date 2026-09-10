"""CLI bind defaults. --demo never needs GPIO; 8080 is the Pi product port."""

from __future__ import annotations

import importlib.util
from pathlib import Path
from unittest.mock import MagicMock

import pytest

# Repo root is also a package (`__init__.py`), so `import pulselm` is not pulselm.py.
_CLI_PATH = Path(__file__).resolve().parents[1] / "pulselm.py"
_spec = importlib.util.spec_from_file_location("pulselm_cli", _CLI_PATH)
assert _spec is not None and _spec.loader is not None
cli = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(cli)


def test_parse_args_demo_and_port_override():
    args = cli.parse_args(["--demo", "--host", "0.0.0.0", "--port", "18080", "--r10"])
    assert args.demo is True
    assert args.host == "0.0.0.0"
    assert args.port == 18080
    assert args.r10 is True
    assert args.r10_port == 921
    default = cli.parse_args([])
    assert default.demo is False
    assert default.host is None
    assert default.port is None
    assert default.r10 is False


def test_serve_bind_error_mentions_8080_and_18080(capsys):
    app = MagicMock()
    app.run.side_effect = OSError("Address already in use")
    with pytest.raises(SystemExit) as ei:
        cli.serve(app, "0.0.0.0", 8080)
    assert ei.value.code == 1
    err = capsys.readouterr().err
    assert "0.0.0.0:8080" in err
    assert "18080" in err
    assert "portproxy" in err.lower() or "IP Helper" in err
