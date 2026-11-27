function build_paper_assets(results,paperDir)
% Generate every numerical figure and table used by ingles.tex.
images = fullfile(paperDir,'images');
s = readtable(fullfile(results,'summary.csv'),'TextType','string');
root = fileparts(mfilename('fullpath'));
fis = readfis(fullfile(root,'Fuzzy_2_2A.fis'));
variant = readfis(fullfile(root,'Fuzzy_1_8A.fis'));
options = evalfisOptions('NumSamplePoints',101);
palette = [0.00 .37 .55; .73 .29 .12; .20 .50 .36; .48 .34 .65; .52 .40 .14];
vars = [fis.Inputs fis.Outputs];
labels = {'Feedback voltage V_b (V)','Voltage margin V_d (V)','Requested current (A)'};
names = {'membership_vb','membership_vd','membership_current'};
for j = 1:3
    v = vars(j);
    f = newfig(8.7,5.0); ax = axes(f,'FontSize',10.5);
    [x,y] = plotmf(fis, ternary(j<3,'input','output'),min(j,1+double(j==2)));
    hold(ax,'on'); colororder(ax,palette);
    plot(ax,x,y,'LineWidth',1.45);
    xlim(ax,v.Range); ylim(ax,[0 1.08]);
    xlabel(ax,labels{j}); ylabel(ax,'Membership grade');
    legend(ax,{v.MembershipFunctions.Name},'Location','northoutside', ...
        'Orientation','horizontal','Box','off','FontSize',10);
    export(f,images,names{j});
end
f = newfig(8.7,5.1);
ax = axes(f,'FontSize',10);
hold(ax,'on');
colororder(ax,palette);
[x,y] = plotmf(variant,'output',1);
plot(ax,x,y,'LineWidth',1.55);
xlim(ax,variant.Outputs.Range);
xticks(ax,[0.5 0.7 0.9 1.1 1.3 1.5 1.8]);
ylim(ax,[0 1.05]);
yticks(ax,[0 0.5 1]);
xlabel(ax,'Requested current (A)');
ylabel(ax,'Membership grade');
legend(ax,{variant.Outputs.MembershipFunctions.Name},'Location','northoutside', ...
    'Orientation','horizontal','Box','off','FontSize',10);
export(f,images,'membership_current_180');

vb = linspace(3.08,4.30,61);
vd = linspace(0,1.22,61);
[X,Y] = meshgrid(vb,vd);
Z = reshape(evalfis(fis,[X(:),Y(:)],options),size(X));
f = newfig(8.7,6.7); ax = axes(f);
contourf(ax,X,Y,Z,.5:.085:2.2,'LineStyle','none'); hold(ax,'on');
path = plot(ax,vb,4.30-vb,'w-','LineWidth',1.6);
scatter(ax,4.2,.1,22,'w','filled','MarkerEdgeColor',[.15 .15 .15]);
clim(ax,[.5 2.2]); colormap(ax,parula);
b = colorbar(ax); b.Label.String = 'Requested current (A)';
xlabel(ax,'Feedback voltage V_b (V)'); ylabel(ax,'Voltage margin V_d (V)');
legend(ax,path,{'Operating trajectory'},'Location','northeast','Box','off');
export(f,images,'fis_surface');

point = [3.4 .45]; query = evalfis(fis,point,options);
gridI = linspace(.5,2.2,101)';
idx = [2 2; 2 3; 3 2; 3 3];
q = [3 4 3 4];
active = zeros(101,4);
for n = 1:4
    strength = min(evalmf(fis.Inputs(1).MembershipFunctions(idx(n,1)),point(1)), ...
        evalmf(fis.Inputs(2).MembershipFunctions(idx(n,2)),point(2)));
    active(:,n) = min(strength,evalmf(fis.Outputs.MembershipFunctions(q(n)),gridI));
