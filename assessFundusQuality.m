function [m,M] = assessFundusQuality(I,c,fixedMask)
%ASSESSFUNDUSQUALITY Stage 2: field, focus, noise and illumination proxies.
% I: RGB floating [0,1]. M: native-size logical field, not an anatomical mask.
if nargin < 2, c = fundusConfig(); end
scale = min(1,c.analysisSize/max(size(I,1),size(I,2)));
A = im2double(imresize(I,scale)); G = rgb2gray(A);
if nargin < 3
    smallMask = max(A,[],3) > c.maskThreshold;
    smallMask = imclose(smallMask,strel('disk',3,0));
    smallMask = imfill(smallMask,'holes'); smallMask = bwareafilt(smallMask,1);
    M = logical(imresize(smallMask,[size(I,1) size(I,2)],'nearest'));
else
    if ~islogical(fixedMask) || ~isequal(size(fixedMask),[size(I,1) size(I,2)])
        error('fundus:Mask','fixedMask must be native-size logical.');
    end
    M = fixedMask;
    smallMask = logical(imresize(M,[size(A,1) size(A,2)],'nearest'));
end
m = struct('minDimension',min(size(I,1),size(I,2)), ...
    'analysisSize',[size(A,1) size(A,2)], ...
    'coverage',nnz(smallMask)/numel(smallMask),'solidity',0,'axisRatio',Inf, ...
    'centerOffset',Inf,'focus',0,'mean',0,'darkFraction',1, ...
    'brightFraction',0,'illuminationCV',Inf,'contrast',0,'noise',0, ...
    'status','rejected','reasons',{{}},'reasonCodes',{{}});
if nnz(smallMask) >= 100
    p = regionprops(smallMask,'Area','Solidity','MajorAxisLength','MinorAxisLength','Centroid');
    [~,largest] = max([p.Area]); p = p(largest);
    m.solidity = p.Solidity;
    m.axisRatio = p.MajorAxisLength/max(p.MinorAxisLength,eps);
    sz = [size(G,2) size(G,1)];
    m.centerOffset = norm((p.Centroid-(sz+1)/2)./sz);
    inner = imerode(smallMask,strel('disk',max(2,round(min(size(G))*0.015)),0));
    if nnz(inner) < 100, inner = smallMask; end
    v = G(inner); m.mean = mean(v);
    m.darkFraction = mean(v < 0.03); m.brightFraction = mean(v > 0.97);
    sorted = sort(v); n = numel(sorted);
    m.contrast = sorted(max(1,round(.95*n))) - sorted(max(1,round(.05*n)));
    smooth = imgaussfilt(G,0.7);
    lap = imfilter(smooth,[0 1 0;1 -4 1;0 1 0],'replicate');
    m.focus = var(lap(inner),1);
    residual = G-medfilt2(G,[3 3],'symmetric'); rv = residual(inner);
    m.noise = median(abs(rv-median(rv)))/0.6745;
    sigma = max(5,min(size(G))*0.06);
    field = imgaussfilt(G.*double(smallMask),sigma) ./ ...
        max(imgaussfilt(double(smallMask),sigma),eps);
    fv = field(inner); m.illuminationCV = std(fv)/max(mean(fv),eps);
end
[m.status,m.reasons,m.reasonCodes] = gateFundusQuality(m,c);
end
