function e = explainDRModel(X,m,targetGrade,displaySize)
%EXPLAINDRMODEL Genuine Grad-CAM for the CNN contribution, not lesion truth.
e = struct('available',false,'map',[],'overlay',[], ...
    'featureLayer','','reductionLayer','','message','Grad-CAM unavailable.');
try
    index = find(m.classValues==targetGrade,1);
    args = {'ExecutionEnvironment','cpu'};
    if ~isempty(m.featureLayer), args = [args {'FeatureLayer',m.featureLayer}]; end
    if ~isempty(m.reductionLayer), args = [args {'ReductionLayer',m.reductionLayer}]; end
    if isa(m.net,'dlnetwork')
        target = index;
    else
        target = char(string(targetGrade));
    end
    [map,feature,reduction] = gradCAM(m.net,X,target,args{:});
    if isa(map,'dlarray'), map = extractdata(map); end
    if isa(map,'gpuArray'), map = gather(map); end
    map = double(map);
    map = squeeze(map);
    if ~ismatrix(map) || any(~isfinite(map(:)))
        error('drdemo:CAM','Unexpected Grad-CAM output.');
    end
    map = imresize(map,displaySize);
    range = max(map(:))-min(map(:));
    if range<=eps
        e.message = 'Grad-CAM is constant for this image; no localized attention shown.'; return
    end
    e.map = single((map-min(map(:)))/range);
    e.featureLayer = feature; e.reductionLayer = reduction;
    e.available = true;
    e.message = 'CNN attention for the displayed grade; attention is not a lesion segmentation.';
catch ME
    e.message = ['Grad-CAM unavailable: ' ME.message];
end
end
