function [I,raw,meta] = readFundus(input,c)
%READFUNDUS Stage 1: native-size file or camera SDK RGB frame input.
% Indexed files are decoded; non-opaque or multipage files fail explicitly.
if nargin < 2, c = fundusConfig(); end
meta = struct('source','array','nativeSize',[],'inputClass','', ...
    'indexed',false,'convertedGrayscale',false,'orientationApplied',false);
if ischar(input) || (isstring(input) && isscalar(input))
    meta.source = char(input);
    if ~isfile(meta.source), error('fundus:Input','Image not found: %s',meta.source); end
    info = imfinfo(meta.source);
    if numel(info) ~= 1
        error('fundus:Input','Multipage files require explicit frame selection as an RGB array.');
    end
    % Transparency output is defined for PNG; avoid requesting it from JPEG
    % or other decoder implementations that only expose image and colormap.
    alpha = [];
    if strcmpi(info.Format,'png'), [raw,map,alpha] = imread(meta.source);
    else, [raw,map] = imread(meta.source); end
    if ~isempty(alpha)
        if isinteger(alpha), opaque = intmax(class(alpha)); else, opaque = 1; end
        if any(alpha(:) ~= opaque)
            error('fundus:Input','Transparent pixels unsupported; export an opaque retinal image.');
        end
    end
    if ~isempty(map), raw = ind2rgb(raw,map); meta.indexed = true; end
else
    raw = input;
end
if ~(isa(raw,'uint8') || isa(raw,'uint16') || isa(raw,'single') || isa(raw,'double')) ...
        || isempty(raw) || ~isreal(raw) || issparse(raw)
    error('fundus:Input','Supply real uint8/uint16 or normalized single/double pixels.');
end
meta.nativeSize = size(raw); meta.inputClass = class(raw);
if ismatrix(raw)
    if ~c.allowGrayscale
        error('fundus:Input','Grayscale disabled. Supply RGB or set allowGrayscale=true for review only.');
    end
    meta.convertedGrayscale = true;
elseif ndims(raw) ~= 3 || size(raw,3) ~= 3
    error('fundus:Input','Expected H-by-W-by-3 RGB pixels.');
end
if isfloat(raw) && (any(~isfinite(raw(:))) || any(raw(:)<0 | raw(:)>1))
    error('fundus:Input','Float pixels must be finite in [0,1]; they are never automatically rescaled.');
end
I = im2single(raw);
if meta.convertedGrayscale, I = repmat(I,1,1,3); end
end
