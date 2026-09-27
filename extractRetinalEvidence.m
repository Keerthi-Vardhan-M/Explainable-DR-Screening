function e = extractRetinalEvidence(I,fieldMask,c)
%EXTRACTRETINALEVIDENCE Untrained morphological/Hessian presentation baseline.
% Lesions, disc and fovea are CANDIDATES, not validated clinical detections.
% Analysis runs at a configurable reduced resolution; no subpixel MA claim.
if nargin < 3, c = drDemoConfig(); end
scale = min(1,c.lesionAnalysisSize/max(size(I,1),size(I,2)));
A = imresize(im2single(I),scale); sz = [size(A,1) size(A,2)];
M = logical(imresize(fieldMask,sz,'nearest'));
e = struct('version','retinal-candidates-v1','image',A,'field',M, ...
    'nativeSize',[size(I,1) size(I,2)],'analysisSize',sz, ...
    'vessels',false(sz),'microaneurysms',false(sz),'hemorrhages',false(sz), ...
    'exudates',false(sz),'discMask',false(sz),'discCenter',[NaN NaN], ...
    'foveaCenter',[NaN NaN],'discRadius',NaN,'lesions',table(), ...
    'features',zeros(1,12),'featureNames',{{}},'overlay',A, ...
    'counts',struct('MA',0,'HE',0,'EX',0),'message','', ...
    'neovascularization','Not assessed: specialist review required');
if nnz(M)<100
    e.message = 'Retinal field too small for candidate analysis.'; return
end
G = A(:,:,2); width = size(A,2);
radius = max(2,round(width*0.012));
inner = imerode(M,strel('disk',radius,0));
if nnz(inner)<100, inner = M; end
field = imgaussfilt(G.*single(M),max(6,width*.035)) ./ ...
    max(imgaussfilt(single(M),max(6,width*.035)),single(1e-6));
N = min(1,max(0,0.5+G-field)); N(~M) = 0.5;
tiles = min([8 8],max([2 2],floor(sz/4)));
N = 0.7*N+0.3*adapthisteq(N,'NumTiles',tiles,'ClipLimit',0.005);
% Disc: low-frequency brightness candidate, with a peripheral exclusion.
discRadius = max(5,round(min(sz)*0.055));
discSearch = imerode(M,strel('disk',discRadius,0));
if nnz(discSearch)<100, discSearch = inner; end
brightness = 0.6*A(:,:,1)+0.4*G;
score = imgaussfilt(brightness,discRadius/2);
score(~discSearch) = -Inf;
[best,idx] = max(score(:)); [dy,dx] = ind2sub(sz,idx);
[xx,yy] = meshgrid(1:sz(2),1:sz(1));
if isfinite(best)
    e.discCenter = [dx dy]; e.discRadius = discRadius;
    e.discMask = ((xx-dx).^2+(yy-dy).^2<=discRadius^2) & M;
    % Fovea: dark-region estimate towards the opposite side of the field.
    direction = sign(sz(2)/2-dx); if direction==0, direction = 1; end
    targetX = dx+direction*5*discRadius;
    search = abs(xx-targetX)<=1.5*discRadius & ...
        abs(yy-dy)<=1.5*discRadius & inner & ~e.discMask;
    if any(search(:))
        darkScore = imgaussfilt(G,max(2,discRadius/3)); darkScore(~search) = Inf;
        [~,fi] = min(darkScore(:)); [fy,fx] = ind2sub(sz,fi);
        e.foveaCenter = [fx fy];
    end
end
% Dark tubular Hessian response at multiple pixel scales.
V = zeros(sz,'single');
for sigma = [1 2 3]
    S = imgaussfilt(N,sigma);
    Dxx = imfilter(S,[1 -2 1],'replicate')*sigma^2;
    Dyy = imfilter(S,[1;-2;1],'replicate')*sigma^2;
    Dxy = imfilter(S,[1 0 -1;0 0 0;-1 0 1]/4,'replicate')*sigma^2;
    root = sqrt((Dxx-Dyy).^2+4*Dxy.^2);
    l1 = (Dxx+Dyy-root)/2; l2 = (Dxx+Dyy+root)/2;
    swap = abs(l1)>abs(l2); temp = l1(swap); l1(swap) = l2(swap); l2(swap) = temp;
    strength = sqrt(l1.^2+l2.^2);
    values = sort(strength(inner));
    contrast = max(1e-4,values(max(1,round(.95*numel(values)))));
    response = exp(-(l1./max(abs(l2),single(1e-6))).^2/(2*.5^2)) .* ...
        (1-exp(-strength.^2/(2*contrast^2)));
    response(l2<=0) = 0; response(~inner) = 0;
    V = max(V,response);
