function r = processFundus(input,c)
%PROCESSFUNDUS Diagram stages 1 input, 2 quality gate, 3 enhancement.
% Status describes provisional engineering QA, not clinical gradability.
if nargin < 2, c = fundusConfig(); end
validateFundusConfig(c);
[I,raw,meta] = readFundus(input,c);
r = struct('version',c.version,'status','rejected','enhanced',false, ...
    'clinicalReady',false,'routeToAnalysis',false,'message','', ...
    'reasons',{{}},'reasonCodes',{{}},'operations',{{}}, ...
    'original',raw,'candidate',[],'image',[],'mask',[], ...
    'before',struct(),'after',struct(),'source',meta.source, ...
    'inputMetadata',meta,'config',c);
[r.before,r.mask] = assessFundusQuality(I,c);
r.reasons = r.before.reasons; r.reasonCodes = r.before.reasonCodes;
if strcmp(r.before.status,'rejected')
    r.message = strjoin(r.reasons,' '); return
end
if strcmp(r.before.status,'acceptable')
    r.image = I; r.after = r.before;
    r.status = 'acceptable'; r.routeToAnalysis = true;
    r.message = 'Passes provisional image quality checks.';
else
    [J,r.operations] = enhanceFundus(I,r.mask,r.before,c);
    r.candidate = J;
    r.after = assessFundusQuality(J,c,r.mask);
    clippingWorse = r.after.brightFraction > ...
        r.before.brightFraction+c.maxClippingIncrease || ...
        r.after.darkFraction > r.before.darkFraction+c.maxClippingIncrease;
    if clippingWorse
        r.status = 'review_required';
        r.reasons = {'Enhancement increased clipping; inspect original and candidate or recapture.'};
        r.reasonCodes = {'enhancement_clipping'};
    elseif r.before.focus < c.goodFocus
        % Contrast changes cannot establish recovery of missing retinal detail.
        r.status = 'review_required';
        r.reasons = {'Original focus was borderline; check focus and review or recapture.'};
        r.reasonCodes = {'original_focus_borderline'};
    elseif strcmp(r.after.status,'acceptable')
        r.status = 'enhanced'; r.enhanced = true;
        r.image = J; r.routeToAnalysis = true;
        r.reasons = {}; r.reasonCodes = {};
    else
        r.status = 'review_required';
        r.reasons = r.after.reasons; r.reasonCodes = r.after.reasonCodes;
    end
    if strcmp(r.status,'enhanced')
        r.message = 'Enhanced image passes provisional checks; compare with original.';
    else
        r.message = strjoin(r.reasons,' ');
    end
end
if meta.convertedGrayscale
    r.status = 'review_required'; r.routeToAnalysis = false; r.image = [];
    r.reasons{end+1} = 'Grayscale lacks color evidence; review acquisition before analysis.';
    r.reasonCodes{end+1} = 'grayscale_input';
    r.message = strjoin(r.reasons,' ');
end
end
