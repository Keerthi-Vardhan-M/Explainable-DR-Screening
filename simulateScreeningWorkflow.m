function r = simulateScreeningWorkflow(s)
%SIMULATESCREENINGWORKFLOW Poisson arrival, one-minute fluid queue simulation.
% Services are patient-equivalent rates, not individual discrete-event jobs.
% Localizes resource bottlenecks; no physiological/clinical outcome model.
if nargin < 1, s = workflowConfig(); end
[cap,labels,demand] = workflowCapacities(s);
minutes = round(s.hoursPerDay*60); arrivalRate = demand(1)/60;
oldRng = rng; cleaner = onCleanup(@() rng(oldRng)); rng(s.seed);
arrivals = zeros(minutes,1);
for k = 1:minutes, arrivals(k) = poissonDraw(arrivalRate); end
queue = zeros(minutes+1,4); served = zeros(minutes,4);
for t = 1:minutes
    flow = arrivals(t);
    for stage = 1:4
        if stage==4, flow = flow*s.reviewFraction; end
        available = queue(t,stage)+flow;
        served(t,stage) = min(available,cap(stage)/60);
        queue(t+1,stage) = max(0,available-served(t,stage));
        flow = served(t,stage);
    end
end
normalizedCap = cap; normalizedCap(4) = cap(4)/s.reviewFraction;
[throughput,bottleneck] = min(normalizedCap);
utilization = demand./cap;
meanQueue = mean(queue(2:end,:),1);
arrivalAtStage = [mean(arrivals)*60,mean(served(:,1))*60, ...
    mean(served(:,2))*60,mean(served(:,3))*60*s.reviewFraction];
waitEstimate = meanQueue./max(arrivalAtStage,eps)*60;
r = struct('assumptions',s,'timeMinutes',(0:minutes)', ...
    'arrivals',arrivals,'queues',queue,'served',served,'capacityPerHour',cap, ...
    'demandPerHour',demand,'utilization',utilization,'labels',{labels}, ...
    'bottleneck',labels{bottleneck},'maximumAnnualThroughput', ...
    throughput*s.workingDays*s.hoursPerDay,'meanQueueWaitMinutesEstimate',waitEstimate, ...
    'reviewedPatientEquivalents',sum(served(:,4)), ...
    'modelType','Poisson arrivals with fluid service, one-minute time steps', ...
    'waitCaveat','Finite-day Little-law estimate; not an individual patient wait-time distribution');
end

function n = poissonDraw(lambda)
% Knuth sampler without Statistics Toolbox. Typical rate is <1/minute.
if lambda>30
    n = 0;
    for k = 1:ceil(lambda/20), n = n+poissonDraw(lambda/ceil(lambda/20)); end
    return
end
limit = exp(-lambda); product = 1; n = -1;
while product>limit, product = product*rand; n = n+1; end
n = max(0,n);
end
