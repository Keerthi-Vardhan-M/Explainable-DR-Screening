function [results,rows,folder] = validateDRDemo(c,maxImages)
%VALIDATEDRDEMO Measured metrics on the official IDRiD TEST split.
% Defaults to all test originals. MaxImages may reduce runtime for smoke tests,
% but a partial result must never be presented as the full benchmark.
if nargin < 2, maxImages = Inf; end
data = idridGradeManifest(c.datasetRoot); data = data(data.Split=="testing",:);
data = data(1:min(height(data),floor(maxImages)),:);
if ~isempty(c.lesionModelPath)
    s = load(c.lesionModelPath,'lesionModel');
    % IDRiD resets IDs in the testing folder; identical numbers across splits
    % are valid. Check complete paths, not bare filename IDs.
    assert(~any(ismember(data.ImagePath,s.lesionModel.trainingPaths)),'Train/test file overlap detected.');
end
[p,rows,pA,pB] = scoreDRDataset(data,c); keep = rows.Classified;
if ~any(keep), error('drdemo:Validation','No classified test images. Check feedback and preprocessing.'); end
threshold = c.referableThreshold;
if ~isempty(c.calibrationPath)
    cal = loadDRCalibration(c,loadDRModel(c.modelPath,c));
    assert(~any(ismember(data.ImagePath,cal.developmentPaths)),'Calibration/test file overlap detected.');
    p(keep,:) = temperatureScores(p(keep,:),cal.temperature); threshold = cal.referableThreshold;
end
results = struct('testImages',height(data),'classifiedImages',nnz(keep), ...
    'classifiedCoverage',mean(keep),'withheldImages',nnz(~keep), ...
    'metricPopulation','Classified cases only; withheld cases require manual review', ...
    'CNN',referralMetrics(data.Grade(keep),pA(keep,:),c.referableThreshold), ...
    'integrated',referralMetrics(data.Grade(keep),p(keep,:),threshold), ...
    'lesionBranch',[],'clinicalValidated',false,'partialBenchmark',isfinite(maxImages));
if ~isempty(c.lesionModelPath)
    results.lesionBranch = referralMetrics(data.Grade(keep),pB(keep,:),c.referableThreshold);
end
if ~isfolder(c.outputRoot), mkdir(c.outputRoot); end
folder = tempname(c.outputRoot); mkdir(folder);
writetable(rows,fullfile(folder,'test_cases.csv')); save(fullfile(folder,'validation.mat'),'results','p','pA','pB');
f = figure('Name','Measured IDRiD test results','Color','white','Position',[100 100 1080 500]);
tiledlayout(f,1,2);
ax = nexttile; imagesc(ax,results.integrated.confusion5); colorbar(ax);
xticks(ax,1:5); xticklabels(ax,0:4); yticks(ax,1:5); yticklabels(ax,0:4);
xlabel(ax,'Predicted grade'); ylabel(ax,'Label grade'); title(ax,'Integrated: classified test cases');
ax = nexttile; bar(ax,[results.integrated.sensitivity results.integrated.specificity results.classifiedCoverage]);
xticklabels(ax,{'Sensitivity','Specificity','Coverage'}); ylim(ax,[0 1]);
title(ax,sprintf('Measured on %d/%d test originals',nnz(keep),height(data)));
exportgraphics(f,fullfile(folder,'validation.png'),'Resolution',150);
exportgraphics(f,fullfile(folder,'validation.pdf'),'ContentType','vector');
disp(results); fprintf('Validation saved: %s\n',folder);
end
