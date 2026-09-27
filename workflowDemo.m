function [baseline,improved,recommendations,modelPath] = workflowDemo(folder,s)
%WORKFLOWDEMO Capacity comparison, queue plots, sizing, saved Simulink model.
if nargin < 1, folder = fullfile(pwd,'workflow_results'); end
if nargin < 2, s = workflowConfig(); end
if ~isfolder(folder), mkdir(folder); end
% Every run gets a new folder, keeping earlier scenario evidence intact.
folder = tempname(folder); mkdir(folder);
baseline = simulateScreeningWorkflow(s); recommendations = optimizeScreeningResources(s);
better = s; better.cameraCount = recommendations.cameraCount;
better.processorCount = recommendations.processorCount;
better.reviewerCount = recommendations.reviewerCount;
better.bandwidthMbps = max(s.bandwidthMbps,recommendations.minimumBandwidthMbps);
improved = simulateScreeningWorkflow(better);
f = figure('Name','District screening capacity','Color','white','Position',[80 80 1150 650]);
tiledlayout(f,2,2);
ax = nexttile; bar(ax,[baseline.demandPerHour;baseline.capacityPerHour]');
xticklabels(ax,baseline.labels); ylabel(ax,'Patients / reports per hour');
legend(ax,{'Demand','Capacity'},'Location','best'); title(ax,'Baseline resource capacity');
ax = nexttile; plot(ax,baseline.timeMinutes,baseline.queues,'LineWidth',1.5);
legend(ax,baseline.labels,'Location','best'); xlabel(ax,'Minutes'); ylabel(ax,'Patient-equivalent backlog');
title(ax,['Baseline bottleneck: ' baseline.bottleneck]);
ax = nexttile; plot(ax,improved.timeMinutes,improved.queues,'LineWidth',1.5);
legend(ax,improved.labels,'Location','best'); xlabel(ax,'Minutes'); ylabel(ax,'Patient-equivalent backlog');
title(ax,'Capacity-sized scenario with headroom');
ax = nexttile; axis(ax,'off');
text(ax,.02,.95,sprintf(['Annual target: %d patients\nSuggested cameras: %d\n' ...
    'Suggested processors: %d\nSuggested reviewers: %d\n' ...
    'Minimum bandwidth: %.2f Mbps\n' ...
    'Service/utilization assumptions are editable.\n' ...
    'Doctor review fraction: %.0f%%\nFluid services, Poisson arrivals.'], ...
    s.annualPatients,recommendations.cameraCount,recommendations.processorCount, ...
    recommendations.reviewerCount,recommendations.minimumBandwidthMbps, ...
    100*s.reviewFraction),'VerticalAlignment','top','FontSize',12);
exportgraphics(f,fullfile(folder,'workflow.png'),'Resolution',150);
exportgraphics(f,fullfile(folder,'workflow.pdf'),'ContentType','vector');
save(fullfile(folder,'workflow.mat'),'baseline','improved','recommendations');
modelPath = '';
if ~isempty(which('new_system'))
    try
        [modelPath,name] = buildScreeningSimulink(better,folder);
        sim(name); open_system(name);
    catch ME
        warning('drdemo:Simulink','Simulink build/run failed: %s. MATLAB queue simulation remains available.',ME.message);
    end
end
disp(recommendations); fprintf('Workflow outputs: %s\n',folder);
end
