function [J,ops] = enhanceFundus(I,M,m,c)
%ENHANCEFUNDUS Stage 3: conditional LAB luminance enhancement.
% No resizing/warping/sharpening. Native geometry and outside-mask pixels stay.
if nargin < 4, c = fundusConfig(); end
if ~any(M(:)), error('fundus:Mask','Cannot enhance an empty retinal mask.'); end
ops = {}; lab = rgb2lab(I); L = lab(:,:,1)/100; work = L;
work(~M) = median(L(M));
if m.noise > c.maxNoise
    filtered = imbilatfilt(work,c.denoiseDegree,c.denoiseSpatialSigma);
    work = (1-c.denoiseBlend)*work+c.denoiseBlend*filtered;
    ops{end+1} = 'blended bilateral luminance denoising';
end
if m.illuminationCV > c.goodIlluminationCV ...
        || m.mean < c.goodMeanRange(1) || m.mean > c.goodMeanRange(2)
    sz = m.analysisSize;
    smallL = imresize(work,sz); smallM = imresize(single(M),sz,'nearest');
    sigma = max(5,min(sz)*0.06);
    field = imgaussfilt(smallL.*smallM,sigma) ./ ...
        max(imgaussfilt(smallM,sigma),single(eps));
    target = median(field(smallM > 0));
    if m.mean < c.goodMeanRange(1), target = max(target,0.45); end
    if m.mean > c.goodMeanRange(2), target = min(target,0.65); end
    gain = min(c.maxGain,max(1/c.maxGain,target./max(field,0.05)));
    gain = imresize(gain,[size(L,1) size(L,2)],'bilinear');
    work = min(1,max(0,work.*gain));
    ops{end+1} = 'bounded illumination normalization';
end
if m.contrast < c.goodContrast
    [rows,cols] = find(M); rr = min(rows):max(rows); cc = min(cols):max(cols);
    region = work(rr,cc);
    tiles = min(c.claheTiles,max([2 2],floor(size(region)/4)));
    adjusted = adapthisteq(region,'NumTiles',tiles,'ClipLimit',c.clipLimit);
    work(rr,cc) = (1-c.claheBlend)*region+c.claheBlend*adjusted;
    ops{end+1} = 'blended luminance CLAHE';
end
% Pad ensures finite distance even when the mask covers the entire frame.
distance = bwdist(~padarray(M,[1 1],false,'both'));
distance = distance(2:end-1,2:end-1);
weight = min(1,distance/max(3,min(size(M))*0.01)); weight(~M) = 0;
lab(:,:,1) = 100*min(1,max(0,L.*(1-weight)+work.*weight));
J = min(1,max(0,lab2rgb(lab)));
for k = 1:3
    plane = J(:,:,k); original = I(:,:,k);
    plane(~M) = original(~M); J(:,:,k) = plane;
end
end
