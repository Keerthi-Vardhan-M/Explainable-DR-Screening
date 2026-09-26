function [status,reasons,codes] = gateFundusQuality(m,c)
%GATEFUNDUSQUALITY Three-way gate with reason codes and capture feedback.
reasons = {}; codes = {};
if m.minDimension < c.minDimension
    codes{end+1} = 'native_resolution';
    reasons{end+1} = 'Capture at higher native resolution; resizing cannot restore detail.';
end
if m.coverage < c.minCoverage || m.solidity < c.minSolidity
    codes{end+1} = 'retinal_field';
    reasons{end+1} = 'Retinal field unreliable; check alignment, lens obstruction and framing.';
end
if m.axisRatio > c.maxAxisRatio || m.centerOffset > c.maxCenterOffset
    codes{end+1} = 'framing';
    reasons{end+1} = 'Field shape or centering fails this camera profile; realign or request review.';
end
if m.focus < c.minFocus
    codes{end+1} = 'severe_focus';
    reasons{end+1} = 'Very low focus score; adjust focus, steady camera and recapture.';
end
if m.mean < c.minMean || m.mean > c.maxMean ...
        || m.darkFraction > c.maxDarkFraction || m.brightFraction > c.maxBrightFraction
    codes{end+1} = 'severe_exposure';
    reasons{end+1} = 'Severe exposure loss; check illumination and recapture.';
end
if m.illuminationCV > c.maxIlluminationCV
    codes{end+1} = 'severe_illumination';
    reasons{end+1} = 'Severe illumination variation; check positioning and illumination, then recapture.';
end
if m.noise > c.rejectNoise
    codes{end+1} = 'severe_noise';
    reasons{end+1} = 'Severe noise estimate; check camera exposure and acquisition settings, then recapture.';
end
if ~isempty(codes), status = 'rejected'; return; end
if m.focus < c.goodFocus
    codes{end+1} = 'borderline_focus';
    reasons{end+1} = 'Borderline original focus requires review or recapture.';
end
if m.illuminationCV > c.goodIlluminationCV
    codes{end+1} = 'uneven_illumination';
    reasons{end+1} = 'Borderline illumination: attempt bounded normalization.';
end
if m.mean < c.goodMeanRange(1) || m.mean > c.goodMeanRange(2)
    codes{end+1} = 'borderline_exposure';
    reasons{end+1} = 'Borderline exposure: attempt bounded normalization.';
end
if m.contrast < c.goodContrast
    codes{end+1} = 'low_contrast';
    reasons{end+1} = 'Low contrast: attempt conservative CLAHE.';
end
if m.noise > c.maxNoise
    codes{end+1} = 'borderline_noise';
    reasons{end+1} = 'Borderline noise: attempt conservative luminance denoising.';
end
if isempty(codes), status = 'acceptable'; else, status = 'borderline'; end
end
