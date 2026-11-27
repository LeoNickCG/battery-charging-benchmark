function write_output_variant(nominalFile,variantFile,upperCurrent)
% Keep the input partitions and rules, and affinely rescale the output.
fis = readfis(nominalFile);
nominal = fis;
lo = fis.Outputs.Range(1);
hi = fis.Outputs.Range(2);
assert(isscalar(upperCurrent) && lo < upperCurrent && upperCurrent < hi, ...
    'The variant upper bound must be inside the nominal output range.');
scale = (upperCurrent-lo)/(hi-lo);
fis.Outputs.Range = [lo upperCurrent];
for k = 1:numel(fis.Outputs.MembershipFunctions)
    original = nominal.Outputs.MembershipFunctions(k).Parameters;
    fis.Outputs.MembershipFunctions(k).Parameters = lo+scale*(original-lo);
end
[~,name] = fileparts(variantFile);
fis.Name = string(name);
writeFIS(fis,variantFile);

% Check the saved FIS and its centroid mapping before using it in Simulink.
saved = readfis(variantFile);
for k = 1:numel(nominal.Inputs)
    before = nominal.Inputs(k);
    after = saved.Inputs(k);
    assert(strcmp(before.Name,after.Name) && isequal(before.Range,after.Range));
    assert(isequal({before.MembershipFunctions.Name},{after.MembershipFunctions.Name}) && ...
        isequal({before.MembershipFunctions.Type},{after.MembershipFunctions.Type}) && ...
        isequal({before.MembershipFunctions.Parameters},{after.MembershipFunctions.Parameters}), ...
        'The saved variant changed an input membership function.');
end
for property = ["Antecedent","Consequent","Weight","Connection"]
    assert(isequal({nominal.Rules.(property)},{saved.Rules.(property)}), ...
        'The saved variant changed a rule.');
end
assert(isequal(saved.Outputs.Range,[lo upperCurrent]), ...
    'The saved variant has an unexpected output universe.');
[vb,vd] = ndgrid(linspace(3.08,4.30,13),linspace(0,1.22,13));
inputs = [vb(:) vd(:)];
options = evalfisOptions('NumSamplePoints',101);
expected = lo+scale*(evalfis(nominal,inputs,options)-lo);
assert(max(abs(evalfis(saved,inputs,options)-expected))<1e-8, ...
    'The saved variant does not preserve the affine centroid mapping.');
end
