"""Bake one deterministic, tileable RGB mask; no noise generation during play.

R: multiscale chip threshold, G: directional scratches, B: dirt/smoke variation.
Original procedural asset for Ion Rush; requires Pillow and NumPy.
"""
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SIZE = 512
rng = np.random.default_rng(90419)
frequency = np.fft.fftfreq(SIZE)
radius = frequency[:, None] ** 2 + frequency[None, :] ** 2

def noise(scale):
    spectrum = np.fft.fft2(rng.normal(size=(SIZE, SIZE)))
    value = np.fft.ifft2(spectrum * np.exp(-radius * scale * scale * 20)).real
    return (value - value.mean()) / value.std()

chips = noise(32) * .65 + noise(5) * .24 + noise(.8) * .11
chips = np.clip(.52 + chips * .15, 0, 1)
dirt = np.clip(.5 + noise(15) * .19 + noise(3) * .06, 0, 1)
scratches = Image.new("L", (SIZE, SIZE))
draw = ImageDraw.Draw(scratches)
for _ in range(160):
    x, y = rng.integers(0, SIZE, size=2)
    length = int(rng.integers(8, 115))
    lean = int(rng.integers(-12, 13))
    strength = int(rng.integers(90, 256))
    for sx in [-SIZE, 0, SIZE]:
        for sy in [-SIZE, 0, SIZE]:
            draw.line([(int(x + sx), int(y + sy)),
                       (int(x + sx + lean), int(y + sy + length))],
                      fill=strength, width=int(rng.choice([1, 1, 2, 3])))
scratches = scratches.filter(ImageFilter.GaussianBlur(.45))
packed = np.stack([chips * 255, np.asarray(scratches), dirt * 255], axis=-1).astype(np.uint8)
destination = Path(__file__).resolve().parents[1] / "assets" / "paint-wear.png"
Image.fromarray(packed).save(destination)
print(destination)
