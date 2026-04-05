import importlib
import trio
from kivy.app import App


class CanvasPreviewApp(App):
    def build(self):
        import figma_canvas_preview.generated as gen
        importlib.reload(gen)
        return gen.preview


def main() -> None:
    trio.run(CanvasPreviewApp().async_run, "trio")
