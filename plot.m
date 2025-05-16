% Set your CSV file path here
basePath = '/home/rasmus/Downloads/34241 Digital video technology/Project/';
relativePath = 'output_dir/algo4/video__2025-04-24__15-14-57__CAMB_3s.h265__threshold=11.1055_maxcum=3*threshold/summary.csv';

csvFilePath = fullfile(basePath, relativePath);


% Read the CSV file as a table
data = readtable(csvFilePath);

% Extract descriptions and values
descriptions = data.Description;
values = data.Value;

% Convert values to numeric (in case they are strings)
if iscell(values)
    numericValues = str2double(values);
else
    numericValues = values;
end

% Plotting
figure;
bar(numericValues);
set(gca, 'XTickLabel', descriptions, 'XTick', 1:numel(descriptions));
xtickangle(45);
ylabel('Value');
title('Summary Metrics from Algo4');
grid on;
