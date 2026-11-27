function summary = run_benchmark(paperDir)
% Reproduce the paper with MATLAB/Simulink R2023b and the supplied models.
root = fileparts(mfilename('fullpath'));
if nargin == 0
    paperDir = fullfile(root,'InformeBaterias');
    if ~isfolder(paperDir)
        paperDir = fullfile(fileparts(root),'InformeBaterias');
    end
end
old = cd(root);
restoreFolder = onCleanup(@()cd(old));
results = fullfile(root,'results');
if ~isfolder(results), mkdir(results); end
images = fullfile(paperDir,'images');
if ~isfolder(images), mkdir(images); end

nominalFis = "Fuzzy_2_2A.fis";
variantFis = "Fuzzy_1_8A.fis";
write_output_variant(fullfile(root,nominalFis),fullfile(root,variantFis),1.8);

base = 2.5*ones(1,4);
scenarios = {
    'baseline',    base,              2.2, true,  40.5, 20, 1,   1
    'limit110',    base,              1.1, true,  40.5, 20, 1,   1
    'limit150',    base,              1.5, true,  40.5, 20, 1,   1
    'limit180',    base,              1.8, true,  40.5, 20, 1,   1
    'mean20',      [20 20 20 20],      2.2, true,  40.5, 20, 1,   1
    'mean40',      [40 40 40 40],      2.2, true,  40.5, 20, 1,   1
    'spread10',    [15 18 22 25],      2.2, true,  40.5, 20, 1,   1
    'spread30',    [5 15 25 35],       2.2, true,  40.5, 20, 1,   1
    'spread30rev', [35 25 15 5],       2.2, true,  40.5, 20, 1,   1
    'extended',    base,              2.2, false, 40.5, 20, 1,   1
    'thermalLL',   base,              2.2, false, 36,   10, 1,   1
    'thermalLH',   base,              2.2, false, 36,   30, 1,   1
    'thermalHL',   base,              2.2, false, 50,   10, 1,   1
    'thermalHH',   base,              2.2, false, 50,   30, 1,   1
    'solverCheck', base,              2.2, true,  40.5, 20, 1,   .25
    'sampleCheck', base,              2.2, true,  40.5, 20, .5,  .25
};
outputCases = {
    'output180_baseline', base,          2.2, true, 40.5, 20, 1, 1
    'output180_mean20',   [20 20 20 20], 2.2, true, 40.5, 20, 1, 1
    'output180_spread30', [5 15 25 35],  2.2, true, 40.5, 20, 1, 1
};
summary = table;
models = ["SIMULINK_CCCV","SIMULINK_Fuzzy"];
for j = 1:numel(models)
    m = models(j);
    modelFile = fullfile(root,m+".slx");
    if bdIsLoaded(m)
        assert(strcmpi(get_param(m,'FileName'),modelFile), ...
            'Close the open copy of %s before running the benchmark.',m);
    end
    load_system(modelFile);
    modelCases = scenarios;
    if m == "SIMULINK_Fuzzy"
        modelCases = [scenarios;outputCases];
        controller = find_system(m,'SearchDepth',1,'RegExp','on', ...
            'Name','^Fuzzy Logic\s+Controller$');
        assert(numel(controller)==1,'Expected one active fuzzy controller.');
    end
    for k = 1:size(modelCases,1)
        [caseName,soc,limit,stopAtVoltage,cth,rth,ts,step] = modelCases{k,:};
        fprintf('%s / %s\n',m,caseName);
        si = Simulink.SimulationInput(m);
        isOutputVariant = startsWith(caseName,'output180_');
        fisFile = "";
        outputUpper = NaN;
        if m == "SIMULINK_Fuzzy"
            fisFile = nominalFis;
            outputUpper = 2.2;
            if isOutputVariant
                fisFile = variantFis;
                outputUpper = 1.8;
            end
            si = si.setBlockParameter(controller{1},'FIS',char("'"+fisFile+"'"));
        end
        values = struct('SOC0',soc,'Ilimit',limit,'StopAtVoltage', ...
            stopAtVoltage,'Cth',cth,'Rth',rth,'TsPower',ts,'TsFIS',ts);
        for name = string(fieldnames(values))'
            si = si.setVariable(name,values.(name),'Workspace',m);
        end
        rel = '1e-5'; ab = '1e-7';
        if strcmp(caseName,'solverCheck')
            rel = '1e-6'; ab = '1e-8';
        end
        if strcmp(caseName,'sampleCheck')
            % Set the mask value explicitly so SPS recompiles at the requested rate.
            si = si.setBlockParameter(m+"/powergui",'SampleTime',num2str(ts));
        end
        si = si.setModelParameter('MaxStep',num2str(step),'RelTol',rel,'AbsTol',ab);
        out = sim(si);
        logs = out.logsout;
        [row,signals] = summarize(m,caseName,logs,limit,soc,cth,rth,ts,step);
        row.FISFile = fisFile;
        row.FISUpper_A = outputUpper;
        if isOutputVariant
            row{:,{'Cth_J_K','Rth_K_W','RiseToCrossing_K','PeakRise_K','TimeOfPeak_s'}} = NaN;
            signals.Temperature_C = [];
        end
        if strcmp(caseName,'sampleCheck')
            voltageChanges = [false; any(abs(diff(signals{:,2:5})) > 1e-8,2)];
            halfSecondHits = abs(mod(signals.Time_s,1)-ts) < 1e-8;
            assert(any(voltageChanges & halfSecondHits), ...
                'The electrical signals did not update at half-second hits.');
        end
        assert(isfinite(row.Crossing_s),'No voltage crossing in %s/%s.',m,caseName);
        assert(row.PeakCurrent_A <= limit+1e-5, ...
            'Applied current exceeds limit in %s/%s.',m,caseName);
        if stopAtVoltage
            assert(abs(row.End_s-row.Crossing_s) <= ts/100, ...
                'Voltage stop and measured crossing disagree in %s/%s.',m,caseName);
        end
        if m == "SIMULINK_Fuzzy"
            assert(all(signals.FISRequest_A >= 0.5-1e-8 & ...
                signals.FISRequest_A <= outputUpper+1e-8), ...
                'FIS output lies outside the configured universe in %s.',caseName);
        end
        summary = [summary;row]; %#ok<AGROW>
        writetable(signals,fullfile(results,m+"_"+caseName+".csv"));
        fprintf('  t4.2 = %.3f s; Ipeak = %.5f A; deltaV = %.6f V\n', ...
            row.Crossing_s,row.PeakCurrent_A,row.Spread_V);
    end
