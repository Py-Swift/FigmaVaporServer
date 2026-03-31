import trio
from kivy.lang import Builder

from kivy_reloader.app import App


class PreviewApp(App):
    def build(self):
        return Builder.load_file(f"{__file__}/../preview.kv")


def main() -> None:
    
    app = PreviewApp()
    trio.run(app.async_run, "trio")
