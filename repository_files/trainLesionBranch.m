function [lesionModel,path] = trainLesionBranch(c,maxImages)
%TRAINLESIONBRANCH Bagged randomized trees on lesion candidate features.
% Uses only official TRAINING originals, never official test labels/images.
% This is a demo classifier trained on heuristic features, not lesion labels.
if nargin < 1, c = drDemoConfig(); end
if nargin < 2, maxImages = 100; end
validateattributes(maxImages,{'numeric'},{'scalar','real','>=',5});
data = idridGradeManifest(c.datasetRoot); data = data(data.Split=="training",:);
rng(19); chosen = [];
for grade = 0:4
    indices = find(data.Grade==grade); indices = indices(randperm(numel(indices)));
    chosen = [chosen;indices(1:min(numel(indices),floor(maxImages/5)))]; %#ok<AGROW>
end
data = data(chosen,:);
if numel(unique(data.Grade))~=5, error('drdemo:Labels','All five classes required to train lesion branch.'); end
X = zeros(height(data),12);
for k = 1:height(data)
    [I,~] = readFundus(char(data.ImagePath(k)));
    [~,mask] = assessFundusQuality(I);
    evidence = extractRetinalEvidence(I,mask,c); X(k,:) = evidence.features;
    fprintf('Lesion branch features %d/%d\n',k,height(data));
end
trees = templateTree('MaxNumSplits',20,'NumVariablesToSample',4);
Y = categorical(string(data.Grade),string(0:4));
classifier = fitcensemble(X,Y,'Method','Bag','NumLearningCycles',40,'Learners',trees);
lesionModel = struct('classifier',classifier,'analysisSize',c.lesionAnalysisSize, ...
    'extractorVersion','retinal-candidates-v1','trainingIDs',data.ImageID, ...
    'trainingPaths',data.ImagePath,'features',X,'grades',data.Grade, ...
    'trainingSet','IDRiD official training split only','clinicalValidated',false);
if ~isfolder(c.outputRoot), mkdir(c.outputRoot); end
path = fullfile(c.outputRoot,'lesion_branch.mat');
if isfile(path), path = [tempname(c.outputRoot) '_lesion_branch.mat']; end
save(path,'lesionModel','-v7.3'); fprintf('Saved lesion branch: %s\n',path);
end
