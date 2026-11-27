function result = simular_cccv
% Run the saved model and export its To Workspace signals.
root = fileparts(mfilename('fullpath'));
m = 'CCCV_ICR18650';
load_system(fullfile(root,[m '.slx']));
result = sim(Simulink.SimulationInput(m));
voltage = result.get('cell_voltage_V');
soc = result.get('cell_soc_pct');
current = result.get('charge_current_A');
cv = result.get('cv_state');
temp = result.get('temperature_C');
t = (0:10000)';
assert(result.tout(end)==10000 && voltage.Time(end)==10000);
v = sampled(voltage,t,'previous');
s = sampled(soc,t,'previous');
i = sampled(current,t,'previous');
c = sampled(cv,t,'previous')>.5;
temperature = sampled(temp,t,'linear');
assert(all(s(1,:)==0) && all(abs(s-s(:,1))<1e-7,'all'));
trace = table(t,t/60,v(:,1),i,s(:,1),c,temperature, ...
    'VariableNames',{'Time_s','Time_min','Voltage_V','Current_A','SOC_pct','CV','Temperature_C'});
data=fullfile(root,'datos');
if ~isfolder(data), mkdir(data); end
writetable(trace,fullfile(data,'simulacion_cccv.csv'));
fprintf('End %.0f s / CV %.0f s / SOC at end %.4f %%\n', t(end),t(find(c,1)),s(end,1));
end

function out = sampled(v,t,method)
[time,k] = unique(v.Time,'last');
out = interp1(time,double(v.Data(k,:)),t,method);
assert(all(isfinite(out),'all'));
end
