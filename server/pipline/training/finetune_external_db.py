#!/usr/bin/env python3
"""Fine-tune the served TB classifier on an external CXR database.

Motivation: the model trained on the lab's own NIH/TB-portal exports is
massively over-confident there (train loss ~4e-4) and collapses to
"normal" with p(TB) ~ 1e-5 on every image of other databases.

This script fine-tunes the checkpoint the server actually serves, using
the server's own pipeline steps so training and inference stay consistent:

    image -> Segmenter (`cxr_lung_segment_including_heart_512.pt`)
          -> multiply by the lung mask
          -> resize, 3-channel, Normalize(0.5, 0.5)   [app.ml.preprocess]

Masks are computed once and cached on disk; caching runs in worker
subprocesses (`--mask-worker`) so TorchScript models never share state
through a fork.

Usage (from server/):
    .venv/bin/python pipline/training/finetune_external_db.py \
        --data-dir ~/Downloads/imgs-testing/TB_Chest_Radiography_Database
"""

import argparse
import collections
import json
import math
import pathlib
import random
import subprocess
import sys

import numpy as np
import torch
import torch.nn as nn
from PIL import Image
from torch.utils.data import DataLoader, Dataset


def roc_auc(labels, probs):
    """Rank-based AUC (no sklearn dependency)."""
    labels, probs = np.asarray(labels), np.asarray(probs)
    order = np.argsort(probs)
    ranks = np.empty_like(order, dtype=np.float64)
    ranks[order] = np.arange(1, len(probs) + 1)
    # average ranks for ties
    sorted_probs = probs[order]
    i = 0
    while i < len(sorted_probs):
        j = i
        while j + 1 < len(sorted_probs) and sorted_probs[j + 1] == sorted_probs[i]:
            j += 1
        if j > i:
            ranks[order[i:j + 1]] = (i + 1 + j + 1) / 2.0
        i = j + 1
    pos, neg = labels == 1, labels == 0
    if not pos.any() or not neg.any():
        return float("nan")
    return float((ranks[pos].sum() - pos.sum() * (pos.sum() + 1) / 2) / (pos.sum() * neg.sum()))

SERVER_DIR = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(SERVER_DIR))

from app.ml import preprocess  # noqa: E402

TB_DIR = "Tuberculosis"
NORMAL_DIR = "Normal"


def list_images(data_dir, per_class):
    """Stratified selection: every TB image plus an equal, seeded normal sample."""
    data_dir = pathlib.Path(data_dir).expanduser()
    tb = sorted((data_dir / TB_DIR).glob("*.png"))
    normal = sorted((data_dir / NORMAL_DIR).glob("*.png"))
    rng = random.Random(42)
    normals = normal if per_class <= 0 else rng.sample([str(p) for p in normal], per_class)
    normals = [pathlib.Path(p) for p in normals]
    return [(p, 1) for p in tb] + [(p, 0) for p in normals]


def mask_cache_path(cache_dir, path):
    """Cache location mirroring <class-folder>/<name>.png."""
    rel = f"{path.parent.name}/{path.name}"
    return pathlib.Path(cache_dir) / rel, rel


def precompute_masks(data_dir, cache_dir, per_class, shards, shard):
    items = list_images(data_dir, per_class)
    from app.ml.pipeline import Pipeline  # after sys.path is set

    pipeline = Pipeline(str(SERVER_DIR / "models"))
    cache_dir = pathlib.Path(cache_dir)
    done = 0
    for i, (path, _label) in enumerate(items):
        if i % shards != shard:
            continue
        _d, rel = mask_cache_path(cache_dir, path)
        out = cache_dir / rel
        if out.is_file():
            continue
        out.parent.mkdir(parents=True, exist_ok=True)
        gray = preprocess.load_gray(path)
        mask = pipeline.segmenter.mask(gray)
        Image.fromarray((mask.astype(np.uint8) * 255)).save(out, format="PNG")
        done += 1
        if done % 25 == 0:
            print(f"[shard {shard}/{shards}] {i + 1}/{len(items)} cached", flush=True)
    print(f"[shard {shard}/{shards}] done ({done} new masks)", flush=True)