end
aggregate = max(active,[],2);
assert(abs(sum(gridI.*aggregate)/sum(aggregate)-query)<1e-8);
f = newfig(8.7,5.2); ax = axes(f);
area(ax,gridI,aggregate,'FaceColor',[.79 .88 .94],'EdgeColor',palette(1,:),'LineWidth',1.3);
hold(ax,'on'); xline(ax,query,'--','Centroid','Color',palette(2,:), ...
    'LabelVerticalAlignment','middle','LabelHorizontalAlignment','left');
xlim(ax,[.5 2.2]); ylim(ax,[0 .59]);
xlabel(ax,'Requested current (A)'); ylabel(ax,'Aggregated grade');
export(f,images,'fis_centroid');

cc = getdata(results,'SIMULINK_CCCV','baseline');
fz = getdata(results,'SIMULINK_Fuzzy','baseline');
f = newfig(8.7,8.0); p = tiledlayout(f,2,1,'TileSpacing','compact','Padding','compact');
ax = nexttile(p); hold(ax,'on');
line1 = plot(ax,cc.Time_s/60,cc.Vmax_V,'Color',palette(1,:),'LineWidth',1.35);
line2 = plot(ax,fz.Time_s/60,fz.Vmax_V,'Color',palette(2,:),'LineWidth',1.35);
yline(ax,4.2,':','4.2 V','LabelHorizontalAlignment','left');
ylabel(ax,'Maximum cell voltage (V)');
legend(ax,[line1 line2],{'CC-CV','Mamdani'},'Location','southeast','Box','off','AutoUpdate','off');
ax = nexttile(p); hold(ax,'on');
plot(ax,cc.Time_s/60,cc.Current_A,'Color',palette(1,:),'LineWidth',1.35);
plot(ax,fz.Time_s/60,fz.Current_A,'Color',palette(2,:),'LineWidth',1.35);
ylim(ax,[0 2.38]); ylabel(ax,'Applied current (A)'); xlabel(ax,'Time (min)');
export(f,images,'nominal_response');

f = newfig(8.7,5.2); ax = axes(f); hold(ax,'on');
short = fz.Time_s<=15;
stairs(ax,fz.Time_s(short),fz.FISRequest_A(short),'Color',palette(2,:),'LineWidth',1.1);
stairs(ax,fz.Time_s(short),fz.SourceCommand_A(short),'Color',palette(1,:),'LineWidth',1.7);
plot(ax,fz.Time_s(short),fz.Current_A(short),'o','Color',[.12 .17 .2], ...
    'MarkerSize',3,'MarkerFaceColor','w');
xlim(ax,[0 15]); ylim(ax,[0 2.2]); xlabel(ax,'Time (s)'); ylabel(ax,'Current (A)');
legend(ax,{'FIS request','Source command','Measured current'}, ...
    'Location','southeast','Box','off');
export(f,images,'source_tracking');

f = newfig(8.7,8.5); p = tiledlayout(f,2,1,'TileSpacing','compact','Padding','compact');
for j = 1:2
    model = ternary(j==1,'SIMULINK_CCCV','SIMULINK_Fuzzy');
    t = getdata(results,model,'spread30');
    ax = nexttile(p); colororder(ax,palette(1:4,:));
    h = plot(ax,t.Time_s/60,t{:,2:5},'LineWidth',1.2);
    yline(ax,4.2,':','4.2 V','LabelHorizontalAlignment','left');
    title(ax,ternary(j==1,'CC-CV','Mamdani'),'FontWeight','normal');
    ylabel(ax,'Cell voltage (V)');
    legend(ax,h,{'BV1','BV2','BV3','BV4'},'Location','southeast','Box','off');
end
xlabel(ax,'Time (min)');
export(f,images,'soc_imbalance');

plot_output_sensitivity(results,images,palette);

