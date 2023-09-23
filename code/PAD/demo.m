%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 2023.9 Ziheng Deng @ SJTU
% This is a demo for Pseudo All-phase clinical Dataset (PAD) in cardiac CT
% Please download the data:
% The Astra toolbox is use for CT reconstruction in this demo. You can access it at https://www.astra-toolbox.com/
% Or you can implement your own CT reconstruction algorithm
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% 1. CT reconstruction parameters.
phase_num=100;
P_size=512;  % image size
Z_size=160;
pixsize=1;
SOD=2000;  % source to origin distance
DOD=2000;  % detector to origin distance
u_width=1200; % size of the detector
u_num=800;
v_width=270;
v_num=180;
fan_angle=atan(u_width/2/(SOD+DOD)); % Parker weighted short-scan. Actually it has been implemented with Astra toolbox.
ang_st=1;                            % But I just know it recently.
[yy,xx]=meshgrid(1:P_size,1:P_size);xx=xx-0.5-P_size/2;yy=yy-0.5-P_size/2;
circle=single(sqrt(xx.*xx+yy.*yy));circle(circle<(P_size/2+0.5))=0;circle(circle>0)=1;circle=1-circle;
circle2=repmat(circle,1,1,Z_size-40);
ang_whole=1980; % the whole sampling angles. for example, a long CT scan for 6 rounds to show a complete cardiac cycle.
samp_rate=1000; % 1000 views are sampled for each round.
ang_num=floor(ang_whole/360*samp_rate);
rotate_period=250; % rotation speed, typically 250 ms/r

%% 2. CT imaging: sampling projections from pseudo all-phase cardiac CT images
% Use GPU! It may takes several minutes. Modify the "ang_whole" to save the time.

