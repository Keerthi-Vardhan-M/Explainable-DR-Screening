function c = setupDRDemo(projectRoot)
%SETUPDRDEMO Run from any folder after extracting the full project.
here = fileparts(mfilename('fullpath')); addpath(genpath(here));
if nargin < 1 || isempty(projectRoot), projectRoot = here; end
c = drDemoConfig(); c.projectRoot = char(projectRoot);
c.datasetRoot = fullfile(c.projectRoot,'datasets','IDRiD');
c.outputRoot = fullfile(c.projectRoot,'dr_demo_results');
modelCandidates = {fullfile(c.projectRoot,'models','trainedDRModel.mat'), ...
    fullfile(c.projectRoot,'trainedDRModel.mat'), ...
    fullfile(c.projectRoot,'trainedDRModel (1).mat')};
c.modelPath = modelCandidates{1};
for k = 1:numel(modelCandidates)
    if isfile(modelCandidates{k}), c.modelPath = modelCandidates{k}; break; end
end
checkFundusEnvironment();
if ~isfolder(c.outputRoot), mkdir(c.outputRoot); end
fprintf('Full DR demo %s ready.\n',c.version);
fprintf('Dataset: %s\n',c.datasetRoot);
fprintf('Deep Learning: %d; Simulink: %d; Statistics: %d\n', ...
    ~isempty(which('gradCAM')),~isempty(which('new_system')),~isempty(which('fitcensemble')));
if isfile(c.modelPath)
    inspectDRModel(c.modelPath);
else
    fprintf('Place your trained MAT file at %s or choose it in the app.\n',c.modelPath);
end
fprintf('Confirm model pixel scaling before enabling classification.\n');
fprintf('Launch: launchDRDemo(c)\n');
end
