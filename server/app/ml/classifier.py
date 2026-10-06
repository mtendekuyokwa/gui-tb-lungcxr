import numpy as np
import torch
from torch import nn
from torchvision import models

from . import preprocess

LABELS = ("normal", "tb")  # index 1 is TB, as in training (has_tb)


class Classifier:
    """ResNet18 with the Dropout + Linear head from pipline/training."""

    def __init__(self, checkpoint_path):
        model = models.resnet18(weights=None)
        model.fc = nn.Sequential(nn.Dropout(0.3), nn.Linear(model.fc.in_features, 2))
        checkpoint = torch.load(str(checkpoint_path), map_location="cpu", weights_only=True)
        model.load_state_dict(checkpoint.get("model_state_dict", checkpoint))
        self.model = model.eval()

    def predict(self, masked):
        """(label, TB probability, Grad-CAM heatmap 512x512 in 0..1).

        The heatmap explains the predicted class and is taken from the last
        ResNet block, like the pipeline's Grad-CAM job.
        """
        captured = {}
        layer = self.model.layer4[-1]
        handle = layer.register_forward_hook(
            lambda _module, _inputs, output: captured.update(activations=output)
        )
        try:
            logits = self.model(preprocess.classifier_input(masked))
        finally:
            handle.remove()
        probabilities = torch.softmax(logits, dim=1)[0]
        index = int(probabilities.argmax())

        activations = captured["activations"]
        (gradients,) = torch.autograd.grad(logits[0, index], activations)
        weights = gradients.mean(dim=(2, 3), keepdim=True)
        cam = torch.relu((weights * activations).sum(dim=1, keepdim=True)).detach()
        low, high = cam.min(), cam.max()
        cam = (cam - low) / (high - low) if high > low else torch.zeros_like(cam)
        cam = torch.nn.functional.interpolate(
            cam, size=(preprocess.SIZE, preprocess.SIZE), mode="bilinear", align_corners=False
        )[0, 0]
        return LABELS[index], probabilities[1].item(), np.clip(cam.numpy(), 0, 1)
