#!/usr/bin/env python3
"""
Generate images_metadata.csv by combining:
- Normal images from normal_full_images.csv
- TB images from tb_full_images.csv + all_tb_metadata.csv
"""

import os
import sys
import pandas as pd
from pathlib import Path
import logging

# Setup logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def get_image_dimensions_png(image_path):
    """Extract PNG image dimensions using PIL"""
    try:
        from PIL import Image
        if os.path.exists(image_path):
            img = Image.open(image_path)
            return img.width, img.height
        else:
            return None, None
    except Exception as e:
        logger.debug(f"Could not read PNG dimensions from {image_path}: {e}")
        return None, None

def extract_dicom_id(dicom_path):
    """Extract DICOM ID from the file path"""
    parts = str(dicom_path).strip().split('/')
    # Find the part that looks like a DICOM UID (starts with 1.2)
    for part in parts:
        if part.startswith('1.') and '.dcm' in part:
            return part.replace('.dcm', '')
    # Fallback: just get the last part before .dcm
    filename = parts[-1] if parts else ''
    return filename.replace('.dcm', '') if '.dcm' in filename else filename

def process_normal_images(normal_csv_path):
    """Process normal images CSV"""
    logger.info(f"Processing normal images from: {normal_csv_path}")
    
    df = pd.read_csv(normal_csv_path)
    logger.info(f"Loaded {len(df)} normal images")
    
    # Extract image dimensions from PNG files
    widths = []
    heights = []
    for idx, row in df.iterrows():
        cxr_file = row['cxr_file']
        width, height = get_image_dimensions_png(cxr_file)
        widths.append(width)
        heights.append(height)
        
        if (idx + 1) % 1000 == 0:
            logger.info(f"Processed {idx + 1}/{len(df)} normal images for dimensions")
    
    # Create metadata dataframe
    result = pd.DataFrame({
        'image_id': df['cxr_file'].apply(lambda x: Path(x).stem),
        'image_type': 'normal',
        'cxr_file': df['cxr_file'],
        'image_width': widths,
        'image_height': heights,
        'segmentation_file': df['pred_seg_file'],
        'patient_id': None,
        'age_of_onset': None,
        'sex': None,
        'country': None,
        'diagnosis_code': None,
        'type_of_resistance': None,
        'outcome': None,
        'cxr_outlier': None
    })
    
    logger.info(f"Processed {len(result)} normal images successfully")
    return result

def process_tb_images(tb_csv_path, tb_metadata_path):
    """Process TB images CSV and merge with metadata"""
    logger.info(f"Processing TB images from: {tb_csv_path}")
    logger.info(f"Loading TB metadata from: {tb_metadata_path}")
    
    # Load TB images
    tb_images = pd.read_csv(tb_csv_path)
    logger.info(f"Loaded {len(tb_images)} TB images")
    
    # Load TB metadata
    tb_meta = pd.read_csv(tb_metadata_path)
    logger.info(f"Loaded {len(tb_meta)} TB metadata records")
    
    # Extract DICOM IDs from image paths for matching
    logger.info("Extracting DICOM IDs for matching...")
    tb_images['dicom_id'] = tb_images['cxr_file'].apply(extract_dicom_id)
    tb_meta['dicom_id'] = tb_meta['series_instance_content_url'].apply(extract_dicom_id)
    
    # Check matching
    n_matched = tb_images['dicom_id'].isin(tb_meta['dicom_id']).sum()
    logger.info(f"Matched {n_matched}/{len(tb_images)} TB images with metadata")
    
    # Merge on DICOM ID
    logger.info("Merging TB images with metadata...")
    merged = tb_images.merge(
        tb_meta[['dicom_id', 'patient_id', 'age_of_onset', 'sex', 'country', 
                  'diagnosis_code', 'type_of_resistance', 'outcome', 'cxr_outlier']],
        on='dicom_id',
        how='left'
    )
    
    unmatched = merged['patient_id'].isna().sum()
    logger.info(f"After merge: {len(merged) - unmatched} matched, {unmatched} unmatched")
    
    # Create final dataframe
    result = pd.DataFrame({
        'image_id': merged['dicom_id'],
        'image_type': 'TB',
        'cxr_file': merged['cxr_file'],
        'image_width': None,  # DICOM dimensions not extracted
        'image_height': None,
        'segmentation_file': merged['pred_seg_file'],
        'patient_id': merged['patient_id'],
        'age_of_onset': merged['age_of_onset'],
        'sex': merged['sex'],
        'country': merged['country'],
        'diagnosis_code': merged['diagnosis_code'],
        'type_of_resistance': merged['type_of_resistance'],
        'outcome': merged['outcome'],
        'cxr_outlier': merged['cxr_outlier']
    })
    
    logger.info(f"Processed {len(result)} TB images successfully")
    return result

def main():
    # Define paths
    base_dir = os.path.expanduser('~/lungcxr')
    seg_dir = os.path.join(base_dir, 'lung_cxr_segmentation')
    
    normal_csv = os.path.join(seg_dir, 'normal-inference-metadata/normal_full_images.csv')
    tb_csv = os.path.join(seg_dir, 'tb-inference-metadata/tb_full_images.csv')
    tb_metadata = os.path.join(base_dir, 'all_tb_metadata.csv')
    output_file = os.path.join(base_dir, 'images_metadata.csv')
    
    logger.info("="*70)
    logger.info("GENERATING IMAGES METADATA CSV")
    logger.info("="*70)
    
    # Check if files exist
    for f in [normal_csv, tb_csv, tb_metadata]:
        if not os.path.exists(f):
            logger.error(f"File not found: {f}")
            sys.exit(1)
        logger.info(f"✓ Found: {f}")
    
    try:
        # Process both datasets
        logger.info("\n" + "="*70)
        logger.info("STEP 1: Processing Normal Images")
        logger.info("="*70)
        normal_df = process_normal_images(normal_csv)
        
        logger.info("\n" + "="*70)
        logger.info("STEP 2: Processing TB Images")
        logger.info("="*70)
        tb_df = process_tb_images(tb_csv, tb_metadata)
        
        # Combine
        logger.info("\n" + "="*70)
        logger.info("STEP 3: Combining Datasets")
        logger.info("="*70)
        combined_df = pd.concat([normal_df, tb_df], ignore_index=True)
        logger.info(f"Combined dataframe shape: {combined_df.shape}")
        
        # Save
        combined_df.to_csv(output_file, index=False)
        logger.info(f"\n✓ Successfully created: {output_file}")
        
        # Summary statistics
        logger.info("\n" + "="*70)
        logger.info("SUMMARY")
        logger.info("="*70)
        logger.info(f"Total records: {len(combined_df)}")
        logger.info(f"  - Normal images: {(combined_df['image_type'] == 'normal').sum()}")
        logger.info(f"  - TB images: {(combined_df['image_type'] == 'TB').sum()}")
        logger.info(f"\nColumns in output CSV:")
        for i, col in enumerate(combined_df.columns, 1):
            logger.info(f"  {i}. {col}")
        
        logger.info(f"\nFirst 3 rows of output:")
        print("\n" + combined_df.head(3).to_string())
        
    except Exception as e:
        logger.error(f"Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == '__main__':
    main()
