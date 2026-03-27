# FigmaVaporServer

Vapor server that receives Figma node JSON from the [figma4kivy](https://github.com/Py-Swift/figma4kivy) plugin and converts it to Kivy `.kv` layout code.

## Requirements

- Xcode 26+
- macOS 15+

## Run

```bash
swift run
```

Server starts on `http://localhost:8080`.

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/kv` | Convert Figma nodes JSON → `.kv` string |
| `POST` | `/json-dump` | Pretty-print received nodes (debug) |
| `WS`   | `/ws` | Persistent WebSocket from Figma plugin |
