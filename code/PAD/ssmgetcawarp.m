%%%在线计算ca_warp
function capoint3=ssmgetcawarp(capoint2,d,D,phase,phase_num,x_s,x_e,y_s,y_e,z_s,z_e)

[YY,XX,ZZ]=meshgrid(1:192,1:192,1:192);

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
    
    D_phase1=D_temp(:,:,:,1);
    D_phase2=D_temp(:,:,:,2);
    D_phase3=D_temp(:,:,:,3);
    
    mfield1=interp3(YY,XX,ZZ,D_phase1,capoint2(:,1),capoint2(:,2),capoint2(:,3));
    mfield2=interp3(YY,XX,ZZ,D_phase2,capoint2(:,1),capoint2(:,2),capoint2(:,3));
    mfield3=interp3(YY,XX,ZZ,D_phase3,capoint2(:,1),capoint2(:,2),capoint2(:,3));
    
    mfield1(isnan(mfield1))=0;mfield2(isnan(mfield2))=0;mfield3(isnan(mfield3))=0;
    
    capoint3=capoint2;
    capoint3(:,1)=(capoint3(:,1)-mfield1-1)/191*(x_e-x_s)+x_s;
    capoint3(:,2)=(capoint3(:,2)-mfield2-1)/191*(y_e-y_s)+y_s;
    capoint3(:,3)=(capoint3(:,3)-mfield3-1)/191*(z_e-z_s)+z_s;


end











