import argparse
import importlib
import trio
from kivy.config import Config
from kivy.app import App


class CanvasPreviewApp(App):
    def build(self):
        import figma_canvas_preview.generated as gen
        importlib.reload(gen)
        return gen.preview


def main() -> None:
    parser = argparse.ArgumentParser(description="Figma canvas preview")
    parser.add_argument("--width",  type=int, default=800)
    parser.add_argument("--height", type=int, default=600)
    args = parser.parse_args()

    Config.set("graphics", "width",     str(args.width))
    Config.set("graphics", "height",    str(args.height))
    Config.set("graphics", "resizable", "0")

    trio.run(CanvasPreviewApp().async_run, "trio")
