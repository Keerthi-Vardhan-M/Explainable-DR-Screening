function m = loadDRModel(path,c)
%LOADDRMODEL Load a SeriesNetwork, DAGNetwork or dlnetwork from a MAT file.
% Pixel scaling is a user-confirmed setting; it is not guessed from weights.
if nargin < 2, c = drDemoConfig(); end
if ~isfile(path), error('drdemo:Model','Model file not found: %s',path); end
S = load(path); names = fieldnames(S); nets = {}; netNames = {};
for k = 1:numel(names)
    value = S.(names{k});
    if isNetwork(value)
        nets{end+1} = value; netNames{end+1} = names{k}; %#ok<AGROW>
    elseif isstruct(value) && isscalar(value) && isfield(value,'net') && isNetwork(value.net)
        nets{end+1} = value.net; netNames{end+1} = [names{k} '.net']; %#ok<AGROW>
    end
end
if numel(nets) ~= 1
    error('drdemo:Model','Expected one supported MATLAB network; found %d. Use inspectDRModel or export one net variable.',numel(nets));
end
net = nets{1}; inputSize = c.modelInputSize; normalization = 'unknown'; meanRange = [];
for k = 1:numel(net.Layers)
    layer = net.Layers(k);
    if isa(layer,'nnet.cnn.layer.ImageInputLayer')
        inputSize = layer.InputSize; normalization = char(string(layer.Normalization));
        if isprop(layer,'Mean') && ~isempty(layer.Mean)
            meanRange = [min(layer.Mean(:)) max(layer.Mean(:))];
        elseif isprop(layer,'AverageImage') && ~isempty(layer.AverageImage)
            meanRange = [min(layer.AverageImage(:)) max(layer.AverageImage(:))];
        end
        break
    end
end
if numel(inputSize) ~= 3 || inputSize(3) ~= 3 || ~isequal(inputSize,c.modelInputSize)
    error('drdemo:Model','Network input %s differs from configured RGB input %s.', ...
        mat2str(inputSize),mat2str(c.modelInputSize));
end
values = c.classValues;
if ~isa(net,'dlnetwork') && isprop(net.Layers(end),'Classes')
    labels = string(net.Layers(end).Classes);
    numeric = str2double(labels);
    if numel(numeric)==5 && isequal(sort(numeric(:))',(0:4))
        values = numeric(:)';
    else
        error('drdemo:Classes','Network class names must be 0-4. Export numeric DR labels or supply a documented class mapping.');
    end
end
if numel(values)~=5 || ~isequal(sort(values),(0:4))
    error('drdemo:Classes','classValues must give the five output channels in DR grade order.');
end
m = struct('net',net,'path',char(path),'variable',netNames{1}, ...
    'inputSize',inputSize,'inputRange',c.modelInputRange,'classValues',values, ...
    'networkNormalization',normalization,'preprocessingConfirmed',c.preprocessingConfirmed, ...
    'outputs',c.modelOutputs,'featureLayer',c.featureLayer,'reductionLayer',c.reductionLayer, ...
    'storedInputMeanRange',meanRange);
end

function tf = isNetwork(value)
tf = isa(value,'SeriesNetwork') || isa(value,'DAGNetwork') || isa(value,'dlnetwork');
end
