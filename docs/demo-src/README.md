# Demo animation source

`demo.html` draws each frame with `render(t)`; `capture.py` screenshots it with Playwright, then:

```bash
ffmpeg -framerate 12 -i f/%04d.png -vf "palettegen=max_colors=96:stats_mode=diff" pal.png
ffmpeg -framerate 12 -i f/%04d.png -i pal.png -lavfi "paletteuse=dither=none:diff_mode=rectangle" -loop 0 demo.gif
```

Needs `fonts/` with Inter and Noto Sans Thai (400/600 `.woff`, from @fontsource) and `icon_256.png` next to the HTML.
Every sentence shown in the demo is checked against `tests/ref.py` so the animation only shows what the app really does.
