function [audit,summary,runDir] = validateIDRiD(datasetRoot,outputRoot,maxImages)
%VALIDATEIDRID Compatibility audit on real original images, not clinical QA.
% Default processes five originals; use Inf to process the full dataset.
if nargin < 2, outputRoot = fullfile(pwd,'stage123_results'); end
if nargin < 3, maxImages = 5; end
validateattributes(maxImages,{'numeric'},{'real','scalar','>=',1});
if isnan(maxImages), error('fundus:Validation','maxImages must be at least 1 or Inf.'); end
c = fundusConfig(); c.datasetMode = 'idrid';
files = discoverFundus(datasetRoot,c);
count = min(height(files),floor(maxImages));
audit = struct('discoveredImages',height(files),'processedImages',count, ...
    'softwareCompatibility',false,'clinicalQualityValidated',false);
% Use native images throughout, no dataset-specific enhancement settings.
for k = 1:count
    r = processFundus(char(files.ImagePath(k)),c);
    assert(isequal(size(r.mask),[size(r.original,1) size(r.original,2)]));
    if r.routeToAnalysis
        assert(isequal(size(r.image),size(r.original)));
        assert(all(isfinite(r.image(:))) && all(r.image(:)>=0 & r.image(:)<=1));
    else
        assert(isempty(r.image));
    end
    assert(~r.clinicalReady);
end
[summary,runDir] = runStage123(files.ImagePath(1:count),outputRoot,c);
audit.softwareCompatibility = ~any(summary.Status=="error");
save(fullfile(runDir,'idrid_audit.mat'),'audit');
assert(audit.softwareCompatibility,'Some IDRiD originals failed; inspect summary.csv.');
fprintf('IDRiD software compatibility passed on %d/%d images.\n',count,height(files));
end
