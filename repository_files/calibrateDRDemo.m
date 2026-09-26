function [c,calibration,path] = calibrateDRDemo(c,maxImages)
%CALIBRATEDRDEMO Temperature and referral threshold using training development
% originals; excludes IDs used to fit the optional lesion branch.
% Official test split remains untouched. APTOS training IDs are unavailable,
% so this is NOT patient-level leakage certification.
if nargin < 2, maxImages = 60; end
data = idridGradeManifest(c.datasetRoot); data = data(data.Split=="training",:);
if ~isempty(c.lesionModelPath)
    s = load(c.lesionModelPath,'lesionModel');
    data = data(~ismember(data.ImageID,s.lesionModel.trainingIDs),:);
end
rng(23); chosen = [];
for g = 0:4
    indices = find(data.Grade==g); indices = indices(randperm(numel(indices)));
    chosen = [chosen;indices(1:min(numel(indices),max(1,floor(maxImages/5))))]; %#ok<AGROW>
end
data = data(chosen,:); [p,rows] = scoreDRDataset(data,c);
keep = rows.Classified; p = p(keep,:); y = data.Grade(keep);
if numel(y)<10 || ~any(y<2) || ~any(y>=2)
    error('drdemo:Calibration','Too few classified development images or one referral class is absent.');
end
grid = [.5 .75 1 1.5 2 3 5 8]; loss = zeros(size(grid));
for k = 1:numel(grid)
    calibrated = temperatureScores(p,grid(k));
    ix = sub2ind(size(p),(1:numel(y))',y+1);
    loss(k) = -mean(log(max(calibrated(ix),1e-12)));
end
[~,best] = min(loss); T = grid(best); p = temperatureScores(p,T);
thresholds = 0:.01:1; candidates = zeros(numel(thresholds),2);
for k = 1:numel(thresholds)
    met = referralMetrics(y,p,thresholds(k));
    candidates(k,:) = [met.sensitivity met.specificity];
end
possible = find(candidates(:,1)>=.90);
[~,chosenIndex] = max(candidates(possible,2)); threshold = thresholds(possible(chosenIndex));
calibration = struct('temperature',T,'referableThreshold',threshold, ...
    'modelPath',char(c.modelPath),'inputRange',c.modelInputRange, ...
    'lesionModelPath',c.lesionModelPath,'fusionWeight',c.cnnFusionWeight, ...
    'developmentIDs',data.ImageID(keep),'developmentPaths',data.ImagePath(keep), ...
    'classifiedCoverage',mean(keep), ...
    'developmentMetrics',referralMetrics(y,p,threshold), ...
    'clinicalValidated',false,'method','Development-set log-score temperature scaling');
if ~isfolder(c.outputRoot), mkdir(c.outputRoot); end
path = fullfile(c.outputRoot,'calibration.mat');
if isfile(path), path = [tempname(c.outputRoot) '_calibration.mat']; end
save(path,'calibration'); writetable(rows,[path '.development.csv']);
c.calibrationPath = path; disp(calibration.developmentMetrics);
fprintf('Development-selected threshold %.2f; independent test metrics still required.\n',threshold);
end