cc = getdata(results,'SIMULINK_CCCV','extended');
fz = getdata(results,'SIMULINK_Fuzzy','extended');
f = newfig(17.5,9.8); p = tiledlayout(f,2,2,'TileSpacing','compact','Padding','compact');
series = {'Vmax_V','Current_A','SOC1_pct','Temperature_C'};
axisNames = {'Maximum cell voltage (V)','Applied current (A)','Cell SOC (%)','Temperature (deg C)'};
ccEvent = select(s,'SIMULINK_CCCV','extended');
fzEvent = select(s,'SIMULINK_Fuzzy','extended');
for j = 1:4
    ax = nexttile(p); hold(ax,'on');
    h1 = plot(ax,cc.Time_s/60,cc.(series{j}),'Color',palette(1,:),'LineWidth',1.35);
    h2 = plot(ax,fz.Time_s/60,fz.(series{j}),'Color',palette(2,:),'LineWidth',1.35);
    if j==1
        yline(ax,4.2,':','4.2 V','LabelHorizontalAlignment','left');
        split_voltage(ax,h1,cc,palette(1,:));
        split_voltage(ax,h2,fz,palette(2,:));
        legend(ax,[h1 h2],{'CC-CV','Mamdani'},'Location','southeast','Box','off','AutoUpdate','off');
    end
    xline(ax,ccEvent.Crossing_s/60,':','Color',palette(1,:));
    xline(ax,fzEvent.Crossing_s/60,':','Color',palette(2,:));
    ylabel(ax,axisNames{j});
    xlabel(ax,'Time (min)');
end
export(f,images,'extended_response');

write_tex(s,fis,query,paperDir);
write_complementary_tex(s,results,paperDir,root);
end

function plot_output_sensitivity(results,images,palette)
f = newfig(17.5,9.2);
p = tiledlayout(f,2,3,'TileSpacing','compact','Padding','compact');
cases = ["baseline","mean20","spread30"];
headings = {'Uniform 2.5% SOC','Uniform 20% SOC','SOC 5, 15, 25, 35%'};
nominalTraces = cell(size(cases));
variantTraces = cell(size(cases));
endTime = 0;
for k = 1:numel(cases)
    nominalTraces{k} = getdata(results,'SIMULINK_Fuzzy',cases(k));
    variantTraces{k} = getdata(results,'SIMULINK_Fuzzy',"output180_"+cases(k));
    endTime = max([endTime,nominalTraces{k}.Time_s(end),variantTraces{k}.Time_s(end)]);
end
lastMinute = 30*ceil(endTime/1800);
for k = 1:numel(cases)
    nominal = nominalTraces{k};
    variant = variantTraces{k};
    axVoltage = nexttile(p,k);
    axCurrent = nexttile(p,k+3);
    ax = [axVoltage axCurrent];
    fields = ["Vmax_V","Current_A"];
    for j = 1:2
        hold(ax(j),'on');
        a = plot(ax(j),nominal.Time_s/60,nominal.(fields(j)), ...
            'Color',palette(1,:),'LineWidth',1.35);
        b = plot(ax(j),variant.Time_s/60,variant.(fields(j)),'--', ...
            'Color',palette(2,:),'LineWidth',1.45);
        xlim(ax(j),[0 lastMinute]);
        xticks(ax(j),0:30:lastMinute);
        if j==1 && k==1
            key = legend(ax(j),[a b],{'Nominal [0.5, 2.2] A','Variant [0.5, 1.8] A'}, ...
                'Orientation','horizontal','Box','off','AutoUpdate','off');
            key.Layout.Tile = 'south';
        end
    end
    title(axVoltage,headings{k},'FontWeight','normal');
    yline(axVoltage,4.2,':','Color',[.3 .3 .3]);
    ylim(axVoltage,[3.2 4.24]);
    ylim(axCurrent,[0 2.05]);
    xlabel(axCurrent,'Time (min)');
    if k==1
        ylabel(axVoltage,'Maximum cell voltage (V)');
        ylabel(axCurrent,'Applied current (A)');
    end
