% Path to the CSV directory
clear all;
close all;
basePath = '/home/rasmus/Downloads/34241 Digital video technology/Project/';
csvDir = fullfile(basePath, 'output_dir', 'algo4', 'csv_output_dir');

csvFiles = dir(fullfile(csvDir, '*.csv'));

numFiles = length(csvFiles);

sum_normal_TI = zeros(numFiles,1);
sum_cumsum_TI = zeros(numFiles,1);
videoNames = strings(numFiles,1);

for k = 1:numFiles
    csvPath = fullfile(csvDir, csvFiles(k).name);
    
    % Read CSV - specify options to be sure of the format
    opts = detectImportOptions(csvPath);
    opts.VariableNamesLine = 1; % assume first line is header
    T = readtable(csvPath, opts);
    
    % Display first few rows to check what's read
    disp(['File: ', csvFiles(k).name]);
    %disp(head(T,5));
    disp(T)
    
    % Convert all descriptions and values to strings (trim spaces)
    descriptions = strtrim(string(T{:,1}));
    values_raw = string(T{:,2});
    
    % Convert values to numeric safely (remove commas or spaces)
    values_num = str2double(erase(values_raw, ','));
    
    % Define a helper function to find value by partial match
    getVal = @(desc) values_num(contains(descriptions, desc, 'IgnoreCase', true));
    
    maxTI_L = getVal('Frames kept due to normal TI threshold (Left)');
    maxTI_R = getVal('Frames kept due to normal TI threshold (Right)');
    maxTI_both = getVal('Frames kept due to both normal TI threshold exceeded');
    cumsum_both = getVal('Frames kept due to both cumsum TI threshold exceeded');
    cumsum_L = getVal('Frames kept due to cumulative TI threshold (Left)');
    cumsum_R = getVal('Frames kept due to cumulative TI threshold (Right)');
    
    sum_normal_TI(k) = maxTI_L + maxTI_R + maxTI_both;
    sum_cumsum_TI(k) = cumsum_both + cumsum_L + cumsum_R;
    
    [~,name,~] = fileparts(csvFiles(k).name);
    videoNames(k) = strrep(extractAfter(name, 11), '_', ' ');
end

disp('Sum of max TI triggers per video:');
disp(table(videoNames, sum_normal_TI));

disp('Sum of cumulative TI triggers per video:');
disp(table(videoNames, sum_cumsum_TI));
% Plotting
% Plotting - nicer academic style
figure('Color', 'w', 'Position', [100 100 900 500]);

% Bar plot with grouped bars
b = bar([sum_normal_TI, sum_cumsum_TI], 'BarWidth', 0.7);

% Set colors (can customize these)
b(1).FaceColor = [0.2 0.6 0.8];   % bluish
b(2).FaceColor = [0.9 0.4 0.3];   % reddish

% Labels and title
ylabel('Number of Frames', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('Video Name', 'FontSize', 12, 'FontWeight', 'bold');
title('Comparison of TI Triggers Across Videos', 'FontSize', 14, 'FontWeight', 'bold');

% X-axis labels and rotation
xticks(1:numFiles);
xticklabels(videoNames);
xtickangle(45);

% Grid and box off
grid on;
ax = gca;
ax.GridColor = [0.8 0.8 0.8];
ax.GridAlpha = 0.5;
ax.Box = 'off';

% Legend with marker shapes
legend({'Max TI triggers', 'Cumulative TI triggers'}, 'Location', 'best');

% Increase font size of axes ticks
ax.FontSize = 11;
ax.FontWeight = 'normal';

% Add a vertical dotted line to split the groups between 4 and 5
hold on;
xline(4.5, '--k', 'LineWidth', 1.5, 'HandleVisibility','off');
hold off;

