function m = referralMetrics(y,p,threshold)
%REFERRALMETRICS Numeric DR grade 2+ metrics from measured predictions only.
truth = y(:)>=2; referral = sum(p(:,3:5),2); predicted = referral>=threshold;
TP = nnz(truth & predicted); TN = nnz(~truth & ~predicted);
FP = nnz(~truth & predicted); FN = nnz(truth & ~predicted);
[~,grade] = max(p,[],2);
m = struct('N',numel(y),'threshold',threshold,'TP',TP,'TN',TN,'FP',FP,'FN',FN, ...
    'sensitivity',divide(TP,TP+FN),'specificity',divide(TN,TN+FP), ...
    'PPV',divide(TP,TP+FP),'NPV',divide(TN,TN+FN), ...
    'fiveClassAccuracy',mean(grade-1==y(:)), ...
    'sensitivityCI95',wilson(TP,TP+FN),'specificityCI95',wilson(TN,TN+FP), ...
    'confusion5',zeros(5),'clinicalValidated',false);
for k = 1:numel(y), m.confusion5(y(k)+1,grade(k)) = m.confusion5(y(k)+1,grade(k))+1; end
end

function v = divide(a,b)
if b==0, v = NaN; else, v = a/b; end
end

function ci = wilson(k,n)
if n==0, ci = [NaN NaN]; return; end
z = 1.96; p = k/n; center = (p+z^2/(2*n))/(1+z^2/n);
half = z*sqrt(p*(1-p)/n+z^2/(4*n^2))/(1+z^2/n);
ci = [max(0,center-half) min(1,center+half)];
end
