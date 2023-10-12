## GBM Survival prediction online portal step-by-step instructions

1. Access the [CBICA Image Processing Portal](https://ipp.cbica.upenn.edu) and create an account if you haven’t yet. Account creation may take a few days after submitting the form.

1. Click on Application Categories -> Analysis -> **GBM Survival ReSPOND 2023 Model**. 


1.	Enter the input and click on the **Submit Job** button.

1.	Required fields:
  -	User description: The text input in this field will be displayed in the output results report. It is not a model input.
  -	Age of patient in year
  -	Image input type (see image input below)
  -	T1, T1-POST, T2, T2-FLAIR image input. This can be either a
    -	DICOM series (upload all files per series) (Input type 1)
    -	Un-preprocessed NIfTI (Input type 1)
    -	BraTS pipeline preprocessed NIfTI in SRI space (co-registered, skull-stripped) (input type 2)

    

1.	Optional parameters:
    -	Series to use for BrainMAGE brain mask [T1 or T1-POST]: By default, the software will use the T1-POST image to create the brain mask. When the T1-POST image is cropped, the pipeline will benefit from using the T1 mask.
    -	Brain Mask image: User provided binary brain mask in SRI space. Labels are 1: brain; 0: non-brain. When provided, the pipeline will skip the brain mask generation and use this mask instead.
    -	Tumor Segmentation Image: User provided tumor segmentation mask in SRI space. Tumor segmentation labels should follow the BraTS convention, which includes enhancing tumor (ET — label 4), the peritumoral edema (ED — label 2), and the necrotic and non-enhancing tumor core (NCR/NET — label 1), as described both in the BraTS 2012-2013 TMI paper (10.1109/TMI.2014.2377694) and in the latest BraTS summarizing paper (arXiv:1811.02629). When provided, the pipeline will skip the tumor segmentation and use this mask instead.

1.	Results
    - Please note that the pipeline could take anywhere from 30min to a day to generate results, depending on CBICA cluster traffic. 
    -	When complete, users will be able to download all results in a zip file from this site.
    -	Results folder will include the prediction report, as well as the preprocessed images, brain mask, tumor segmentation, extracted features, and the Survival Prediction Index (SPI)
