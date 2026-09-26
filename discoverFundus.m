function files = discoverFundus(source,c)
%DISCOVERFUNDUS List dataset inputs without loading all images into memory.
% source: folder, image file, file list, ImageDatastore, table/CSV ImagePath.
% Automatic folder discovery excludes annotation files. Explicit lists bypass
% these filters, allowing arbitrary naming in other datasets.
if nargin < 2, c = fundusConfig(); end
validateFundusConfig(c);
root = ''; explicit = true;
if isa(source,'matlab.io.datastore.ImageDatastore')
    paths = string(source.Files(:));
elseif istable(source)
    paths = manifestPaths(source,pwd);
elseif iscell(source) || (isstring(source) && ~isscalar(source))
    paths = string(source(:));
elseif ischar(source) || (isstring(source) && isscalar(source))
    source = char(source);
    if isfolder(source)
        explicit = false; root = absolutePath(source);
        if c.recursive, entries = dir(fullfile(root,'**','*'));
        else, entries = dir(fullfile(root,'*')); end
        entries = entries(~[entries.isdir]);
        paths = strings(numel(entries),1);
        for k = 1:numel(entries)
            paths(k) = string(fullfile(entries(k).folder,entries(k).name));
        end
    elseif isfile(source)
        [~,~,ext] = fileparts(source);
        if strcmpi(ext,'.csv')
            source = absolutePath(source);
            % A one-column CSV has no commas in its body. Auto detection can
            % mistake spaces in image paths for delimiters or data for headers.
            % The manifest contract explicitly uses commas and first-row names.
            manifest = readtable(source,'FileType','text','Delimiter',',', ...
                'ReadVariableNames',true,'NumHeaderLines',0, ...
                'VariableNamingRule','preserve','TextType','string');
            paths = manifestPaths(manifest,fileparts(source));
        else
            paths = string(absolutePath(source));
        end
    else
        error('fundus:Dataset','Input path not found. Extract ZIP datasets first: %s',source);
    end
else
    error('fundus:Dataset','Use a folder, image, file list, ImageDatastore, or ImagePath manifest.');
end
paths = paths(:);
if any(ismissing(paths) | strlength(paths)==0)
    error('fundus:Dataset','The input list contains empty or missing ImagePath values.');
end
for k = 1:numel(paths), paths(k) = string(absolutePath(char(paths(k)))); end
paths = unique(paths,'stable');
relative = paths;
if ~isempty(root), relative = extractAfter(paths,strlength(string(root))+1); end
if ~explicit
    keep = false(size(paths));
    for k = 1:numel(paths)
        [~,name,ext] = fileparts(char(paths(k)));
        normalized = lower(strrep(char(relative(k)),'\','/'));
        segments = strsplit(normalized,'/');
        folders = strjoin(segments(1:end-1),'/');
        keep(k) = any(strcmpi(ext,c.extensions));
        for j = 1:numel(c.excludeFolderPatterns)
            if contains(folders,lower(c.excludeFolderPatterns{j})), keep(k) = false; end
        end
        for j = 1:numel(c.excludeFilePatterns)
            if endsWith(lower(name),lower(c.excludeFilePatterns{j})), keep(k) = false; end
        end
    end
    % IDRiD has Original Images and Groundtruths below the same dataset root.
    % Select the former even if the user points at the complete archive root.
    original = contains(lower(strrep(relative,'\','/')),'original images/');
    if any(original & keep) && ~strcmp(c.datasetMode,'generic')
        keep = keep & original;
    elseif strcmp(c.datasetMode,'idrid')
        for k = 1:numel(paths)
            [~,name] = fileparts(char(paths(k)));
            keep(k) = keep(k) && ~isempty(regexp(name,'^IDRiD_\d+(\(\d+\))?$','once'));
        end
    end
    paths = paths(keep); relative = relative(keep);
    [paths,order] = sort(paths); relative = relative(order);
end
if isempty(paths)
    error('fundus:Dataset','No supported images discovered; check folder, extraction, and exclusion settings.');
end
ids = strings(size(paths)); splits = repmat("unspecified",size(paths));
for k = 1:numel(paths)
    [~,name] = fileparts(char(paths(k))); ids(k) = string(name);
    dirs = lower(strrep(fileparts(char(paths(k))),'\','/'));
    if contains(dirs,'training'), splits(k) = "training";
    elseif contains(dirs,'testing') || contains(dirs,'test set'), splits(k) = "testing";
    elseif contains(dirs,'validation'), splits(k) = "validation"; end
end
files = table(paths,relative,ids,splits, ...
    'VariableNames',{'ImagePath','RelativePath','ImageID','DatasetSplit'});
end

function paths = manifestPaths(t,baseDir)
if ~ismember('ImagePath',t.Properties.VariableNames)
    error('fundus:Dataset','CSV/table must contain an ImagePath column.');
end
paths = string(t.ImagePath(:));
for k = 1:numel(paths)
    if ~ismissing(paths(k)) && strlength(paths(k))>0 && ~isAbsolute(char(paths(k)))
        paths(k) = string(fullfile(baseDir,char(paths(k))));
    end
end
end

function path = absolutePath(path)
if ~isAbsolute(path), path = fullfile(pwd,path); end
% Resolve dots and repeated separators when the parent exists, no Java needed.
[ok,attr] = fileattrib(path);
if ok, path = attr.Name; end
end

function tf = isAbsolute(path)
tf = startsWith(path,'/') || startsWith(path,'\') ...
    || ~isempty(regexp(path,'^[A-Za-z]:[\\/]','once'));
end
