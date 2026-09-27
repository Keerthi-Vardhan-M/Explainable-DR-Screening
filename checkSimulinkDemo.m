function [path,name] = checkSimulinkDemo(folder)
%CHECKSIMULINKDEMO Generate and execute the actual connected queue model.
if nargin < 1, folder = fullfile(pwd,'workflow_results'); end
s = workflowConfig(); [path,name] = buildScreeningSimulink(s,folder);
result = sim(name);
for variable = {'CameraQueue','UploadQueue','ProcessingQueue','DoctorReviewQueue'}
    trace = result.get(variable{1});
    assert(~isempty(trace.Data) && all(isfinite(trace.Data(:))) && all(trace.Data(:)>=-1e-9));
end
open_system(name); fprintf('Simulink compile/run checks passed.\n');
end
