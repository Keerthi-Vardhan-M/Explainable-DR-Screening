function saveFundusResult(r,folder,c)
%SAVEFUNDUSRESULT PNG images, quality JSON, review preview, optional MAT.
% folder must be new so stale analysis images cannot survive a rejected run.
if nargin < 3, c = r.config; end
if isfolder(folder) || isfile(folder)
    error('fundus:Output','Result folder already exists; use a new folder: %s',folder);
end
[ok,msg] = mkdir(folder); if ~ok, error('fundus:Output','%s',msg); end
if r.routeToAnalysis && ~isempty(r.image)
    writePNG(r.image,fullfile(folder,'analysis_image.png'),c);
end
if c.writeCandidate && ~isempty(r.candidate)
    writePNG(r.candidate,fullfile(folder,'enhancement_candidate.png'),c);
end
imwrite(r.mask,fullfile(folder,'retinal_mask.png'));
if c.writePreview
    % Small PNG for review, generated without a graphics window or display.
    original = r.original;
    if ismatrix(original), original = repmat(original,1,1,3); end
    original = im2single(original);
    scale = min(1,640/max(size(original,1),size(original,2)));
    left = imresize(original,scale);
    if ~isempty(r.candidate), right = imresize(r.candidate,[size(left,1) size(left,2)]);
    elseif ~isempty(r.image), right = imresize(r.image,[size(left,1) size(left,2)]);
    else, right = left; end
    middle = repmat(single(imresize(r.mask,[size(left,1) size(left,2)],'nearest')),1,1,3);
    imwrite(im2uint8([left middle right]),fullfile(folder,'comparison.png'));
end
quality = rmfield(r,{'original','candidate','image','mask'});
quality.previewOrder = 'original | estimated retinal field | candidate or unchanged original';
quality.hasCandidate = ~isempty(r.candidate);
quality.hasAnalysisImage = r.routeToAnalysis && ~isempty(r.image);
quality.nonfiniteMetrics = 'JSON null denotes unavailable/nonfinite, not zero';
fid = fopen(fullfile(folder,'quality.json'),'w','n','UTF-8');
if fid < 0, error('fundus:Output','Cannot write quality.json'); end
closer = onCleanup(@() fclose(fid));
fprintf(fid,'%s\n',jsonencode(quality));
clear closer
if c.writeMAT, save(fullfile(folder,'result.mat'),'r','-v7.3'); end
end

function writePNG(I,path,c)
if c.pngBitDepth == 16, encoded = im2uint16(I); else, encoded = im2uint8(I); end
imwrite(encoded,path);
end
