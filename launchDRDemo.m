function app = launchDRDemo(c)
%LAUNCHDRDEMO MATLAB Online review dashboard. Run setupDRDemo first.
if nargin < 1, c = setupDRDemo(); end
imageStartFolder = c.datasetRoot;
if ~isfolder(imageStartFolder)
    imageStartFolder = fullfile(c.projectRoot,'demo_assets');
end
f = uifigure('Name','DR Screening | Rural Care Prototype','Position',[30 30 1320 880]);
grid = uigridlayout(f,[5 1]); grid.RowHeight = {48,76,'1x',190,32};
grid.Padding = [14 12 14 12]; grid.RowSpacing = 10;
header = uilabel(grid,'Text','RETINAL SCREENING  /  Quality • Evidence • Review', ...
    'FontSize',22,'FontWeight','bold','FontColor',[.04 .22 .30]);
header.Layout.Row = 1;
controls = uigridlayout(grid,[2 5]); controls.Layout.Row = 2;
controls.ColumnWidth = {'1x',150,150,160,170}; controls.RowHeight = {30,30};
pathField = uieditfield(controls,'text','Placeholder','Choose a fundus image');
pathField.Layout.Row = 1; pathField.Layout.Column = [1 3];
browse = uibutton(controls,'Text','Choose image','ButtonPushedFcn',@chooseImage);
browse.Layout.Row = 1; browse.Layout.Column = 4;
runButton = uibutton(controls,'Text','Run screening','ButtonPushedFcn',@runCase);
runButton.Layout.Row = 1; runButton.Layout.Column = 5;
modelField = uieditfield(controls,'text','Value',c.modelPath);
modelField.Layout.Row = 2; modelField.Layout.Column = [1 2];
modelButton = uibutton(controls,'Text','Choose MAT model','ButtonPushedFcn',@chooseModel);
modelButton.Layout.Row = 2; modelButton.Layout.Column = 3;
scaling = uidropdown(controls,'Items',{'0–255 RGB','0–1 RGB'}, ...
    'ItemsData',{'zero_255','zero_one'},'Value',c.modelInputRange);
scaling.Layout.Row = 2; scaling.Layout.Column = 4;
confirmed = uicheckbox(controls,'Text','Scaling verified','Value',c.preprocessingConfirmed);
confirmed.Layout.Row = 2; confirmed.Layout.Column = 5;
images = uigridlayout(grid,[2 3]); images.Layout.Row = 3;
axesList = gobjects(1,6);
names = {'Original','Enhanced / unchanged','Vessel candidates', ...
    'Lesion + structure candidates','Grad-CAM','Class scores'};
for k = 1:6
    axesList(k) = uiaxes(images); title(axesList(k),names{k});
    axesList(k).XTick = []; axesList(k).YTick = [];
end
bottom = uigridlayout(grid,[1 2]); bottom.Layout.Row = 4;
bottom.ColumnWidth = {'1x',440};
summary = uitextarea(bottom,'Editable','off','Value', ...
    {'Load a fundus image to start.','Confirm model preprocessing to enable classification.', ...
    'Lesion candidates are an untrained baseline; specialist confirmation required.'});
review = uigridlayout(bottom,[4 3]); review.ColumnWidth = {135,'1x',125};
review.RowHeight = {28,28,'1x',30};
uilabel(review,'Text','Reviewer'); reviewer = uieditfield(review,'text');
pdfButton = uibutton(review,'Text','Export PDF','Enable','off','ButtonPushedFcn',@exportPDF);
uilabel(review,'Text','Review status');
reviewStatus = uidropdown(review,'Items',{'Pending','Reviewed','Recapture requested','Specialist review requested'});
doctorGrade = uidropdown(review,'Items',{'Not recorded','0','1','2','3','4'});
notes = uitextarea(review,'Placeholder','Reviewer notes (optional)');
notes.Layout.Row = 3; notes.Layout.Column = [1 3];
saveButton = uibutton(review,'Text','Save review','Enable','off','ButtonPushedFcn',@saveReview);
saveButton.Layout.Row = 4; saveButton.Layout.Column = 1;
simulationButton = uibutton(review,'Text','Workflow simulation','ButtonPushedFcn',@runSimulation);
simulationButton.Layout.Row = 4; simulationButton.Layout.Column = [2 3];
status = uilabel(grid,'Text','RESEARCH DEMO • No diagnosis or treatment recommendation', ...
    'FontColor',[.65 .12 .12]); status.Layout.Row = 5;
