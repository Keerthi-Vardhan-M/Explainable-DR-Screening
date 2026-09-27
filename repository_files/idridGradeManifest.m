function data = idridGradeManifest(datasetRoot)
%IDRIDGRADEMANIFEST Match original image IDs to official grading CSVs.
% Copies with suffixes are excluded, IDs repeated within a split cause error.
c = fundusConfig(); c.datasetMode = 'idrid'; files = discoverFundus(datasetRoot,c);
csvs = dir(fullfile(datasetRoot,'**','*.csv')); rows = table();
for k = 1:numel(csvs)
    name = lower(csvs(k).name);
    if ~contains(name,'grading') && ~contains(name,'label'), continue; end
    path = fullfile(csvs(k).folder,csvs(k).name);
    t = readtable(path,'Delimiter',',','ReadVariableNames',true, ...
        'NumHeaderLines',0,'VariableNamingRule','preserve','TextType','string');
    headers = lower(string(t.Properties.VariableNames));
    imageCol = find(contains(headers,'image'),1);
    gradeCol = find(contains(headers,'retinopathy'),1);
    if isempty(gradeCol), gradeCol = find(headers=="grade" | headers=="dr grade",1); end
    if isempty(imageCol) || isempty(gradeCol), continue; end
    if contains(name,'training'), split = 'training';
    elseif contains(name,'testing') || contains(name,'test'), split = 'testing';
    else, continue; end
    imageNames = string(t{:,imageCol}); grades = str2double(string(t{:,gradeCol}));
    if any(~isfinite(grades) | grades<0 | grades>4 | grades~=floor(grades))
        error('drdemo:Labels','Invalid DR grades in %s.',path);
    end
    paths = strings(height(t),1); ids = paths;
    for j = 1:height(t)
        [~,id] = fileparts(char(imageNames(j)));
        token = regexp(id,'^IDRiD_(\d+)$','tokens','once');
        if isempty(token), error('drdemo:Labels','Unexpected image ID %s in labels.',id); end
        matches = false(height(files),1);
        for f = 1:height(files)
            candidate = regexp(char(files.ImageID(f)),'^IDRiD_(\d+)$','tokens','once');
            if ~isempty(candidate)
                matches(f) = str2double(candidate{1})==str2double(token{1}) ...
                    && strcmp(files.DatasetSplit(f),split);
            end
        end
        if nnz(matches)~=1
            error('drdemo:Labels','ID %s has %d matching %s originals; select B. Disease Grading alone.',id,nnz(matches),split);
        end
        paths(j) = files.ImagePath(matches); ids(j) = files.ImageID(matches);
    end
    part = table(paths,ids,grades,repmat(string(split),height(t),1), ...
        'VariableNames',{'ImagePath','ImageID','Grade','Split'});
    if isempty(rows), rows = part; else, rows = [rows;part]; end %#ok<AGROW>
end
if isempty(rows), error('drdemo:Labels','No official grading training/testing label CSVs found.'); end
keys = rows.Split+"/"+rows.ImageID;
if numel(unique(keys))~=height(rows)
    error('drdemo:Labels','Duplicate grading labels found; choose one extracted grading dataset.');
end
data = rows;
end