end
writetable(summary,fullfile(results,'summary.csv'));
validationDir = fullfile(root,'Validacion_Eisto');
oldPath = path;
restorePath = onCleanup(@()path(oldPath));
addpath(validationDir);
ejecutar_comparacion;
copyfile(fullfile(validationDir,'figuras','comparacion_cccv.pdf'), ...
    fullfile(images,'eisto_comparison.pdf'));
copyfile(fullfile(validationDir,'datos','curva_ficha.png'), ...
    fullfile(images,'eisto_charge_characteristics.png'));
build_paper_assets(results,paperDir);
export_model_configuration(results);
end

function [row,signals] = summarize(model,caseName,logs,limit,soc,cth,rth,ts,step)
voltage = logs.get('cellVoltage').Values;
[t,k] = unique(voltage.Time,'last');
v = reshape(voltage.Data(k,:),numel(k),4);
s = sample(logs,'cellSOC',t,'previous');
i = sample(logs,'measuredCurrent',t,'previous');
temp = sample(logs,'temperature',t,'linear');
[vmax,first] = max(v,[],2);
vmin = min(v,[],2);
event = find(vmax>=4.2,1);
cross = nan; id = "--"; spread = nan; upper = nan; lower = nan; endSOC = nan;
crossRise = nan; eventIndex = nan;
if ~isempty(event)
    cross = t(event);
    assert(abs(cross/ts-round(cross/ts))<1e-8, ...
        'The voltage crossing fell outside the electrical sampling grid.');
    eventIndex = event;
    id = "BV"+first(event);
    if all(abs(v(event,:)-vmax(event))<1e-8)
        id = "all";
    end
    upper = vmax(event);
    lower = vmin(event);
    spread = upper-lower;
    endSOC = mean(s(event,:));
    crossRise = max(temp(1:event))-25;
end
raw = nan(size(t)); command = raw; cv = false(size(t)); tracking = nan;
if model == "SIMULINK_Fuzzy"
    raw = sample(logs,'fisRequest',t,'previous');
    command = sample(logs,'sourceCommand',t,'previous');
    tracking = max(abs(abs(i)-abs(command)));
else
    cv = logical(sample(logs,'cvMode',t,'previous'));
    command = sample(logs,'ccSetpoint',t,'previous');
    command(cv) = nan;
    tracking = max(abs(abs(i(~cv & t>0))-abs(command(~cv & t>0))));
end
fullI = abs(logs.get('measuredCurrent').Values.Data);
[peakRise,x] = max(temp-25);
eventSignal = logical(sample(logs,'voltageEvent',t,'previous'));
assert(isequal(eventSignal,vmax>=4.2),'Logged threshold signal disagrees with Vmax.');
signals = table(t,v(:,1),v(:,2),v(:,3),v(:,4),vmax,s(:,1),s(:,2),s(:,3),s(:,4), ...
    i,abs(i),temp,raw,command,cv,eventSignal, ...
    'VariableNames',{'Time_s','BV1_V','BV2_V','BV3_V','BV4_V','Vmax_V', ...
    'SOC1_pct','SOC2_pct','SOC3_pct','SOC4_pct','MeasuredSigned_A','Current_A', ...
    'Temperature_C','FISRequest_A','SourceCommand_A','CVMode','VoltageEvent'});
row = table(model,string(caseName),limit,mean(soc),max(soc)-min(soc),cth,rth,ts,step, ...
    cross,eventIndex,id,upper,lower,spread,endSOC, ...
    crossRise,peakRise,t(x),max(fullI),max(vmax),t(end),max(s(end,:)),tracking, ...
    'VariableNames',{'Model','Scenario','Limit_A','MeanSOC_pct','InitialSpread_pp', ...
    'Cth_J_K','Rth_K_W','Sample_s','MaxStep_s','Crossing_s','EventRow','FirstCell', ...
    'VmaxAtCrossing_V','VminAtCrossing_V','Spread_V','MeanSOCAtCrossing_pct', ...
    'RiseToCrossing_K','PeakRise_K','TimeOfPeak_s','PeakCurrent_A','PeakVoltage_V', ...
    'End_s','FinalMaxSOC_pct','MaxTrackingError_A'});
end

function data = sample(logs,name,t,kind)
v = logs.get(name).Values;
[time,idx] = unique(v.Time,'last');
d = double(v.Data(idx,:));
if numel(time)==1
    data = repmat(d,numel(t),1);
else
    data = interp1(time,d,t,kind,'extrap');
end
end
