function checkStage123()
%CHECKSTAGE123 Engineering regressions; these are not clinical validation.
checkFundusEnvironment(); c = fundusConfig();
r = processFundus(zeros(768,768,3,'uint8'),c);
assert(strcmp(r.status,'rejected') && isempty(r.image) && ~r.routeToAnalysis);
assert(~r.clinicalReady);
[x,y] = meshgrid(1:768); M = (x-384).^2+(y-384).^2<330^2;
I = zeros(768,768,3); scales = [1.3 1 0.7];
for k = 1:3
    plane = (0.30+0.12*sin(x/2).*sin(y/3))*scales(k);
    plane(~M) = 0; I(:,:,k) = plane;
end
r = processFundus(I,c);
assert(isequal(r.original,I),'Original pixels must be retained exactly.');
assert(r.before.coverage > 0.4 && r.before.solidity > 0.9);
assert(strcmp(r.status,'acceptable'),r.message);
assert(isequal(size(r.image),size(I)) && isequal(size(r.mask),size(M)));
assert(r.routeToAnalysis && all(isfinite(r.image(:))));
assert(all(r.image(:)>=0 & r.image(:)<=1));
blurred = processFundus(imgaussfilt(I,8),c);
assert(blurred.before.focus < r.before.focus,'Blur must decrease focus on this fixture.');
assert(strcmp(blurred.status,'rejected') && isempty(blurred.image));
borderline = c; borderline.minFocus = 0.5*r.before.focus;
borderline.goodFocus = 2*r.before.focus;
b = processFundus(I,borderline);
assert(strcmp(b.status,'review_required') && isempty(b.image) && ~b.routeToAnalysis);
assert(~isempty(b.candidate),'Borderline input retains a comparison candidate.');
assert(any(strcmp(b.reasonCodes,'original_focus_borderline')));
% Exercise each enhancement operation and verify geometry, background, range.
m = r.before; m.noise = c.maxNoise*1.1; m.contrast = 0;
m.illuminationCV = c.goodIlluminationCV*1.1;
[J,ops] = enhanceFundus(im2single(I),r.mask,m,c);
assert(numel(ops)==3 && isequal(size(J),size(I)));
assert(all(isfinite(J(:))) && all(J(:)>=0 & J(:)<=1));
for k = 1:3
    a = J(:,:,k); original = single(I(:,:,k));
    assert(isequal(a(~r.mask),original(~r.mask)),'Outside-field pixels must remain exact.');
end
fixed = assessFundusQuality(J,c,r.mask);
assert(abs(fixed.coverage-r.before.coverage)<0.001);
% Full-frame masks must not create Inf/NaN in boundary feathering.
m.analysisSize = [128 128];
[J,~] = enhanceFundus(single(I(1:128,1:128,:)+0.3),true(128),m,c);
assert(all(isfinite(J(:))));
assertInputError(@() processFundus(NaN(32,32,3),c));
assertInputError(@() processFundus(ones(32,32,3)*(1+eps),c));
assertInputError(@() processFundus(ones(32,32,3)*255,c));
assertInputError(@() processFundus(zeros(32,32),c));
assertInputError(@() processFundus(zeros(32,32,4),c));
assertInputError(@() processFundus(complex(I,I),c));
gray = c; gray.allowGrayscale = true;
b = processFundus(im2uint8(rgb2gray(I)),gray);
assert(~b.routeToAnalysis && isempty(b.image) && b.inputMetadata.convertedGrayscale);
assert(isequal(b.original,im2uint8(rgb2gray(I))));
[decoded,raw,meta] = readFundus(im2uint16(I),c);
assert(isa(raw,'uint16') && isequal(size(decoded),size(I)) && ~meta.convertedGrayscale);
% Policy checks for specific failure reasons, independent of image content.
m = r.before; m.darkFraction = c.maxDarkFraction+0.1;
[s,~,codes] = gateFundusQuality(m,c);
assert(strcmp(s,'rejected') && any(strcmp(codes,'severe_exposure')));
m = r.before; m.minDimension = c.minDimension-1;
[s,~,codes] = gateFundusQuality(m,c);
assert(strcmp(s,'rejected') && any(strcmp(codes,'native_resolution')));
% Folder, manifest, duplicate-name, corrupt-file and output persistence tests.
root = tempname; mkdir(root);
cleanup = onCleanup(@() removeFixture(root));
originalDir = fullfile(root,'A. Segmentation','1. Original Images');
trainDir = fullfile(originalDir,'a. Training Set');
testDir = fullfile(originalDir,'b. Testing Set');
truthDir = fullfile(root,'A. Segmentation','2. All Segmentation Groundtruths','MA');
mkdir(trainDir); mkdir(testDir); mkdir(truthDir);
imwrite(im2uint8(I),fullfile(trainDir,'IDRiD_01.jpg'));
imwrite(im2uint8(I),fullfile(testDir,'IDRiD_01.jpg'));
imwrite(uint8(M)*255,fullfile(truthDir,'IDRiD_01_MA.tif'));
files = discoverFundus(root,c);
assert(height(files)==2 && all(files.ImageID=="IDRiD_01"));
assert(any(files.DatasetSplit=="training") && any(files.DatasetSplit=="testing"));
manifest = table(string(fullfile('A. Segmentation','1. Original Images', ...
    'a. Training Set','IDRiD_01.jpg')),'VariableNames',{'ImagePath'});
