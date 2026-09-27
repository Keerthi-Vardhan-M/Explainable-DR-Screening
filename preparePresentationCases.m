function [cases,folder] = preparePresentationCases(c)
%PREPAREPRESENTATIONCASES Prepare labelled illustration cases and recapture demo.
% Selection uses label grades for variety, not model predictions/performance.
% These examples are NOT an independent evaluation population.
data = idridGradeManifest(c.datasetRoot); data = data(data.Split=="training",:);
selected = [];
for grade = [0 2 4]
    matches = find(data.Grade==grade);
    selected = [selected;matches(1:min(2,numel(matches)))]; %#ok<AGROW>
end
if ~isfolder(c.outputRoot), mkdir(c.outputRoot); end
folder = tempname(c.outputRoot); mkdir(folder);
cases = data(selected,:); cases.OutputFolder = repmat("",height(cases),1);
cases.ModelGrade = NaN(height(cases),1); cases.Quality = repmat("",height(cases),1);
demoConfig = c; demoConfig.outputRoot = folder;
for k = 1:height(cases)
    out = runDRCase(char(cases.ImagePath(k)),demoConfig);
    cases.OutputFolder(k) = string(out.outputFolder);
    cases.ModelGrade(k) = out.prediction.grade; cases.Quality(k) = string(out.quality.status);
end
% Explicitly simulated optical blur, kept separate from real originals.
[I,~] = readFundus(char(cases.ImagePath(1)));
I = imresize(I,min(1,1024/max(size(I,1),size(I,2))));
I = imgaussfilt(I,10);
blurPath = fullfile(folder,'SIMULATED_BLUR_FOR_RECAPTURE.png'); imwrite(im2uint8(I),blurPath);
runDRCase(blurPath,demoConfig);
writetable(cases,fullfile(folder,'presentation_cases.csv'));
fprintf('Illustration cases, reports and simulated recapture image: %s\n',folder);
end