nm=40; % To select a patient. try nm=40 or nm=50.
load(strcat('data\',num2str(nm),'\DF2')); % The simulated motion field.
load(strcat('data\',num2str(nm),'\DF3')); % Refer to our paper to see how to simulate your own motion field
load(strcat('data\',num2str(nm),'\DF4')); % for a clinical single-phase cardiac CT image.
load(strcat('data\',num2str(nm),'\transwarprange')); % the heart roi.
load(strcat('data\',num2str(nm),'\param'));
load(strcat('data\',num2str(nm),'\img3')); % Here is the original single-phase clinical cardiac CT images.
load(strcat('data\',num2str(nm),'\capoint')); % the extracted right coronary artery.
% some preprocessing. never mind, please turn to line 79.
capoint(:,1)=512-capoint(:,1);capoint(:,2)=512-capoint(:,2);capoint2=capoint;
capoint2(:,1)=(capoint2(:,1)-x_s)/(x_e-x_s)*(191)+1;capoint2(:,2)=(capoint2(:,2)-y_s)/(y_e-y_s)*(191)+1;capoint2(:,3)=(capoint2(:,3)-z_s)/(z_e-z_s)*(191)+1;
img=img3;img(img<-1000)=-1000;
for i=1:size(img,3)
    img(:,:,i)=imrotate(img(:,:,i),180);
end
DF=single(zeros(20,192,192,192,3));
DF(:,:,:,:,1)=DF4;
DF(:,:,:,:,2)=DF3;
DF(:,:,:,:,3)=DF2;
clear DF2 DF3 DF4
for phase=1:20
    for dim=1:3
        DF(phase,:,:,:,dim)=imfilter(squeeze(DF(phase,:,:,:,dim)),ones(3,3,3)/27,'replicate');
    end
end
D=permute(DF,[3,4,2,1,5])*1.4; % Modify the amplitude of the motion field.
D_ds=D;
D(:,:,:,:,1)=D(:,:,:,:,1)*(y_e-y_s+1)/192;  % rescale
D(:,:,:,:,2)=D(:,:,:,:,2)*(x_e-x_s+1)/192;
D(:,:,:,:,3)=D(:,:,:,:,3)*(z_e-z_s+1)/192;
D_temp=imfilter(D,ones(1,1,1,3,1)/3,'replicate');
D(:,:,:,2:19,:)=D_temp(:,:,:,2:19,:);
clear D_temp
for i=1:3
    for j=1:20
        D_temp(:,:,:,j,i)=imresize3(D(:,:,:,j,i),[y_e-y_s+1,x_e-x_s+1,z_e-z_s+1]);
    end
end
D=D_temp;
clear D_temp

img_warp=img;
patch1=imresize3(img(x_s:x_e,y_s:y_e,z_s:z_e),[192,192,192]);
phase_num=100;

% In this subsection, we first turn the single-phase clinical CT image into
% pseudo all-phase images. Then, we sample cone-beam projection from them.
tic
noise_rate=rand()*10+20;rand_size=200+round(rand()*120);noise=single(imresize3(randn(rand_size,rand_size,round(rand_size/1.5))*noise_rate,[P_size,P_size,Z_size])); % random noise
hr=60+randi(20); % random heart rate
d=6; %diameter of the rca
phase_rand=0; % starting cardiac phase (0~100)
heart_period=60000/hr; % heart period
ang_start=randi(360)/180*pi;  % random starting scan angle of the detector and the xrac source
load(strcat('data\',num2str(nm),'\zslice'));zslice1=max(1,zslice1);
vol_geom = astra_create_vol_geom(P_size,P_size,Z_size); % scan geometry in Astra toolbox
% Compute CT projection.
% As the heart is beating, the projection should be sampled according to a specific cardiac phase.
% That is why we need a pseudo all-phase motion field.
t_round=-1;
i_hold=0;
for i=1:ang_num % i is the sampling number.
    t=i/samp_rate*rotate_period; % projection no.i is sampled at timepoint t.
    t_round_temp=mod(round(t/(heart_period/phase_num)),phase_num); % at timepoint t, the heart is at cardiac phase t_round_temp (0~100 % R-R interval)
    if(t_round_temp~=t_round)
        if(i_hold~=0)
            proj_geom = astra_create_proj_geom('cone', v_width/v_num, u_width/u_num, v_num, u_num, ang_start - (i_hold:i-1)/samp_rate*2*pi, 2000, 2000);
            noise2=imresize3(randn(round(rand_size*1.5),round(rand_size*1.5),rand_size)*1.5,size(noise));
            [proj_id, proj_data] = astra_create_sino3d_cuda(double(img2+noise+noise2), proj_geom, vol_geom); % compute CT projection using Astra toolbox
            projection(:,:,(i_hold:i-1))=permute(single(proj_data),[1,3,2]);
            astra_mex_data3d('delete', proj_id);
        end
        i_hold=i;
        t_round=t_round_temp;
        img_warp=ssmgetimgwarp(img(x_s:x_e,y_s:y_e,z_s:z_e),D,mod(t_round_temp+1+phase_rand,phase_num)+1,phase_num); % warp the single-phase image to a specific cardiac phase
        ca_warp=ssmcagen(ssmgetcawarp(capoint2,d,D_ds*1.2,mod(t_round_temp+1+phase_rand,phase_num)+1,phase_num,x_s,x_e,y_s,y_e,z_s,z_e),img,x_space,y_space,z_space,d); % warp the rca separately
        img2=img;
        img2((x_s+3):(x_e-3),(y_s+3):(y_e-3),(z_s+3):(z_e-3))=img_warp(4:end-3,4:end-3,4:end-3);
        img2=imresize3(img2(:,:,zslice1:zslice2),[P_size,P_size,Z_size]);
        ca_warp_resize=imresize3(ca_warp(:,:,zslice1:zslice2),[P_size,P_size,Z_size],'nearest');
        img2=img2.*(1-ca_warp_resize);
        img2(ca_warp_resize>0)=ca_hu;
    end
    if(i==ang_num)
        proj_geom = astra_create_proj_geom('cone', v_width/v_num, u_width/u_num, v_num, u_num, ang_start - (i_hold:i)/samp_rate*2*pi, 2000, 2000);
        noise2=imresize3(randn(round(rand_size*1.5),round(rand_size*1.5),rand_size)*1.5,size(noise));
        [proj_id, proj_data] = astra_create_sino3d_cuda(double(img2+noise+noise2), proj_geom, vol_geom);
        projection(:,:,(i_hold:i))=permute(single(proj_data),[1,3,2]); % compute CT projection using Astra toolbox
        astra_mex_data3d('delete', proj_id);
    end
end
toc
% In this way, the computer simulated CT scan is performed for a moving heart.

%% 3. CT image reconstruction: get paired data(with or without motion artifacts) for deep learning research and more.
% Use GPU! It takes several minutes.
tic
timeinter=25; % reconstruct a 3D CT image at an interval of 12.5 ms.
for timepoint=75:timeinter:1275 % modify to save time.  
    % Get 4D ground truth cardiac CT image with no motion artifacts! First we need ground truth projection data.
    t=timepoint;
    t_round_temp=mod(round(t/(heart_period/phase_num)),phase_num);
    t_round=t_round_temp;
    noise2=imresize3(randn(round(rand_size*1.5),round(rand_size*1.5),rand_size)*1.5,size(noise));
    img_warp=ssmgetimgwarp(img(x_s:x_e,y_s:y_e,z_s:z_e),D,mod(t_round_temp+1+phase_rand,phase_num)+1,phase_num);
    ca_warp=ssmcagen(ssmgetcawarp(capoint2,d,D_ds*1.2,mod(t_round_temp+1+phase_rand,phase_num)+1,phase_num,x_s,x_e,y_s,y_e,z_s,z_e),img,x_space,y_space,z_space,d);

    img2=img;
    img2((x_s+3):(x_e-3),(y_s+3):(y_e-3),(z_s+3):(z_e-3))=img_warp(4:end-3,4:end-3,4:end-3);
    img2=imresize3(img2(:,:,zslice1:zslice2),[P_size,P_size,Z_size]);
    ca_warp_resize=imresize3(ca_warp(:,:,zslice1:zslice2),[P_size,P_size,Z_size],'nearest');
    img2=img2.*(1-ca_warp_resize);
    img2(ca_warp_resize>0)=ca_hu;

    %Get ground truth projection data
    bt=round(500*(pi+fan_angle*2)/pi);  % minimun number of projection views for short-scan reconstruction.
    % As mentioned before, the short-scan recon has been implemented in Astra toolbox. You may modify the code here for a more convenient implementation.
    proj_center=round(timepoint/rotate_period*samp_rate);
    proj_geom = astra_create_proj_geom('cone', v_width/v_num, u_width/u_num, v_num, u_num, ang_start - (((proj_center-round(bt/2)):(proj_center-round(bt/2)+bt-1))/samp_rate*2*pi), 2000, 2000);
    vol_geom = astra_create_vol_geom(P_size,P_size,Z_size);
    [proj_id, proj_data] = astra_create_sino3d_cuda(double(img2+noise+noise2), proj_geom, vol_geom);
    projection_gt=permute(single(proj_data),[1,3,2]);
    astra_mex_data3d('delete', proj_id);
    projection_wt=getshortscanweighted(projection_gt,SOD,DOD,u_width,180+2*fan_angle*180/pi);
    vol_geom = astra_create_vol_geom(P_size,P_size,Z_size-40);
    proj_geom = astra_create_proj_geom('cone', v_width/v_num, u_width/u_num, v_num, u_num, ang_start - (((proj_center-round(bt/2)):(proj_center-round(bt/2)+bt-1))/samp_rate*2*pi), 2000, 2000);
    proj_id = astra_mex_data3d('create', '-proj3d', proj_geom, permute(projection_wt,[1,3,2]));
    rec_id = astra_mex_data3d('create', '-vol', vol_geom);
    cfg1 = astra_struct('FDK_CUDA');
    cfg1.ReconstructionDataId = rec_id;
    cfg1.ProjectionDataId = proj_id;
    alg1_id = astra_mex_algorithm('create', cfg1);
    astra_mex_algorithm('run', alg1_id);
    P_recon=astra_mex_data3d('get', rec_id)*bt/500;
    P_recon(circle2==0)=-1000;
    astra_mex_data3d('delete', rec_id);
    astra_mex_data3d('delete', proj_id);
    subplot(1,2,1)
    imshow(squeeze(P_recon(x_s:x_e,y_s:y_e,50))',[-300,500]);title(strcat('GTimage',num2str(timepoint)));pause(.01)
    if(timepoint==75)
        eval(['P_recon_gt',num2str(timepoint),'=single(P_recon);']);
        save(strcat('data\',num2str(nm),'\P_recon_gt',num2str(round(timepoint))),strcat('P_recon_gt',num2str(timepoint)));
    else
        roi_recon=single(P_recon(x_s:x_e,y_s:y_e,:));
        save(strcat('data\',num2str(nm),'\roi_recon_gt',num2str(round(timepoint))),'roi_recon');
    end

    % Get 4D cardiac CT images with motion artifacts.
    bt=round(500*(pi+fan_angle*2)/pi);
    proj_center=round(timepoint/rotate_period*samp_rate);
    projection_sc=projection(:,:,(proj_center-round(bt/2)):(proj_center-round(bt/2)+bt-1));
    projection_wt=getshortscanweighted(projection_sc,SOD,DOD,u_width,180+2*fan_angle*180/pi);
    vol_geom = astra_create_vol_geom(P_size,P_size,Z_size-40);
    proj_geom = astra_create_proj_geom('cone', v_width/v_num, u_width/u_num, v_num, u_num, ang_start - (((proj_center-round(bt/2)):(proj_center-round(bt/2)+bt-1))/samp_rate*2*pi), 2000, 2000);
    proj_id = astra_mex_data3d('create', '-proj3d', proj_geom, permute(projection_wt,[1,3,2]));
    rec_id = astra_mex_data3d('create', '-vol', vol_geom);
    cfg1 = astra_struct('FDK_CUDA');
    cfg1.ReconstructionDataId = rec_id;
    cfg1.ProjectionDataId = proj_id;
    alg1_id = astra_mex_algorithm('create', cfg1);
    astra_mex_algorithm('run', alg1_id);
    P_recon=astra_mex_data3d('get', rec_id)*bt/500;
    P_recon(circle2==0)=-1000;
    astra_mex_data3d('delete', rec_id);
    astra_mex_data3d('delete', proj_id);
    subplot(1,2,2)
    imshow(squeeze(P_recon(x_s:x_e,y_s:y_e,50))',[-300,500]);title(strcat('Artifact',num2str(timepoint)));pause(.01)
    toc
    if(timepoint==75)
        eval(['P_recon',num2str(timepoint),'=single(P_recon);']);
        save(strcat('data\',num2str(nm),'\P_recon',num2str(round(timepoint))),strcat('P_recon',num2str(timepoint)));
    else
        roi_recon=single(P_recon(x_s:x_e,y_s:y_e,:));
        save(strcat('data\',num2str(nm),'\roi_recon',num2str(round(timepoint))),'roi_recon');
    end
end










