function [p,networkIndex,X] = predictDRModel(I,m)
%PREDICTDRMODEL Return five scores in numeric grade order 0,1,2,3,4.
X = prepareDRInput(I,m);
if isa(m.net,'dlnetwork')
    values = predict(m.net,dlarray(X,'SSCB'));
    values = extractdata(values);
    if isa(values,'gpuArray'), values = gather(values); end
else
    values = predict(m.net,X,'ExecutionEnvironment','cpu');
end
values = double(values(:)');
if numel(values)~=5 || any(~isfinite(values))
    error('drdemo:Scores','Expected five finite classifier outputs.');
end
if strcmp(m.outputs,'logits')
    values = exp(values-max(values)); values = values/sum(values);
elseif strcmp(m.outputs,'probabilities')
    if any(values<0) || abs(sum(values)-1)>0.02
        error('drdemo:Scores','Outputs are not normalized class probabilities. Check modelOutputs and preprocessing.');
    end
    values = values/sum(values);
else
    error('drdemo:Scores','modelOutputs must be probabilities or logits.');
end
p = zeros(1,5); p(m.classValues+1) = values;
[~,networkIndex] = max(values);
end
