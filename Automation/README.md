# PCdare automation

# Licenses

CC BY-NC-SA 4.0 License  
Attribution-NonCommercial-ShareAlike 4.0 International  
Copyright (c) 2024 Mirko Kaiser  
Copyright (c) 2024 Kübra Bektas  

## U-Net implementation
https://github.com/mateuszbuda/brain-segmentation-pytorch/  
MIT License  
Copyright (c) 2019 mateuszbuda  

## YOLO
https://github.com/ultralytics/ultralytics  
GNU AFFERO GENERAL PUBLIC LICENSE Version 3, 19 November 2007  
Copyright (C) 2007 Free Software Foundation, Inc. <https://fsf.org/>  

## UNet++ implementation
https://github.com/4uiiurz1/pytorch-nested-unet  
MIT License  
Copyright (c) 2018 Takato Kimura  

# Installation

## Anaconda and Jupyter
conda create -n pcda python=3.11.7  
conda activate pcda  
conda install jupyter (https://jupyter.org/install)  
conda install pytorch==2.2.1 torchvision==0.17.1 torchaudio==2.2.1 pytorch-cuda=11.8 -c pytorch -c nvidia    
pip install -r requirements.txt  

# Getting Started

## Jupyter
jupyter lab  
1_center_cropped.ipynb  
2_flipped.ipynb  
3_random_cropped.ipynb  

python 4_train.py --expt_name="test1" --max_epochs=300 --batch_size=8 --lr=1e-3 --loss="Loss" --pretrained  

5_yolov8-train.ipynb  
6_yolov8-predict.ipynb  
7_inference_centercropped_based_model.ipynb  
8_inference_yolo_based_model.ipynb  
  
10_Pipeline_Part1_running_inference_yolo.ipynb  
11_Pipeline_Part2_running_inference_unet.ipynb  
12_Pipeline_Part_3_Postprocessing.ipynb  
13_Pipeline_Part4_Spline.ipynb  
  
9_spline_both_data.ipynb  