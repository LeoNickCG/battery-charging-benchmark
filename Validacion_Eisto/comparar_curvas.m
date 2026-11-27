function comparar_curvas
% Common axes and error metrics on the overlap of simulation and chart.
root=fileparts(mfilename('fullpath'));
data=fullfile(root,'datos');
figures=fullfile(root,'figuras');
if ~isfolder(figures), mkdir(figures); end
sim=readtable(fullfile(data,'simulacion_cccv.csv'));
ref=readtable(fullfile(data,'ficha_digitalizada.csv'));
tr=ref.Time_s;
ts=sim.Time_s;
names={'Voltage_V','Current_A','SOC_pct'};
refNames={'Voltage_V','Current_A','Relative_capacity_pct'};
first=ref.Time_s>0;
sel=tr(first);
residual=nan(numel(sel),3);
for j=1:3
    residual(:,j)=interp1(ts,sim.(names{j}),sel)-ref.(refNames{j})(first);
end
refV=tr(sustained(tr,ref.Voltage_V>=4.2,30));
simV=ts(sustained(ts,sim.Voltage_V>=4.2,30));
refI=tr(sustained(tr,ref.Current_A<=.99*1.1,30));
simI=ts(sustained(ts,sim.Current_A<=.99*1.1,30));
metrics=table(refV,simV,simV-refV,refI,simI,simI-refI,tr(end),ts(end), ...
    mean(abs(residual(:,1))),sqrt(mean(residual(:,1).^2)), ...
    mean(abs(residual(:,2))),sqrt(mean(residual(:,2).^2)),mean(abs(residual(:,3))), ...
    'VariableNames',{'Ref_4p2_s','Sim_4p2_s','Gap_4p2_s','Ref_taper_s','Sim_taper_s', ...
    'Gap_taper_s','Ref_end_s','Sim_end_s','MAE_voltage_V','RMSE_voltage_V', ...
    'MAE_current_A','RMSE_current_A','MAE_progress_pp'});
writetable(metrics,fullfile(data,'metricas.csv'));
errorTable=table(sel,residual(:,1),residual(:,2),residual(:,3), ...
    'VariableNames',{'Time_s','Error_voltage_V','Error_current_A','Error_progress_pp'});
writetable(errorTable,fullfile(data,'residuos.csv'));
disp(metrics);
draw_curves(ref,[],fullfile(figures,'curva_digitalizada'));
draw_curves(sim,[],fullfile(figures,'curva_simulada'));
draw_curves(ref,sim,fullfile(figures,'comparacion_cccv'));
end

function k=sustained(time,hit,duration)
edge=diff([false;hit(:);false]);
first=find(edge==1);
last=find(edge==-1)-1;
k=first(find(time(last)-time(first)>=duration,1));
assert(~isempty(k));
end

function draw_curves(first,second,file)
f=figure('Visible','off','Color','white','Units','centimeters', ...
    'Position',[1 1 12.2 15], 'DefaultAxesFontName','Arial', ...
    'DefaultAxesFontSize',10,'DefaultAxesXGrid','on','DefaultAxesYGrid','on');
closeFigure=onCleanup(@()close(f));
p=tiledlayout(f,3,1,'TileSpacing','compact','Padding','compact');
axesList=gobjects(3,1);
hasRef=ismember('Relative_capacity_pct',first.Properties.VariableNames);
fields={'Voltage_V','Current_A','SOC_pct'};
if hasRef, fields{3}='Relative_capacity_pct'; end
yText={'Cell voltage (V)','Charging current (A)','SOC / relative capacity (%)'};
dataLabel={'Datasheet voltage','Datasheet current','Datasheet relative capacity'};
simLabel={'Simulated voltage','Simulated current','Simulated SOC'};
bounds={[3.1 4.27],[0 1.2],[0 100]};
for k=1:3
    ax=nexttile(p);axesList(k)=ax;hold(ax,'on');
    if hasRef
        a=plot(ax,first.Time_s,first.(fields{k}),'--','Color',[0 .35 .55],'LineWidth',1.5);
        if isempty(second)
            legend(ax,a,dataLabel{k},'Location','southeast','Box','off');
        else
            other={'Voltage_V','Current_A','SOC_pct'};
            b=plot(ax,second.Time_s,second.(other{k}),'-','Color',[.71 .28 .12],'LineWidth',1.4);
            legend(ax,[a b],{dataLabel{k},simLabel{k}},'Location','southeast','Box','off');
        end
    else
        a=plot(ax,first.Time_s,first.(fields{k}),'-','Color',[.71 .28 .12],'LineWidth',1.5);
        legend(ax,a,simLabel{k},'Location','southeast','Box','off');
    end
    ylabel(ax,yText{k});
    ylim(ax,bounds{k});
    if k<3, ax.XTickLabel=[]; end
end
linkaxes(axesList,'x');
xlim(axesList(3),[0 10000]); xticks(axesList(3),0:2000:10000);
xlabel(axesList(3),'Elapsed time (s)');
exportgraphics(f,[file '.pdf'],'ContentType','vector');
exportgraphics(f,[file '.png'],'Resolution',180);
end
