.PHONY: generate_csv segmentation_inference classifier 

generate_csv:
	python -m segment_lung_cxr.data_preparation.prepare_ls2_csv

segmentation_inference:
	python -m segment_lung_cxr.inference.inference_lung_segment \
    segment_lung_cxr/data/input_csv_files/LS2/all_files.csv \
    segment_lung_cxr/data/weights/cxr_lung_segment_including_heart_512.pt \
    --dataset LS2 \
    --img_size 512 512 --patch_size 512 512 --post_process True

classifier:
	python -m classification.train \
    ~/Downloads/TB_Chest_Radiography_Database \
    results/classification/tb_classifier.pt

evaluate:
	python -m classification.evaluate \
    results/classification/predictions.csv \
    results/classification/

