#!/usr/bin/env python3
"""Ensure the Qt Multimedia QML backend is included in a generated deploy spec."""

import configparser
import sys
from pathlib import Path


spec = Path(sys.argv[1] if len(sys.argv) > 1 else "pysidedeploy.spec")
config = configparser.ConfigParser(interpolation=None)
if not config.read(spec, encoding="utf-8"):
    raise SystemExit(f"Cannot read deploy configuration: {spec}")

plugins = [item.strip() for item in config.get("qt", "plugins", fallback="").split(",") if item.strip()]
if "multimedia" not in plugins:
    plugins.append("multimedia")
config.set("qt", "plugins", ",".join(plugins))
config.set("app", "exec_directory", "deployment")

# Nuitka's Windows standalone scan requires this utility. In CI, explicitly
# allow its verified, cached download instead of failing on an interactive prompt.
extra_args = config.get("nuitka", "extra_args", fallback="").split()
if sys.platform == "win32" and "--assume-yes-for-downloads" not in extra_args:
    extra_args.append("--assume-yes-for-downloads")
    config.set("nuitka", "extra_args", " ".join(extra_args))

with spec.open("w", encoding="utf-8") as stream:
    config.write(stream)