end
threshold = max(0.12,graythresh(V(inner)));
vessels = bwareaopen(V>threshold & inner,max(5,round(width*.012)));
e.vessels = vessels;
excludeDisc = imdilate(e.discMask,strel('disk',max(2,round(discRadius*.3)),0));
vesselMargin = imdilate(vessels,strel('disk',1,0));
% Dark lesion candidates: bottom-hat response and connected-component shape.
dark = imbothat(N,strel('disk',max(3,round(width*.012)),0));
values = sort(dark(inner & ~excludeDisc));
if isempty(values), darkThreshold = 1;
else, darkThreshold = max(.025,values(max(1,round(.975*numel(values))))); end
redEvidence = A(:,:,1)>A(:,:,3)+.015;
darkMask = dark>darkThreshold & inner & ~excludeDisc & ~vesselMargin & redEvidence;
cc = bwconncomp(darkMask);
p = regionprops(cc,'Area','Eccentricity','Solidity');
unit = max(0.25,(width/768)^2);
for k = 1:cc.NumObjects
    area = p(k).Area;
    if area>=2*unit && area<=28*unit && p(k).Eccentricity<.88 && p(k).Solidity>.55
        e.microaneurysms(cc.PixelIdxList{k}) = true;
    elseif area>28*unit && area<nnz(inner)*.015 && p(k).Solidity>.30
        e.hemorrhages(cc.PixelIdxList{k}) = true;
    end
end
% Bright yellow/white candidates: top-hat plus color, excluding disc estimate.
bright = imtophat(N,strel('disk',max(5,round(width*.022)),0));
values = sort(bright(inner & ~excludeDisc));
if isempty(values), brightThreshold = 1;
else, brightThreshold = max(.035,values(max(1,round(.975*numel(values))))); end
color = A(:,:,1)>.25 & G>.20 & G>A(:,:,3)*1.05;
ex = bright>brightThreshold & color & inner & ~excludeDisc;
cc = bwconncomp(ex); p = regionprops(cc,'Area');
for k = 1:cc.NumObjects
    if p(k).Area>=3*unit && p(k).Area<nnz(inner)*.02
        e.exudates(cc.PixelIdxList{k}) = true;
    end
end
ma = bwconncomp(e.microaneurysms); he = bwconncomp(e.hemorrhages); ex = bwconncomp(e.exudates);
e.counts = struct('MA',ma.NumObjects,'HE',he.NumObjects,'EX',ex.NumObjects);
skel = bwmorph(vessels,'skel',Inf); branches = bwmorph(skel,'branchpoints');
v = G(inner); ordered = sort(v); n = numel(ordered); total = nnz(inner);
e.features = [log1p(ma.NumObjects),nnz(e.microaneurysms)/total, ...
    log1p(he.NumObjects),nnz(e.hemorrhages)/total, ...
    log1p(ex.NumObjects),nnz(e.exudates)/total,nnz(vessels)/total, ...
    nnz(skel)/total,nnz(branches)/total,mean(v),std(v), ...
    ordered(max(1,round(.95*n)))-ordered(max(1,round(.05*n)))];
e.featureNames = {'logMA','MAAreaFraction','logHE','HEAreaFraction', ...
    'logEX','EXAreaFraction','VesselFraction','SkeletonFraction', ...
    'BranchFraction','GreenMean','GreenStd','GreenContrast'};
e.lesions = [lesionTable(e.microaneurysms,'MA',e); ...
    lesionTable(e.hemorrhages,'HE',e);lesionTable(e.exudates,'EX',e)];
e.overlay = makeEvidenceOverlay(e);
e.message = 'Untrained lesion/structure candidates; reduced-resolution analysis, specialist confirmation required.';
end

function t = lesionTable(mask,kind,e)
p = regionprops(mask,'Area','Centroid'); n = numel(p);
type = repmat(string(kind),n,1); area = zeros(n,1); x = area; y = area;
scaleX = e.nativeSize(2)/e.analysisSize(2); scaleY = e.nativeSize(1)/e.analysisSize(1);
for k = 1:n
    area(k) = p(k).Area;
    x(k) = (p(k).Centroid(1)-.5)*scaleX+.5;
    y(k) = (p(k).Centroid(2)-.5)*scaleY+.5;
end
t = table(type,area,x,y,'VariableNames',{'CandidateType','AnalysisAreaPixels','NativeX','NativeY'});
end