class MaskedCXRDataset(Dataset):
    """Masked, classifier-resolution inputs from the on-disk mask cache."""

    def __init__(self, items, cache_dir, augment):
        self.items = items
        self.cache_dir = pathlib.Path(cache_dir)
        self.augment = augment
        self.norm = preprocess.classifier_input  # (0.5, 0.5) like the server

    def __len__(self):
        return len(self.items)

    def __getitem__(self, idx):
        path, label = self.items[idx]
        _d, rel = mask_cache_path(self.cache_dir, path)
        mask = np.asarray(Image.open(self.cache_dir / rel).convert("L"))
        mask = (mask > 127).astype(np.float32)

        with Image.open(path) as image:  # the raw upload (the DB is 512x512)
            gray = image.convert("L")
        masked, _ = preprocess.classifier_arrays(gray, mask)
        tensor = self.norm(masked)[0]

        if self.augment:
            geometry = torch.nn.functional
            if random.random() < 0.5:
                tensor = torch.flip(tensor, dims=(2,))
            angle = random.uniform(-15, 15)
            tensor = _rotate(tensor, angle)
            scale = random.uniform(0.9, 1.0)
            tensor = _scale(tensor, scale)
            tensor = _shift(tensor, 0.05)
            jitter = random.uniform(-0.25, 0.25)
            tensor = (tensor + jitter).clamp(-1, 1)
        return tensor, label


def _rotate(tensor, degrees):
    """Nearest-neighbour rotate about the centre (no grid_sample padding tricks)."""
    img = Image.fromarray(((tensor[0] + 1) * 127.5).clamp(0, 255).numpy().astype(np.uint8))
    rotated = img.rotate(degrees, resample=Image.BILINEAR)
    back = np.asarray(rotated, dtype=np.float32) / 127.5 - 1.0
    return torch.from_numpy(np.stack([back] * 3))


