#!/usr/bin/env python3
"""QML front-end and FFmpeg backend for ClipCut."""

from __future__ import annotations

import json
import math
import os
import platform
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import time
import uuid
import configparser
from pathlib import Path

from PySide6.QtCore import QObject, Property, QSettings, QThread, QTimer, QUrl, Signal, Slot
from PySide6.QtGui import QColor, QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine


QUALITY = {
    "Alta qualidade": {"h264": 18, "hevc": 20, "av1": 30, "nvenc": 19},
    "Máxima qualidade": {"h264": 15, "hevc": 17, "av1": 25, "nvenc": 16},
    "Compacto": {"h264": 23, "hevc": 26, "av1": 36, "nvenc": 25},
}


def capture(args: list[str], timeout=30):
    return subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                          text=True, timeout=timeout, check=False)


def ratio_value(text: str, width: int, height: int):
    if text == "Original":
        return width / max(1, height)
    if text == "Livre":
        return None
    try:
        w, h = (int(v) for v in text.split(":", 1))
        return w / h if w > 0 and h > 0 else None
    except (ValueError, TypeError):
        return None


class Task(QObject):
    done = Signal(object, str, int)

    def __init__(self, fn, generation, kind="analysis"):
        super().__init__()
        self.fn = fn
        self.generation = generation
        self.kind = kind
        self.cancelled = threading.Event()
        self.process = None

    def run_process(self, args, timeout=30, text=False):
        self.process = subprocess.Popen(args, stdout=subprocess.PIPE,
                                        stderr=subprocess.PIPE, text=text)
        deadline = time.monotonic() + timeout if timeout is not None else None
        try:
            while True:
                if self.cancelled.is_set():
                    if self.process.poll() is None:
                        try:
                            self.process.terminate()
                        except ProcessLookupError:
                            pass
                    try:
                        stdout, stderr = self.process.communicate(timeout=2)
                    except subprocess.TimeoutExpired:
                        try:
                            self.process.kill()
                        except ProcessLookupError:
                            pass
                        stdout, stderr = self.process.communicate()
                    raise RuntimeError("Operação cancelada")
                if deadline is not None and time.monotonic() >= deadline:
                    try:
                        self.process.kill()
                    except ProcessLookupError:
                        pass
                    stdout, stderr = self.process.communicate()
                    raise subprocess.TimeoutExpired(args, timeout, output=stdout, stderr=stderr)
                try:
                    stdout, stderr = self.process.communicate(timeout=0.1)
                    return subprocess.CompletedProcess(args, self.process.returncode, stdout, stderr)
                except subprocess.TimeoutExpired:
                    continue
        finally:
            self.process = None

    @Slot()
    def run(self):
        try:
            self.done.emit(self.fn(self), "", self.generation)
        except Exception as e:
            self.done.emit(None, str(e), self.generation)
        finally:
            QThread.currentThread().quit()

    def cancel(self):
        self.cancelled.set()
        if self.process and self.process.poll() is None:
            try:
                self.process.terminate()
            except ProcessLookupError:
                pass


class ExportTask(QObject):
    progress = Signal(int)
    done = Signal(bool, str)

    def __init__(self, command: list[str], duration: float, temp_path: str,
                 output_path: str):
        super().__init__()
        self.command = command
        self.duration = max(duration, 0.001)
        self.process = None
        self.cancelled = threading.Event()
        self.temp_path = temp_path
        self.output_path = output_path

    @Slot()
    def run(self):
        try:
            def execute(command):
                args = command[:-1] + ["-progress", "pipe:1", "-nostats", command[-1]]
                # Keep stderr off a pipe while stdout is consumed for progress.
                # If stderr's pipe fills, FFmpeg blocks before closing stdout and
                # the export loop deadlocks waiting for its next progress line.
                with tempfile.TemporaryFile(mode="w+t", encoding="utf-8") as error_log:
                    self.process = subprocess.Popen(args, stdout=subprocess.PIPE,
                                                    stderr=error_log, text=True, bufsize=1)
                    with self.process.stdout:
                        for line in self.process.stdout:
                            if self.cancelled.is_set():
                                try:
                                    self.process.terminate()
                                except ProcessLookupError:
                                    pass
                                break
                            if line.startswith("out_time_us="):
                                try:
                                    t = int(line.split("=", 1)[1]) / 1_000_000
                                    self.progress.emit(min(99, max(0, round(t / self.duration * 100))))
                                except ValueError:
                                    pass
                        code = self.process.wait()
                    error_log.flush()
                    error_log.seek(0, os.SEEK_END)
                    error_size = error_log.tell()
                    error_log.seek(max(0, error_size - 2500))
                    error = error_log.read()
                    self.process = None
                    return code, error

            code, error = execute(self.command)
            if self.cancelled.is_set():
                self.done.emit(False, "Exportação cancelada")
            elif code:
                self.done.emit(False, error.strip()[-2500:] or f"FFmpeg terminou com código {code}")
            else:
                check = capture(["ffprobe", "-v", "error", "-count_packets",
                                 "-show_entries", "stream=codec_type,nb_read_packets",
                                 "-of", "json", self.temp_path], timeout=30)
                try:
                    streams = json.loads(check.stdout).get("streams", [])
                    has_video = any(s.get("codec_type") == "video" and
                                    int(s.get("nb_read_packets", 0)) > 0 for s in streams)
                except (ValueError, TypeError):
                    has_video = False
                if check.returncode or not has_video:
                    raise RuntimeError(check.stderr.strip() or "O arquivo exportado não contém vídeo válido")
                os.replace(self.temp_path, self.output_path)
                self.progress.emit(100)
                self.done.emit(True, "Exportação concluída")
        except Exception as e:
            self.done.emit(False, str(e))
        finally:
            if os.path.exists(self.temp_path):
                try:
                    os.unlink(self.temp_path)
                except OSError:
                    pass
            QThread.currentThread().quit()

    def cancel(self):
        self.cancelled.set()
        process = self.process
        if process and process.poll() is None:
            try:
                process.terminate()
            except ProcessLookupError:
                return

            def kill_if_still_running():
                try:
                    process.wait(timeout=2)
                except subprocess.TimeoutExpired:
                    try:
                        process.kill()
                    except ProcessLookupError:
                        pass

            threading.Thread(target=kill_if_still_running, daemon=True).start()


