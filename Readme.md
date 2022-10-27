# [WIP] TT-U-Net: Temporal Transformer U-Net for motion artifact reduction in dynamic cardiac CT

Ziheng Deng, School of BME, Shanghai Jiao Tong University

This repository is the official implementation of TT-U-Net: Temporal Transformer U-Net for motion artifact reduction in dynamic cardiac CT. In this paper, we introduce a novel framework for motion artifact reduction in dynamic cardiac CT imaging. Two main contributions of the paper are:

* We propose a simulated motion-perturbed cardiac CT dataset. The dataset provides paired training samples (image with and without motion artifacts) and is with realistic appearance.

* We propose a novel temporal transformer U-Net (TT U-Net) for motion artifact reduction. We handle this challenging problem as a video deblurring task and modify the vanilla U-Net by introducing self-attention mechanism along temporal dimension.

## Demo

Here are some examples of our motion artifact reduction algorithm tested on real clinical CT scans. TT U-Net restores the CT images in a post-processing way, which is effective and efficient.

|           Case            |                  Case1                   |                  Case2                   |                   Case3                   |
| :-----------------------: | :--------------------------------------: | :--------------------------------------: | :---------------------------------------: |
|    Uncorrected images     | <img width="180" src="gif/7_40_fdk.gif"> | <img width="180" src="gif/9_60_fdk.gif"> | <img width="180" src="gif/10_60_fdk.gif"> |
| TT U-Net corrected images |  <img width="180" src="gif/7_40_1.gif">  |  <img width="180" src="gif/9_60_1.gif">  |  <img width="180" src="gif/10_60_1.gif">  |



## Contents

* [Simulated motion-perturbed cardiac CT dataset](#Simulated motion-perturbed cardiac CT dataset)
* [TT U-Net](#TT U-Net)

