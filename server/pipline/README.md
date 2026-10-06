# Lung Segmentation in Chest X Rays

[![Code style: black](https://img.shields.io/badge/code%20style-black-000000.svg)](https://github.com/psf/black) &nbsp;&nbsp;
![pre-commit tests](https://github.com/niaid/lung_cxr_segmentation/actions/workflows/pre_commit.yml/badge.svg)

The models in this repository were trained using publicly available CXRs,[covid-19 data from V7 labs](https://github.com/v7labs/covid-19-xray-dataset).

**Note**: Model weights in this repository are stored using [git-lfs](https://git-lfs.com/). Install it before cloning the repository otherwise the actual model weight files will not be downloaded and the files on disk will only contain the hash.

## How to Cite

If you find these models useful in your work, please cite them as:

K. Kantipudi, J. Gu, V. Bui, H. Yu, S. Jaeger, Z. Yaniv, "Automated Pulmonary Tuberculosis Severity Assessment on Chest X-rays", J Imaging Inform Med, 37(5):2173-2185, 2024. doi:[10.1007/s10278-024-01052-7](https://doi.org/10.1007/s10278-024-01052-7).

## Install the environment

```
pip install -r requirements.txt
```

or 

```
conda env create -f environment.yml
```

## Download the dataset
Download the dataset from the [link](https://github.com/v7labs/covid-19-xray-dataset) and run the below command
to generate CSV file with columns as 'cxr_file' and 'ref_seg_file' representing chest x ray
file path and its corresponding label respectively.

```
python -m segment_lung_cxr.data_preparation.data_prep /path/to/covid-19-chest-x-ray-dataset/releases/all-images/annotations /path/to/covid-19-chest-x-ray-dataset/images  /path/to/covid-19-chest-x-ray-dataset/annotations/all-images-semantic-masks all_files.csv
```

## Prepare input files for training and inference
After running the above command user can use the all_files.csv file to run the below script to generate input files for training and inference.
```
python segment_lung_cxr.data_preparation.generate_input_files.py all_files.csv 5 0 inputs.csv
```
In the above command line, 5 represents the number of folds to performs cross validation for and 0 represents fold number to generate the output CSV files for training and inference. Above command will generate three files: train_inputs.csv, val_inputs.csv and test_inputs.csv
Prepare the inputs for this experiment by running the below commands.

## Training

After running the above command user will observe that the number of files for train/val/test are:
Train: 4797
Val:801
Test: 801

For training the model without any data augmentation during training,user can run the below command

```
python -m segment_lung_cxr.training.train_lung_segment segment_lung_cxr/training/resnet_unet_configuration.json train_inputs.csv val_inputs.csv segment_lung_cxr/data/weights/cxr_segment.pt
```

From the above command line user will be able to generate the models and will be able to use it for inference purposes.

## Inference

To run the inference results from the model, user can run the below command.
```
python -m segment_lung_cxr.inference.inference_lung_segment sample_inputs.csv segment_lung_cxr/data/weights/cxr_lung_segment_including_heart_512.pt  --output_pred_dir prediction_outputs --img_size 512 512 --patch_size 512 512  --post_process True
```

Users can also use, segment_lung_cxr/data/weights/cxr_lung_segment_including_heart_224.pt or segment_lung_cxr/data/weights/cxr_lung_segment_excluding_heart_224.pt except the predictions might contain more artefcats in the segmentations.

To use the ensemble from the models trained on input sizes of 224 and 512,use the following command line
```
python -m segment_lung_cxr.inference.ensemble_inference_lung_segment sample_inputs.csv segment_lung_cxr/data/weights/cxr_lung_segment_including_heart_224.pt segment_lung_cxr/data/weights/cxr_lung_segment_including_heart_512.pt --output_pred_dir prediction_outputs  --img_sizes 224 224 512 512 --patch_sizes 224 224 512 512 --post_process True
```

## Evaluation:
```
python -m segment_lung_cxr.evaluation.evaluate_segmentations test_inputs.csv prediction_outputs overlap_results.csv surface_distance_results.csv
```
From the above command, overlap_results.csv and surface_distance_results.csv are the two csv files computed from the
reference binary mask and prediction mask.

