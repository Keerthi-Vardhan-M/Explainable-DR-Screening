function checkFullDRDemo()
%CHECKFULLDRDEMO Smoke tests for evidence, withholding, PDF and simulation.
% Does not validate clinical performance or your external network accuracy.
checkFundusEnvironment(); c = drDemoConfig();
root = tempname; mkdir(root); cleaner = onCleanup(@() removeFixture(root));
c.outputRoot = fullfile(root,'outputs'); c.modelPath = ''; c.preprocessingConfirmed = false;
[x,y] = meshgrid(1:768); M = (x-384).^2+(y-384).^2<330^2;
I = zeros(768,768,3,'single'); scales = [1.3 1 .7];
for k = 1:3
    p = (.30+.12*sin(x/2).*sin(y/3))*scales(k); p(~M) = 0; I(:,:,k) = single(p);
end
imagePath = fullfile(root,'synthetic_fundus.png'); imwrite(im2uint8(I),imagePath);
e = extractRetinalEvidence(I,M,c);
assert(isequal(size(e.overlay),size(I)) && all(isfinite(e.overlay(:))));
assert(numel(e.features)==12 && all(isfinite(e.features)));
assert(~any(e.microaneurysms(~e.field)) && ~any(e.exudates(~e.field)));
assert(isequal(size(e.vessels),size(M)));
out = runDRCase(imagePath,c);
assert(~out.prediction.available && ~out.clinicalReady);
assert(isfile(out.pdfPath) && isfile(fullfile(out.outputFolder,'case.mat')));
assert(isfile(fullfile(out.outputFolder,'case_summary.json')));
fid = fopen(out.pdfPath,'rb'); signature = char(fread(fid,5,'uint8')'); fclose(fid);
assert(strcmp(signature,'%PDF-'),'Report must be an actual PDF.');
% Resized floating-point previews may have bicubic interpolation overshoot.
% Report export must display clipped pixels without changing case arrays.
overshoot = out;
overshoot.original(1,1,1) = single(-0.03);
overshoot.enhanced(1,1,1) = single(1.03);
overshoot.evidence.overlay(1,1,2) = single(-0.02);
overshoot.explanation.available = true;
overshoot.explanation.overlay = overshoot.original;
overshootPDF = exportDRReport(overshoot,fullfile(out.outputFolder,'overshoot_report.pdf'));
assert(isfile(overshootPDF) && overshoot.original(1,1,1)<0);
invalid = fullfile(root,'black.png'); imwrite(zeros(768,768,3,'uint8'),invalid);
out = runDRCase(invalid,c);
assert(strcmp(out.quality.status,'rejected') && ~out.prediction.available);
assert(isempty(out.prediction.scores) && isfile(out.pdfPath));
p = temperatureScores([.1 .2 .3 .2 .2],2);
assert(abs(sum(p)-1)<1e-12 && all(p>0));
met = referralMetrics([0;1;2;3;4],eye(5),.5);
assert(met.sensitivity==1 && met.specificity==1 && met.fiveClassAccuracy==1);
s = workflowConfig(); r = simulateScreeningWorkflow(s);
assert(all(r.queues(:)>=0) && all(r.served(:)>=0));
assert(isequal(r,simulateScreeningWorkflow(s)),'Fixed-seed workflow must reproduce.');
assert(abs(sum(r.arrivals)-sum(r.served(:,1))-r.queues(end,1))<1e-8);
for stage = 2:4
    input = sum(r.served(:,stage-1)); if stage==4, input = input*s.reviewFraction; end
    assert(abs(input-sum(r.served(:,stage))-r.queues(end,stage))<1e-8,'Queue must conserve workload.');
end
recommendations = optimizeScreeningResources(s); better = s;
better.cameraCount = recommendations.cameraCount; better.processorCount = recommendations.processorCount;
better.reviewerCount = recommendations.reviewerCount;
better.bandwidthMbps = max(s.bandwidthMbps,recommendations.minimumBandwidthMbps);
improved = simulateScreeningWorkflow(better);
assert(all(improved.utilization<=s.targetUtilization+1e-10));
fprintf('Full-project smoke checks passed (external model and Simulink not tested by this function).\n');
clear cleaner
end

function removeFixture(root)
if isfolder(root), rmdir(root,'s'); end
end
