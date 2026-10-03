import warnings

import numpy as np
import torch
from scipy import ndimage

from . import preprocess


class Segmenter:
    """Lung mask from the NIH TorchScript model (`..._including_heart_512.pt`)."""

    def __init__(self, model_path, threshold=0.5):
        with warnings.catch_warnings():
            # torch.jit.load warns on Python 3.14; the scripted model still loads.
            warnings.simplefilter("ignore", FutureWarning)
            self.model = torch.jit.load(str(model_path), map_location="cpu").eval()
        self.threshold = threshold

    @torch.no_grad()
    def mask(self, gray):
        """Boolean array (H, W) at the image's original size."""
        logits = self.model(preprocess.segmenter_input(gray))
        # Channel 1 is the lung class; undo the (W, H) transpose from the input.
        probability = torch.sigmoid(logits)[0, 1].T[None, None]
        width, height = gray.size
        probability = torch.nn.functional.interpolate(
            probability, size=(height, width), mode="bilinear", align_corners=False
        )[0, 0]
        return _two_largest_filled(probability.numpy() > self.threshold)


def _two_largest_filled(mask):
    """Keep the two largest connected regions (the lungs) and fill their holes."""
    labels, count = ndimage.label(mask)
    if count == 0:
        return mask
    sizes = ndimage.sum_labels(mask, labels, index=np.arange(1, count + 1))
    keep = np.argsort(sizes)[::-1][:2] + 1
    return ndimage.binary_fill_holes(np.isin(labels, keep))
