function X = prepareDRInput(I,m)
%PREPAREDRINPUT Identical original-image preprocessing for predict/Grad-CAM.
% Full-frame resize only. If training used cropping/CLAHE/etc, adapt here.
if ~m.preprocessingConfirmed
    error('drdemo:Preprocessing','Confirm training pixel scaling before classification.');
end
I = im2single(I); X = imresize(I,m.inputSize(1:2));
switch m.inputRange
    case 'zero_one'
        % Input layer may apply its own stored normalization afterwards.
    case 'zero_255'
        X = X*255;
    otherwise
        error('drdemo:Preprocessing','Supported presets: zero_one or zero_255. Custom training transforms must be added to prepareDRInput.');
end
end
