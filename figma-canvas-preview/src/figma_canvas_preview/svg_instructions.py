from kivy.graphics import Rectangle, Color, InstructionGroup
from kivy.core.text import Label as CoreLabel
from kivy.graphics.texture import Texture, create_texture
from thorvg_cython.sw_canvas import SwCanvas
from thorvg_cython.thorvg import Shape, Picture


class Svg(Rectangle):

    swc: SwCanvas

    def __init__(self,x, y, width: int, height: int, path: str):
        size = (width, height)
        
        tex = Texture.create(size=(width, height), colorfmt='rgba')
        swc = SwCanvas(width, height)

        pic = Picture()
        
        pic.load(path)
        pic.set_size(width, height)
        swc.add(pic)

        swc.sync()
        swc.draw()
        
        tex.blit_buffer(swc, colorfmt='rgba', bufferfmt='ubyte')
        

        self.swc = swc
        self.pic = pic
        super().__init__(texture=tex, size=size, pos=(x, y))


    def resize(self, width: int, height: int):
        swc = self.swc
        tex = Texture.create(size=(width, height), colorfmt='rgba')
        swc.resize(width, height)
        swc.sync()
        swc.draw()
        tex.blit_buffer(swc, colorfmt='rgba', bufferfmt='ubyte')
        self.texture = tex
        self.size = (width, height)
