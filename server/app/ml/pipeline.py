import pathlib
from dataclasses import dataclass

import numpy as np
from PIL import Image

from . import preprocess
from .classifier import Classifier
from .segmenter import Segmenter

SEGMENTER_FILE = "cxr_lung_segment_including_heart_512.pt"
CLASSIFIER_FILE = "tb_classifier.pth"
# Below this share of the image, the "lungs" are not lungs.
MIN_LUNG_FRACTION = 0.02


class ModelError(Exception):
    """The models could not give a meaningful reading for this image."""


@dataclass
class Reading:
    label: str
    tb_probability: float
    mask: Image.Image  # "L", 0/255, original image size
    overlay: Image.Image  # RGBA heatmap, 512x512, transparent where the model did not look


def heatmap_overlay(cam, mask_small):
    """Jet-coloured Grad-CAM, with opacity following the activation inside the lungs."""
    r = np.clip(1.5 - np.abs(4 * cam - 3), 0, 1)
    g = np.clip(1.5 - np.abs(4 * cam - 2), 0, 1)
    b = np.clip(1.5 - np.abs(4 * cam - 1), 0, 1)
    alpha = cam * mask_small
    rgba = np.stack([r, g, b, alpha], axis=-1)
    return Image.fromarray((rgba * 255).astype(np.uint8), mode="RGBA")


class Pipeline:
    """Loads both models once; `read` runs mask -> classifier -> Grad-CAM."""

    def __init__(self, models_dir):
        models_dir = pathlib.Path(models_dir)
        missing = [f for f in (SEGMENTER_FILE, CLASSIFIER_FILE)
                   if not (models_dir / f).is_file()]
        if missing:
            raise FileNotFoundError(f"Model files missing from {
                                    models_dir}: {', '.join(missing)}")
        self.segmenter = Segmenter(models_dir / SEGMENTER_FILE)
        self.classifier = Classifier(models_dir / CLASSIFIER_FILE)

    def read(self, image_path, mask_path=None):
        """Reads one X-ray. With ``mask_path`` (a doctor-corrected lung mask,
        0/255 PNG) the segmenter is skipped and that mask is used instead."""
        gray = preprocess.load_gray(image_path)
        if mask_path is None:
            mask = self.segmenter.mask(gray)
        else:
            with Image.open(mask_path) as given:
                mask = np.asarray(
                    given.convert("L").resize(gray.size, Image.NEAREST)) > 127
        assert mask is not None
        if mask.mean() < MIN_LUNG_FRACTION:
            raise ModelError("No lungs found in the image.")
        masked, mask_small = preprocess.classifier_arrays(gray, mask)
        label, tb_probability, cam = self.classifier.predict(masked)
        # The heatmap is blended over the mask at the overlay (SIZE) resolution.
        mask_big = np.asarray(
            Image.fromarray((mask_small * 255).astype(np.uint8)).resize(
                (preprocess.SIZE, preprocess.SIZE), Image.BILINEAR),
            dtype=np.float32) / 255.0
        return Reading(
            label=label,
            tb_probability=tb_probability,
            mask=Image.fromarray(mask.astype(np.uint8) * 255),
            overlay=heatmap_overlay(cam, mask_big),
        )