csvPath = fullfile(root,'manifest.csv'); writetable(manifest,csvPath);
fromCSV = discoverFundus(csvPath,c);
assert(height(fromCSV)==1);
assert(fromCSV.ImagePath(1)==string(fullfile(trainDir,'IDRiD_01.jpg')), ...
    'One-column manifest must preserve spaces and the first-row ImagePath header.');
% Multirow one-column CSVs, extra columns and quoted commas are also valid.
multi = table(files.ImagePath,'VariableNames',{'ImagePath'});
multiCSV = fullfile(root,'multirow.csv'); writetable(multi,multiCSV);
fromCSV = discoverFundus(multiCSV,c);
assert(isequal(fromCSV.ImagePath,files.ImagePath));
multi.Grade = [0;2];
multiCSV = fullfile(root,'extra_columns.csv'); writetable(multi,multiCSV);
fromCSV = discoverFundus(multiCSV,c);
assert(isequal(fromCSV.ImagePath,files.ImagePath));
commaDir = fullfile(root,'patient, visit 1'); mkdir(commaDir);
commaImage = fullfile(commaDir,'fundus.jpg'); imwrite(im2uint8(I),commaImage);
quoted = table(string(commaImage),'VariableNames',{'ImagePath'});
quotedCSV = fullfile(root,'quoted_comma.csv'); writetable(quoted,quotedCSV);
fromCSV = discoverFundus(quotedCSV,c);
assert(height(fromCSV)==1 && fromCSV.ImagePath(1)==string(commaImage));
assert(height(discoverFundus(imageDatastore(trainDir),c))==1);
opaque = fullfile(root,'opaque.png');
imwrite(im2uint8(I),opaque,'Alpha',uint8(ones(size(M))*255));
readFundus(opaque,c);
transparent = fullfile(root,'transparent.png');
imwrite(im2uint8(I),transparent,'Alpha',uint8(zeros(size(M))));
assertInputError(@() processFundus(transparent,c));
indexed = fullfile(root,'indexed.png');
imwrite(uint8(M),[0 0 0; 0.4 0.3 0.2],indexed);
[~,~,meta] = readFundus(indexed,c); assert(meta.indexed);
badFile = fullfile(root,'broken.jpg'); fid = fopen(badFile,'w');
fprintf(fid,'not an image'); fclose(fid);
batchConfig = c; batchConfig.writeMAT = false; batchConfig.writePreview = false;
[summary,runDir] = runStage123([files.ImagePath;string(badFile)], ...
    fullfile(root,'stage123_results'),batchConfig);
assert(height(summary)==3 && summary.Status(3)=="error");
assert(summary.RouteToAnalysis(1) && summary.RouteToAnalysis(2));
assert(summary.OutputFolder(1)~=summary.OutputFolder(2));
assert(isfile(fullfile(runDir,'summary.csv')));
assert(isfile(fullfile(char(summary.OutputFolder(1)),'analysis_image.png')));
quality = jsondecode(fileread(fullfile(char(summary.OutputFolder(1)),'quality.json')));
assert(quality.routeToAnalysis && ~quality.clinicalReady);
% Native-size 16-bit export and lossless original persistence.
resultFolder = fullfile(root,'saved_result'); saveFundusResult(r,resultFolder,c);
loaded = load(fullfile(resultFolder,'result.mat'),'r');
assert(isequal(loaded.r.original,I));
encoded = imread(fullfile(resultFolder,'analysis_image.png'));
assert(isa(encoded,'uint16') && isequal(size(encoded),size(I)));
rejectedFolder = fullfile(root,'saved_reject'); saveFundusResult(blurred,rejectedFolder,c);
assert(~isfile(fullfile(rejectedFolder,'analysis_image.png')));
fprintf('All stage 1-3 engineering regression checks passed.\n');
clear cleanup
end

function assertInputError(action)
caught = false;
try, action(); catch ME, caught = strcmp(ME.identifier,'fundus:Input'); end
assert(caught,'Invalid pixels or file encoding must raise fundus:Input.');
end

function removeFixture(root)
% Only delete the exact unique temporary directory created by this test.
if isfolder(root), rmdir(root,'s'); end
end
