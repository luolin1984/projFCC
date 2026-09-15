clear; clc;
rootDir = 'C:\Users\PC\Desktop\推倒重来！\工业数据集';
timeseriesDir = fullfile(rootDir, 'timeseriesdata');
outputDir = fullfile(rootDir, 'Extracted_Data_timeseries');
% 提取标签
tags = {'FIR111', 'FIR110', 'TIR101', 'TIR110'};
% 时间列设置
hasTimeCol = true;
timeColName = 'Time';
% 创建输出目录
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end
% 获取 timeseriesdata 下所有子文件夹
if ~exist(timeseriesDir, 'dir')
    error('未找到 timeseriesdata 文件夹，请检查 rootDir 设置！');
end
% 获取子文件夹列表
subDirs = dir(timeseriesDir);
subDirs = subDirs([subDirs.isdir] & ~ismember({subDirs.name}, {'.', '..'}));

fprintf('找到 %d 个子文件夹\n', length(subDirs));

% 遍历每个子文件夹
totalFiles = 0;
for i = 1:length(subDirs)
    folderName = subDirs(i).name;
    folderPath = fullfile(timeseriesDir, folderName);
    
    % 获取该文件夹下所有 CSV 文件
    csvFiles = dir(fullfile(folderPath, '*.csv'));
    fprintf('处理文件夹: %s （包含 %d 个 CSV 文件）\n', folderName, length(csvFiles));
    
    for j = 1:length(csvFiles)
        filePath = fullfile(folderPath, csvFiles(j).name);
        [~, fileName, ~] = fileparts(csvFiles(j).name);
        
        % 读取 CSV 文件
        try
            opts = detectImportOptions(filePath);
            opts.VariableNamingRule = 'preserve';   % 保留原始列名
            data = readtable(filePath, opts);
        catch ME
            warning('读取文件失败: %s\n错误信息: %s', filePath, ME.message);
            continue;
        end
        
        % 检查所需标签是否都存在
        missingTags = setdiff(tags, data.Properties.VariableNames);
        if ~isempty(missingTags)
            warning('文件 %s 缺少标签: %s，跳过', fileName, strjoin(missingTags, ', '));
            continue;
        end
        
        % 提取所需列
        extracted = data(:, tags);
        
        % 处理时间列
        if hasTimeCol && any(strcmp(data.Properties.VariableNames, timeColName))
            timeVec = data.(timeColName);
            % 如果时间列是 datetime 类型，转换为相对秒数
            if isdatetime(timeVec)
                timeVec = seconds(timeVec - timeVec(1));
            else
                % 如果是数值，假设已经是秒数
                timeVec = double(timeVec);
            end
            % 确保时间从0开始
            if ~isempty(timeVec) && timeVec(1) ~= 0
                timeVec = timeVec - timeVec(1);
            end
            extracted = [table(timeVec, 'VariableNames', {'Time'}), extracted];
        else
            % 没有时间列，自动生成等间隔时间（假设采样间隔 1 秒）
            nRows = height(extracted);
            timeVec = (0:nRows-1)';
            extracted = [table(timeVec, 'VariableNames', {'Time'}), extracted];
            warning('文件 %s 没有时间列，自动生成时间向量（步长1秒）', fileName);
        end
        
        % 保存 .mat 文件到输出目录
        saveFolder = fullfile(outputDir, folderName);
        if ~exist(saveFolder, 'dir')
            mkdir(saveFolder);
        end
        saveFile = fullfile(saveFolder, [fileName, '_extracted.mat']);
        save(saveFile, 'extracted');
        
        totalFiles = totalFiles + 1;
        fprintf('  已提取: %s\n', saveFile);
    end
end

fprintf('\n===== 提取完成 =====\n');
fprintf('共处理 %d 个 CSV 文件，提取结果保存在: %s\n', totalFiles, outputDir);