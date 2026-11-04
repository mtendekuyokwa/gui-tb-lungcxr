"""Bakes a doctor's lung-mask corrections into a new mask image.

The edits are the review's ``mask_edits``: strokes with image-relative
(0..1) points and a width that is a fraction of the image width. ``add``
strokes paint lung in, ``erase`` strokes cut it away, in order. The result
feeds the classifier when the case is re-evaluated (see ``worker.py``).
"""

import pathlib

from flask import current_app
from PIL import Image, ImageDraw

LUNG = 255
BACKGROUND = 0


def bake(base_relative, edits, out_relative):
    """Writes the base mask with ``edits`` applied to ``out_relative``.

    Both paths are relative to the storage directory. The output keeps the
    base mask's size, which is the original image's.
    """
    storage = pathlib.Path(current_app.config["STORAGE_DIR"])
    with Image.open(storage / base_relative) as base:
        mask = base.convert("L").point(lambda v: LUNG if v > 127 else BACKGROUND)
    draw = ImageDraw.Draw(mask)
    width, height = mask.size
    for edit in edits:
        fill = LUNG if edit.kind == "add" else BACKGROUND
        stroke = max(1, round(edit.width * width))
        points = [(x * width, y * height) for x, y in edit.points]
        if len(points) > 1:
            draw.line(points, fill=fill, width=stroke, joint="curve")
        # Round caps (and single taps), matching the Flutter painter.
        radius = stroke / 2
        for x, y in points:
            draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=fill)
    out = storage / out_relative
    out.parent.mkdir(parents=True, exist_ok=True)
    mask.save(out, format="PNG")
    return out_relative
