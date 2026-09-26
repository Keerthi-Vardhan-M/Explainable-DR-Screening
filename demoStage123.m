function r = demoStage123(imagePath,outputDir,c)
% Interactive file input when no path supplied. No camera-driver dependency.
if nargin<1
    [f,p]=uigetfile({'*.jpg;*.jpeg;*.png;*.tif;*.tiff','Fundus RGB images'});
    if isequal(f,0), r=[]; return; end
    imagePath=fullfile(p,f);
end
if nargin<3, c=fundusConfig(); end
if nargin<2, outputDir=fullfile(pwd,'stage123_results'); end
checkFundusEnvironment();
if ~isfolder(outputDir), mkdir(outputDir); end
r=processFundus(imagePath,c);
fprintf('%s\n%s\n',r.status,r.message);
fig=figure('Name','Fundus quality assessment');
tiledlayout(1,3);
nexttile; imshow(r.original); title('Original');
nexttile; imshow(r.mask); title('Estimated retinal field');
nexttile;
if ~isempty(r.candidate), imshow(r.candidate); title(['Candidate: ' r.status],'Interpreter','none');
else, imshow(r.original); title(r.status,'Interpreter','none'); end
% Separate per-image folder; do not overwrite an earlier run.
runDir=tempname(outputDir);
saveFundusResult(r,runDir,c);
exportgraphics(fig,fullfile(runDir,'comparison_labeled.png'));
fprintf('Saved results: %s\n',runDir);
end
