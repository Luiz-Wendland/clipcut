import os
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from string import Formatter

from localization import resolve_language
from translations_pt_br import PT_BR


ROOT = Path(__file__).resolve().parents[1]


class LocalizationTests(unittest.TestCase):
    def test_resolve_language(self):
        self.assertEqual(resolve_language("system", ["pt-BR", "en"]), "pt-BR")
        self.assertEqual(resolve_language("system", ["en-GB", "pt-BR"]), "en")
        self.assertEqual(resolve_language("system", ["pt_PT"]), "pt-BR")
        self.assertEqual(resolve_language("system", ["fr-FR"]), "en")
        self.assertEqual(resolve_language("en", ["pt-BR"]), "en")
        self.assertEqual(resolve_language("pt-BR", ["en-US"]), "pt-BR")

    def test_catalog_covers_qml_and_preserves_placeholders(self):
        for path in [ROOT / "Main.qml", *(ROOT / "components").glob("*.qml")]:
            for source in re.findall(r'qsTr\("([^"]+)"\)', path.read_text(encoding="utf-8")):
                if source != "CODEC":
                    self.assertIn(source, PT_BR, str(path))
        for source, translation in PT_BR.items():
            fields = lambda s: sorted(key for _, key, _, _ in Formatter().parse(s) if key is not None)
            self.assertEqual(fields(source), fields(translation), source)
            self.assertEqual(sorted(re.findall(r"%\d+", source)),
                             sorted(re.findall(r"%\d+", translation)), source)

    def test_qml_switches_live_and_persists_language(self):
        probe = r'''
import sys
from pathlib import Path

from PySide6.QtCore import QObject, QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from shiboken6 import delete

from main import ClipBackend, EXPORT_CANCELED
from localization import tr

app = QGuiApplication([])

def load():
    engine = QQmlApplicationEngine()
    backend = ClipBackend()
    backend.attach_translations(engine)
    engine.rootContext().setContextProperty("backend", backend)
    engine.load(QUrl.fromLocalFile(str(Path("Main.qml").resolve())))
    assert engine.rootObjects()
    return engine, backend

def strings(root):
    return {item.property("text") for item in root.findChildren(QObject)
            if isinstance(item.property("text"), str)}

engine, backend = load()
root = engine.rootObjects()[0]
root.setProperty("showSettings", True)
selector = root.findChild(QObject, "languageSelector")
assert backend.languageMode == "system"
assert selector.property("currentText") == "System default"
assert "Open video" in strings(root)
root.setProperty("activeTool", "Crop")
root.setProperty("selectedRatio", "Custom")

selector.setProperty("currentIndex", 2)
selector.activated.emit(2)
app.processEvents()
assert backend.languageMode == "pt-BR"
assert selector.property("currentText") == "Português (Brasil)"
assert {"Abrir vídeo", "Preferências", "Exportar clipe"} <= strings(root)
assert root.property("activeTool") == "Crop"
assert root.property("selectedRatio") == "Custom"
assert backend.status == "Abra um vídeo ou solte-o aqui"
assert "Codificadores disponíveis:" in backend.diagnosticReport()
assert tr("External error from FFmpeg") == "External error from FFmpeg"
backend._set_status("Exporting {name} with {encoder}…", name="clip.mp4", encoder="libx264")
assert backend.status == "Exportando clip.mp4 com libx264…"
backend._active_queue_job = {}
backend._active_queue_job["status"] = "exporting"
backend._export_done(False, EXPORT_CANCELED)
assert backend._active_queue_job["status"] == "cancelled"
assert backend.status == "Exportação cancelada"
# Destroy the QML bindings while their context property is still alive.
delete(engine)
backend.shutdown()
del root, selector, engine, backend

engine, backend = load()
root = engine.rootObjects()[0]
selector = root.findChild(QObject, "languageSelector")
assert backend.languageMode == "pt-BR"
assert "Abrir vídeo" in strings(root)
selector.setProperty("currentIndex", 1)
selector.activated.emit(1)
app.processEvents()
assert backend.languageMode == "en"
assert {"Open video", "Preferences", "Export clip"} <= strings(root)
delete(engine)
backend.shutdown()
'''
        with tempfile.TemporaryDirectory() as directory:
            result = subprocess.run(
                [sys.executable, "-c", probe], cwd=ROOT, capture_output=True, text=True,
                env={**os.environ, "XDG_CONFIG_HOME": directory, "QT_QPA_PLATFORM": "offscreen",
                     "QT_QUICK_BACKEND": "software", "LC_ALL": "C", "LANGUAGE": "en"},
                timeout=45,
            )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn("ReferenceError:", result.stderr)
        self.assertNotIn("TypeError:", result.stderr)
