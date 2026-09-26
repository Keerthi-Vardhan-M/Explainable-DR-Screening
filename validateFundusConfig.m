function validateFundusConfig(c)
%VALIDATEFUNDUSCONFIG Fail early on missing settings or inconsistent thresholds.
base = fundusConfig(); names = fieldnames(base);
if ~isstruct(c) || ~isscalar(c) || ~all(isfield(c,names)) ...
        || ~isempty(setdiff(fieldnames(c),names))
    error('fundus:Config','Use fundusConfig() and edit its existing fields.');
end
numericNames = {'analysisSize','minDimension','maskThreshold','minCoverage', ...
    'minSolidity','maxAxisRatio','maxCenterOffset','minFocus','goodFocus', ...
    'minMean','maxMean','maxDarkFraction','maxBrightFraction', ...
    'maxIlluminationCV','goodIlluminationCV','goodContrast','maxNoise', ...
    'rejectNoise','clipLimit','claheBlend','maxGain','maxClippingIncrease', ...
    'denoiseBlend','denoiseSpatialSigma','denoiseDegree','pngBitDepth'};
for k = 1:numel(numericNames)
    validateattributes(c.(numericNames{k}),{'numeric'}, ...
        {'real','finite','scalar','nonnegative'},mfilename,numericNames{k});
end
unitNames = {'maskThreshold','minCoverage','minSolidity','maxCenterOffset', ...
    'minMean','maxMean','maxDarkFraction','maxBrightFraction','goodContrast', ...
    'maxNoise','rejectNoise','clipLimit','claheBlend','denoiseBlend', ...
    'maxClippingIncrease'};
for k = 1:numel(unitNames)
    if c.(unitNames{k}) > 1
        error('fundus:Config','%s must be between 0 and 1.',unitNames{k});
    end
end
validateattributes(c.goodMeanRange,{'numeric'},{'real','finite','numel',2,'>=',0,'<=',1});
validateattributes(c.claheTiles,{'numeric'},{'real','finite','integer','size',[1 2],'>=',2});
validateattributes(c.analysisSize,{'numeric'},{'integer','>=',64});
validateattributes(c.minDimension,{'numeric'},{'integer','>=',8});
if c.minFocus >= c.goodFocus || c.maxNoise >= c.rejectNoise ...
        || c.goodIlluminationCV >= c.maxIlluminationCV ...
        || c.minMean >= c.goodMeanRange(1) || c.goodMeanRange(1) >= c.goodMeanRange(2) ...
        || c.goodMeanRange(2) >= c.maxMean || c.maxGain < 1 || c.maxAxisRatio < 1 ...
        || c.maskThreshold == 0 || c.denoiseSpatialSigma == 0 || c.denoiseDegree == 0
    error('fundus:Config','Inconsistent thresholds or enhancement settings.');
end
if ~ismember(c.pngBitDepth,[8 16]), error('fundus:Config','pngBitDepth must be 8 or 16.'); end
flags = {'allowGrayscale','recursive','writeMAT','writeCandidate','writePreview','continueOnError'};
for k = 1:numel(flags), validateattributes(c.(flags{k}),{'logical'},{'scalar'}); end
if ~any(strcmp(c.datasetMode,{'auto','idrid','generic'}))
    error('fundus:Config','datasetMode must be auto, idrid, or generic.');
end
for name = {'excludeFolderPatterns','excludeFilePatterns','extensions'}
    if ~iscellstr(c.(name{1})) %#ok<ISCLSTR>
        error('fundus:Config','%s must be a cell array of character vectors.',name{1});
    end
end
end
