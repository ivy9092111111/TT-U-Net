function arti=ssmcagen(point,img,x_space,y_space,z_space,d)
%%%%%用来生成冠脉，输入是中心线坐标等
branchpoints=bwmorph3(point,'branchpoints');

[YY,XX,ZZ] = meshgrid(1:512,1:512,1:size(img,3));
arti=zeros(size(img));
for i=1:length(point)
    x_s=floor(point(i,1)-10);
    x_e=ceil(point(i,1)+10);
    y_s=floor(point(i,2)-10);
    y_e=ceil(point(i,2)+10);
    z_s=max(1,floor(point(i,3)-10));
    z_e=min(size(img,3),ceil(point(i,3)+10));
    dist=((XX(x_s:x_e,y_s:y_e,z_s:z_e)-point(i,1))*x_space).^2+((YY(x_s:x_e,y_s:y_e,z_s:z_e)-point(i,2))*y_space).^2+((ZZ(x_s:x_e,y_s:y_e,z_s:z_e)-point(i,3))*z_space).^2;
    dist(dist>((d/2.5).^2))=0;
    dist(dist>0)=1;
    arti(x_s:x_e,y_s:y_e,z_s:z_e)=arti(x_s:x_e,y_s:y_e,z_s:z_e)+dist;
end
arti(arti>0)=1;

end