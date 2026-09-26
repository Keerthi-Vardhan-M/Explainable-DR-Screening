function [summary,runDir] = runStage123(source,outputRoot,c)
%RUNSTAGE123 Batch diagram stages 1-3, one image at a time.
% source: folder, file list, imageDatastore, image, or ImagePath CSV/table.
% A unique run directory prevents overwriting prior outputs.
if nargin < 3, c = fundusConfig(); end
if nargin < 2 || isempty(outputRoot), outputRoot = fullfile(pwd,'stage123_results'); end
validateFundusConfig(c);
checkFundusEnvironment();
files = discoverFundus(source,c);
if ~isfolder(outputRoot), [ok,msg] = mkdir(outputRoot); if ~ok, error('fundus:Output','%s',msg); end, end
runDir = tempname(outputRoot);
[ok,msg] = mkdir(runDir); if ~ok, error('fundus:Output','%s',msg); end
writetable(files,fullfile(runDir,'input_manifest.csv'));
config = c; save(fullfile(runDir,'configuration.mat'),'config');
rows = repmat(emptyRow(),height(files),1);
for k = 1:height(files)
    row = emptyRow();
    row.ImagePath = files.ImagePath(k); row.ImageID = files.ImageID(k);
    row.DatasetSplit = files.DatasetSplit(k);
    safeName = regexprep(char(row.ImageID),'[^A-Za-z0-9_-]','_');
    row.OutputFolder = string(fullfile(runDir,sprintf('%06d_%s',k,safeName)));
    start = tic;
    try
        r = processFundus(char(row.ImagePath),c);
        saveFundusResult(r,char(row.OutputFolder),c);
        row.Status = string(r.status); row.RouteToAnalysis = r.routeToAnalysis;
        row.Feedback = string(r.message); row.ReasonCodes = string(strjoin(r.reasonCodes,';'));
        row.Operations = string(strjoin(r.operations,';'));
        row.BeforeQuality = string(r.before.status);
        row.FocusBefore = r.before.focus; row.MeanBefore = r.before.mean;
        row.ContrastBefore = r.before.contrast; row.NoiseBefore = r.before.noise;
        row.IlluminationCVBefore = r.before.illuminationCV;
        row.FieldCoverage = r.before.coverage;
        if ~isempty(fieldnames(r.after))
            row.AfterQuality = string(r.after.status);
            row.FocusAfter = r.after.focus; row.MeanAfter = r.after.mean;
            row.ContrastAfter = r.after.contrast; row.NoiseAfter = r.after.noise;
            row.IlluminationCVAfter = r.after.illuminationCV;
        end
        clear r
    catch ME
        if ~c.continueOnError, rethrow(ME); end
        row.Status = "error"; row.ErrorID = string(ME.identifier);
        row.Feedback = string(ME.message);
        warning('fundus:BatchItem','Item %d failed: %s',k,ME.message);
    end
    row.Seconds = toc(start); rows(k) = row;
    summary = struct2table(rows(1:k));
    % Save progress after each item, including corrupt/unreadable images.
    writetable(summary,fullfile(runDir,'summary.csv'));
    fprintf('[%d/%d] %s: %s\n',k,height(files),char(row.ImageID),char(row.Status));
end
fprintf('Outputs: %s\n',runDir);
end

function row = emptyRow()
row = struct('ImagePath',"",'ImageID',"",'DatasetSplit',"", ...
    'Status',"",'RouteToAnalysis',false,'BeforeQuality',"",'AfterQuality',"", ...
    'Feedback',"",'ReasonCodes',"",'Operations',"", ...
    'FocusBefore',NaN,'FocusAfter',NaN,'MeanBefore',NaN,'MeanAfter',NaN, ...
    'ContrastBefore',NaN,'ContrastAfter',NaN,'NoiseBefore',NaN,'NoiseAfter',NaN, ...
    'IlluminationCVBefore',NaN,'IlluminationCVAfter',NaN, ...
    'FieldCoverage',NaN,'Seconds',NaN,'OutputFolder',"",'ErrorID',"");
end
