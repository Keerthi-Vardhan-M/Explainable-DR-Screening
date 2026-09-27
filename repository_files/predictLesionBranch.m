function p = predictLesionBranch(features,m)
%PREDICTLESIONBRANCH Trained random-forest posterior in numeric grade order.
[~,scores] = predict(m.classifier,features);
values = str2double(string(m.classifier.ClassNames));
if numel(values)~=5 || ~isequal(sort(values(:))',(0:4))
    error('drdemo:Classes','Lesion branch must contain all five grade classes.');
end
p = zeros(1,5); p(values+1) = double(scores(:)');
p = p/max(sum(p),eps);
end