def _scale(tensor, scale_factor):
    img = Image.fromarray(((tensor[0] + 1) * 127.5).clamp(0, 255).numpy().astype(np.uint8))
    w = int(img.width * scale_factor) or 1
    h = int(img.height * scale_factor) or 1
    resized = img.resize((w, h), Image.BILINEAR)
    canvas = Image.new("L", (img.width, img.height), 0)
    canvas.paste(resized, ((img.width - w) // 2, (img.height - h) // 2))
    back = np.asarray(canvas, dtype=np.float32) / 127.5 - 1.0
    return torch.from_numpy(np.stack([back] * 3))


def _shift(tensor, fraction):
    import torch.nn.functional as F

    pixels = int(tensor.shape[-1] * fraction)
    dx = random.randint(-pixels, pixels)
    dy = random.randint(-pixels, pixels)
    return torch.roll(tensor, shifts=(dy, dx), dims=(1, 2))


def split(items, seed=42):
    """80/10/10 stratified by class."""
    rng = random.Random(seed)
    by_class = collections.defaultdict(list)
    for path, label in items:
        by_class[label].append((path, label))
    train, val, test = [], [], []
    for label in sorted(by_class):
        group = sorted((str(p), l) for p, l in by_class[label])
        rng.shuffle(group)
        group = [(pathlib.Path(p), l) for p, l in group]
        n = len(group)
        n_val = max(1, int(0.10 * n))
        n_test = max(1, int(0.10 * n))
        val += group[:n_val]
        test += group[n_val:n_val + n_test]
        train += group[n_val + n_test:]
    return train, val, test


@torch.no_grad()
def evaluate(model, loader, device):
    model.eval()
    probs, labels = [], []
    for tensors, targets in loader:
        out = model(tensors.to(device))
        probs += torch.softmax(out, dim=1)[:, 1].cpu().tolist()
        labels += targets
    probs, labels = np.array(probs), np.array(labels)
    preds = (probs > 0.5).astype(int)
    acc = float((preds == labels).mean())
    sens = float(preds[labels == 1].mean()) if (labels == 1).any() else float("nan")
    spec = float((preds[labels == 0] == 0).mean()) if (labels == 0).any() else float("nan")
    auc = roc_auc(labels, probs)
    return {"accuracy": acc, "sensitivity": sens, "specificity": spec, "auc": auc,
            "prob_mean": float(probs.mean()), "abstain_gap": float(np.abs(probs - labels).mean())}


def train(args):
    torch.set_num_threads(args.threads)
    device = torch.device("cpu")
    items = [(p, l) for p, l in list_images(args.data_dir, args.per_class)]
    train_items, val_items, test_items = split(items, seed=42)
    print(f"train {len(train_items)} | val {len(val_items)} | test {len(test_items)}", flush=True)

    from torchvision import models

    def build():
        model = models.resnet18(weights=None)
        model.fc = nn.Sequential(nn.Dropout(0.3), nn.Linear(model.fc.in_features, 2))
        return model

    model = build()
    checkpoint = torch.load(str(args.checkpoint), map_location="cpu", weights_only=True)
    model.load_state_dict(checkpoint.get("model_state_dict", checkpoint))
    print("loaded", args.checkpoint, flush=True)

    train_ds = MaskedCXRDataset(train_items, args.mask_cache, augment=True)
    val_ds = MaskedCXRDataset(val_items, args.mask_cache, augment=False)
    test_ds = MaskedCXRDataset(test_items, args.mask_cache, augment=False)
    train_loader = DataLoader(train_ds, batch_size=args.batch, shuffle=True, drop_last=True)
    val_loader = DataLoader(val_ds, batch_size=args.batch)
    test_loader = DataLoader(test_ds, batch_size=args.batch)

    print("baseline on this database:",
          json.dumps(evaluate(model, test_loader, device)), flush=True)

    criterion = nn.CrossEntropyLoss(label_smoothing=0.1)
    optimizer = torch.optim.AdamW(model.parameters(), lr=args.lr, weight_decay=1e-4)
    scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=len(train_loader) * args.epochs)
    scaler = None  # CPU training

    out_dir = pathlib.Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    history = []
    best_val_loss = float("inf")
    patience = args.patience
    wait = 0

    for epoch in range(1, args.epochs + 1):
        model.train()
        running = correct = seen = 0.0
        for tensors, targets in train_loader:
            optimizer.zero_grad()
            out = model(tensors)
            loss = criterion(out, torch.tensor(targets))
            loss.backward()
            optimizer.step()
            scheduler.step()
            running += loss.item() * len(targets)
            correct += (out.argmax(1).numpy() == np.array(targets)).sum()
            seen += len(targets)
        val = evaluate(model, val_loader, device)
        history.append({"epoch": epoch, "train_loss": running / seen,
                        "train_acc": correct / seen, **{f"val_{k}": v for k, v in val.items()}})
        print(f"epoch {epoch}/{args.epochs}: train_loss={running/seen:.4f} "
              f"train_acc={correct/seen:.4f} val_auc={val['auc']:.4f} "
              f"val_sens={val['sensitivity']:.3f} val_spec={val['specificity']:.3f} "
              f"val_abstain_gap={val['abstain_gap']:.4f}", flush=True)

        val_loss = history[-1]["train_loss"]  # kept for the record; selection uses abstain_gap
        score = val["abstain_gap"]  # lower = closer to truth
        if score < best_val_loss - 1e-4:
            best_val_loss, wait = score, 0
            torch.save({"model_state_dict": model.state_dict(), "epoch": epoch,
                        "val": val}, out_dir / "best_finetuned.pth")
        else:
            wait += 1
            if wait >= patience:
                print("early stop", flush=True)
                break

    model.load_state_dict(torch.load(out_dir / "best_finetuned.pth",
                                     map_location="cpu")["model_state_dict"])
    test = evaluate(model, test_loader, device)
    print("TEST:", json.dumps(test), flush=True)
    with open(out_dir / "history.json", "w") as fh:
        json.dump({"history": history, "test": test}, fh, indent=2)

    # swap into the served models dir, backing up the old checkpoint once
    served = pathlib.Path(args.checkpoint)
    backup = served.with_name("tb_classifier_v1_indomain.pth")
    if not backup.is_file():
        served.replace(backup)
    (out_dir / "best_finetuned.pth").replace(served)
    print("served model replaced:", served, flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data-dir", default="~/Downloads/imgs-testing/TB_Chest_Radiography_Database")
    parser.add_argument("--checkpoint", default=str(SERVER_DIR / "models/tb_classifier.pth"))
    parser.add_argument("--mask-cache", default=str(SERVER_DIR / ".cache/lung-masks"))
    parser.add_argument("--out-dir", default=str(SERVER_DIR / "pipline/training/finetune_external"))
    parser.add_argument("--per-class", type=int, default=700)
    parser.add_argument("--epochs", type=int, default=30)
    parser.add_argument("--batch", type=int, default=16)
    parser.add_argument("--lr", type=float, default=2e-5)
    parser.add_argument("--patience", type=int, default=6)
    parser.add_argument("--threads", type=int, default=3)
    parser.add_argument("--mask-workers", type=int, default=3)
    parser.add_argument("--masks-only", action="store_true")
    parser.add_argument("--mask-worker", type=int, default=-1,
                        help="internal: run one caching shard and exit")
    args = parser.parse_args()

    if args.mask_worker >= 0:
        precompute_masks(args.data_dir, args.mask_cache, args.per_class,
                         max(args.mask_workers, 1), args.mask_worker)
        return

    if args.masks_only:
        subs = [subprocess.Popen(
            [sys.executable, __file__, "--mask-worker", str(i)], cwd=str(SERVER_DIR))
            for i in range(args.mask_workers)]
        for s in subs:
            s.wait()
        if any(s.returncode for s in subs):
            raise SystemExit("mask precompute failed")
        return

    train(args)


if __name__ == "__main__":
    main()
