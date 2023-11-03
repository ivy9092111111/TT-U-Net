function projection_weighted=getshortscanweighted(projection,SOD,DOD,u_width,ang_range)
%%%%%%%%%%%CBCTµÄparker¼ÓÈ¨
u_num=size(projection,1);
ang_num=size(projection,3);
weight=ones(u_num,ang_num);
[yy,xx]=meshgrid(ang_range/ang_num:ang_range/ang_num:ang_range,1:u_num);
xx=xx-u_num/2-0.5;
xx=xx.*u_width./u_num;
yy=yy/180*pi;
alpha=atan(xx./(SOD+DOD));
delta=max(max(alpha));

weight1=sin(pi/4.*yy./(delta-alpha)).^2;
weight2=sin(pi/4.*(pi+2*delta-yy)./(alpha+delta)).^2;

weight((delta-alpha)>(yy./2))=weight1((delta-alpha)>(yy./2));
weight(logical((yy>(pi-2*alpha)).*(yy<pi+2*delta)))=weight2(logical((yy>(pi-2*alpha)).*(yy<pi+2*delta)));
weight(yy>(pi+2*delta))=0;

% weight=weight(end:-1:1,:);


projection=permute(projection,[1,3,2]);

for i=1:size(projection,3)
    proj(:,:)=projection(:,:,i);
    projection_weighted(:,:,i)=proj.*weight;
end

projection_weighted=permute(projection_weighted,[1,3,2]);









