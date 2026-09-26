function cal = loadDRCalibration(c,model)
%LOADDRCALIBRATION Refuse stale preprocessing/fusion settings.
s = load(c.calibrationPath,'calibration'); cal = s.calibration;
if ~strcmp(cal.modelPath,model.path) || ~strcmp(cal.inputRange,model.inputRange) ...
        || ~strcmp(cal.lesionModelPath,c.lesionModelPath) ...
        || cal.fusionWeight~=c.cnnFusionWeight
    error('drdemo:Calibration','Calibration does not match this model/preprocessing/fusion configuration. Refit it.');
end
end
