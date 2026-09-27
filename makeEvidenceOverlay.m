function O = makeEvidenceOverlay(e)
%MAKEEVIDENCEOVERLAY Color-coded candidate evidence; never called Grad-CAM.
O = e.image;
O = paint(O,e.vessels,[0 .9 .9],.45);
O = paint(O,imdilate(e.microaneurysms,strel('disk',1,0)),[1 .1 .2],.85);
O = paint(O,e.hemorrhages,[.75 .15 1],.70);
O = paint(O,e.exudates,[1 .9 .05],.80);
O = paint(O,bwperim(e.discMask),[.2 1 .3],1);
if all(isfinite(e.foveaCenter))
    [x,y] = meshgrid(1:size(O,2),1:size(O,1));
    mark = abs(x-e.foveaCenter(1))<=5 & abs(y-e.foveaCenter(2))<=1 ...
        | abs(x-e.foveaCenter(1))<=1 & abs(y-e.foveaCenter(2))<=5;
    O = paint(O,mark,[1 1 1],1);
end
end

function O = paint(O,M,color,alpha)
for k = 1:3
    plane = O(:,:,k); plane(M) = (1-alpha)*plane(M)+alpha*color(k); O(:,:,k) = plane;
end
end
