function info = inspectDRModel(path)
%INSPECTDRMODEL Print stored variable names and network input metadata.
variables = whos('-file',path);
fprintf('Model file: %s\n',path);
disp(struct2table(variables));
c = drDemoConfig(); m = loadDRModel(path,c);
info = rmfield(m,'net');
fprintf('Network: %s; input: %s\n',class(m.net),mat2str(m.inputSize));
fprintf('Output DR order: %s\n',mat2str(m.classValues));
fprintf('Input normalization layer: %s\n',m.networkNormalization);
disp(info);
end