end
export(f,images,'output_sensitivity');
end

function split_voltage(ax,handle,signals,color)
above = signals.Vmax_V>4.2;
nominal = signals.Vmax_V;
diagnostic = nominal;
nominal(above) = nan;
diagnostic(~above) = nan;
set(handle,'YData',nominal);
plot(ax,signals.Time_s/60,diagnostic,'--','Color',color,'LineWidth',1.4);
end

function write_tex(s,fis,query,paperDir)
h = fopen(fullfile(paperDir,'resultados_generados.tex'),'w','n','UTF-8');
assert(h>0,'Could not create the generated LaTeX input.');
cleanup = onCleanup(@()fclose(h));
fprintf(h,'%% Generated by MATLAB build_paper_assets.m.\n');
cc = select(s,'SIMULINK_CCCV','baseline'); fz = select(s,'SIMULINK_Fuzzy','baseline');
macro(h,'TimeCC',num2str(cc.Crossing_s,'%.0f'));
macro(h,'TimeFZ',num2str(fz.Crossing_s,'%.0f'));
macro(h,'PeakIFZ',num2str(fz.PeakCurrent_A,'%.3f'));
macro(h,'RiseCC',num2str(cc.RiseToCrossing_K,'%.2f'));
macro(h,'RiseFZ',num2str(fz.RiseToCrossing_K,'%.2f'));
macro(h,'StaticCurrent',num2str(query,'%.3f'));
macro(h,'TrackingError',num2str(fz.MaxTrackingError_A,'%.3g'));
macro(h,'ExtraTimeFZ',num2str(fz.Crossing_s-cc.Crossing_s,'%.0f'));
macro(h,'RelativeExtraFZ',num2str(100*(fz.Crossing_s-cc.Crossing_s)/cc.Crossing_s,'%.1f'));
xc = select(s,'SIMULINK_CCCV','extended'); xf = select(s,'SIMULINK_Fuzzy','extended');
macro(h,'ExtendedCCPeak',num2str(xc.PeakRise_K,'%.2f'));
macro(h,'ExtendedFZPeak',num2str(xf.PeakRise_K,'%.2f'));
macro(h,'ExtendedCCPeakTime',num2str(xc.TimeOfPeak_s,'%.0f'));
macro(h,'ExtendedFZPeakTime',num2str(xf.TimeOfPeak_s,'%.0f'));
macro(h,'ExtendedCCStop',num2str(xc.End_s,'%.0f'));
macro(h,'ExtendedFZStop',num2str(xf.End_s,'%.0f'));
macro(h,'ExtendedCCSOC',num2str(xc.FinalMaxSOC_pct,'%.2f'));
macro(h,'ExtendedFZSOC',num2str(xf.FinalMaxSOC_pct,'%.2f'));
macro(h,'ExtendedCCVoltage',num2str(xc.PeakVoltage_V,'%.4f'));
macro(h,'ExtendedFZVoltage',num2str(xf.PeakVoltage_V,'%.4f'));
macro(h,'ExtendedCCCurrent',num2str(xc.PeakCurrent_A,'%.4f'));
macro(h,'ExtendedFZCurrent',num2str(xf.PeakCurrent_A,'%.4f'));
macro(h,'CCSolverChange',num2str(select(s,'SIMULINK_CCCV','solverCheck').Crossing_s-cc.Crossing_s,'%.1f'));
macro(h,'FZSolverChange',num2str(select(s,'SIMULINK_Fuzzy','solverCheck').Crossing_s-fz.Crossing_s,'%.1f'));
macro(h,'CCSampleChange',num2str(select(s,'SIMULINK_CCCV','sampleCheck').Crossing_s-cc.Crossing_s,'%.1f'));
macro(h,'FZSampleChange',num2str(select(s,'SIMULINK_Fuzzy','sampleCheck').Crossing_s-fz.Crossing_s,'%.1f'));

