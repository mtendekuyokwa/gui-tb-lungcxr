"""The one copy of image loading and preprocessing shared by every model step."""

import numpy as np
import torch
from PIL import Image

SIZE = 512
IMAGENET_MEAN = torch.tensor([0.485, 0.456, 0.406]).view(3, 1, 1)
IMAGENET_STD = torch.tensor([0.229, 0.224, 0.225]).view(3, 1, 1)


def load_gray(path):
    """The image as a PIL greyscale ("L") image at its original size."""
    with Image.open(path) as image:
        return image.convert("L")


def segmenter_input(gray):
    """Input for the lung segmentation model.

    Mirrors the transforms in segment_lung_cxr/inference/inference_lung_segment.py:
    the array is transposed to (W, H) as that code does, resized bilinearly,
    min-max scaled to 0..1, repeated to 3 channels and ImageNet-normalised.
    """
    array = torch.from_numpy(np.asarray(gray, dtype=np.float32)).T[None, None]
    array = torch.nn.functional.interpolate(
        array, size=(SIZE, SIZE), mode="bilinear", align_corners=False
    )[0]
    low, high = array.min(), array.max()
    array = (array - low) / (high - low) if high > low else torch.zeros_like(array)
    return ((array.repeat(3, 1, 1) - IMAGENET_MEAN) / IMAGENET_STD)[None]


def classifier_arrays(gray, mask):
    """The masked 512x512 image (0..1) and the resized mask (0..1).

    Same steps as MaskedCXRDataset in the training script: PIL resize of both
    the image and the 0/255 mask with PIL's default filter, then multiply.
    """
    image = np.asarray(gray.resize((SIZE, SIZE)), dtype=np.float32) / 255.0
    mask_image = Image.fromarray(mask.astype(np.uint8) * 255)
    mask_small = np.asarray(mask_image.resize((SIZE, SIZE)), dtype=np.float32) / 255.0
    return image * mask_small, mask_small


def classifier_input(masked):
    """3-channel tensor normalised with mean 0.5, std 0.5, as in training."""
    tensor = torch.from_numpy(np.stack([masked] * 3, axis=0))
    return ((tensor - 0.5) / 0.5)[None]
