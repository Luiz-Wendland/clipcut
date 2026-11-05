import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(subprocess.run(["sh", "-c", "command -v ffmpeg && command -v ffprobe"],
                                   capture_output=True).returncode == 0,
                     "FFmpeg and ffprobe are required for the QML timeline test")
class TimelineQmlTests(unittest.TestCase):
    def test_generated_images_load_into_visible_timeline_items(self):
        with tempfile.TemporaryDirectory() as directory:
            video = Path(directory) / "timeline-test.mp4"
            subprocess.run([
                "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
                "-f", "lavfi", "-i", "testsrc2=size=320x180:rate=12:duration=2",
                "-f", "lavfi", "-i", "sine=frequency=440:duration=2",
                "-af", "volume='if(lt(mod(t,1),0.5),1,0.05)':eval=frame",
                "-c:v", "mpeg4", "-pix_fmt", "yuv420p", "-c:a", "aac", "-shortest", str(video),
            ], check=True, capture_output=True, timeout=20)

            probe = r'''
import sys, time
from PySide6.QtCore import QObject, QPointF, QUrl
from PySide6.QtGui import QGuiApplication, QImageReader
from PySide6.QtQml import QQmlApplicationEngine, QQmlContext, QQmlExpression
from PySide6.QtQuick import QQuickItem
sys.path.insert(0, sys.argv[1])
from main import ClipBackend
app = QGuiApplication([])
engine = QQmlApplicationEngine()
backend = ClipBackend()
engine.rootContext().setContextProperty("backend", backend)
engine.load(QUrl.fromLocalFile(sys.argv[1] + "/Main.qml"))
if not engine.rootObjects():
    raise SystemExit("Main.qml did not create a window")
root = engine.rootObjects()[0]
last_directory = backend.localPath(backend.lastExportDirectoryUrl.toString())
assert root.property("outputDirectory") == last_directory, "export folder should default to the last used directory"
assert root.property("pendingOutput").startswith(last_directory.rstrip("/") + "/")
backend.loadFile(sys.argv[2])
timeline = root.findChild(QObject, "timelinePanel")
repeater = root.findChild(QObject, "timelineThumbnailRepeater")
waveform = root.findChild(QObject, "timelineWaveformImage")
context = QQmlContext(engine.rootContext())
context.setContextProperty("timelineRoot", root)
deadline = time.monotonic() + 25
while time.monotonic() < deadline:
    app.processEvents()
    if (backend._thumbnail_status == "ready" and backend._waveform_status == "ready" and
            repeater and repeater.property("count") > 0 and waveform and
            waveform.property("loadState") == "ready" and
            timeline.property("firstThumbnailState") == "ready"):
        break
    time.sleep(.01)
app.processEvents()
assert backend._thumbnail_status == "ready", backend.status
assert backend._waveform_status == "ready", backend.status
app.processEvents()
assert timeline.property("firstThumbnailState") == "ready"
assert waveform.property("visible"), "waveform image is not visible"
assert waveform.property("width") > 0 and waveform.property("height") > 0
base_count = timeline.property("visibleThumbnailCount")
timeline.setProperty("viewZoom", 2.0)
app.processEvents()
zoomed_count = timeline.property("visibleThumbnailCount")
assert zoomed_count > base_count, "Zoom should reveal more sampled video frames"
assert timeline.property("maxZoom") == 4.0, "Zoom must not exceed available thumbnail sampling"
timeline.setProperty("viewZoom", timeline.property("maxZoom"))
app.processEvents()
assert timeline.property("visibleThumbnailCount") == 48
zoom_in = root.findChild(QObject, "timelineZoomIn")
assert zoom_in is not None and not zoom_in.property("enabled"), "Zoom-in button should disable at 4×"
timeline.setProperty("viewZoom", 1.0)
app.processEvents()
layer = root.findChild(QObject, "timelineVisualLayer")
context.setContextProperty("targetItem", layer)
capture_path = sys.argv[2] + ".timeline.png"
expression = QQmlExpression(context, layer,
    "targetItem.grabToImage(function(result) { result.saveToFile('" + capture_path + "') }, "
    "Qt.size(targetItem.width, targetItem.height))")
expression.evaluate()
capture_deadline = time.monotonic() + 8
while time.monotonic() < capture_deadline:
    app.processEvents()
    if __import__("os").path.isfile(capture_path):
        break
    time.sleep(.01)
rendered = QImageReader(capture_path).read()
assert not rendered.isNull(), "timeline render capture is missing"
sampled_colors = set()
for y in range(20, min(54, rendered.height()), 2):
    for x in range(0, rendered.width(), 4):
        sampled_colors.add(rendered.pixelColor(x, y).rgba())
assert len(sampled_colors) > 20, "Rendered thumbnail lane is visually empty"
waveform_colors = set()
for y in range(max(0, rendered.height() - 34), rendered.height() - 2, 2):
    for x in range(0, rendered.width(), 4):
        waveform_colors.add(rendered.pixelColor(x, y).rgba())
assert len(waveform_colors) > 3, "Rendered waveform lane is visually empty or flat"
surface = root.findChild(QQuickItem, "appSurface")
track_background = root.findChild(QQuickItem, "timelineTrackBackground")
assert surface is not None and track_background is not None
surface_capture_path = sys.argv[2] + ".surface.png"
context.setContextProperty("targetItem", surface)
surface_expression = QQmlExpression(context, surface,
    "targetItem.grabToImage(function(result) { result.saveToFile('" + surface_capture_path + "') }, "
    "Qt.size(targetItem.width, targetItem.height))")
surface_expression.evaluate()
surface_deadline = time.monotonic() + 8
while time.monotonic() < surface_deadline:
    app.processEvents()
    if __import__("os").path.isfile(surface_capture_path):
        break
    time.sleep(.01)
surface_image = QImageReader(surface_capture_path).read()
assert not surface_image.isNull(), "composited app surface capture is missing"
track_origin = track_background.mapToItem(surface, QPointF(0, 0))
corners = [
    (int(track_origin.x()) + 3, int(track_origin.y()) + 3),
    (int(track_origin.x() + track_background.width()) - 4, int(track_origin.y()) + 3),
    (int(track_origin.x()) + 3, int(track_origin.y() + track_background.height()) - 4),
    (int(track_origin.x() + track_background.width()) - 4,
     int(track_origin.y() + track_background.height()) - 4),
]
background = track_background.property("color")
for x, y in corners:
    corner = surface_image.pixelColor(x, y)
    assert sum(abs(a - b) for a, b in zip((corner.red(), corner.green(), corner.blue()),
                                          (background.red(), background.green(), background.blue()))) < 24, \
           "Rounded timeline corner leaked content: corner=" + str(corner.getRgb()) + \
           " background=" + str(background.getRgb()) + " position=" + str((x, y))
task_deadline = time.monotonic() + 15
while backend._tasks and time.monotonic() < task_deadline:
    app.processEvents()
    time.sleep(.01)
assert not backend._tasks, "A background preview/media task did not finish"
print("QML timeline images loaded and have visible geometry")
backend.shutdown()
app.quit()
'''
            environment = os.environ.copy()
            environment["QT_QPA_PLATFORM"] = "offscreen"
            environment["QT_QUICK_BACKEND"] = "software"
            result = subprocess.run(
                [sys.executable, "-c", probe, str(ROOT), str(video)],
                cwd=ROOT, env=environment, capture_output=True, text=True, timeout=45,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("QML timeline images loaded", result.stdout)

    def test_timeline_visuals_avoid_gpu_effect_masking(self):
        source = (ROOT / "components" / "ClipTimeline.qml").read_text(encoding="utf-8")
        visuals = source.split('objectName: "timelineVisualLayer"', 1)[1].split("\n            }", 1)[0]
        self.assertIn("clip: true", visuals)
        self.assertIn("import QtQuick.Shapes", source)
        self.assertIn("PathCubic", source)
        self.assertNotIn("MultiEffect", source)
        self.assertIn("Image.PreserveAspectFit", source)


if __name__ == "__main__":
    unittest.main()
