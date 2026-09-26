function s = workflowConfig()
%WORKFLOWCONFIG Editable scenario assumptions, not measured field data.
s.annualPatients = 100000;
s.workingDays = 250;
s.hoursPerDay = 8;
s.cameraCount = 4;
s.acquisitionMinutes = 4;      % Patient capture including both eyes
s.recaptureFraction = .10;    % Independent recapture: mean attempts 1/(1-r)
s.imageMBPerPatient = 2;      % Total upload payload per patient
s.bandwidthMbps = 2;
s.processorCount = 1;
s.processingSeconds = 20;
s.reviewFraction = 1;         % Your plan: doctor reviews every patient report
s.reviewerCount = 1;
s.reviewSeconds = 30;         % Scenario assumption, not a measured review time
s.targetUtilization = .80;    % Capacity margin
s.seed = 27;
end
