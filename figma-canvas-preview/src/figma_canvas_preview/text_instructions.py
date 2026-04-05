from kivy.graphics import Rectangle, Color, InstructionGroup
from kivy.core.text import Label as CoreLabel

class Text(Rectangle):
    label: CoreLabel # type: ignore
    def __init__(self,text: str, **kwargs):
        self.text = text
        pos = kwargs.pop("pos", (0, 0))
        label = CoreLabel(**kwargs)
        self.label = label
        label.text = text
        label.refresh()
        tex = label.texture
        super().__init__(texture=tex, size=tex.size, pos=pos)

    def update(self):
        label = self.label
        
        label.refresh()
        texture = label.texture
        self.texture = texture


    @property
    def text(self) -> str:
        return self.label.text
    
    @text.setter
    def text(self, value: str):
        self.label.text = value

    
    @property
    def font_size(self) -> int:
        return self.label.font_size
    
    @font_size.setter
    def font_size(self, value: int):
        self.label.font_size = value

    @property
    def font_name(self) -> str:
        return self.label.font_name
    
    @font_name.setter
    def font_name(self, value: str):
        self.label.font_name = value