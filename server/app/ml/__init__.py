"""Model serving: lung mask -> TB classifier -> Grad-CAM.

Imported lazily (by the worker only) so the web app and its tests do not need
PyTorch. Preprocessing here must stay identical to what the classifier was
trained with (pipline/training/train_classifier.py).
"""
