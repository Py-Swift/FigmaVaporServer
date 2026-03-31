# figma-canvas-preview

Live preview app for figma2kv canvas-py output.

Polls `GET http://localhost:8765/canvas-py/last` every second, dynamically `exec`s the returned code, finds the first generated Widget subclass, and displays it full-screen.

## Usage

```bash
uv run preview
```

Make sure `FigmaVaporServer` is running on port 8765, and send at least one canvas-py generation from the Figma plugin.
