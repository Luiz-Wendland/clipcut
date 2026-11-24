#!/usr/bin/env python3
"""Extract ClipCut's static design values from the QML source of truth."""

from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "DesignTokens.qml"
OUTPUT = Path(__file__).resolve().parents[1] / "src" / "design" / "tokens.json"

text = SOURCE.read_text(encoding="utf-8")
color_properties = {"onAccent": "accentForeground"}
patterns = {
    "colors": {
        key: rf'property color {color_properties.get(key, key)}:[ \t]*"(#[0-9a-fA-F]{{6}})"'
        for key in (
            "canvas", "surface", "surfaceLow", "surfaceHigh", "surfaceHighest",
            "foreground", "muted", "accent", "onAccent", "accentSoft", "outline",
            "danger", "success", "warning", "preview",
        )
    },
    "radii": {
        "small": r'property int radiusSmall:\s*(\d+)',
        "medium": r'property int radiusMedium:\s*(\d+)',
        "large": r'property int radiusLarge:\s*(\d+)',
        "extraLarge": r'property int radiusExtraLarge:\s*(\d+)',
    },
    "spacing": {
        "2": r'property int space2:\s*(\d+)',
        "4": r'property int space4:\s*(\d+)',
        "6": r'property int space6:\s*(\d+)',
        "8": r'property int space8:\s*(\d+)',
        "10": r'property int space10:\s*(\d+)',
        "14": r'property int space14:\s*(\d+)',
        "16": r'property int space16:\s*(\d+)',
    },
    "type": {
        "xs": r'property int textXs:\s*(\d+)',
        "sm": r'property int textSm:\s*(\d+)',
        "md": r'property int textMd:\s*(\d+)',
        "lg": r'property int textLg:\s*(\d+)',
        "xl": r'property int textXl:\s*(\d+)',
    },
    "layout": {
        "outerMargin": r'property int outerMargin:\s*(\d+)',
        "toolbarHeight": r'property int toolbarHeight:\s*(\d+)',
        "inspectorWidth": r'property int inspectorWidth:\s*(\d+)',
        "timelineHeight": r'property int timelineHeight:\s*(\d+)',
    },
}

result: dict[str, dict[str, str | int]] = {section: {} for section in patterns}
for section, values in patterns.items():
    for key, pattern in values.items():
        match = re.search(pattern, text, flags=re.MULTILINE | re.DOTALL)
        if not match:
            raise SystemExit(f"Could not extract {section}.{key} from {SOURCE}")
        value = match.group(1)
        result[section][key] = value if section == "colors" else int(value)

OUTPUT.parent.mkdir(parents=True, exist_ok=True)
OUTPUT.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
print(f"Extracted ClipCut design tokens to {OUTPUT.relative_to(ROOT)}")
