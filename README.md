<p align="center">
  <img src="assets/branding/clipcut-split-timeline-smooth.svg" alt="ClipCut logo" width="88" height="88">
</p>

<h1 align="center">ClipCut</h1>

<p align="center">A video clip editor for Windows and Linux. Trim, crop, and export video locally.</p>

<p align="center">
  <a href="#download">Download</a> ·
  <a href="#how-to-use">How to use</a> ·
  <a href="https://github.com/Luiz-Wendland/clipcut/issues">Report an issue</a>
</p>

<p align="center">
  <a href="requirements.txt"><img src="https://img.shields.io/badge/Python_%C2%B7_Qt_Quick-b8a4ed" alt="Python and Qt Quick"></a>
  <a href="https://github.com/Luiz-Wendland/clipcut/releases/latest"><img src="https://img.shields.io/badge/Windows_%C2%B7_Linux-24292f" alt="Windows and Linux"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-b8a4ed" alt="MIT license"></a>
</p>

https://github.com/user-attachments/assets/d6869850-90fa-4b82-ad44-f9b1bd8cca2f

ClipCut started as a personal project for making quick cuts without opening a full video editor. It turned out to be useful enough to share, so I published it.

## Download

| Windows | Linux |
|---|---|
| [MSI installer](https://github.com/Luiz-Wendland/clipcut/releases/latest/download/ClipCut-windows-x86_64.msi) | [AppImage](https://github.com/Luiz-Wendland/clipcut/releases/latest/download/ClipCut-x86_64.AppImage) |
| [Portable ZIP](https://github.com/Luiz-Wendland/clipcut/releases/latest/download/ClipCut-windows-x86_64.zip) | [tar.gz](https://github.com/Luiz-Wendland/clipcut/releases/latest/download/ClipCut-linux-x86_64.tar.gz) |

These **x86_64** packages include Python and Qt. **Install FFmpeg and ffprobe separately and make sure both are on your `PATH`.**

Extract the ZIP and open `main.exe`, or extract the tar.gz and run `./ClipCut`. Make the AppImage executable before opening it. The MSI requires administrator privileges. Windows packages are not digitally signed.

[All releases](https://github.com/Luiz-Wendland/clipcut/releases).

English and Brazilian Portuguese are available starting with v0.3.0. Open **Preferences → Language** to switch immediately. ClipCut remembers your choice. **System default** follows the system's preferred supported language and falls back to English.

## How to use

1. Open a video or drag it into the window.
2. Set in and out points on the timeline using the thumbnails and audio waveform.
3. Use **Crop** to choose an aspect ratio and drag the crop frame. The panel shows the output dimensions, for example `1920 × 1080 → 1920 × 822`.
4. In **Export**, choose a codec, quality, and destination. Export the clip or add it to the queue.

Aspect ratios: Original, 4:3, 16:9, 21:9, 9:16, 1:1, 4:5, or **Custom** (for example, `3:2`). Changing the ratio preserves the crop position; use **Center crop** to reset it.

**Shortcuts:** Space to play or pause, I/O to set in and out points, and ←/→ to step one frame backward or forward.

H.264, HEVC, AV1, and GPU encoding depend on the encoders and drivers available. Stream copy trims at keyframes and does not support cropping. Target file size is an estimate. Videos with rotation metadata and anamorphic video are cropped as displayed.

## Run from source

Requires Python 3.10+, PySide6 6.8+, FFmpeg, and ffprobe.

```sh
python -m pip install -r requirements.txt
python main.py
```

Run the tests:

```sh
python -m unittest discover -s tests -v
```

## License

[MIT](LICENSE). Qt/PySide6 and FFmpeg are distributed under their own licenses.
