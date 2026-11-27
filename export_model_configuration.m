function export_model_configuration(results)
% Export the active model parameters, compiled sample times and connections.
root = fileparts(mfilename('fullpath'));
previous = cd(root);
folderCleanup = onCleanup(@()cd(previous));
if nargin == 0, results = fullfile(root,'results'); end
if ~isfolder(results), mkdir(results); end
for model = ["SIMULINK_CCCV","SIMULINK_Fuzzy"]
    m = char(model);
    path = fullfile(root,model+".slx");
    if bdIsLoaded(m)
        assert(strcmpi(get_param(m,'FileName'),path), ...
            'Close the open copy of %s before exporting its configuration.',m);
    end
    load_system(path);
    set_param(m,'SimulationCommand','update');
    config = struct('Model',m,'MATLAB',version,'InstalledProducts',ver);
    fields = {'SolverType','Solver','RelTol','AbsTol','AutoScaleAbsTol', ...
        'InitialStep','MinStep','MaxStep','StopTime','ZeroCrossControl', ...
        'ZeroCrossAlgorithm','SignalLoggingName'};
    for k = 1:numel(fields)
        config.Solver.(fields{k}) = get_param(m,fields{k});
    end
    ws = get_param(m,'ModelWorkspace');
    list = whos(ws);
    for k = 1:numel(list)
        config.ModelWorkspace.(list(k).name) = getVariable(ws,list(k).name);
    end
    blocks = find_system(m,'SearchDepth',1,'LookUnderMasks','all','Type','Block');
    for k = 1:numel(blocks)
        path = blocks{k};
        entry = struct('Path',path,'Type',get_param(path,'BlockType'), ...
            'Library',get_param(path,'ReferenceBlock'),'Parameters',struct, ...
            'CompiledSampleTime',[],'Ports',[],'MatlabFunction','');
        entry.CompiledSampleTime = get_param(path,'CompiledSampleTime');
        dialog = get_param(path,'DialogParameters');
        names = {};
        if isstruct(dialog)
            names = fieldnames(dialog);
        end
        for j = 1:numel(names)
            value = get_param(path,names{j});
            if ischar(value) || isstring(value) || islogical(value) || isnumeric(value)
                entry.Parameters.(names{j}) = value;
            end
        end
        ports = get_param(path,'PortConnectivity');
        if ~isempty(ports)
            entry.Ports = repmat(struct('Type','','Source',strings(0,1), ...
                'SourcePort',[],'Destination',strings(0,1),'DestinationPort',[]),size(ports));
        end
        for j = 1:numel(ports)
            port = ports(j);
            sourcePorts = port.SrcPort;
            destinationPorts = port.DstPort;
            sources = paths(port.SrcBlock);
            destinations = paths(port.DstBlock);
            if startsWith(string(port.Type),["LConn","RConn"])
                [sources,sourcePorts] = conserving_ports(sources,sourcePorts);
                [destinations,destinationPorts] = conserving_ports(destinations,destinationPorts);
            end
            entry.Ports(j) = struct('Type',port.Type,'Source',sources, ...
                'SourcePort',sourcePorts,'Destination',destinations, ...
                'DestinationPort',destinationPorts);
        end
        config.Blocks(k) = entry;
    end
    rt = sfroot;
    for j = 1:numel(blocks)
        chart = rt.find('-isa','Stateflow.EMChart','Path',blocks{j});
        if ~isempty(chart)
            config.Blocks(j).MatlabFunction = chart.Script;
        end
    end
    filename = fullfile(results,model+"_configuration.json");
    file = fopen(filename,'w','n','UTF-8');
    assert(file>0,'Could not open the model configuration for writing.');
    cleanup = onCleanup(@()fclose(file));
    fwrite(file,jsonencode(config,'PrettyPrint',true),'char');
    clear cleanup config
end
end

function [blocks,ports] = conserving_ports(blocks,handles)
ports = strings(size(handles));
for k = 1:numel(handles)
    record = get_param(get_param(handles(k),'Parent'),'PortHandles');
    left = find(record.LConn==handles(k),1);
    if isempty(left)
        right = find(record.RConn==handles(k),1);
        assert(~isempty(right),'Unrecognized conserving connection.');
        ports(k) = "RConn"+right;
    else
        ports(k) = "LConn"+left;
    end
end
assert(numel(blocks)==numel(ports));
[~,order] = sort(blocks(:)+"/"+ports(:));
blocks = blocks(order);
ports = ports(order);
end

function result = paths(handles)
handles = handles(handles>0);
result = strings(size(handles));
for i = 1:numel(handles)
    result(i) = string(getfullname(handles(i)));
end
end
