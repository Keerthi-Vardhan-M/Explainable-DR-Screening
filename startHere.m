%STARTHERE Quick start in MATLAB Online or desktop MATLAB.
% Upload matlab_stage123.zip to MATLAB Drive, then run the two commands:
%   unzip('matlab_stage123.zip');
%   cd('matlab_stage123'); startHere
addpath(fileparts(mfilename('fullpath')));
checkFundusEnvironment();
fprintf('Environment ready: MATLAB %s\n',version('-release'));
fprintf('Running engineering regression checks...\n');
checkStage123();
fprintf('\nSingle image: r = demoStage123(''path/to/image.jpg'');\n');
fprintf('Dataset folder: [summary,runDir] = runStage123(''path/to/dataset'');\n');
fprintf('IDRiD: see README.md for extraction and batch commands.\n');
