function [p,rows,pA,pB] = scoreDRDataset(data,c)
%SCOREDRDATASET Batch model evaluation without PDF/Grad-CAM overhead.
% Quality-held cases are excluded from classified-only metrics but remain
% in rows, and coverage must be reported with every metric table.
m = loadDRModel(c.modelPath,c); n = height(data);
p = NaN(n,5); pA = p; pB = p;
rows = data; rows.Quality = repmat("",n,1); rows.Classified = false(n,1);
rows.Feedback = repmat("",n,1);
lm = [];
if ~isempty(c.lesionModelPath), s = load(c.lesionModelPath,'lesionModel'); lm = s.lesionModel; end
for k = 1:n
    try
        q = processFundus(char(data.ImagePath(k)));
        rows.Quality(k) = string(q.status);
        if ~q.routeToAnalysis
            rows.Feedback(k) = string(q.message); continue
        end
        I = im2single(q.original); pA(k,:) = predictDRModel(I,m);
        p(k,:) = pA(k,:);
        if ~isempty(lm)
            if lm.analysisSize~=c.lesionAnalysisSize || ~strcmp(lm.extractorVersion,'retinal-candidates-v1')
                error('drdemo:Fusion','Feature analysis size differs from training.');
            end
            e = extractRetinalEvidence(I,q.mask,c);
            pB(k,:) = predictLesionBranch(e.features,lm);
            p(k,:) = c.cnnFusionWeight*pA(k,:)+(1-c.cnnFusionWeight)*pB(k,:);
        end
        rows.Classified(k) = true;
    catch ME
        rows.Feedback(k) = string(ME.message); rows.Quality(k) = "error";
    end
    fprintf('Scored %d/%d\n',k,n);
end
end