fprintf(h,'\\newcommand{\\OutputMFs}{%%\n');
for k=1:5
    a = fis.Inputs(1).MembershipFunctions(k);
    b = fis.Inputs(2).MembershipFunctions(k);
    c = fis.Outputs.MembershipFunctions(k);
    fprintf(h,'%s & $(%.3f,%.3f,%.3f)$ & $(%.3f,%.3f,%.3f)$ & $(%.4f,%.4f,%.4f)$ \\\\\n', ...
        a.Name,a.Parameters,b.Parameters,c.Parameters);
end
fprintf(h,'}\n\\newcommand{\\NominalRows}{%%\n');
for row = 1:2
    x = ternary(row==1,cc,fz);
    fprintf(h,'%s & %.0f & %.3f & %.2f & %.2f \\\\\n', ...
        ternary(row==1,'CC--CV','Mamdani'),x.Crossing_s,x.PeakCurrent_A, ...
        x.MeanSOCAtCrossing_pct,x.RiseToCrossing_K);
end
fprintf(h,'}\n\\newcommand{\\CurrentRows}{%%\n');
for name = ["limit110","limit150","limit180","baseline"]
    a = select(s,'SIMULINK_CCCV',name); b = select(s,'SIMULINK_Fuzzy',name);
    fprintf(h,'%.2f & %.0f & %.0f & %.3f \\\\\n',a.Limit_A,a.Crossing_s,b.Crossing_s,b.PeakCurrent_A);
end
fprintf(h,'}\n\\newcommand{\\SOCRows}{%%\n');
socSets = {'2.5, 2.5, 2.5, 2.5','20, 20, 20, 20','40, 40, 40, 40', ...
    '15, 18, 22, 25','5, 15, 25, 35','35, 25, 15, 5'};
cases = ["baseline","mean20","mean40","spread10","spread30","spread30rev"];
for k = 1:numel(cases)
    a = select(s,'SIMULINK_CCCV',cases(k)); b = select(s,'SIMULINK_Fuzzy',cases(k));
    fprintf(h,'%s & %.0f & %.0f & %.0f & %.0f & %s/%s \\\\\n',socSets{k}, ...
        a.Crossing_s,b.Crossing_s,1000*a.Spread_V,1000*b.Spread_V,a.FirstCell,b.FirstCell);
end
fprintf(h,'}\n\\newcommand{\\ThermalRows}{%%\n');
for name = ["extended","thermalLL","thermalLH","thermalHL","thermalHH"]
    a = select(s,'SIMULINK_CCCV',name); b = select(s,'SIMULINK_Fuzzy',name);
    fprintf(h,'%.1f & %.0f & %.2f & %.0f & %.2f & %.0f \\\\\n',a.Cth_J_K,a.Rth_K_W, ...
        a.PeakRise_K,a.TimeOfPeak_s,b.PeakRise_K,b.TimeOfPeak_s);
end
fprintf(h,'}\n');
fprintf(h,'\\newcommand{\\OutputSensitivityRows}{%%\n');
cases = ["baseline","mean20","spread30"];
socSets = {'2.5, 2.5, 2.5, 2.5','20, 20, 20, 20','5, 15, 25, 35'};
deltaTime = zeros(1,numel(cases));
for k = 1:numel(cases)
    ref = select(s,'SIMULINK_Fuzzy',cases(k));
    alt = select(s,'SIMULINK_Fuzzy',"output180_"+cases(k));
    deltaTime(k) = alt.Crossing_s-ref.Crossing_s;
    fprintf(h,'%s & %.0f & %.0f & %.0f & %.0f \\\\\n',socSets{k}, ...
        ref.Crossing_s,alt.Crossing_s,1000*ref.Spread_V,1000*alt.Spread_V);
