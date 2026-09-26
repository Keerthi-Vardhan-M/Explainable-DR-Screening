function checkFundusEnvironment()
%CHECKFUNDUSENVIRONMENT Check required functions in desktop or MATLAB Online.
needed = {'imresize','rgb2lab','lab2rgb','adapthisteq','imbilatfilt', ...
    'imgaussfilt','regionprops','bwareafilt','medfilt2','bwdist'};
for k = 1:numel(needed)
    if isempty(which(needed{k}))
        error('fundus:Toolbox','%s unavailable. This package needs Image Processing Toolbox.',needed{k});
    end
end
if verLessThan('matlab','9.9')
    error('fundus:Release','Use MATLAB R2020b or newer.');
end
end
