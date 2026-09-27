function [c,audit] = verifyDRPreprocessing(c,maxImages)
%VERIFYDRPREPROCESSING Compare two declared adapters on TRAINING labels only.
% Selects an empirical demo adapter; does not recover undocumented transforms.
% Official test labels are never used for adapter choice.
if nargin < 2, maxImages = 20; end
data = idridGradeManifest(c.datasetRoot); train = data(data.Split=="training",:);
rng(17); chosen = [];
for grade = 0:4
    indices = find(train.Grade==grade); indices = indices(randperm(numel(indices)));
    chosen = [chosen;indices(1:min(numel(indices),max(1,floor(maxImages/5))))]; %#ok<AGROW>
end
if numel(chosen)<5, error('drdemo:Labels','Too few training originals for adapter comparison.'); end
subset = train(chosen,:); presets = {'zero_255','zero_one'};
loss = zeros(2,1); accuracy = loss;
for a = 1:2
    c.modelInputRange = presets{a}; c.preprocessingConfirmed = true;
    m = loadDRModel(c.modelPath,c); p = zeros(height(subset),5);
    for j = 1:height(subset)
        [I,~] = readFundus(char(subset.ImagePath(j)));
        p(j,:) = predictDRModel(I,m);
    end
    linear = sub2ind(size(p),(1:height(subset))',subset.Grade+1);
    loss(a) = -mean(log(max(p(linear),1e-12)));
    [~,pred] = max(p,[],2); accuracy(a) = mean(pred-1==subset.Grade);
end
[~,best] = min(loss); c.modelInputRange = presets{best}; c.preprocessingConfirmed = true;
audit = struct('method','Empirical full-frame resize/pixel-scale adapter selection on IDRiD training subset', ...
    'selectedRange',c.modelInputRange,'presets',{presets},'negativeLogLoss',loss, ...
    'accuracy',accuracy,'imageIDs',subset.ImageID,'originalTrainingTransformRecovered',false);
if ~isfolder(c.outputRoot), mkdir(c.outputRoot); end
save(fullfile(c.outputRoot,'verified_demo_config.mat'),'c','audit');
disp(table(string(presets(:)),loss,accuracy,'VariableNames',{'InputRange','LogLoss','Accuracy'}));
fprintf('Selected demo adapter: %s. Verify training code if available.\n',c.modelInputRange);
end
