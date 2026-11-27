function preparar_cccv
% Project copy dedicated to the 1.1 A reference profile.
root = fileparts(mfilename('fullpath'));
m = 'CCCV_ICR18650';
load_system(fullfile(root,[m '.slx']));
ws = get_param(m,'ModelWorkspace');
assignin(ws,'SOC0',zeros(1,4));
assignin(ws,'Ilimit',1.1);
assignin(ws,'StopAtVoltage',false);
assignin(ws,'SOCstop',Inf);
set_param(m,'StopTime','10000','ReturnWorkspaceOutputs','on','SaveTime','on','SaveOutput','off');
assert(isempty(find_system(m,'SearchDepth',1,'BlockType','ToFile')));
signals = {
    'Cell voltages',1,'Voltage export','cell_voltage_V'
    'Cell SOC',1,'SOC export','cell_soc_pct'
    'Current Measurement',1,'Current export','charge_current_A'
    'MATLAB Function',2,'CV state export','cv_state'
    'Integrator',1,'Temperature export','temperature_C'
};
for k=1:size(signals,1)
    [source,port,label,var] = signals{k,:};
    dest = [m '/' label];
    if getSimulinkBlockHandle(dest)==-1
        y = 40+65*k;
        add_block('simulink/Sinks/To Workspace',dest,'Position',[1850 y 1990 y+30], ...
            'VariableName',var,'SaveFormat','Timeseries','MaxDataPoints','inf');
        a = get_param([m '/' source],'PortHandles');
        b = get_param(dest,'PortHandles');
        add_line(m,a.Outport(port),b.Inport(1),'autorouting','on');
    end
end
save_system(m);
end
