function [path,name] = buildScreeningSimulink(s,folder)
%BUILDSCREENINGSIMULINK Generate four actual connected queue stages as SLX.
% Deterministic fluid model in minutes; stochastic counterpart is MATLAB.
% No SimEvents needed. Inputs and assumptions stored in model workspace.
if nargin < 1, s = workflowConfig(); end
if nargin < 2, folder = fullfile(pwd,'workflow_results'); end
[cap,~,demand] = workflowCapacities(s);
if ~isfolder(folder), mkdir(folder); end
[~,nonce] = fileparts(tempname); name = ['DRScreening_' nonce(1:min(12,numel(nonce)))];
new_system(name); load_system('simulink');
set_param(name,'Solver','FixedStepDiscrete','FixedStep','1', ...
    'StartTime','0','StopTime',num2str(s.hoursPerDay*60),'ReturnWorkspaceOutputs','on');
workspace = get_param(name,'ModelWorkspace');
assignin(workspace,'scenario',s);
add_block('simulink/Sources/Constant',[name '/PatientArrivals'], ...
    'Value',num2str(demand(1)/60,16),'Position',[25 90 110 125]);
upstream = 'PatientArrivals/1';
stageNames = {'Camera','Upload','Processing','DoctorReview'};
for k = 1:4
    x = 170+(k-1)*310; prefix = stageNames{k};
    if k==4
        add_block('simulink/Math Operations/Gain',[name '/ReviewFraction'], ...
            'Gain',num2str(s.reviewFraction,16),'Position',[x-65 90 x-30 125]);
        add_line(name,upstream,'ReviewFraction/1','autorouting','on'); upstream = 'ReviewFraction/1';
    end
    add_block('simulink/Math Operations/Sum',[name '/' prefix '_Demand'], ...
        'Inputs','++','Position',[x 90 x+30 125]);
    add_block('simulink/Sources/Constant',[name '/' prefix '_Capacity'], ...
        'Value',num2str(cap(k)/60,16),'Position',[x+45 170 x+115 205]);
    add_block('simulink/Math Operations/MinMax',[name '/' prefix '_Served'], ...
        'Function','min','Inputs','2','Position',[x+140 85 x+185 130]);
    add_block('simulink/Math Operations/Sum',[name '/' prefix '_NetQueue'], ...
        'Inputs','+-','Position',[x+15 275 x+45 310]);
    add_block('simulink/Discrete/Discrete-Time Integrator',[name '/' prefix '_Queue'], ...
        'SampleTime','1','InitialCondition','0','LimitOutput','on', ...
        'LowerSaturationLimit','0','UpperSaturationLimit','inf', ...
        'Position',[x+80 270 x+150 315]);
    add_block('simulink/Sinks/To Workspace',[name '/' prefix '_Log'], ...
        'VariableName',[prefix 'Queue'],'SaveFormat','Timeseries', ...
        'Position',[x+170 360 x+270 395]);
    add_line(name,upstream,[prefix '_Demand/1'],'autorouting','on');
    add_line(name,[prefix '_Queue/1'],[prefix '_Demand/2'],'autorouting','on');
    add_line(name,[prefix '_Demand/1'],[prefix '_Served/1'],'autorouting','on');
    add_line(name,[prefix '_Capacity/1'],[prefix '_Served/2'],'autorouting','on');
    add_line(name,upstream,[prefix '_NetQueue/1'],'autorouting','on');
    add_line(name,[prefix '_Served/1'],[prefix '_NetQueue/2'],'autorouting','on');
    add_line(name,[prefix '_NetQueue/1'],[prefix '_Queue/1'],'autorouting','on');
    add_line(name,[prefix '_Queue/1'],[prefix '_Log/1'],'autorouting','on');
    upstream = [prefix '_Served/1'];
end
add_block('simulink/Sinks/To Workspace',[name '/CompletedReviews'], ...
    'VariableName','ReviewRate','SaveFormat','Timeseries','Position',[1450 90 1560 125]);
add_line(name,upstream,'CompletedReviews/1','autorouting','on');
path = fullfile(folder,[name '.slx']); save_system(name,path);
fprintf('Simulink model saved: %s\n',path);
end