current = []; cachedModel = []; cachedSettings = '';
app = struct('Figure',f,'Axes',axesList);

    function chooseImage(~,~)
        [name,folder] = uigetfile({'*.jpg;*.jpeg;*.png;*.tif;*.tiff;*.bmp','Fundus images'}, ...
            'Choose a fundus image',imageStartFolder);
        if isequal(name,0), return; end
        pathField.Value = fullfile(folder,name);
    end

    function chooseModel(~,~)
        [name,folder] = uigetfile('*.mat','Choose the trained MATLAB network',c.projectRoot);
        if isequal(name,0), return; end
        modelField.Value = fullfile(folder,name); cachedModel = [];
        confirmed.Value = false;
    end

    function runCase(~,~)
        if ~isfile(pathField.Value), uialert(f,'Choose an existing fundus image.','Input required'); return; end
        runButton.Enable = 'off'; status.Text = 'Processing image...'; drawnow;
        cleaner = onCleanup(@enableRun);
        try
            c.modelPath = modelField.Value; c.modelInputRange = scaling.Value;
            c.preprocessingConfirmed = confirmed.Value;
            key = [c.modelPath '|' c.modelInputRange];
            if c.preprocessingConfirmed && (isempty(cachedModel) || ~strcmp(key,cachedSettings))
                cachedModel = loadDRModel(c.modelPath,c); cachedSettings = key;
            end
            current = runDRCase(pathField.Value,c,cachedModel);
            renderCase(); pdfButton.Enable = 'on'; saveButton.Enable = 'on';
            reviewer.Value = ''; reviewStatus.Value = 'Pending';
            doctorGrade.Value = 'Not recorded'; notes.Value = {''};
            status.Text = sprintf('Analysis %.1f s | %s',current.seconds,current.outputFolder);
        catch ME
            status.Text = 'Processing failed'; uialert(f,ME.message,'Screening error');
        end
        clear cleaner
    end

    function enableRun()
        if isvalid(runButton), runButton.Enable = 'on'; end
    end

    function renderCase()
        for a = axesList, cla(a); end
        imshow(current.original,'Parent',axesList(1)); title(axesList(1),'Original');
        imshow(current.enhanced,'Parent',axesList(2)); title(axesList(2),'Enhanced / unchanged');
        imshow(current.evidence.vessels,'Parent',axesList(3)); title(axesList(3),'Vessel candidates');
        imshow(current.evidence.overlay,'Parent',axesList(4)); title(axesList(4),'Lesion + structure candidates');
        if current.explanation.available
            imshow(current.explanation.overlay,'Parent',axesList(5)); title(axesList(5),'Grad-CAM | CNN attention');
        else
            axis(axesList(5),'off');
            text(axesList(5),.05,.55,'Grad-CAM unavailable','Units','normalized','FontSize',13);
        end
        p = current.prediction;
        if p.available
            axis(axesList(6),'on'); bar(axesList(6),0:4,p.scores,'FaceColor',[.05 .45 .55]);
            ylim(axesList(6),[0 1]); axesList(6).XTick = 0:4; axesList(6).YTick = [0 .5 1];
            title(axesList(6),sprintf('Model grade %d | score %.1f%%',p.grade,100*p.score));
            xlabel(axesList(6),'DR grade'); ylabel(axesList(6),'Class score');
        else
            axis(axesList(6),'off');
            text(axesList(6),.05,.55,'Classification withheld / unavailable','Units','normalized','FontSize',12);
        end
        count = current.evidence.counts;
        summary.Value = {sprintf('CASE %s | QUALITY %s',current.imageID,current.quality.status), ...
            current.quality.message,p.message, ...
            sprintf('CANDIDATES: MA %d | Hemorrhages %d | Exudates %d',count.MA,count.HE,count.EX), ...
            'Cyan vessels • Red MA • Purple hemorrhages • Yellow exudates', ...
            'Green disc / white fovea are estimates; neovascularization is not assessed.', ...
            current.explanation.message};
    end

    function recordReview()
        current.review = struct('status',reviewStatus.Value,'reviewer',reviewer.Value, ...
            'confirmedGrade',doctorGrade.Value,'notes',strjoin(cellstr(string(notes.Value)),newline));
        writeCaseSummary(current);
        if c.saveCaseMAT, out = current; save(fullfile(current.outputFolder,'case.mat'),'out','-v7.3'); end
    end

    function saveReview(~,~)
        if isempty(current), return; end
        try, recordReview(); status.Text = 'Reviewer-entered findings saved.';
        catch ME, uialert(f,ME.message,'Save error'); end
    end

    function exportPDF(~,~)
        if isempty(current), return; end
        try
            recordReview(); current.pdfPath = exportDRReport(current);
            status.Text = ['PDF saved: ' current.pdfPath];
        catch ME, uialert(f,ME.message,'PDF error'); end
    end

    function runSimulation(~,~)
        try, workflowDemo(fullfile(c.outputRoot,'workflow'));
        catch ME, uialert(f,ME.message,'Simulation error'); end
    end
end
