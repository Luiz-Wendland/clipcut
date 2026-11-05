import os
import shutil
import subprocess
import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

from PySide6.QtCore import QCoreApplication, QUrl
from PySide6.QtGui import QImageReader

from main import ClipBackend, ratio_value


APP = QCoreApplication.instance() or QCoreApplication([])
SAMPLE_PATH = os.path.join(tempfile.gettempdir(), "source with çedilha.mp4")


class BackendTests(unittest.TestCase):
    def setUp(self):
        self.backend = ClipBackend()
        self.backend._path = SAMPLE_PATH
        self.backend._duration = 10.0
        self.backend._width, self.backend._height = 1920, 1080
        self.backend._fps = 30.0
        self.backend._start, self.backend._end = 1.0, 4.0
        self.backend._encoders.update({"libx264", "libx265", "libsvtav1"})

    def tearDown(self):
        self.backend.shutdown()

    def wait_for_tasks_to_finish(self, timeout=15):
        deadline = time.monotonic() + timeout
        while self.backend._tasks and time.monotonic() < deadline:
            APP.processEvents()
            time.sleep(.01)
        APP.processEvents()
        self.assertFalse(self.backend._tasks, "Background media tasks did not finish")

    def test_linux_gpu_detection_maps_amd_intel_and_render_nodes(self):
        with tempfile.TemporaryDirectory() as directory, patch("main.shutil.which", return_value=None):
            root = Path(directory)
            drm = root / "sys/class/drm"
            dri = root / "dev/dri"
            expected = (("card0", "renderD128", "0x1002", "amd"),
                        ("card1", "renderD129", "0x8086", "intel"))
            for card, render, vendor_id, _ in expected:
                device = root / "sys/devices" / card
                device.mkdir(parents=True)
                (device / "vendor").write_text(vendor_id, encoding="ascii")
                card_dir = drm / card
                card_dir.mkdir(parents=True)
                (card_dir / "device").symlink_to(device, target_is_directory=True)
                render_dir = drm / render
                render_dir.mkdir(parents=True)
                (render_dir / "device").symlink_to(device, target_is_directory=True)

            devices = ClipBackend._detect_gpu_devices(drm, dri)

        self.assertEqual([device["vendor"] for device in devices], ["amd", "intel"])
        self.assertEqual([device["renderNode"] for device in devices],
                         [str(dri / "renderD128"), str(dri / "renderD129")])

    def test_encoder_selection_is_explicit_and_ampere_av1_gpu_is_unavailable(self):
        self.backend._gpu_devices = [{"vendor": "nvidia", "name": "NVIDIA GeForce RTX 30 Series",
                                      "renderNode": ""}]
        self.backend._encoders.update({"h264_nvenc", "hevc_nvenc", "av1_nvenc"})
        gpu_command, _ = self.backend._command("out.mp4", "h264", "Original", "3:2",
                                                "Alta qualidade", True)
        cpu_command, _ = self.backend._command("out.mp4", "h264", "Original", "3:2",
                                                "Alta qualidade", False)
        self.assertEqual(gpu_command[gpu_command.index("-c:v") + 1], "h264_nvenc")
        self.assertEqual(cpu_command[cpu_command.index("-c:v") + 1], "libx264")
        self.assertTrue(self.backend.hardwareEncoderAvailable("h264"))
        self.assertFalse(self.backend.hardwareEncoderAvailable("av1"))
        with self.assertRaisesRegex(ValueError, "não oferece codificação AV1"):
            self.backend._command("out.mp4", "av1", "Original", "3:2",
                                  "Alta qualidade", True)
        av1_command, _ = self.backend._command("out.mp4", "av1", "Original", "3:2",
                                                "Alta qualidade", False)
        self.assertEqual(av1_command[av1_command.index("-c:v") + 1], "libsvtav1")

    def test_amd_vaapi_command_uploads_frames_to_gpu(self):
        self.backend._gpu_devices = [{"vendor": "amd", "name": "AMD Radeon RX 7800 XT",
                                      "renderNode": "/dev/dri/renderD128"}]
        self.backend._encoders.add("h264_vaapi")
        with patch("main.os.access", return_value=True):
            command, _ = self.backend._command("out.mp4", "h264", "4:3", "3:2",
                                                "Alta qualidade", True)
        self.assertEqual(command[command.index("-c:v") + 1], "h264_vaapi")
        self.assertEqual(command[command.index("-vaapi_device") + 1], "/dev/dri/renderD128")
        self.assertIn("crop=1440:1080:240:0,format=nv12,hwupload=extra_hw_frames=64",
                      command[command.index("-vf") + 1])

    def test_intel_quick_sync_initializes_qsv_from_render_node(self):
        self.backend._gpu_devices = [{"vendor": "intel", "name": "Intel Arc A770",
                                      "renderNode": "/dev/dri/renderD129"}]
        self.backend._encoders.add("h264_qsv")
        with patch("main.os.access", return_value=True):
            command, _ = self.backend._command("out.mp4", "h264", "Original", "3:2",
                                                "Alta qualidade", True)
        self.assertEqual(command[command.index("-c:v") + 1], "h264_qsv")
        self.assertIn("vaapi=va:/dev/dri/renderD129", command)
        self.assertIn("qsv=hw@va", command)
        self.assertIn("format=nv12,hwupload=extra_hw_frames=64",
                      command[command.index("-vf") + 1])

    def test_ratio_validation(self):
        self.assertAlmostEqual(ratio_value("Original", 1920, 1080), 16 / 9)
        self.assertAlmostEqual(ratio_value("4:3", 1920, 1080), 4 / 3)
        self.assertAlmostEqual(ratio_value("9:16", 1920, 1080), 9 / 16)
        self.assertAlmostEqual(ratio_value("1:1", 1920, 1080), 1)
        self.assertAlmostEqual(ratio_value("4:5", 1920, 1080), 4 / 5)
        self.assertIsNone(ratio_value("bad", 1920, 1080))

    def test_social_crop_presets_generate_centered_even_dimensions(self):
        expected = {
            "9:16": "crop=606:1080:656:0",
            "1:1": "crop=1080:1080:420:0",
            "4:5": "crop=864:1080:528:0",
        }
        for ratio, crop_filter in expected.items():
            with self.subTest(ratio=ratio):
                command, _ = self.backend._command("out.mp4", "h264", ratio, "3:2",
                                                    "Alta qualidade", False)
                self.assertEqual(command[command.index("-vf") + 1], crop_filter)

    def test_crop_dimensions_are_even_and_exact_for_4_3_case(self):
        command, _ = self.backend._command("out.mp4", "h264", "4:3", "3:2",
                                            "Alta qualidade", False)
        self.assertEqual(command[command.index("-vf") + 1], "crop=1440:1080:240:0")

    def test_odd_source_dimensions_are_made_encoder_safe(self):
        self.backend._width, self.backend._height = 1921, 1081
        command, _ = self.backend._command("out.mp4", "h264", "Original", "3:2",
                                            "Alta qualidade", False)
        self.assertEqual(command[command.index("-vf") + 1], "crop=1920:1080:0:0")

    def test_custom_crop_and_reposition(self):
        self.backend.setCropRatio("Livre", "3:2")
        initial = self.backend.cropRect
        self.backend.moveCrop(0.6, 0.5)
        moved = self.backend.cropRect
        self.assertLess(moved["x"], initial["x"] + 0.1)
        command, _ = self.backend._command("out.mp4", "h264", "Livre", "3:2",
                                            "Alta qualidade", False)
        self.assertIn("crop=1620:1080:", command[command.index("-vf") + 1])

    def test_invalid_custom_ratio_and_copy_crop_are_rejected(self):
        with self.assertRaisesRegex(ValueError, "Proporção livre inválida"):
            self.backend._command("out.mp4", "h264", "Livre", "x:y",
                                  "Alta qualidade", False)
        with self.assertRaisesRegex(ValueError, "Copiar vídeo"):
            self.backend._command("out.mp4", "copy", "4:3", "3:2",
                                  "Alta qualidade", False)

    def test_target_size_uses_bitrate_and_rejects_stream_copy(self):
        command, _ = self.backend._command("out.mp4", "h264", "Original", "3:2",
                                            "Alta qualidade", False, 20)
        bitrate = int(command[command.index("-b:v") + 1])
        self.assertGreater(bitrate, 1_000_000)
        with self.assertRaisesRegex(ValueError, "stream copy"):
            self.backend._command("out.mp4", "copy", "Original", "3:2",
                                  "Alta qualidade", False, 20)

    def test_export_can_exclude_audio(self):
        self.backend._audio = True
        command, _ = self.backend._command("out.mp4", "h264", "Original", "3:2",
                                            "Alta qualidade", False, include_audio=False)
        self.assertIn("-an", command)
        self.assertNotIn("0:a?", command)
        self.assertNotIn("-c:a", command)

    def test_local_file_url_conversion(self):
        path = SAMPLE_PATH
        url = QUrl.fromLocalFile(path).toString()
        self.assertEqual(self.backend.localPath(url), path)
        self.assertEqual(self.backend.localPath("https://example.com/video.mp4"), "")

    def test_loading_and_exporting_have_distinct_states(self):
        self.backend._set_busy(True)
        self.assertTrue(self.backend.busy)
        self.assertFalse(self.backend.exporting)
        self.backend._set_exporting(True)
        self.assertTrue(self.backend.exporting)
        self.backend._set_exporting(False)
        self.assertTrue(self.backend.busy)
        self.assertFalse(self.backend.exporting)

    def test_opening_new_media_cancels_stale_analysis_but_preview_can_be_cancelled_alone(self):
        old_probe = MagicMock(kind="probe")
        old_preview = MagicMock(kind="preview")
        current_export = MagicMock(kind="export")
        original_tasks = self.backend._tasks
        self.backend._tasks = {object(): old_probe, object(): old_preview,
                               object(): current_export}

        self.backend._cancel_background_tasks("preview")
        old_preview.cancel.assert_called_once_with()
        old_probe.cancel.assert_not_called()
        current_export.cancel.assert_not_called()

        self.backend._cancel_background_tasks()
        old_probe.cancel.assert_called_once_with()
        current_export.cancel.assert_called_once_with()
        self.backend._tasks = original_tasks

    def test_diagnostic_report_lists_encoders_without_media_paths(self):
        self.backend._gpu_devices = [{"vendor": "nvidia", "name": "NVIDIA GeForce RTX 3060 Ti",
                                      "renderNode": ""}]
        self.backend._encoders.update({"h264_nvenc", "hevc_nvenc"})
        report = self.backend.diagnosticReport()
        self.assertIn("FFmpeg:", report)
        self.assertIn("H.264", report)
        self.assertIn("h264_nvenc", report)
        self.assertIn("HEVC", report)
        self.assertNotIn(SAMPLE_PATH, report)

    def test_last_export_directory_is_saved_and_exposed_as_url(self):
        class MemorySettings:
            IniFormat = 1
            UserScope = 0

            def __init__(self, *args):
                self.values = {}

            def value(self, key, default="", type=None):
                return self.values.get(key, default)

            def setValue(self, key, value):
                self.values[key] = value

            def sync(self):
                pass

        with tempfile.TemporaryDirectory() as directory, patch("main.QSettings", MemorySettings):
            backend = ClipBackend()
            try:
                backend.rememberExportDirectory(directory)
                self.assertEqual(backend.lastExportDirectoryUrl.toLocalFile(), directory)
                self.assertEqual(backend._settings.value("export/lastDirectory"), directory)
            finally:
                backend.shutdown()

    def test_kde_palette_reads_distinct_surface_and_button_roles(self):
        with tempfile.TemporaryDirectory() as directory:
            with open(os.path.join(directory, "kdeglobals"), "w", encoding="utf-8") as config:
                config.write("""[Colors:Window]
BackgroundNormal=#141725
BackgroundAlternate=#202235
DecorationFocus=#b5c0ff
[Colors:View]
BackgroundNormal=#0b0e16
ForegroundNormal=#e2e4fc
ForegroundInactive=#717589
ForegroundPositive=#31c193
ForegroundNegative=#ff6a9d
ForegroundNeutral=#ff734a
[Colors:Button]
BackgroundNormal=#1a1d2b
BackgroundAlternate=#202235
DecorationHover=#b5c0ff
[Colors:Selection]
BackgroundNormal=#b5c0ff
BackgroundAlternate=#b5c0ff
DecorationHover=#bdc4f4
ForegroundNormal=#2a3986
[Colors:Tooltip]
BackgroundNormal=#141725
ForegroundNormal=#e2e4fc
""")
            with patch.dict(os.environ, {"XDG_CONFIG_HOME": directory}):
                palette = ClipBackend._read_palette()

        self.assertEqual(palette["bg"], "#141725")
        self.assertEqual(palette["viewbg"], "#0b0e16")
        self.assertEqual(palette["buttonbg"], "#1a1d2b")
        self.assertEqual(palette["buttonalt"], "#202235")
        self.assertEqual(palette["accentHover"], "#bdc4f4")
        self.assertEqual(palette["positive"], "#31c193")

    def test_output_overwrite_is_rejected_without_confirmation(self):
        with tempfile.TemporaryDirectory() as directory:
            path = os.path.join(directory, "existing.mp4")
            with open(path, "wb") as output:
                output.write(b"keep")
            errors = []
            self.backend.exportDone.connect(lambda success, message: errors.append(message))
            self.backend.exportFile(path, "h264", "Original", "3:2",
                                    "Alta qualidade", False)
            self.assertIn("já existe", errors[-1])
            with open(path, "rb") as output:
                self.assertEqual(output.read(), b"keep")

    def test_original_input_cannot_be_export_target(self):
        self.backend._path = os.path.join(tempfile.gettempdir(), "source.mp4")
        errors = []
        self.backend.exportDone.connect(lambda success, message: errors.append(message))
        self.backend.exportFile(self.backend._path, "h264", "Original", "3:2",
                                "Alta qualidade", False)
        self.assertIn("original", errors[-1])

    def test_failed_confirmed_overwrite_preserves_existing_file(self):
        with tempfile.TemporaryDirectory() as directory:
            path = os.path.join(directory, "existing.mp4")
            with open(path, "wb") as output:
                output.write(b"original destination")
            results = []
            self.backend.exportDone.connect(lambda success, message: results.append((success, message)))
            self.backend.exportFile(path, "h264", "Original", "3:2",
                                    "Alta qualidade", False, True)
            deadline = time.monotonic() + 10
            while not results and time.monotonic() < deadline:
                APP.processEvents()
                time.sleep(.01)
            self.assertTrue(results)
            self.assertFalse(results[-1][0])
            with open(path, "rb") as output:
                self.assertEqual(output.read(), b"original destination")
            self.assertEqual(os.listdir(directory), ["existing.mp4"])

    def test_export_queue_snapshots_jobs_and_rejects_duplicate_destinations(self):
        with tempfile.TemporaryDirectory() as directory:
            first = os.path.join(directory, "first.mp4")
            second = os.path.join(directory, "second.mp4")
            self.assertTrue(self.backend.enqueueExport(
                first, "h264", "Original", "3:2", "Alta qualidade", False, 0, False))
            first_job = self.backend._export_queue[0]
            self.backend.setRange(2, 4)
            self.assertTrue(self.backend.enqueueExport(
                second, "h264", "Original", "3:2", "Alta qualidade", False, 0, False))
            second_job = self.backend._export_queue[1]

            self.assertEqual(first_job["command"][first_job["command"].index("-ss") + 1], "1.000000")
            self.assertEqual(second_job["command"][second_job["command"].index("-ss") + 1], "2.000000")
            self.assertEqual(self.backend.queuedExportCount, 2)
            self.assertFalse(self.backend.enqueueExport(
                first, "h264", "Original", "3:2", "Alta qualidade", False, 0, False))
            self.backend.removeQueuedExport(first_job["id"])
            self.assertEqual(self.backend.queuedExportCount, 1)
            self.backend.clearExportQueue()
            self.assertEqual(self.backend.queuedExportCount, 0)

    @unittest.skipUnless(shutil.which("ffmpeg") and shutil.which("ffprobe"),
                         "FFmpeg and ffprobe are required for this integration test")
    def test_export_queue_runs_jobs_sequentially(self):
        with tempfile.TemporaryDirectory() as directory:
            source = os.path.join(directory, "source.mp4")
            subprocess.run([
                "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
                "-f", "lavfi", "-i", "testsrc2=size=128x96:rate=10:duration=1",
                "-c:v", "mpeg4", "-pix_fmt", "yuv420p", source,
            ], check=True, capture_output=True, timeout=20)
            self.backend._path = source
            self.backend._duration = 1.0
            self.backend._width, self.backend._height = 128, 96
            self.backend._fps = 10
            self.backend._start, self.backend._end = 0, 1
            self.backend._audio = False
            self.backend._encoders.add("libx264")
            destinations = [os.path.join(directory, f"cut-{index}.mp4") for index in (1, 2)]
            for destination in destinations:
                self.assertTrue(self.backend.enqueueExport(
                    destination, "h264", "Original", "3:2", "Alta qualidade", False, 0, False))

            self.backend.startExportQueue()
            deadline = time.monotonic() + 30
            while (self.backend.exportQueueRunning or self.backend.exporting) and time.monotonic() < deadline:
                APP.processEvents()
                time.sleep(.01)
            APP.processEvents()

            self.assertFalse(self.backend.exportQueueRunning)
            self.assertEqual([job["status"] for job in self.backend._export_queue], ["done", "done"])
            self.assertTrue(all(os.path.isfile(path) for path in destinations))

    @unittest.skipUnless(shutil.which("ffmpeg") and shutil.which("ffprobe"),
                         "FFmpeg and ffprobe are required for this integration test")
    def test_loading_video_generates_timeline_thumbnails_and_audio_waveform(self):
        with tempfile.TemporaryDirectory() as directory:
            source = os.path.join(directory, "source.mp4")
            subprocess.run([
                "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
                "-f", "lavfi", "-i", "testsrc2=size=320x180:rate=12:duration=2",
                "-f", "lavfi", "-i", "sine=frequency=440:duration=2",
                "-af", "volume='if(lt(mod(t,2),1),1,0.05)':eval=frame",
                "-c:v", "mpeg4", "-pix_fmt", "yuv420p", "-c:a", "aac", "-shortest", source,
            ], check=True, capture_output=True, timeout=20)
            self.backend.loadFile(source)
            deadline = time.monotonic() + 30
            while (not self.backend._thumbnails or not self.backend._waveform) and time.monotonic() < deadline:
                APP.processEvents()
                time.sleep(.01)
            APP.processEvents()

            self.assertTrue(self.backend._thumbnails, self.backend.status)
            self.assertTrue(self.backend._waveform, self.backend.status)
            self.assertEqual(self.backend._thumbnail_status, "ready")
            self.assertEqual(self.backend._waveform_status, "ready")
            images = []
            for url in (self.backend._thumbnails[0]["url"], self.backend._waveform):
                path = QUrl(url).toLocalFile()
                self.assertTrue(os.path.isfile(path))
                reader = QImageReader(path)
                self.assertTrue(reader.canRead(), reader.errorString())
                image = reader.read()
                self.assertFalse(image.isNull(), reader.errorString())
                images.append(image)

            waveform = images[1]
            self.assertEqual((waveform.width(), waveform.height()), (2400, 80))
            alpha_per_column = [
                sum(waveform.pixelColor(x, y).alpha() > 0 for y in range(waveform.height()))
                for x in range(waveform.width())
            ]
            loud_section = sum(alpha_per_column[240:1080]) / 840
            quiet_section = sum(alpha_per_column[1320:2160]) / 840
            self.assertGreater(loud_section, quiet_section * 2,
                               "Waveform must retain changes in audio amplitude")
            self.wait_for_tasks_to_finish()

    @unittest.skipUnless(shutil.which("ffmpeg") and shutil.which("ffprobe"),
                         "FFmpeg and ffprobe are required for this integration test")
    def test_video_without_audio_still_generates_visible_thumbnail_asset(self):
        with tempfile.TemporaryDirectory() as directory:
            source = os.path.join(directory, "silent.mp4")
            subprocess.run([
                "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
                "-f", "lavfi", "-i", "testsrc2=size=320x180:rate=12:duration=2",
                "-c:v", "mpeg4", "-pix_fmt", "yuv420p", source,
            ], check=True, capture_output=True, timeout=20)
            self.backend.loadFile(source)
            deadline = time.monotonic() + 20
            while (self.backend._thumbnail_status != "ready" and
                   self.backend._thumbnail_status != "error" and time.monotonic() < deadline):
                APP.processEvents()
                time.sleep(.01)
            APP.processEvents()

            self.assertEqual(self.backend._thumbnail_status, "ready", self.backend.status)
            self.assertFalse(self.backend.hasAudio)
            self.assertEqual(self.backend._waveform_status, "none")
            self.assertTrue(QImageReader(QUrl(self.backend._thumbnails[0]["url"]).toLocalFile()).canRead())
            self.wait_for_tasks_to_finish()


if __name__ == "__main__":
    unittest.main()
