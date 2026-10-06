"""Fixed lists the app offers a doctor. Codes are what the database stores.

Finding codes match the Dart `LesionType` enum names in
lib/feature_home/models/lesion.dart so the viewer can map them by name.
The disease and test lists are a proposal and need clinical sign-off.
"""

VERDICTS = {
    "tb_suspected": "TB suspected",
    "no_tb": "No TB",
    "other_disease": "Other disease suspected",
    "unreadable": "Image unreadable",
}

FINDINGS = {
    "consolidation": ("parenchymal", "Consolidation"),
    "cavity": ("parenchymal", "Cavity"),
    "nodule": ("parenchymal", "Nodule"),
    "miliary": ("parenchymal", "Miliary pattern"),
    "fibrosis": ("parenchymal", "Fibrosis"),
    "calcification": ("parenchymal", "Calcification"),
    "effusion": ("pleural", "Pleural effusion"),
    "pleuralThickening": ("pleural", "Pleural thickening"),
    "pneumothorax": ("pleural", "Pneumothorax"),
    "hilarLymphadenopathy": ("mediastinal", "Hilar lymphadenopathy"),
    "mediastinalWidening": ("mediastinal", "Mediastinal widening"),
    "other": ("other", "Other finding"),
}

DISEASES = {
    "pneumonia": "Pneumonia",
    "lung_cancer": "Lung cancer suspected",
    "copd": "COPD / emphysema",
    "heart_failure": "Heart failure / cardiomegaly",
    "silicosis": "Silicosis",
    "old_tb": "Old healed TB",
    "other": "Other",
}

TESTS = {
    "genexpert": "Sputum GeneXpert",
    "smear": "Sputum smear microscopy",
    "culture": "Sputum culture",
    "ct_chest": "CT chest",
    "repeat_xray": "Repeat X-ray",
    "other": "Other",
}

URGENCIES = {"routine": "Routine", "urgent": "Urgent"}

FEEDBACK_KINDS = {
    "false_positive": "Model said TB, doctor says no TB",
    "false_negative": "Model said Normal, doctor suspects TB",
    "wrong_region": "Heatmap highlights the wrong area",
    "cannot_judge": "Image quality too poor to judge",
}

# Model output labels, as stored in predictions.label.
LABEL_TB = "tb"
LABEL_NORMAL = "normal"


def _options(mapping):
    return [{"code": code, "label": label} for code, label in mapping.items()]


def as_dict():
    return {
        "verdicts": _options(VERDICTS),
        "findings": [
            {"code": code, "group": group, "label": label}
            for code, (group, label) in FINDINGS.items()
        ],
        "diseases": _options(DISEASES),
        "tests": _options(TESTS),
        "urgencies": _options(URGENCIES),
        "feedback_kinds": _options(FEEDBACK_KINDS),
    }
