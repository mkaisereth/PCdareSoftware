close all, clear all, clc;

basePath = "./Data/Adams";
basePath = "./Data/Forward";
plyFilter = '/Photoneo2*.ply';

loadLastFile = true;
drawOnly = false;

addpath("../XrayRegistration/"); % TODO

dirList = dir(basePath);
totalNum = size(dirList,1)-2;
inc=0;
startTime = now;
for i=3:size(dirList,1)
    close all;
    subjectPath = append(dirList(i).folder, '/', dirList(i).name);
    subjectName = dirList(i).name;
    
    inc = inc+1;
    if inc > 1
        eta = ((now-startTime)/(inc-1)*(totalNum-inc))*24*60;
    else
        eta = 0;
    end
    disp(inc + "/" + totalNum + " eta: " + round(eta,1) + " min");
    
    if ~isfolder(subjectPath) || strcmp(subjectName, "Output")
        continue;
    end

    outputPath = append(subjectPath, "/Output");

    % get file names
    pcPath = dir(append(subjectPath, '/', plyFilter));
    pcPath = append(pcPath(1).folder, "/", pcPath(1).name);

    global pcMarkers;
    if loadLastFile


        % load information from files only
        markerFiles = dir(append(outputPath,'/',subjectName,'*PcLinePts*.json'));% TODO handle if multiple
        markerFiles = dir(append(outputPath,'/*PcLinePts*.json'));% TODO handle if multiple
        % use last one
        markerFile = markerFiles(size(markerFiles, 1));
        filetext = fileread(append(markerFile.folder, "/", markerFile.name));
        jsonObject = jsondecode(filetext);
        if jsonObject.subjectName ~= subjectName
            disp('Warning: this data does not belong to this subject!')
        end
        % transpose, because after reading json it's opposite
        pcLinePtInds = jsonObject.pcLinePtInds';
        pcLinePts = jsonObject.pcLinePts;
        % read pc
        pc = ReadPc(pcPath);
        pcLinePtInds = knnsearch(pc.Location*1000, pcLinePts);
        pcLinePtInds = unique(pcLinePtInds, 'stable');
    else
        % ask user to draw markers and lines
        [pc, fig3, pcLinePtInds] = PcMarkerApp(pcPath, 0, true);
    
        % save the markers to file
        if ~exist(outputPath, "dir")
            mkdir(outputPath);
        end
        jsonObject.subjectName = subjectName;
        if isfield(pcMarkers, 'H')
            pcMarkers = rmfield(pcMarkers, 'H');
        end
        jsonObject.pcMarkers = pcMarkers;
        jsonObject.pcLinePtInds = pcLinePtInds;
    
        jsonString = jsonencode(jsonObject);
        fid=fopen(append(outputPath, "/", subjectName, "_Markers_", datestr(now,'yyyymmdd_HHMMSSFFF'), ".json"), 'w');
        fprintf(fid, jsonString);
        fclose(fid);
    
        waitfor(fig3);
    end
    
    if drawOnly
        continue;
    end

    figure;
    pcshow(pc);
    hold on;
    % show the external line
    % fit polynomial for external line
    pcLinePts = pc.Location(pcLinePtInds, :);
    t = 1:length(pcLinePtInds); % Assumed time stamp
    px = polyfit(t,pcLinePts(:,1),3);
    xx = polyval(px,t);
    py = polyfit(t,pcLinePts(:,2),1);
    yy = polyval(py,t);
    pz = polyfit(t,pcLinePts(:,3),6);
    zz = polyval(pz,t);
    pcPolyLinePts = [xx',yy',zz'];
    pcshow(pcLinePts, 'y', 'MarkerSize', 12);
    pcshow(pcPolyLinePts, 'c', 'MarkerSize', 12);

    nowString = datestr(now,'yyyymmdd_HHMMSSFFF');
    % save lines
    jsonObject.subjectName = subjectName;
    jsonObject.eslLinePts = pcPolyLinePts;
    jsonString = jsonencode(jsonObject);
    fid=fopen(append(outputPath, "/", subjectName, "_Markers2_", nowString, ".json"), 'w');
    fprintf(fid, jsonString);
    fclose(fid);

    disp(subjectName + " done");
end