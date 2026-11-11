import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def ffmpeg_available():
    return subprocess.run(["sh", "-c", "command -v ffmpeg && command -v ffprobe"],
                           capture_output=True).returncode == 0


@unittest.skipUnless(ffmpeg_available(),
                     "FFmpeg and ffprobe are required for the QML crop test")
class CropQmlTests(unittest.TestCase):
    """The framing shown on screen must match what the export writes."""

    def test_crop_overlay_and_reported_size_match_the_export(self):
        with tempfile.TemporaryDirectory() as directory:
            video = Path(directory) / "crop-test.mp4"
            subprocess.run([
                "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
                "-f", "lavfi", "-i", "testsrc2=size=640x360:rate=12:duration=2",
                "-c:v", "mpeg4", "-pix_fmt", "yuv420p", str(video),
            ], check=True, capture_output=True, timeout=20)

            probe = r'''
import sys, time
from PySide6.QtCore import QObject
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickItem
sys.path.insert(0, sys.argv[1])
from main import ClipBackend
app = QGuiApplication([])
engine = QQmlApplicationEngine()
backend = ClipBackend()
engine.rootContext().setContextProperty("backend", backend)
engine.load(__import__("PySide6.QtCore", fromlist=["QUrl"]).QUrl.fromLocalFile(sys.argv[1] + "/Main.qml"))
if not engine.rootObjects():
    raise SystemExit("Main.qml did not create a window")
root = engine.rootObjects()[0]
backend.loadFile(sys.argv[2])
deadline = time.monotonic() + 20
while time.monotonic() < deadline and not backend.hasVideo:
    app.processEvents()
    time.sleep(.01)
assert backend.hasVideo, backend.status
root.setProperty("activeTool", "Enquadrar")
root.setProperty("showExport", True)
app.processEvents()

frame = root.findChild(QQuickItem, "cropFrame")
assert frame is not None, "crop frame item is missing"
video_output = root.findChild(QQuickItem, "clipcutVideoOutput")
player = root.findChild(QObject, "clipcutMediaPlayer")
assert video_output is not None and player is not None
player.play()

def rendered():
    rect = video_output.property("sourceRect")
    return rect.width() > 0 and rect.height() > 0

def texts(item):
    found = []
    def walk(node):
        for child in node.childItems():
            value = child.property("text")
            if isinstance(value, str) and value.strip():
                found.append(value)
            walk(child)
    if item:
        walk(item)
    return found

inspector = root.findChild(QQuickItem, "inspectorPanel")
popover = root.findChild(QQuickItem, "exportPopover")
assert inspector is not None and popover is not None

for ratio, target in (("21:9", 21 / 9), ("9:16", 9 / 16), ("1:1", 1.0), ("4:3", 4 / 3)):
    backend.setCropRatio(ratio, "3:2")
    backend.centerCrop()
    app.processEvents()
    deadline = time.monotonic() + 20
    while time.monotonic() < deadline and not rendered():
        app.processEvents()
        time.sleep(.01)
    assert rendered(), "the video frame was never rendered"
    app.processEvents()
    screen_aspect = frame.width() / frame.height()
    assert abs(screen_aspect / target - 1) < 0.02, \
        "on screen frame %s does not match %s" % (screen_aspect, target)

    size = backend.cropSize
    assert size["width"] % 2 == 0 and size["height"] % 2 == 0
    # The test source is small, so a single even pixel is worth ~0.3% of aspect.
    assert abs((size["width"] / size["height"]) / target - 1) < 0.005, \
        "exported size %s does not match %s" % (size, target)

    # The reported resolution must be the one the export writes.
    command, _ = backend._command(sys.argv[2] + ".mp4", "h264", ratio, "3:2",
                                  "Alta qualidade", False)
    filter_value = command[command.index("-vf") + 1]
    width, height = (int(v) for v in filter_value[len("crop="):].split(":")[:2])
    assert (size["width"], size["height"]) == (width, height), \
        "reported size %s differs from the export filter %s" % (size, filter_value)

    reported = [t for t in texts(popover) if t.endswith("px")]
    assert reported, "the export panel does not report a resolution"
    assert "%d × %d px" % (width, height) in reported, \
        "export panel reports %s, expected %d x %d" % (reported, width, height)

    summary = [t for t in texts(inspector) if "→" in t]
    assert summary, "the framing panel does not report the resulting size"
    assert "%d × %d" % (width, height) in summary[0], summary[0]

# Stream copy keeps the source untouched.
root.setProperty("selectedCodec", "copy")
app.processEvents()
reported = [t for t in texts(popover) if t.endswith("px")]
assert "%d × %d px" % (backend.videoWidth, backend.videoHeight) in reported, \
    "stream copy must report the source resolution, got %s" % reported
print("QML crop overlay matches the exported framing")
backend.shutdown()
app.quit()
'''
            environment = os.environ.copy()
            environment["QT_QPA_PLATFORM"] = "offscreen"
            environment["QT_QUICK_BACKEND"] = "software"
            result = subprocess.run(
                [sys.executable, "-c", probe, str(ROOT), str(video)],
                cwd=ROOT, env=environment, capture_output=True, text=True, timeout=60,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("QML crop overlay matches", result.stdout)

    def test_ratio_grammar_matches_the_backend_parser(self):
        main_source = (ROOT / "Main.qml").read_text(encoding="utf-8")
        inspector_source = (ROOT / "components" / "ToolInspector.qml").read_text(encoding="utf-8")
        popover_source = (ROOT / "components" / "ExportPopover.qml").read_text(encoding="utf-8")

        # One grammar, declared once: the panels must not re-derive it.
        self.assertIn('readonly property bool customRatioValid: '
                      '/^[1-9][0-9]{0,3}:[1-9][0-9]{0,3}$/.test(customRatioValue)', main_source)
        self.assertNotIn("[1-9][0-9]*:[1-9][0-9]*", inspector_source)
        self.assertNotIn("[1-9][0-9]*:[1-9][0-9]*", popover_source)
        self.assertIn("customRatioValid: root.customRatioValid", main_source)
        # The panels report the same flag the root computed.
        self.assertIn("invalid: !root.customRatioValid", inspector_source)
        self.assertIn("invalid: !root.customRatioValid", popover_source)


if __name__ == "__main__":
    unittest.main()
