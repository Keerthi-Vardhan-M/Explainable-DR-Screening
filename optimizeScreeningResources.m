function recommendations = optimizeScreeningResources(s)
%OPTIMIZESCREENINGRESOURCES Smallest independent capacities with headroom.
% This is a capacity sizing rule, not cost-optimal stochastic optimization.
[~,~,demand] = workflowCapacities(s); u = s.targetUtilization;
cameras = max(1,ceil(demand(1)*s.acquisitionMinutes/(60*(1-s.recaptureFraction)*u)));
processors = max(1,ceil(demand(3)*s.processingSeconds/(3600*u)));
reviewers = max(1,ceil(demand(4)*s.reviewSeconds/(3600*u)));
bandwidth = demand(2)*8*s.imageMBPerPatient/(3600*u);
recommendations = struct('cameraCount',cameras,'processorCount',processors, ...
    'reviewerCount',reviewers,'minimumBandwidthMbps',bandwidth, ...
    'targetUtilization',u,'annualPatientTarget',s.annualPatients, ...
    'method','Independent bottleneck capacity sizing with utilization margin');
end
