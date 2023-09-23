%%%%在线计算某个phase的心脏图像，输入是原始图像+全心动周期运动场
function img_warp=ssmgetimgwarp(patch1,D,phase,phase_num)
    phase_t=(phase-1)/(phase_num-1)*(20)+1;
    phase_a=floor(phase_t+0.00000001);phase_b=phase_a+1;
    if(phase_a>20)
        phase_a=phase_a-20;
    end
    if(phase_b>20)
        phase_b=phase_b-20;
    end
    a_p=ceil(phase_t+0.000000001)-phase_t;b_p=1-a_p;
    
    D_temp=a_p*squeeze(D(:,:,:,phase_a,:))+b_p*squeeze(D(:,:,:,phase_b,:));

    img_warp=permute(gather(imwarp(permute(patch1,[2,1,3]),D_temp)),[2,1,3]);


end











