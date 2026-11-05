# ClipCut interface mapping (QML → Remotion)

The QML application remains the source of truth. The promo recreates only the visual states required for the launch video; no Python backend, Qt runtime, or real media export is executed in the composition.

| QML source | QML details used | Remotion representation |
|---|---|---|
| `DesignTokens.qml` | ClipCut dark palette, lavender accent, radii, spacing, type scale, outer margin, toolbar/timeline dimensions | `src/design/tokens.json`, extracted by `scripts/extract-tokens.py`; `src/design/index.ts` adds only semantic aliases derived from those values |
| `Main.qml` toolbar | Branding, project/file title, status pill, Preferences and Export actions | Header in `src/components/ClipCutWindow.tsx` |
| `Main.qml` workspace / `ToolTab.qml` | 72 px rail, Corte / Enquadrar / Áudio selection and active state | Navigation rail in `ClipCutWindow.tsx` |
| `Main.qml` preview | rounded `#090a0d` viewport, aspect-fit image, crop mask and transport pill | `PreviewArtwork.tsx`, player overlay and `CropFrame` in `ClipCutWindow.tsx` |
| `ClipTimeline.qml` | IN/OUT time fields, duration, zoom, selected range, dimmed outside region, playhead, thumbnails, waveform | Timeline panel in `ClipCutWindow.tsx`; frame-driven `inPoint`, `outPoint` and `playhead` props |
| `ToolInspector.qml` | Crop ratio choices, center action, audio inclusion and preview volume | Inspector panel in `ClipCutWindow.tsx`; only relevant controls are shown per scene |
| `ExportPopover.qml` | H.264/HEVC/AV1/copy, CPU/GPU, quality, ratio and output summary | Export sheet in `ClipCutWindow.tsx`; progress is a visual animation only |
| `ProgressRail.qml` | Bounded accent progress fill | Export-sheet progress rail |
| `ActionButton.qml` | Tonal/primary/quiet states, compact dimensions, pill and rounded-medium radii | `Button` and `Chip` primitives in `ClipCutWindow.tsx` |
| `assets/branding/clipcut-split-timeline-smooth.svg` | Original layered gradient mark | Copied unmodified to `public/clipcut-brand.svg` by `scripts/copy-brand.mjs` |

## Faithfulness and simulation notes

- Colors and fixed layout values are extracted from `DesignTokens.qml`; the promo does not maintain a separate hand-edited copy of the palette.
- QML animations are visual references. Remotion reproduces selected motion deterministically from frame numbers rather than executing QML's event loop.
- The preview landscape, timeline thumbnails and waveform are original generated illustrations for this video. They are not sample media shipped with the editor and make no claim about real playback/export performance.
- The shown H.264/HEVC/AV1 options, CPU/GPU preference, framing ratios, source duration, and progress state mirror controls and concepts present in the ClipCut source. GPU availability is intentionally not asserted.
- Several UI labels are represented in a compact launch-video layout; this is not a full QML-to-React port or a substitute for the actual application.
- V2 adds editorial typography, camera framing, an animated filmstrip, a background grid and a simulated cursor outside the app replica. These are promotional motion graphics, not QML features. Simulated export progress is explicitly labeled as illustrative in the video.
- The original 120 BPM score and transition/click sounds are generated from sine waves and seeded noise by `scripts/create-soundtrack.py`, not captured from the app or sourced from music libraries. They accompany the full MP4 only; the README GIF remains silent.
