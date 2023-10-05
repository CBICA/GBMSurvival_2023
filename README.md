# GBMSurvival_2023NatureMedicine


This repository includes the source codes to evaluate the survival model described in our paper
"Novel ML-based Prognostic Subgrouping of Glioblastoma: A Multi-center Study", submitted to Nature Medicine.

### Code description

- src/run_GBMsurvival_predict.sh: Main bash code to extract features from images and apply the pretrained model.
Inputs are patient age, preprocessed MRI images (t1,t1gd,t2,t2-flair), and tumor segmentation mask. 

- src/FeatEx.m : function to extract features

- src/GBMSurvival_predict.m : matlab fuction to run predictions

- src/data: model and atlases
- src/libs: matlab libraries

### Software requirements

- MATLAB version 9.4 (R2018a)

- greedy: https://github.com/pyushkevich/greedy [1]

- python3 for pdf report creation


### Online platform
In addition to making the source codes available here, we have created an online platform where users can preprocess and apply our model on their own images to obtain survival prediction without the need for installation.

- https://ipp.cbica.upenn.edu

- Sample input data from the public dataset UPENN-GBM (https://doi.org/10.7937/TCIA.709X-DN49) and output report are available in the folder sample_data

### Image preprocessing

Codes for the image preprocessing are available separately through the following GitHub repositories
- dicom to nifti conversion and image co-registration (with optional brain extraction and  tumor segmentation): https://github.com/CBICA/CaPTk [2]

- Brain extraction: https://github.com/CBICA/BrainMaGe [3]

- Tumor segmentation: https://github.com/FETS-AI/Front-End [4].


### References
[1]   Yushkevich, P.A., Pluta, J., Wang, H., Wisse, L.E., Das, S. and Wolk, D., 2016. Fast Automatic Segmentation of Hippocampal Subfields and Medial Temporal Lobe Subregions in 3 Tesla and 7 Tesla MRI. Alzheimer's & Dementia: The Journal of the Alzheimer's Association, 12(7), pp.P126-P127.

[2] Davatzikos et al. Cancer imaging phenomics toolkit: quantitative imaging analytics for precision diagnostics and predictive modeling of clinical outcome, J Med Imaging, 5(1):011018, 2018

[3] Thakur, S., et al. Brain extraction on MRI scans in presence of diffuse glioma: Multi-institutional performance evaluation of deep learning methods and robust modality-agnostic training. NeuroImage 220, 117081 (2020).

[4] Pati, S., et al. The federated tumor segmentation (FeTS) tool: an open-source solution to further solid tumor research. Physics in Medicine & Biology (2022).
