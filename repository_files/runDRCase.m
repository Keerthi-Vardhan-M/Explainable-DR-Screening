function out = runDRCase(imagePath,c,model)
%RUNDRCASE End-to-end prototype, withholding predictions on quality failures.
if nargin < 2, c = drDemoConfig(); end
if nargin < 3, model = []; end
checkFundusEnvironment(); start = tic;
q = processFundus(imagePath);
original = im2single(q.original);
if ismatrix(original), original = repmat(original,1,1,3); end
out = struct('version',c.version,'source',char(imagePath),'imageID','', ...
    'timestamp',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')), ...
    'quality',rmfield(q,{'original','image','candidate','mask'}), ...
    'original',[],'enhanced',[],'field',[],'evidence',struct(), ...
    'prediction',struct('available',false,'grade',NaN,'scores',[], ...
    'cnnScores',[],'lesionScores',[],'score',NaN,'referableScore',NaN, ...
    'referableFlag',false,'calibrated',false,'method','Unavailable','message',''), ...
    'explanation',struct('available',false,'map',[],'overlay',[],'message','Not computed'), ...
    'review',struct('status','Pending','reviewer','','confirmedGrade','Not recorded','notes',''), ...
    'seconds',NaN,'outputFolder','','pdfPath','','clinicalReady',false);
[~,out.imageID] = fileparts(imagePath);
if ~isempty(q.image), enhanced = q.image;
elseif ~isempty(q.candidate), enhanced = q.candidate;
else, enhanced = original; end
% Consistent evidence features on ORIGINAL images; enhancement is shown for
% comparison and reserved for separately validated downstream use.
out.evidence = extractRetinalEvidence(original,q.mask,c);
sz = out.evidence.analysisSize;
out.original = imresize(original,sz); out.enhanced = imresize(enhanced,sz);
out.field = out.evidence.field;
if ~q.routeToAnalysis
    out.prediction.message = ['Classification withheld: ' q.message];
elseif ~c.preprocessingConfirmed
    out.prediction.message = 'Confirm model training preprocessing before classification.';
else
    try
        if isempty(model), model = loadDRModel(c.modelPath,c); end
        [p,~,X] = predictDRModel(original,model);
        out.prediction.cnnScores = p;
        out.prediction.method = 'Trained CNN';
        if ~isempty(c.lesionModelPath)
            S = load(c.lesionModelPath,'lesionModel'); lm = S.lesionModel;
            if lm.analysisSize~=c.lesionAnalysisSize || ~strcmp(lm.extractorVersion,out.evidence.version)
                error('drdemo:Fusion','Lesion branch extraction settings differ from training.');
            end
            b = predictLesionBranch(out.evidence.features,lm);
            out.prediction.lesionScores = b;
            p = c.cnnFusionWeight*p+(1-c.cnnFusionWeight)*b;
            out.prediction.method = 'CNN + trained lesion-feature branch';
        end
        threshold = c.referableThreshold;
        if ~isempty(c.calibrationPath)
            cal = loadDRCalibration(c,model);
            p = temperatureScores(p,cal.temperature); threshold = cal.referableThreshold;
            out.prediction.calibrated = true;
        end
        [score,idx] = max(p); grade = idx-1;
        out.prediction.available = true; out.prediction.grade = grade;
        out.prediction.scores = p; out.prediction.score = score;
        out.prediction.referableScore = sum(p(3:5));
        out.prediction.referableFlag = sum(p(3:5))>=threshold;
        out.prediction.message = 'Research screening estimate; doctor confirmation required.';
        if score<c.lowScoreThreshold
            out.prediction.message = 'Low model score; prioritize manual review.';
        end
        if c.computeGradCAM
            out.explanation = explainDRModel(X,model,grade,sz);
            if out.explanation.available
                out.explanation.overlay = blendAttention(out.original,out.explanation.map);
            end
        end
    catch ME
        out.prediction.available = false;
        out.prediction.grade = NaN; out.prediction.score = NaN;
        out.prediction.message = ['Model unavailable: ' ME.message];
    end
end
out.seconds = toc(start);
if ~isfolder(c.outputRoot), mkdir(c.outputRoot); end
out.outputFolder = tempname(c.outputRoot); mkdir(out.outputFolder);
imwrite(im2uint8(out.original),fullfile(out.outputFolder,'original_preview.png'));
imwrite(im2uint8(out.enhanced),fullfile(out.outputFolder,'enhanced_preview.png'));
imwrite(im2uint8(out.evidence.overlay),fullfile(out.outputFolder,'lesion_candidates.png'));
imwrite(out.field,fullfile(out.outputFolder,'retinal_field.png'));
for entry = {'vessels','microaneurysms','hemorrhages','exudates','discMask'}
    imwrite(out.evidence.(entry{1}),fullfile(out.outputFolder,[entry{1} '.png']));
end
if out.explanation.available
    imwrite(im2uint8(out.explanation.overlay),fullfile(out.outputFolder,'gradcam.png'));
end
if ~isempty(out.evidence.lesions)
    writetable(out.evidence.lesions,fullfile(out.outputFolder,'lesion_candidates.csv'));
end
writeCaseSummary(out);
if c.exportReport, out.pdfPath = exportDRReport(out); end
if c.saveCaseMAT, save(fullfile(out.outputFolder,'case.mat'),'out','-v7.3'); end
fprintf('%s | quality=%s | %s\n',out.imageID,q.status,out.prediction.message);
fprintf('Saved: %s\n',out.outputFolder);
end