class ClipBackend(QObject):
    fileChanged = Signal()
    mediaChanged = Signal()
    rangeChanged = Signal()
    positionChanged = Signal()
    previewChanged = Signal()
    busyChanged = Signal()
    exportingChanged = Signal()
    statusChanged = Signal()
    progressChanged = Signal()
    gpuChanged = Signal()
    gpuPreferenceChanged = Signal()
    paletteChanged = Signal()
    exportDirectoryChanged = Signal()
    waveformChanged = Signal()
    exportQueueChanged = Signal()
    exportDone = Signal(bool, str)

    def __init__(self):
        super().__init__()
        self._path = ""
        self._duration = 0.0
        self._width = self._height = 0
        self._codec = ""
        self._fps = 0.0
        self._sample_aspect = 1.0
        self._audio = False
        self._start = 0.0
        self._end = 0.0
        self._position = 0.0
        self._preview = ""
        self._thumbnail_status = "empty"
        self._thumbnails = []
        self._waveform = ""
        self._waveform_status = "empty"
        self._busy = False
        self._exporting = False
        self._status = "Abra um vídeo ou arraste-o para esta janela"
        self._progress = 0
        self._gpu_devices = self._detect_gpu_devices()
        self._palette = self._read_palette()
        self._settings = QSettings(QSettings.IniFormat, QSettings.UserScope, "ClipCut", "ClipCut")
        saved_directory = self._settings.value("export/lastDirectory", "", type=str)
        self._last_export_directory = saved_directory if saved_directory and os.path.isdir(saved_directory) else str(Path.home())
        self._prefer_gpu = self._settings.value("encoding/preferGpu", True, type=bool)
        self._tmp = tempfile.TemporaryDirectory(prefix="clipcut-")
        self._generation = 0
        self._preview_id = 0
        self._tasks: dict[QThread, Task] = {}
        self._export_thread = None
        self._export_task = None
        self._export_queue = []
        self._queue_running = False
        self._active_queue_job = None
        self._next_queue_id = 1
        self._shutting_down = False
        self._crop_ratio = "Original"
        self._crop_custom = ""
        self._crop_x = self._crop_y = 0.5
        self._encoders = self._detect_encoders()
        self._gpu_name = self._preferred_gpu_name()

    @staticmethod
    def _detect_gpu_devices(drm_root="/sys/class/drm", dev_root="/dev/dri"):
        """Find display adapters and Linux render nodes without assuming NVIDIA."""
        devices = []
        drm_root = Path(drm_root)
        dev_root = Path(dev_root)
        vendor_ids = {"0x10de": "nvidia", "0x1002": "amd", "0x8086": "intel"}
        nvidia_names = []
        if shutil.which("nvidia-smi"):
            try:
                result = capture(["nvidia-smi", "--query-gpu=name", "--format=csv,noheader"], 5)
                if result.returncode == 0:
                    nvidia_names = [line.strip() for line in result.stdout.splitlines() if line.strip()]
            except (OSError, subprocess.SubprocessError):
                pass

        if sys.platform.startswith("linux"):
            render_nodes = list(drm_root.glob("renderD*/device"))
            nvidia_index = 0
            seen = set()
            for device_link in sorted(drm_root.glob("card[0-9]*/device")):
                card_name = device_link.parent.name
                if not re.fullmatch(r"card\d+", card_name):
                    continue
                try:
                    real_device = device_link.resolve()
                    identity = str(real_device)
                    if identity in seen:
                        continue
                    vendor_id = (device_link / "vendor").read_text(encoding="ascii").strip().lower()
                    vendor = vendor_ids.get(vendor_id)
                    if not vendor:
                        continue
                    seen.add(identity)
                except (OSError, RuntimeError):
                    continue

                render_node = ""
                for render_link in render_nodes:
                    try:
                        if render_link.resolve() == real_device:
                            render_node = str(dev_root / render_link.parent.name)
                            break
                    except (OSError, RuntimeError):
                        continue

                name = {"nvidia": "NVIDIA GPU", "amd": "AMD GPU", "intel": "Intel GPU"}[vendor]
                address = real_device.name
                if shutil.which("lspci") and re.fullmatch(r"[0-9a-fA-F:.]+", address):
                    try:
                        result = capture(["lspci", "-s", address], 3)
                        description = result.stdout.strip().split(": ", 1)
                        if result.returncode == 0 and len(description) == 2:
                            name = description[1]
                    except (OSError, subprocess.SubprocessError):
                        pass
                if vendor == "nvidia" and nvidia_index < len(nvidia_names):
                    name = nvidia_names[nvidia_index]
                    nvidia_index += 1
                devices.append({"vendor": vendor, "name": name, "renderNode": render_node})

        if not devices and sys.platform == "win32":
            powershell = shutil.which("powershell.exe") or shutil.which("powershell")
            if powershell:
                try:
                    result = capture([powershell, "-NoProfile", "-Command",
                                      "Get-CimInstance Win32_VideoController | ForEach-Object {$_.Name}"], 8)
                    if result.returncode == 0:
                        for name in result.stdout.splitlines():
                            lower = name.lower()
                            vendor = ("nvidia" if "nvidia" in lower or "geforce" in lower else
                                      "amd" if "amd" in lower or "radeon" in lower else
                                      "intel" if "intel" in lower or "arc" in lower else "other")
                            devices.append({"vendor": vendor, "name": name.strip(), "renderNode": ""})
                except (OSError, subprocess.SubprocessError):
                    pass

        # nvidia-smi also works in containers where DRM sysfs is not mounted.
        for name in nvidia_names:
            if not any(device["vendor"] == "nvidia" and device["name"] == name for device in devices):
                devices.append({"vendor": "nvidia", "name": name, "renderNode": ""})
        return devices

    @staticmethod
    def _supports_hardware_av1(device):
        name = device.get("name", "").lower()
        vendor = device.get("vendor")
        if vendor == "nvidia":
            return bool(re.search(r"rtx\s*(?:40|50|60)|\b(?:l4|l40|b100|b200)\b", name))
        if vendor == "amd":
            return bool(re.search(r"\b(?:rx\s*7\d{2,3}|rx\s*9\d{2,3}|w7\d{2,3})\b", name))
        if vendor == "intel":
            return bool(re.search(r"\barc\b|meteor|lunar|arrow|battlemage|core ultra", name))
        return False

    def _hardware_encoder_for(self, codec, device=None):
        devices = [device] if device else self._gpu_devices
        api_order = {
            "nvidia": ("nvenc",),
            "amd": ("vaapi", "amf") if sys.platform.startswith("linux") else ("amf", "vaapi"),
            "intel": ("qsv", "vaapi"),
            "other": ("nvenc", "amf", "qsv", "vaapi"),
        }
        for candidate in devices:
            if codec == "av1" and not self._supports_hardware_av1(candidate):
                continue
            for api in api_order.get(candidate.get("vendor"), api_order["other"]):
                encoder = f"{codec}_{api}"
                if encoder not in self._encoders:
                    continue
                render_node = candidate.get("renderNode", "")
                if api in ("vaapi", "qsv") and sys.platform.startswith("linux"):
                    if not render_node or not os.access(render_node, os.R_OK | os.W_OK):
                        continue
                return {"encoder": encoder, "api": api, "device": candidate}
        return None

    def _preferred_gpu_name(self):
        for device in self._gpu_devices:
            if any(self._hardware_encoder_for(codec, device) for codec in ("h264", "hevc")):
                return device["name"]
        return self._gpu_devices[0]["name"] if self._gpu_devices else ""

    @staticmethod
    def _gpu_api_label(api):
        return {"nvenc": "NVENC", "amf": "AMD AMF", "qsv": "Intel Quick Sync", "vaapi": "VA-API"}.get(api, "GPU")

    @staticmethod
    def _detect_encoders():
        if not shutil.which("ffmpeg"):
            return set()
        try:
            p = capture(["ffmpeg", "-hide_banner", "-encoders"], 10)
            return {fields[1] for line in p.stdout.splitlines()
                    if len(fields := line.split()) >= 3 and fields[0].startswith("V") and fields[1] != "="}
        except (OSError, subprocess.SubprocessError):
            return set()

    @staticmethod
    def _read_palette():
        fallback = {"bg": "#141212", "fg": "#f4f1ee", "fgdim": "#a8a4a0",
                    "accent": "#e9e5e1", "onaccent": "#141212",
                    "viewbg": "#101116", "windowalt": "#1d1e25",
                    "buttonbg": "#24262e", "buttonalt": "#2d3039",
                    "accentHover": "#d8d2e6", "decoration": "#d8d2e6",
                    "focus": "#d8d2e6", "positive": "#b9d6c3",
                    "negative": "#ffb4ab", "neutral": "#e4c48e",
                    "tooltipbg": "#24262e", "tooltipfg": "#f4f1ee"}
        config = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "kdeglobals"
        parser = configparser.ConfigParser(interpolation=None, strict=False)
        parser.optionxform = str
        try:
            parser.read(config, encoding="utf-8")
            sections = {
                "bg": ("Colors:Window", "BackgroundNormal"),
                "fg": ("Colors:View", "ForegroundNormal"),
                "fgdim": ("Colors:View", "ForegroundInactive"),
                "accent": ("Colors:Selection", "BackgroundNormal"),
                "onaccent": ("Colors:Selection", "ForegroundNormal"),
                "viewbg": ("Colors:View", "BackgroundNormal"),
                "windowalt": ("Colors:Window", "BackgroundAlternate"),
                "buttonbg": ("Colors:Button", "BackgroundNormal"),
                "buttonalt": ("Colors:Button", "BackgroundAlternate"),
                "accentHover": ("Colors:Selection", "DecorationHover"),
                "decoration": ("Colors:Button", "DecorationHover"),
                "focus": ("Colors:Window", "DecorationFocus"),
                "positive": ("Colors:View", "ForegroundPositive"),
                "negative": ("Colors:View", "ForegroundNegative"),
                "neutral": ("Colors:View", "ForegroundNeutral"),
                "tooltipbg": ("Colors:Tooltip", "BackgroundNormal"),
                "tooltipfg": ("Colors:Tooltip", "ForegroundNormal"),
            }
            for key, (section, name) in sections.items():
                value = parser.get(section, name, fallback="").strip()
                color = QColor(value)
                if color.isValid():
                    fallback[key] = color.name()
            return fallback
        except (OSError, configparser.Error):
            return fallback

    def _property(name, signal):
        return Property(str, lambda self: getattr(self, name), notify=signal)

    @Property(str, notify=fileChanged)
    def fileName(self):
        return Path(self._path).name if self._path else ""

    @Property(str, notify=fileChanged)
    def filePath(self):
        return self._path

    @Property(QUrl, notify=fileChanged)
    def mediaUrl(self):
        return QUrl.fromLocalFile(self._path) if self._path else QUrl()

    @Slot(str, result=bool)
    def outputExists(self, path: str):
        return os.path.exists(os.path.abspath(path))

    @Slot(str, result=bool)
    def outputIsSource(self, path: str):
        if not self._path or not path:
            return False
        return os.path.realpath(os.path.abspath(path)) == os.path.realpath(self._path)

    @Property(float, notify=mediaChanged)
    def duration(self):
        return self._duration

    @Property(int, notify=mediaChanged)
    def videoWidth(self):
        return self._width

    @Property(int, notify=mediaChanged)
    def videoHeight(self):
        return self._height

    @Property(float, notify=mediaChanged)
    def fps(self):
        return self._fps

    @Property(str, notify=mediaChanged)
    def mediaInfo(self):
        if not self._path:
            return ""
        fps = f" · {self._fps:.0f} fps" if self._fps else ""
        return f"{self._width} × {self._height} · {self._codec.upper()}{fps} · {self._duration:.2f} s"

    @Property(bool, notify=mediaChanged)
    def hasAudio(self):
        return self._audio

    @Property(float, notify=rangeChanged)
    def clipStart(self):
        return self._start

    @Property(float, notify=rangeChanged)
    def clipEnd(self):
        return self._end

    @Property(float, notify=positionChanged)
    def position(self):
        return self._position

    @Property(str, notify=previewChanged)
    def previewUrl(self):
        return self._preview

    @Property(str, notify=previewChanged)
    def timelineImageStatus(self):
        return self._thumbnail_status

    @Property("QVariantList", notify=previewChanged)
    def timelineThumbnails(self):
        return self._thumbnails

    @Property(str, notify=waveformChanged)
    def waveformUrl(self):
        return self._waveform

    @Property(str, notify=waveformChanged)
    def waveformStatus(self):
        return self._waveform_status

    @Property("QVariantList", notify=exportQueueChanged)
    def queuedExports(self):
        return [{"id": job["id"], "name": job["name"], "status": job["status"]}
                for job in self._export_queue]

    @Property(int, notify=exportQueueChanged)
    def queuedExportCount(self):
        return sum(job["status"] == "queued" for job in self._export_queue)

    @Property(bool, notify=exportQueueChanged)
    def exportQueueRunning(self):
        return self._queue_running

    @Property(QUrl, notify=exportDirectoryChanged)
    def lastExportDirectoryUrl(self):
        return QUrl.fromLocalFile(self._last_export_directory)

    @Slot(str)
    def rememberExportDirectory(self, directory: str):
        path = os.path.abspath(directory.strip())
        if not os.path.isdir(path) or path == self._last_export_directory:
            return
        self._last_export_directory = path
        self._settings.setValue("export/lastDirectory", path)
        self._settings.sync()
        self.exportDirectoryChanged.emit()

    @Property("QVariantMap", notify=rangeChanged)
    def cropRect(self):
        return self._crop_geometry()

    @Property(bool, notify=mediaChanged)
    def hasVideo(self):
        return bool(self._path and self._duration > 0)

    @Property(bool, notify=busyChanged)
    def busy(self):
        return self._busy

    @Property(bool, notify=exportingChanged)
    def exporting(self):
        return self._exporting

    @Property(str, notify=statusChanged)
    def status(self):
        return self._status

    @Property(int, notify=progressChanged)
    def progress(self):
        return self._progress

    @Property(bool, notify=gpuChanged)
    def gpuAvailable(self):
        return any(self._hardware_encoder_for(codec)
                   for codec in ("h264", "hevc", "av1"))

    @Property(bool, notify=gpuPreferenceChanged)
    def preferGpu(self):
        return self._prefer_gpu

    @Slot(bool)
    def setPreferGpu(self, value: bool):
        value = bool(value)
        if self._prefer_gpu == value:
            return
        self._prefer_gpu = value
        self._settings.setValue("encoding/preferGpu", value)
        self._settings.sync()
        self.gpuPreferenceChanged.emit()

    @Property(str, notify=gpuChanged)
    def gpuName(self):
        if not self._gpu_name:
            return "GPU não detectada"
        apis = []
        codecs = []
        for codec, label in (("h264", "H.264"), ("hevc", "HEVC"), ("av1", "AV1")):
            selected = self._hardware_encoder_for(codec)
            if selected:
                if selected["api"] not in apis:
                    apis.append(selected["api"])
                codecs.append(label)
        if not apis:
            return f"{self._gpu_name} · encoder de hardware indisponível no FFmpeg"
        api_text = " / ".join(self._gpu_api_label(api) for api in apis)
        return f"{self._gpu_name} · {api_text} · {', '.join(codecs)}"

    @Slot(str, result=str)
    def hardwareEncoderName(self, codec):
        selected = self._hardware_encoder_for(codec)
        return self._gpu_api_label(selected["api"]) if selected else "CPU"

    @Slot(str, result=bool)
    def hardwareEncoderAvailable(self, codec):
        return bool(self._hardware_encoder_for(codec))

    @Slot(str, result=str)
    def hardwareEncoderStatus(self, codec):
        if self._hardware_encoder_for(codec):
            return ""
        if codec == "av1" and self._gpu_devices and not any(
                self._supports_hardware_av1(device) for device in self._gpu_devices):
            return "Esta GPU não oferece codificação AV1 por hardware; será usada a CPU."
        return "Encoder de GPU indisponível para este codec nesta instalação. Será usada a CPU."

    @Slot(result=str)
    def diagnosticReport(self):
        ffmpeg = shutil.which("ffmpeg")
        version = "indisponível"
        if ffmpeg:
            try:
                result = capture([ffmpeg, "-hide_banner", "-version"], 5)
                if result.returncode == 0 and result.stdout.strip():
                    version = result.stdout.splitlines()[0].strip()
            except (OSError, subprocess.SubprocessError):
                pass
        lines = [
            "ClipCut — diagnóstico de exportação",
            f"Sistema: {platform.system()} ({sys.platform})",
            f"Python: {platform.python_version()}",
            f"FFmpeg: {version}",
            "",
            "Encoders disponíveis:",
        ]
        for codec, label in (("h264", "H.264"), ("hevc", "HEVC"), ("av1", "AV1")):
            cpu_encoder = {"h264": "libx264", "hevc": "libx265", "av1": "libsvtav1"}[codec]
            hardware = self._hardware_encoder_for(codec)
            cpu = cpu_encoder if cpu_encoder in self._encoders else "indisponível"
            if hardware:
                device = hardware["device"].get("name", "GPU")
                lines.append(f"- {label}: {hardware['encoder']} ({device}); CPU: {cpu}")
            else:
                lines.append(f"- {label}: CPU {cpu}; GPU: indisponível")
        lines.extend(("", "O relatório não inclui caminhos de arquivos de mídia."))
        return "\n".join(lines)

    @Slot()
    def copyDiagnosticReport(self):
        QGuiApplication.clipboard().setText(self.diagnosticReport())
        self._set_status("Diagnóstico copiado para a área de transferência.")

    @Property("QVariantMap", notify=paletteChanged)
    def themePalette(self):
        return self._palette

    @Slot(QUrl)
    def openUrl(self, url: QUrl):
        if url.isLocalFile():
            self.loadFile(url.toLocalFile())
        else:
            self._set_status("Abra um arquivo de vídeo local.")

    @Slot(str)
    def openLocalUrl(self, value: str):
        url = QUrl(value)
        if url.isLocalFile():
            self.loadFile(url.toLocalFile())
        else:
            self._set_status("Abra um arquivo de vídeo local.")

    @Slot(str, result=str)
    def localPath(self, value: str):
        url = QUrl(value)
        return url.toLocalFile() if url.isLocalFile() else ""

    @Slot(str)
    def loadFile(self, path: str):
        path = os.path.abspath(path.strip())
        if not os.path.isfile(path):
            self._set_status("Não encontrei esse arquivo. Escolha um vídeo local.")
            return
        if not shutil.which("ffmpeg") or not shutil.which("ffprobe"):
            self._set_status("FFmpeg e ffprobe precisam estar instalados e no PATH.")
            return
        self._generation += 1
        generation = self._generation
        self._preview_id += 1
        self._cancel_background_tasks()
        self._path = path
        self._preview = self._waveform = ""
        self._thumbnails = []
        self._thumbnail_status = "loading"
        self._waveform_status = "checking"
        self._duration = self._width = self._height = 0
        self._codec, self._fps = "", 0.0
        self._sample_aspect = 1.0
        self._audio = False
        self._start = self._end = self._position = 0.0
        self._set_busy(True)
        self.fileChanged.emit()
        self.mediaChanged.emit()
        self.rangeChanged.emit()
        self.positionChanged.emit()
        self.previewChanged.emit()
        self.waveformChanged.emit()
        self._set_status("Lendo vídeo…")

        def probe(task):
            p = task.run_process(["ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", path], text=True)
            if p.returncode:
                raise RuntimeError(p.stderr.strip() or "ffprobe não conseguiu ler o arquivo")
            data = json.loads(p.stdout)
            video = next((s for s in data.get("streams", []) if s.get("codec_type") == "video"), None)
            if not video:
                raise RuntimeError("O arquivo não contém vídeo.")
            audio = any(s.get("codec_type") == "audio" for s in data.get("streams", []))
            duration = float(video.get("duration") or data.get("format", {}).get("duration") or 0)
            if duration <= 0:
                raise RuntimeError("Não foi possível determinar a duração do vídeo.")
            rate = video.get("avg_frame_rate") or video.get("r_frame_rate") or "0/1"
            try:
                a, b = rate.split("/", 1)
                fps = float(a) / max(1, float(b))
            except (ValueError, ZeroDivisionError):
                fps = 0
            sar_text = video.get("sample_aspect_ratio", "1:1") or "1:1"
            try:
                sar_w, sar_h = (float(v) for v in sar_text.split(":", 1))
                sample_aspect = sar_w / sar_h if sar_h else 1.0
            except (ValueError, ZeroDivisionError):
                sample_aspect = 1.0
            return {"duration": duration, "width": int(video.get("width", 0)),
                    "height": int(video.get("height", 0)), "codec": video.get("codec_name", ""),
                    "fps": fps, "audio": audio, "sample_aspect": sample_aspect}

        self._run_task(probe, self._probe_done, generation, "probe")

    def _cancel_background_tasks(self, kind=None):
        for task in tuple(self._tasks.values()):
            if kind is None or task.kind == kind:
                task.cancel()

    def _run_task(self, fn, callback, generation, kind="analysis"):
        thread = QThread(self)
        task = Task(fn, generation, kind)
        task.moveToThread(thread)
        thread.started.connect(task.run)
        task.done.connect(callback)
        thread.finished.connect(task.deleteLater)
        thread.finished.connect(thread.deleteLater)
        thread.finished.connect(lambda t=thread: self._tasks.pop(t, None))
        self._tasks[thread] = task
        thread.start()

    @Slot(object, str, int)
    def _probe_done(self, data, error, generation):
        if self._shutting_down or generation != self._generation:
            return
        if error:
            self._thumbnail_status = "error"
            self._waveform_status = "error"
            self.previewChanged.emit()
            self.waveformChanged.emit()
            self._set_busy(False)
            self._set_status("Falha ao abrir o vídeo")
            self.exportDone.emit(False, error)
            return
        self._duration = data["duration"]
        self._width, self._height = data["width"], data["height"]
        self._codec, self._fps, self._audio = data["codec"], data["fps"], data["audio"]
        self._sample_aspect = data.get("sample_aspect", 1.0)
        self._thumbnail_status = "loading"
        self._waveform_status = "pending" if self._audio else "none"
        self.previewChanged.emit()
        self.waveformChanged.emit()
        self._start, self._end, self._position = 0.0, self._duration, 0.0
        self.mediaChanged.emit()
        self.rangeChanged.emit()
        self.positionChanged.emit()
        self._set_status("Gerando miniaturas…")
        path, duration, has_audio = self._path, self._duration, self._audio

        def make_thumbnails(task):
            # Individual 16:9 thumbnails preserve aspect ratio at every zoom
            # level. 48 evenly sampled frames provide useful detail without
            # building a project/cache database.
            pattern = os.path.join(self._tmp.name, f"timeline-{generation}-%02d.jpg")
            rate = 48 / max(duration, .1)
            vf = f"fps={rate:.8f},scale=160:90:force_original_aspect_ratio=increase,crop=160:90"
            args = ["ffmpeg", "-hide_banner", "-v", "error", "-y", "-i", path, "-vf", vf,
                    "-frames:v", "48", "-q:v", "4", pattern]
            p = task.run_process(args, timeout=120)
            image_paths = sorted(Path(self._tmp.name).glob(f"timeline-{generation}-*.jpg"))
            if p.returncode or not image_paths:
                raise RuntimeError(p.stderr.decode(errors="replace") or "Não consegui criar a timeline")
            sample_span = duration / len(image_paths)
            return [{"url": QUrl.fromLocalFile(str(image)).toString(),
                     "time": sample_span * (index + .5), "span": sample_span}
                    for index, image in enumerate(image_paths)]

        self._run_task(make_thumbnails, self._thumbnails_done, generation, "thumbnails")
        if has_audio:
            def make_waveform(task):
                waveform_path = os.path.join(self._tmp.name, f"waveform-{generation}.png")
                waveform_args = [
                    "ffmpeg", "-hide_banner", "-v", "error", "-y", "-i", path,
                    "-filter_complex",
                    "[0:a:0]aformat=channel_layouts=mono,showwavespic=s=2400x80:colors=0xd0bcff:scale=sqrt:filter=peak[w]",
                    "-map", "[w]", "-frames:v", "1", waveform_path,
                ]
                wave = task.run_process(waveform_args, timeout=120)
                if wave.returncode or not os.path.isfile(waveform_path):
                    message = wave.stderr.decode(errors="replace").strip()
                    raise RuntimeError(message or "Não consegui gerar a waveform")
                return QUrl.fromLocalFile(waveform_path).toString()

            self._run_task(make_waveform, self._waveform_done, generation, "waveform")
        self.requestPreview(0.0)

    @Slot(object, str, int)
    def _thumbnails_done(self, result, error, generation):
        if self._shutting_down or generation != self._generation:
            return
        if error:
            self._thumbnail_status = "error"
            self._set_status(f"Timeline indisponível: {error[:180]}")
        else:
            self._thumbnails = result
            self._thumbnail_status = "ready"
            self.previewChanged.emit()
            self._set_status("Pronto para cortar")
        if error:
            self.previewChanged.emit()
        self._set_busy(False)

    @Slot(object, str, int)
    def _waveform_done(self, result, error, generation):
        if self._shutting_down or generation != self._generation:
            return
        if error:
            self._waveform_status = "error"
            self.waveformChanged.emit()
            # Keep the failure visible without hiding successfully generated thumbnails.
            self._set_status(f"Pronto para cortar · waveform indisponível: {error[:120]}")
            return
        self._waveform = result
        self._waveform_status = "ready"
        self.waveformChanged.emit()

    @Slot(float)
    def requestPreview(self, seconds: float):
        if not self._path or not self._duration:
            return
        sec = max(0.0, min(float(seconds), max(0.0, self._duration - 0.001)))
        self._position = sec
        self.positionChanged.emit()
        self._preview_id += 1
        request_id = self._preview_id
        generation = self._generation
        path = self._path
        preview_path = os.path.join(self._tmp.name, f"frame-{generation}-{request_id}.jpg")

        def grab_frame(task):
            args = ["ffmpeg", "-hide_banner", "-v", "error", "-i", path, "-ss", f"{sec:.4f}",
                    "-frames:v", "1", "-vf", "scale=1280:720:force_original_aspect_ratio=decrease",
                    "-q:v", "3", "-y", preview_path]
            p = task.run_process(args, timeout=30)
            if p.returncode or not os.path.isfile(preview_path):
                raise RuntimeError(p.stderr.decode(errors="replace") or "Quadro indisponível")
            return (request_id, QUrl.fromLocalFile(preview_path).toString() + f"?v={generation}-{request_id}")

        self._cancel_background_tasks("preview")
        self._run_task(grab_frame, self._preview_done, generation, "preview")

    @Slot(object, str, int)
    def _preview_done(self, result, error, generation):
        if self._shutting_down or generation != self._generation:
            return
        if error or not result:
            return
        request_id, url = result
        if request_id == self._preview_id:
            self._preview = url
            self.previewChanged.emit()

    @Slot(float)
    def setPlaybackPosition(self, seconds: float):
        if not self._duration:
            return
        seconds = max(0.0, min(float(seconds), self._duration))
        if abs(self._position - seconds) > 0.001:
            self._position = seconds
            self.positionChanged.emit()

    @Slot(float)
    def setPosition(self, seconds: float):
        self.requestPreview(seconds)

    @Slot()
    def stepBack(self):
        self.requestPreview(self._position - (1 / self._fps if self._fps else 1 / 60))

    @Slot()
    def stepForward(self):
        self.requestPreview(self._position + (1 / self._fps if self._fps else 1 / 60))

    @Slot(float, float)
    def setRange(self, start: float, end: float):
        if not self._duration:
            return
        start = max(0.0, min(float(start), self._duration))
        end = max(start, min(float(end), self._duration))
        if end - start < .01:
            return
        self._start, self._end = start, end
        self.rangeChanged.emit()

    @Slot()
    def markIn(self):
        self.setRange(self._position, self._end)

    @Slot()
    def markOut(self):
        self.setRange(self._start, self._position)

    def _crop_geometry(self, ratio=None, custom_ratio=None):
        if not self._width or not self._height:
            return {"x": 0.0, "y": 0.0, "width": 1.0, "height": 1.0}
        ratio = self._crop_ratio if ratio is None else ratio
        custom_ratio = self._crop_custom if custom_ratio is None else custom_ratio
        source_dar = self._width * self._sample_aspect / self._height
        if ratio == "Original":
            target_dar = source_dar
        elif ratio == "Livre":
            try:
                rw, rh = (float(v) for v in custom_ratio.split(":", 1))
                target_dar = rw / rh if rw > 0 and rh > 0 else source_dar
            except (ValueError, ZeroDivisionError):
                target_dar = source_dar
        else:
            target_dar = ratio_value(ratio, self._width, self._height)
            target_dar = target_dar or source_dar
        if abs(target_dar - source_dar) < 0.002:
            return {"x": 0.0, "y": 0.0, "width": 1.0, "height": 1.0}
        if target_dar < source_dar:
            width = min(1.0, target_dar / source_dar)
            height = 1.0
        else:
            width = 1.0
            height = min(1.0, source_dar / target_dar)
        x = min(max(self._crop_x, width / 2), 1 - width / 2)
        y = min(max(self._crop_y, height / 2), 1 - height / 2)
        return {"x": x - width / 2, "y": y - height / 2,
                "width": width, "height": height}

    @Slot(str, str)
    def setCropRatio(self, ratio: str, custom_ratio: str):
        self._crop_ratio, self._crop_custom = ratio, custom_ratio
        self.rangeChanged.emit()

    @Slot(float, float)
    def moveCrop(self, center_x: float, center_y: float):
        rect = self._crop_geometry()
        self._crop_x = min(max(float(center_x), rect["width"] / 2), 1 - rect["width"] / 2)
        self._crop_y = min(max(float(center_y), rect["height"] / 2), 1 - rect["height"] / 2)
        self.rangeChanged.emit()

    @Slot()
    def centerCrop(self):
        self._crop_x = self._crop_y = 0.5
        self.rangeChanged.emit()

    def _command(self, output, codec, ratio, custom_ratio, quality, use_gpu,
                 target_size_mb=0, include_audio=True):
        if self._end - self._start < .03:
            raise ValueError("Selecione um trecho com pelo menos 0,03 segundo.")
        if not math.isfinite(target_size_mb) or target_size_mb < 0:
            raise ValueError("Tamanho-alvo inválido.")
        source_ratio = self._width * self._sample_aspect / max(1, self._height)
        target_ratio = ratio_value(ratio, self._width, self._height)
        if ratio == "Livre":
            try:
                w, h = (int(v) for v in custom_ratio.split(":", 1))
                if w < 1 or h < 1:
                    raise ValueError()
                target_ratio = w / h
            except ValueError:
                raise ValueError("Proporção livre inválida. Exemplo: 3:2.")
        elif ratio == "Original":
            target_ratio = source_ratio
        else:
            try:
                w, h = (int(v) for v in ratio.split(":", 1))
                if w < 1 or h < 1:
                    raise ValueError()
                target_ratio = w / h
            except ValueError:
                raise ValueError("Proporção inválida.")
        crop_rect = self._crop_geometry(ratio, custom_ratio)
        if ratio == self._crop_ratio and custom_ratio == self._crop_custom:
            crop_rect = self._crop_geometry()
        crop = crop_rect["width"] < .9999 or crop_rect["height"] < .9999
        needs_even_dimensions = codec != "copy" and (self._width % 2 or self._height % 2)
        if codec == "copy" and crop:
            raise ValueError("Copiar vídeo não permite alterar o enquadramento. Escolha um encoder.")
        if target_size_mb and (codec == "copy" or target_size_mb <= 0):
            raise ValueError("Tamanho-alvo requer um encoder, não stream copy.")
        hardware = self._hardware_encoder_for(codec) if use_gpu and codec != "copy" else None
        if use_gpu and codec != "copy" and not hardware:
            raise ValueError(self.hardwareEncoderStatus(codec))
        api = hardware["api"] if hardware else ""
        gpu = bool(hardware)
        encoder = "copy" if codec == "copy" else hardware["encoder"] if hardware else {
            "h264": "libx264", "hevc": "libx265", "av1": "libsvtav1"}.get(codec)
        if not encoder:
            raise ValueError("Codec de vídeo desconhecido.")
        if codec != "copy" and encoder not in self._encoders:
            raise ValueError(f"O encoder {encoder} não está disponível nesta instalação do FFmpeg.")

        command = ["ffmpeg", "-hide_banner", "-y"]
        if api == "vaapi":
            command += ["-vaapi_device", hardware["device"]["renderNode"]]
        elif api == "qsv":
            render_node = hardware["device"].get("renderNode", "")
            if render_node:
                command += ["-init_hw_device", f"vaapi=va:{render_node}",
                            "-init_hw_device", "qsv=hw@va", "-filter_hw_device", "hw"]
            else:
                command += ["-init_hw_device", "qsv=hw", "-filter_hw_device", "hw"]
        if codec == "copy":
            # Input seeking starts at a preceding keyframe; stream-copy cuts are inherently GOP-limited.
            command += ["-ss", f"{self._start:.6f}", "-i", self._path,
                        "-t", f"{self._end-self._start:.6f}"]
        else:
            command += ["-i", self._path, "-ss", f"{self._start:.6f}",
                        "-t", f"{self._end-self._start:.6f}"]
        command += ["-map", "0:v:0"]
        if include_audio:
            command += ["-map", "0:a?"]
        else:
            command += ["-an"]
        command += ["-map_metadata", "0"]
        video_filters = []
        if crop or needs_even_dimensions:
            crop_w = max(2, int(self._width * crop_rect["width"]) // 2 * 2)
            crop_h = max(2, int(self._height * crop_rect["height"]) // 2 * 2)
            crop_x = int(round(self._width * crop_rect["x"])) // 2 * 2
            crop_y = int(round(self._height * crop_rect["y"])) // 2 * 2
            crop_x = max(0, min(crop_x, self._width - crop_w))
            crop_y = max(0, min(crop_y, self._height - crop_h))
            video_filters.append(f"crop={crop_w}:{crop_h}:{crop_x}:{crop_y}")
        if api in ("vaapi", "qsv"):
            video_filters.extend(("format=nv12", "hwupload=extra_hw_frames=64"))
        if video_filters:
            command += ["-vf", ",".join(video_filters)]
        if codec == "copy":
            command += ["-c:v", "copy"]
            actual_encoder = "vídeo copiado (sem recodificar)"
        else:
            qkey = "nvenc" if api == "nvenc" else codec
            q = QUALITY[quality][qkey]
            command += ["-c:v", encoder]
            if target_size_mb:
                duration = self._end - self._start
                audio_rate = 192_000 if self._audio and include_audio else 0
                video_rate = int((target_size_mb * 8_000_000 * .96) / duration - audio_rate)
                if video_rate < 16_000:
                    raise ValueError("Tamanho-alvo muito pequeno para este trecho.")
                command += ["-b:v", str(video_rate)]
                if api == "nvenc":
                    command += ["-preset", "p5", "-tune", "hq", "-rc", "vbr",
                                "-maxrate", str(int(video_rate * 1.15)),
                                "-bufsize", str(video_rate * 2)]
                elif api == "amf":
                    command += ["-rc", "vbr_peak", "-maxrate", str(int(video_rate * 1.15))]
                elif codec in ("h264", "hevc"):
                    command += ["-maxrate", str(int(video_rate * 1.15)),
                                "-bufsize", str(video_rate * 2)]
            elif api == "nvenc":
                command += ["-preset", "p5", "-tune", "hq", "-rc", "vbr", "-cq", str(q), "-b:v", "0"]
            elif api == "vaapi":
                if codec == "av1":
                    command += ["-rc_mode", "ICQ", "-global_quality", str(q)]
                else:
                    command += ["-rc_mode", "CQP", "-qp", str(q)]
            elif api == "qsv":
                command += ["-global_quality", str(q), "-preset", "4"]
            elif api == "amf":
                command += ["-rc", "cqp", "-qp_i", str(q), "-qp_p", str(q), "-quality", "2"]
            elif codec == "h264":
                command += ["-preset", "slow", "-crf", str(q)]
            elif codec == "hevc":
                command += ["-preset", "slow", "-crf", str(q)]
            else:
                command += ["-preset", "6", "-crf", str(q)]
            if api not in ("vaapi", "qsv"):
                command += ["-pix_fmt", "yuv420p"]
            actual_encoder = (f"{encoder} · {self._gpu_api_label(api)}"
                              if gpu else encoder)
        if include_audio:
            command += ["-c:a", "aac", "-b:a", "192k", "-af", "asetpts=PTS-STARTPTS"]
        command += ["-avoid_negative_ts", "make_zero"]
        if Path(output).suffix.lower() == ".mp4":
            command += ["-movflags", "+faststart"]
        command.append(output)
        return command, actual_encoder

    def _prepare_export_job(self, output, codec, ratio, custom_ratio, quality,
                            use_gpu, overwrite, target_size_mb, include_audio):
        try:
            target_size_mb = float(target_size_mb)
        except (TypeError, ValueError):
            return None, "Tamanho-alvo inválido."
        output = QUrl(output).toLocalFile() if output.startswith("file:") else output
        output = os.path.abspath(output)
        if not output.lower().endswith((".mp4", ".mkv")):
            output += ".mp4"
        if os.path.realpath(output) == os.path.realpath(self._path):
            return None, "O arquivo de saída não pode ser o vídeo original."
        if os.path.exists(output) and not overwrite:
            return None, "O arquivo já existe. Confirme a substituição antes de exportar."
        if not os.path.isdir(os.path.dirname(output)):
            return None, "A pasta de destino não existe."
        try:
            command, encoder = self._command(output, codec, ratio, custom_ratio, quality,
                                             use_gpu, target_size_mb, include_audio)
        except ValueError as e:
            return None, str(e)
        return {"output": output, "name": Path(output).name, "command": command,
                "duration": self._end - self._start,
                "encoder": encoder}, ""

    @Slot(str, str, str, str, str, bool, bool, float, bool)
    def exportFile(self, output: str, codec: str, ratio: str, custom_ratio: str,
                   quality: str, use_gpu: bool, overwrite: bool = False,
                   target_size_mb: float = 0.0, include_audio: bool = True):
        job, error = self._prepare_export_job(output, codec, ratio, custom_ratio, quality,
                                              use_gpu, overwrite, target_size_mb, include_audio)
        if error:
            self.exportDone.emit(False, error)
            return
        self._launch_export_job(job)

    @Slot(str, str, str, str, str, bool, float, bool, result=bool)
    def enqueueExport(self, output, codec, ratio, custom_ratio, quality,
                      use_gpu, target_size_mb=0.0, include_audio=True):
        job, error = self._prepare_export_job(output, codec, ratio, custom_ratio, quality,
                                              use_gpu, False, target_size_mb, include_audio)
        if error:
            self.exportDone.emit(False, error)
            return False
        output_key = os.path.normcase(os.path.realpath(job["output"]))
        if any(os.path.normcase(os.path.realpath(queued["output"])) == output_key
               for queued in self._export_queue):
            self.exportDone.emit(False, "Esse destino já está na fila.")
            return False
        job.update(id=self._next_queue_id, status="queued")
        self._next_queue_id += 1
        self._export_queue.append(job)
        self.exportQueueChanged.emit()
        self.exportDone.emit(True, f"{job['name']} adicionado à fila.")
        return True

    @Slot(int)
    def removeQueuedExport(self, job_id):
        before = len(self._export_queue)
        self._export_queue = [job for job in self._export_queue
                              if job["id"] != job_id or job["status"] == "exporting"]
        if len(self._export_queue) != before:
            self.exportQueueChanged.emit()

    @Slot()
    def clearExportQueue(self):
        self._export_queue = [job for job in self._export_queue if job["status"] == "exporting"]
        self.exportQueueChanged.emit()

    @Slot()
    def startExportQueue(self):
        if self._queue_running or self._exporting:
            return
        if not any(job["status"] == "queued" for job in self._export_queue):
            self._set_status("A fila não tem exportações pendentes.")
            return
        self._queue_running = True
        self.exportQueueChanged.emit()
        self._start_next_queued_export()

    def _start_next_queued_export(self):
        if not self._queue_running or self._exporting:
            return
        job = next((item for item in self._export_queue if item["status"] == "queued"), None)
        if job is None:
            self._queue_running = False
            self.exportQueueChanged.emit()
            self._set_status("Fila de exportação concluída.")
            return
        if os.path.exists(job["output"]):
            job["status"] = "failed"
            job["error"] = "O destino passou a existir depois que o item entrou na fila."
            self.exportQueueChanged.emit()
            self.exportDone.emit(False, f"{job['name']}: destino já existe; item ignorado.")
            QTimer.singleShot(0, self._start_next_queued_export)
            return
        job["status"] = "exporting"
        self._active_queue_job = job
        self.exportQueueChanged.emit()
        self._launch_export_job(job)

    def _launch_export_job(self, job):
        output = job["output"]
        temp_path = os.path.join(os.path.dirname(output),
                                 f".{Path(output).stem}-{uuid.uuid4().hex}.partial{Path(output).suffix}")
        command = list(job["command"])
        command[-1] = temp_path
        self._set_busy(True)
        self._set_exporting(True)
        self._progress = 0
        self.progressChanged.emit()
        self._set_status(f"Exportando {job['name']} com {job['encoder']}…")
        thread = QThread(self)
        task = ExportTask(command, job["duration"], temp_path, output)
        task.moveToThread(thread)
        thread.started.connect(task.run)
        task.progress.connect(self._set_progress)
        task.done.connect(self._export_done)
        thread.finished.connect(task.deleteLater)
        thread.finished.connect(self._export_thread_finished)
        thread.finished.connect(thread.deleteLater)
        self._export_thread, self._export_task = thread, task
        thread.start()

    @Slot(int)
    def _set_progress(self, value):
        self._progress = value
        self.progressChanged.emit()

    @Slot(bool, str)
    def _export_done(self, success, message):
        if self._shutting_down:
            return
        if self._active_queue_job:
            self._active_queue_job["status"] = "done" if success else (
                "cancelled" if "cancelada" in message.lower() else "failed")
            self._active_queue_job["result"] = message
            self.exportQueueChanged.emit()
        self._set_status(message)
        if success:
            self._progress = 100
            self.progressChanged.emit()
        self.exportDone.emit(success, message)

    @Slot()
    def _export_thread_finished(self):
        self._export_task = self._export_thread = None
        if not self._shutting_down:
            self._set_exporting(False)
            self._set_busy(False)
            if self._active_queue_job:
                self._active_queue_job = None
                if self._queue_running:
                    QTimer.singleShot(0, self._start_next_queued_export)

    @Slot()
    def cancelExport(self):
        if self._export_task:
            if self._active_queue_job:
                self._queue_running = False
                self.exportQueueChanged.emit()
            self._export_task.cancel()
            self._set_status("Cancelando exportação…")

    @Slot()
    def shutdown(self):
        if self._shutting_down:
            return
        self._shutting_down = True
        self._generation += 1
        self._preview_id += 1
        for task in tuple(self._tasks.values()):
            task.cancel()
        if self._export_task:
            self._export_task.cancel()
        threads = list(self._tasks)
        if self._export_thread:
            threads.append(self._export_thread)
        for thread in threads:
            if thread.isRunning():
                thread.wait()
        self._tasks.clear()
        self._export_task = self._export_thread = None
        self._tmp.cleanup()

    def _set_busy(self, value):
        if self._busy != value:
            self._busy = value
            self.busyChanged.emit()

    def _set_exporting(self, value):
        if self._exporting != value:
            self._exporting = value
            self.exportingChanged.emit()

    def _set_status(self, value):
        self._status = value
        self.statusChanged.emit()


def main():
    # Let the desktop's XDG portal choose the native dialog backend (KDE, GTK, etc.).
    # Respect an explicit platform-theme choice supplied by the user or launcher.
    if sys.platform.startswith("linux"):
        os.environ.setdefault("QT_QPA_PLATFORMTHEME", "xdgdesktopportal")
    app = QGuiApplication(sys.argv)
    app.setApplicationName("ClipCut")
    app.setWindowIcon(QIcon(str(Path(__file__).with_name("assets") / "branding" / "clipcut-split-timeline-smooth.svg")))
    engine = QQmlApplicationEngine()
    backend = ClipBackend()
    backend.setParent(app)
    engine.rootContext().setContextProperty("backend", backend)
    engine.warnings.connect(lambda warnings: [print(w.toString(), file=sys.stderr) for w in warnings])
    qml = Path(__file__).with_name("Main.qml")
    engine.load(QUrl.fromLocalFile(str(qml)))
    if not engine.rootObjects():
        return 1
    video_argument = next((argument for argument in sys.argv[1:]
                           if not argument.startswith("-")), "")
    if video_argument:
        video_url = QUrl.fromUserInput(video_argument)
        QTimer.singleShot(0, lambda: backend.openUrl(video_url))
    app.aboutToQuit.connect(backend.shutdown)
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
