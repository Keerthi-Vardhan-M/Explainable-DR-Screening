% STARTHERE Launch the portable GitHub version of the DR screening demo.
repoRoot = fileparts(mfilename('fullpath'));
addpath(genpath(repoRoot));
addpath(fullfile(repoRoot,'core','matlab_stage123'),'-begin');
clear fundusConfig validateFundusConfig discoverFundus exportDRReport

c = setupDRDemo(repoRoot);

% This adapter was selected empirically on a small labelled IDRiD training
% subset. It is a demo configuration, not recovery of the original training
% pipeline and not clinical validation.
if isfile(c.modelPath)
    c.modelInputRange = 'zero_255';
    c.preprocessingConfirmed = true;
end

app = launchDRDemo(c);
fprintf('\nChoose an IDRiD image, or use:\n%s\n', ...
    fullfile(repoRoot,'demo_assets','synthetic_fundus.png'));
fprintf('The synthetic image tests the interface only; it is not clinical data.\n');
