function c = drDemoConfig()
%DRDEMOCONFIG Presentation prototype, not a clinically validated device.
c.version = 'dr-demo-v1.0';
c.projectRoot = fileparts(mfilename('fullpath'));
c.datasetRoot = fullfile(c.projectRoot,'datasets','IDRiD');
c.outputRoot = fullfile(c.projectRoot,'dr_demo_results');
c.modelPath = fullfile(c.projectRoot,'trainedDRModel.mat');
c.modelInputSize = [224 224 3];
c.modelInputRange = 'zero_255'; % Confirm against training: zero_255 or zero_one
c.preprocessingConfirmed = false;
c.classValues = 0:4;           % Output channel order when net has no class labels
c.modelOutputs = 'probabilities'; % Set logits only for a model without softmax
c.lesionAnalysisSize = 768;    % Heuristic analysis; no subpixel detection claim
c.computeGradCAM = true;
c.featureLayer = '';          % Empty lets gradCAM select the feature layer
c.reductionLayer = '';
c.lesionModelPath = '';
c.calibrationPath = '';
c.cnnFusionWeight = 0.80;
c.referableThreshold = 0.50;   % Provisional until validation-set selection
c.lowScoreThreshold = 0.50;
c.exportReport = true;
c.saveCaseMAT = true;
end