end
fprintf(h,'}\n');
macro(h,'OutputDeltaBaseline',num2str(deltaTime(1),'%+.0f'));
macro(h,'OutputDeltaMean',num2str(deltaTime(2),'%+.0f'));
macro(h,'OutputDeltaSpread',num2str(deltaTime(3),'%+.0f'));
end

function write_complementary_tex(s,results,paperDir,root)
h = fopen(fullfile(paperDir,'resultados_complementarios.tex'),'w','n','UTF-8');
assert(h>0,'Could not create the complementary LaTeX input.');
cleanup = onCleanup(@()fclose(h));
fprintf(h,'%% Generated from the benchmark and Validacion_Eisto CSV files.\n');
cc = select(s,'SIMULINK_CCCV','limit110');
fz = select(s,'SIMULINK_Fuzzy','limit110');
macro(h,'LateLowCap',num2str(100*(fz.Crossing_s/cc.Crossing_s-1),'%.1f'));
models = ["SIMULINK_CCCV","SIMULINK_Fuzzy"];
suffixes = ["CC","FZ"];
times = zeros(1,numel(models));
for j = 1:numel(models)
    trace = getdata(results,models(j),'baseline');
    k = find(trace.SOC1_pct>=90,1);
    assert(~isempty(k) && ~trace.VoltageEvent(k) && ...
        all(abs(trace{k,7:10}-trace.SOC1_pct(k))<1e-8), ...
        'Expected a common 90%% SOC sample before the nominal voltage event.');
    times(j) = trace.Time_s(k);
    macro(h,char("TimeNinety"+suffixes(j)),num2str(times(j),'%.0f'));
    macro(h,char("VoltNinety"+suffixes(j)),num2str(trace.Vmax_V(k),'%.3f'));
    macro(h,char("RiseNinety"+suffixes(j)),num2str(max(trace.Temperature_C(1:k))-25,'%.2f'));
end
macro(h,'LateNinety',num2str(100*(times(2)/times(1)-1),'%.1f'));
eisto = readtable(fullfile(root,'Validacion_Eisto','datos','metricas.csv'));
macro(h,'EistoRefV',num2str(eisto.Ref_4p2_s/60,'%.1f'));
macro(h,'EistoSimV',num2str(eisto.Sim_4p2_s/60,'%.1f'));
macro(h,'EistoAbsGapV',num2str(abs(eisto.Gap_4p2_s)/60,'%.1f'));
macro(h,'EistoRefI',num2str(eisto.Ref_taper_s/60,'%.1f'));
macro(h,'EistoSimI',num2str(eisto.Sim_taper_s/60,'%.1f'));
macro(h,'EistoVoltMAE',num2str(1000*eisto.MAE_voltage_V,'%.1f'));
macro(h,'EistoCurrentMAE',num2str(1000*eisto.MAE_current_A,'%.1f'));
macro(h,'EistoProgressMAE',num2str(eisto.MAE_progress_pp,'%.1f'));
end

function macro(h,name,value)
fprintf(h,'\\newcommand{\\%s}{%s}\n',name,value);
end

function x = select(s,m,c)
x = s(s.Model==m & s.Scenario==c,:);
assert(height(x)==1);
end

function t = getdata(root,model,scenario)
t = readtable(fullfile(root,string(model)+"_"+scenario+".csv"));
end

function f = newfig(w,h)
f = figure('Visible','off','Color','white','Units','centimeters','Position',[2 2 w h], ...
    'DefaultAxesFontName','Arial','DefaultAxesFontSize',9, ...
    'DefaultAxesTickDir','out','DefaultAxesBox','off', ...
    'DefaultAxesXGrid','on','DefaultAxesYGrid','on','DefaultAxesGridAlpha',.14);
end

function export(f,root,name)
savefig(f,fullfile(root,[name '.fig']));
exportgraphics(f,fullfile(root,[name '.pdf']),'ContentType','vector');
close(f);
end

function value = ternary(condition,whenTrue,whenFalse)
if condition
    value = whenTrue;
else
    value = whenFalse;
end
end
