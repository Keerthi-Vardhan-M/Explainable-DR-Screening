function [capacity,labels,demand] = workflowCapacities(s)
%WORKFLOWCAPACITIES Patients/hour at each queue; review uses report arrivals.
validateattributes(s.annualPatients,{'numeric'},{'finite','scalar','positive'});
for name = {'workingDays','hoursPerDay','cameraCount','acquisitionMinutes', ...
        'imageMBPerPatient','bandwidthMbps','processorCount','processingSeconds', ...
        'reviewerCount','reviewSeconds'}
    validateattributes(s.(name{1}),{'numeric'},{'real','finite','scalar','positive'});
end
validateattributes(s.recaptureFraction,{'numeric'},{'real','finite','scalar','>=',0,'<',1});
validateattributes(s.reviewFraction,{'numeric'},{'real','finite','scalar','>',0,'<=',1});
validateattributes(s.targetUtilization,{'numeric'},{'real','finite','scalar','>',0,'<',1});
capacity = [s.cameraCount*60/s.acquisitionMinutes*(1-s.recaptureFraction), ...
    s.bandwidthMbps*3600/(8*s.imageMBPerPatient), ...
    s.processorCount*3600/s.processingSeconds, ...
    s.reviewerCount*3600/s.reviewSeconds];
labels = {'Acquisition','Upload','Processing','Doctor review'};
rate = s.annualPatients/(s.workingDays*s.hoursPerDay);
demand = [rate rate rate rate*s.reviewFraction];
end
