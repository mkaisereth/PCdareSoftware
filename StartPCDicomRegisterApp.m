close all, clear all, clc;
all_fig = findall(0, 'type', 'figure');
close(all_fig)
addpath("XrayRegistration");

% offset to last dataset (meaning 0 ist last, 1 is second last, ...)
evalDataSet = 0;

% IRCCS
%basePath = "IRCCS"
% UKBB
%basePath = "UKBB"
% Balgrist
basePath = "Balgrist";

%dataset = "IRCCS";
%dataset = "UKBB";
dataset = "Balgrist";

% whether to use the image contrast tool to change constrast in X-ray images
useImcontrast = true;
global automaticMarkerOptimization;
automaticMarkerOptimization = 1;
% whether to zoom xray according to Markers
global useMarkerZoom;
useMarkerZoom = true;

% select pc name filter
switch dataset
    case "IRCCS"
        pcNameFilter = 'average_arms_flexed_noarms2.ply';
        pcNameFilter2 = 'average_arms_relaxed_noarms2.ply';
        markerFileName = '_Markers_Formetric_flexed_noarms2';
        markerFileName2 = '_Markers_Formetric_relaxed_noarms2';
    case "UKBB"
        pcPathFilter = "";
    case "Balgrist"
        % cut version
        pcNameFilter = 'Photoneo_1234*_cut.ply';
    otherwise
end

% number of markers to select and use for registration
numOfMarkers = 4;
% whether to load the results from last files
loadLastDcmFile = true;
loadLastPcFile = true;
% whether to only draw, or also to evaluate (takes longer)
drawOnly = false;
% whether to evaluate the ESL alignment
doESLAlignmentEval = true;
% whether to evaluate the Marker registration error
doMarkerRegistrationErrorEval = true;

% 0.5, 1, 2, 3, 4 % the higher, more plots
printLevel = 1;

% whether to use smoothing spline of polynomial fit
useSmoothingSpline = true;
SmoothingSplineParam = 0.0001;

% whether to inject markers into pointcloud
useMarkerInjection = false;

dicomImageLineThreshold1 = 30;
pcImageLineThreshold1 = 30;
dicomImageLineThreshold2 = 10;
pcImageLineThreshold2 = 10;

%% program start

latDiffsTs = [];
latDiffsTMedians = [];
latDiffsTIqrs = [];
latDiffsTMeans = [];
latDiffsTStds = [];
apDiffsTMedians = [];
apDiffsTStds = [];
markerDistRmses = [];
markerDistSds = [];

dirList = dir(basePath);
patientFolders = 3:size(dirList,1);
patientFolderNames = [];
for i= patientFolders
    if dirList(i).isdir
        patientFolderNames = [patientFolderNames, string(dirList(i).name)];
    end
end

totalNum = length(patientFolderNames);
inc=0;
startTime = now;

for i=patientFolderNames
    close all;
    subjectPath = append(dirList(1).folder, '\', i);
    subjectName = i;
    
    inc = inc+1;
    if inc > 1
        eta = ((now-startTime)/(inc-1)*(totalNum-inc))*24*60;
    else
        eta = 0;
    end
    disp(inc + "/" + totalNum + " eta: " + round(eta,1) + " min");
    
    if ~isfolder(subjectPath) || subjectName == "Output"
        continue;
    end

    outputPath = append(subjectPath, "\Output");

    % get file names
    if dataset == "IRCCS"
        apDcmPath = append(subjectPath, '\', 'Frontal.dcm');
        latDcmPath = append(subjectPath, '\', 'Lateral.dcm');
        pcPath = append(subjectPath, '\', pcNameFilter);
        if ~exist(pcPath, "file")
            pcPath = append(subjectPath, '\', pcNameFilter2);
        end
    elseif dataset == "Balgrist"
        pcPathFilter = dir(append(subjectPath, '\ID*_ap_anon2.dcm'));
        apDcmPath = append(pcPathFilter(1).folder, "\", pcPathFilter(1).name);
        pcPathFilter = dir(append(subjectPath, '\ID*_lat_anon2.dcm'));
        latDcmPath = append(pcPathFilter(1).folder, "\", pcPathFilter(1).name);
        pcPathFilter = dir(append(subjectPath, '\', pcNameFilter));
        pcPath = append(pcPathFilter(1).folder, "\", pcPathFilter(1).name);
    elseif dataset == "UKBB"
        apDcmPath = append(subjectPath, '\', subjectName, '_ap.dcm');
        latDcmPath = append(subjectPath, '\', subjectName, '_lat.dcm');
        pcPathFilter = dir(append(subjectPath, '\*_cut.ply'));
        pcPath = append(pcPathFilter(1).folder, "\", pcPathFilter(1).name);
    else
        apDcmPath = append(subjectPath, '\', subjectName, '_ap.dcm');
        latDcmPath = append(subjectPath, '\', subjectName, '_lat.dcm');
        pcPath = append(subjectPath, '\', subjectName, '.stl');
    end
    global pcMarkers;
    doWaitForFigures1 = false;
    doWaitForFigures3 = false;
    if loadLastDcmFile
        % load information from files only
        markerFiles = dir(append(outputPath,'\',subjectName,'_Markers_*.json'));
        % use last one
        evalDataSetInd = size(markerFiles, 1)-evalDataSet;
        markerFile = markerFiles(evalDataSetInd);
        filetext = fileread(append(markerFile.folder, "\", markerFile.name));
        jsonObject = jsondecode(filetext);
        if jsonObject.subjectName ~= subjectName
            disp('Warning: this data does not belong to this subject!')
        end
        % transpose, because after reading json it's opposite
        if isfield(jsonObject.apDcmMarkers, 'Pixel')
            apDcmMarkers = TransposeJsonStruct(jsonObject.apDcmMarkers, true);
            latDcmMarkers = TransposeJsonStruct(jsonObject.latDcmMarkers, true);
        end
        if ~isfield(jsonObject.apLinePts, 'Pixel')
            disp(append('Warning: MarkerFile: ', markerFile.name, " has no apLinePts!"))
            continue;
        end
        apLinePts = TransposeJsonStruct(jsonObject.apLinePts, true);
        if ~isfield(jsonObject.latLinePts, 'Pixel')
            disp(append('Warning: MarkerFile: ', markerFile.name, " has no latLinePts!"))
            continue;
        end
        latLinePts = TransposeJsonStruct(jsonObject.latLinePts, true);

        % read dicom image information
        [apImgInfo, latImgInfo] = ReadDicomInformation(apDcmPath, latDcmPath);

        % draw them
        if printLevel > 0
            f277 = figure;
            apImg = apImgInfo.Image;
            latImg = latImgInfo.Image;
            apImgResY = apImgInfo.ResY;
            apImgResX = apImgInfo.ResX;
            latImgResY = latImgInfo.ResY;
            latImgResX = latImgInfo.ResX;
            if size(apImg,1) ~= size(latImg,1)
                f = msgbox("Warning: Cutting Dicom at bottom, size does not match!");
                waitfor(f);
                minX = min(size(apImg,1), size(latImg,1));
                apImg(minX+1:end,:,:) = [];
                latImg(minX+1:end,:,:) = [];
            end
            overallImg = [apImg, latImg];
            imshow(overallImg, [], 'Border','tight');
            hold on;
            if exist('apDcmMarkers','var')
                for j=1:numOfMarkers
                    rectangle('Position',[apDcmMarkers(j).Pixel(1)-15,apDcmMarkers(j).Pixel(2)-15,30,30], 'FaceColor','g', 'LineStyle','none');
                end
            end
            for j=1:length(apLinePts)
                rectangle('Position',[apLinePts(j).Pixel(1)-10,apLinePts(j).Pixel(2)-10,20,20], 'FaceColor','r', 'LineStyle','none');
            end
   
            latOffsetX = size(apImg,2);
            doAbort=false;
            if exist('latDcmMarkers','var')
                for j=1:numOfMarkers
                    if j>length(latDcmMarkers) || isempty(latDcmMarkers(j).Pixel)
                        disp(append('Warning: MarkerFile: ', markerFile.name, " has no latDcmMarkers!"))
                        doAbort = true;
                        break;
                    end
                    rectangle('Position',[latDcmMarkers(j).Pixel(1)-15+latOffsetX,latDcmMarkers(j).Pixel(2)-15,30,30], 'FaceColor','g', 'LineStyle','none');
                end
            end
            if doAbort
                continue;
            end
            for j=1:length(latLinePts)
                rectangle('Position',[latLinePts(j).Pixel(1)-10+latOffsetX,latLinePts(j).Pixel(2)-10,20,20], 'FaceColor','r', 'LineStyle','none');
            end

            % draw hlines if any
            if isfield(jsonObject, 'hPoints')
                hPoints = jsonObject.hPoints;
                for j=1:length(hPoints)
                    % can be ap or lat, ust draw both
                    rectangle('Position',[hPoints(j).Pixel(1)-10,hPoints(j).Pixel(2)-10,20,20], 'FaceColor','g', 'LineStyle','none');
                    rectangle('Position',[hPoints(j).Pixel(1)-10+latOffsetX,hPoints(j).Pixel(2)-10,20,20], 'FaceColor','g', 'LineStyle','none');
                end
            end

            drawnow();
        end
    else
        % ask user to draw markers and lines
        [apDcmMarkers,apImgInfo,latDcmMarkers,latImgInfo, fig1, apLinePts, latLinePts, hPoints] = DicomMarkerApp(apDcmPath, latDcmPath, numOfMarkers, dataset, useImcontrast);
        doWaitForFigures1 = true;
    end
    if loadLastPcFile
        % load information from files only
        markerFiles = dir(append(outputPath,'\',subjectName,'_Markers_*.json'));
        % use last one
        evalDataSetInd = size(markerFiles, 1)-evalDataSet;
        markerFile = markerFiles(evalDataSetInd);
        filetext = fileread(append(markerFile.folder, "\", markerFile.name));
        jsonObject = jsondecode(filetext);
        if jsonObject.subjectName ~= subjectName
            disp('Warning: this data does not belong to this subject!')
        end
        
        % transpose, because after reading json it's opposite
        pcMarkers = TransposeJsonStruct(jsonObject.pcMarkers, false);
        % transform markers from mm to m (software works in m, saved in mm)
        % check whether it really is mm (old version was m)
        if max([pcMarkers.World])>10 % if it is m no way we have 10m => must be mm
            for pmi=1:length(pcMarkers)
                pcMarkers(pmi).World = pcMarkers(pmi).World/1000;
            end
        end
        pcLinePtInds = jsonObject.pcLinePtInds';
        % read pc
        origPc = ReadPc(pcPath);

        % check whether add missing information (Version 2.0)
        if ~isfield(jsonObject, 'pcLinePts')
            pcLinePts = origPc.Location(pcLinePtInds, :);
            jsonObject.pcLinePts = pcLinePts*1000;
            jsonString = jsonencode(jsonObject);
            fid=fopen(append(markerFile.folder, "\", markerFile.name), 'w');
            fprintf(fid, jsonString);
            fclose(fid);
        else
            pcLinePts = jsonObject.pcLinePts/1000;
            % find nearest neighbor
            [Idx, D] = knnsearch(origPc.Location, pcLinePts);
            if max(D)>0.002
                disp("Warning: nearest neighbor to pcLinePtInd larger than 2mm");
                %keyboard;
            end
            pcLinePtInds = Idx';
        end
        if useMarkerInjection
            % inject markers into point cloud and save
            pcLoc = origPc.Location;
            pcCols = origPc.Color;
            if isempty(pcCols)
                pcCols = uint8(zeros(size(pcLoc)));
            end
            pcLoc = [pcLoc; pcLinePts];
            pcLineCols = repmat([255 0 0],length(pcLinePts), 1);
            pcCols = [pcCols; pcLineCols];
            for pmi=1:length(pcMarkers)
                pcLoc = [pcLoc;pcMarkers(pmi).World];
                pcCols = [pcCols; [0 255 0]];
            end
            pcwrite(pointCloud(pcLoc,"Color",pcCols), replace(pcPath, ".ply", "_wMarkers.ply"), "Encoding","binary");
        end

        pc = origPc;
        if dataset == "IRCCS"
            pcLoc = pc.Location*1000; % m to mm
            %pcLoc(:,3) = pcLoc(:,3)-1000;
            pc = pointCloud(pcLoc);
            origPc = pc;
            %pcLinePts = origPc.Location(pcLinePtInds, :);
            if max(pcLinePts(:,3)<10)
                pcLinePts = pcLinePts*1000;
            end
            for pmi=1:length(pcMarkers)
                if pcMarkers(pmi).World(3)<10
                    pcMarkers(pmi).World = pcMarkers(pmi).World*1000;
                end                %pcMarkers(pmi).World(:,3) = pcMarkers(pmi).World(:,3)-1000;
            end
        elseif dataset == "Balgrist"
            pcLoc = pc.Location*1000; % m to mm
            pc = pointCloud(pcLoc, "Color", pc.Color);
            origPc = pc;
            pcLinePts = origPc.Location(pcLinePtInds, :);
            pc = pcdownsample(pc, "gridAverage", 1);
            for pmi=1:length(pcMarkers)
                if pcMarkers(pmi).World(3)<10
                    pcMarkers(pmi).World = pcMarkers(pmi).World*1000;
                end
            end
        elseif dataset == "UKBB"
            pcLoc = pc.Location*1000; % m to mm
            pc = pointCloud(pcLoc, "Color", pc.Color);
            origPc = pc;
            pcLinePts = origPc.Location(pcLinePtInds, :);
            pc = pcdownsample(pc, "gridAverage", 2);
            for pmi=1:length(pcMarkers)
                pcMarkers(pmi).World = pcMarkers(pmi).World*1000;
            end
        end

        % draw them
        if printLevel > 0
            f547 = figure;
            pcshow(pc, 'MarkerSize', 28);
            hold on;
            for pmi=1:length(pcMarkers)
                pcshow(pcMarkers(pmi).World+[0,0,-10], 'g', 'MarkerSize', 64);
            end
            pcshow(pcLinePts+[0 0 -10], 'r', 'MarkerSize', 32);
            view(0,-90)
            axis off;
            set(gcf,'Color','w')
            drawnow();
        end
    else
        if dataset == "IRCCS"
            addpath("IRCCS");
            [pc, fig3, pcLinePtInds, pcLinePts] = PcFormetricMarkers2(subjectPath, subjectName, pcPath, markerFileName, markerFileName2);
            pcLinePts = pcLinePts*1000;
            pcLoc = pc.Location*1000; % m to mm
            pc = pointCloud(pcLoc);
            origPc = pc;
            for pmi=1:length(pcMarkers)
                pcMarkers(pmi).World = pcMarkers(pmi).World*1000;
            end
        else
            markerSize = [];
            [pc, fig3, pcLinePtInds] = PcMarkerApp(pcPath, numOfMarkers, dataset == "Balgrist", markerSize);
            if dataset == "Balgrist" || dataset == "UKBB"
                pcLoc = pc.Location*1000; % m to mm
                pc = pointCloud(pcLoc, "Color", pc.Color);
                origPc = pc;
                for pmi=1:length(pcMarkers)
                    pcMarkers(pmi).World = pcMarkers(pmi).World*1000;
                end
            end
        end

        %doWaitForFigures3 = true;
    end
    % save if something changed
    if ~loadLastDcmFile || ~loadLastPcFile
        % save the markers to file
        if ~exist(outputPath, "dir")
            mkdir(outputPath);
        end
        jsonObject.subjectName = subjectName;
        jsonObject.apDcmMarkers = apDcmMarkers;
        jsonObject.latDcmMarkers = latDcmMarkers;
        jsonObject.apLinePts = apLinePts;
        jsonObject.latLinePts = latLinePts;
        if exist('hPoints', 'var')
            jsonObject.hPoints = hPoints;
        end
        if isfield(pcMarkers, 'H')
            pcMarkers = rmfield(pcMarkers, 'H');
        end
        jsonObject.pcMarkers = pcMarkers;
        jsonObject.pcLinePtInds = pcLinePtInds;
        if dataset ~= "IRCCS"
            pcLinePts = origPc.Location(pcLinePtInds, :);
        end
        jsonObject.pcLinePts = pcLinePts;
    
        jsonString = jsonencode(jsonObject);
        fid=fopen(append(outputPath, "\", subjectName, "_Markers_", datestr(now,'yyyymmdd_HHMMSSFFF'), ".json"), 'w');
        fprintf(fid, jsonString);
        fclose(fid);
    end
    
    if doWaitForFigures1
        waitfor(fig1);
    end
    if doWaitForFigures3
        waitfor(fig3);
    end
    if drawOnly
        continue;
    end

    %% do the registration TODO for now just Marker 1
    apDx = apDcmMarkers(1).World(1)-pcMarkers(1).World(1);
    apDy = apDcmMarkers(1).World(2)-pcMarkers(1).World(2);
    apDz = pcMarkers(1).World(3)-100;
    latDx = latDcmMarkers(1).World(1)+300;
    latDy = latDcmMarkers(1).World(2)-pcMarkers(1).World(2);
    latDz = latDcmMarkers(1).World(3)-pcMarkers(1).World(3);
    
    % different approach for sanity check use marker 1 and 2 for y size and use
    % this everywhere
    apDcmDeltaY12 = (apDcmMarkers(1).World(2)-apDcmMarkers(2).World(2))/(pcMarkers(1).World(2)-pcMarkers(2).World(2));
    apDcmDeltaX34 = (apDcmMarkers(3).World(1)-apDcmMarkers(4).World(1))/(pcMarkers(3).World(1)-pcMarkers(4).World(1));
    latDcmDeltaY12 = (latDcmMarkers(1).World(2)-latDcmMarkers(2).World(2))/(pcMarkers(1).World(2)-pcMarkers(2).World(2));
    latDcmDeltaX34 = (latDcmMarkers(3).World(3)-latDcmMarkers(4).World(3))/(pcMarkers(3).World(3)-pcMarkers(4).World(3));
    % Ideally this should be 1 (if EOS properly calibrated ...)
    avgDeltaXY = 1;%mean([apDcmDeltaY12, apDcmDeltaX34, latDcmDeltaY12, latDcmDeltaX34]);
    apDeltaXAvg = avgDeltaXY;
    apDeltaYAvg = avgDeltaXY;
    latDeltaYAvg = avgDeltaXY;
    latDeltaZAvg = avgDeltaXY;
    % correct markers
    apCorrectedDcmMarkers{1} = apDcmMarkers(1);
    latCorrectedDcmMarkers{1} = latDcmMarkers(1);
    for ni=2:numOfMarkers
        %ap
        tempMarker = apDcmMarkers(ni);
        tempX = (apDcmMarkers(ni).World(1)-apDcmMarkers(1).World(1))/apDeltaXAvg+apDcmMarkers(1).World(1);
        tempY = (apDcmMarkers(ni).World(2)-apDcmMarkers(1).World(2))/apDeltaYAvg+apDcmMarkers(1).World(2);
        tempMarker.World = [tempX,tempY,tempMarker.World(3)];
        apCorrectedDcmMarkers{ni} = tempMarker;
        %lat
        tempMarker = latDcmMarkers(ni);
        tempY = (latDcmMarkers(ni).World(2)-latDcmMarkers(1).World(2))/latDeltaYAvg+latDcmMarkers(1).World(2);
        tempZ = (latDcmMarkers(ni).World(3)-latDcmMarkers(1).World(3))/latDeltaZAvg+latDcmMarkers(1).World(3);
        tempMarker.World = [tempMarker.World(1),tempY,tempZ];
        latCorrectedDcmMarkers{ni} = tempMarker;
    end
    % correct dcm lines
    % ap
    apCorrectedDcmLine = {};
    for ni=1:size(apLinePts,2)
        tempPt = apLinePts(ni);
        tempX = (apLinePts(ni).World(1)-apDcmMarkers(1).World(1))/apDeltaXAvg+apDcmMarkers(1).World(1);
        tempY = (apLinePts(ni).World(2)-apDcmMarkers(1).World(2))/apDeltaYAvg+apDcmMarkers(1).World(2);
        tempPt.World = [tempX,tempY,tempPt.World(3)];
        apCorrectedDcmLine{ni} = tempPt;
    end
    % lat
    latCorrectedDcmLine = {};
    for ni=1:size(latLinePts,2)
        tempPt = latLinePts(ni);
        tempY = (latLinePts(ni).World(2)-latDcmMarkers(1).World(2))/latDeltaYAvg+latDcmMarkers(1).World(2);
        tempZ = (latLinePts(ni).World(3)-latDcmMarkers(1).World(3))/latDeltaZAvg+latDcmMarkers(1).World(3);
        tempPt.World = [tempPt.World(1),tempY,tempZ];
        latCorrectedDcmLine{ni} = tempPt;
    end
    
    % show the markers
    if dataset ~= "IRCCS"
        pcLinePts = origPc.Location(pcLinePtInds, :);
    end
    if printLevel > 1
        figure;
        pcshow(pc);
        hold on;
        % show the external line
        pcshow(pcLinePts, 'c', 'MarkerSize', 12);
        % show the markers
        for ni=1:numOfMarkers
            pcshow(pcMarkers(ni).World, 'r', 'MarkerSize', 128); % TODO
            pcshow([apCorrectedDcmMarkers{ni}.World(1) - apDx,apCorrectedDcmMarkers{ni}.World(2)-apDy,apDz], 'b', 'MarkerSize', 128); % TODO
            pcshow([latDx,latCorrectedDcmMarkers{ni}.World(2)-latDy,latCorrectedDcmMarkers{ni}.World(3)-latDz], 'b', 'MarkerSize', 128); % TODO
        end
        % show the dcm lines
        % ap
        for ni=1:size(apCorrectedDcmLine,2)
            pcshow([apCorrectedDcmLine{ni}.World(1) - apDx,apCorrectedDcmLine{ni}.World(2)-apDy,apDz], 'c', 'MarkerSize', 64); % TODO
        end
        % lat
        for ni=1:size(latCorrectedDcmLine,2)
            pcshow([latDx,latCorrectedDcmLine{ni}.World(2)-latDy,latCorrectedDcmLine{ni}.World(3)-latDz], 'c', 'MarkerSize', 64); % TODO
        end
    end

    % calculate intersections
    apIntersects = [];
    pcMarkersMat = [];
    for markerInd=1:numOfMarkers
        apMarker1 = apCorrectedDcmMarkers{markerInd}.World - [apDx,apDy,0];
        apMarker1(3) = apDz;
        latMarker1 = latCorrectedDcmMarkers{markerInd}.World - [0,latDy,latDz];
        latMarker1(1) = latDx;
        apIntersect = [apMarker1(1), mean([apMarker1(2),latMarker1(2)]), latMarker1(3)];
        apIntersects(markerInd, :) = apIntersect;
        pcMarkersMat(markerInd, :) = pcMarkers(markerInd).World;
    end

    % show the dicom images
    if printLevel > 0
        downSample = 4;
        %ap
        apImg = apImgInfo.Image;
        apImgResX = apImgInfo.ResX;
        apImgResY = apImgInfo.ResY;
        imgRows = size(apImg,1);
        imgCols = size(apImg,2);
        apImgColors = nan(floor(imgRows/downSample)*floor(imgCols/downSample), 3);
        apPcLoc = nan(floor(imgRows/downSample)*floor(imgCols/downSample), 3);
        counter=1;
        for xi=1:downSample:size(apImg,2)
            for yi=1:downSample:size(apImg,1)
                tempX = ((apImgResX*-xi)-apDcmMarkers(1).World(1))/apDeltaXAvg+apDcmMarkers(1).World(1);
                tempY = ((apImgResY*yi)-apDcmMarkers(1).World(2))/apDeltaYAvg+apDcmMarkers(1).World(2);
                apPcLoc(counter,:) = [tempX-apDx,tempY-apDy,apDz];
                apImgColors(counter, :) = apImg(yi,xi, :);
                counter=counter+1;
            end
        end
        apPcLoc(isnan(apPcLoc(:,1)),:) = [];
        apImgColors(isnan(apImgColors(:,1)),:) = [];
        if printLevel > 1
            pcshow(apPcLoc, uint8(apImgColors), 'MarkerSize', 12);
        end
        %lat
        latImg = latImgInfo.Image;
        latImgResX = latImgInfo.ResX;
        latImgResY = latImgInfo.ResY;
        imgRows = size(latImg,1);
        imgCols = size(latImg,2);
        latImgColors = nan(floor(imgRows/downSample)*floor(imgCols/downSample), 3);
        latPcLoc = nan(floor(imgRows/downSample)*floor(imgCols/downSample), 3);
        counter=1;
        for xi=1:downSample:size(latImg,2)
            for yi=1:downSample:size(latImg,1)
                tempY = ((latImgResY*yi)-latDcmMarkers(1).World(2))/latDeltaYAvg+latDcmMarkers(1).World(2);
                tempZ = ((latImgResX*-xi)-latDcmMarkers(1).World(3))/latDeltaZAvg+latDcmMarkers(1).World(3);
                latPcLoc(counter,:) = [latDx,tempY-latDy,tempZ-latDz];
                latImgColors(counter, :) = latImg(yi,xi, :);
                counter=counter+1;
            end
        end
        latPcLoc(isnan(latPcLoc(:,1)),:) = [];
        latImgColors(isnan(latImgColors(:,1)),:) = [];
        if printLevel > 1
            pcshow(latPcLoc, uint8(latImgColors), 'MarkerSize', 12);
        end

        % get projection and point of intersection
        apCorrectedDcmMarkers_withOffsetCorrection = [];
        latCorrectedDcmMarkers_withOffsetCorrection = [];
        apArrow3Lines = {};
        latArrow3Lines = {};
        for markerInd=1:numOfMarkers
            % dicom image is flat, thus use borders for arrows
            % ap
            apMarker1 = apCorrectedDcmMarkers{markerInd}.World - [apDx,apDy,0];
            apMarker1(3) = apDz;
            apCorrectedDcmMarkers_withOffsetCorrection(markerInd, :) = apMarker1;
            apPCMin = min(apPcLoc,[],1);
            apPCMax = max(apPcLoc,[],1);
            apPCAvg = mean(apPcLoc, 1);
            apArrow1 = [apPCMax(1)-apMarker1(1), apPCMin(2)-apMarker1(2), 0];
            apArrow2 = [apPCMax(1)-apMarker1(1), apPCMax(2)-apMarker1(2), 0];
            % get projection line
            apArrow3 = cross(apArrow1, apArrow2);
            apArrow3 = 150*apArrow3/norm(apArrow3);
            
            % plot arrows
            arrow1Line = [];
            arrow2Line = [];
            apArrow3Line = [];
            for ai=0:0.05:1
                arrow1Line = [arrow1Line; apMarker1 + ai*apArrow1];
                arrow2Line = [arrow2Line; apMarker1 + ai*apArrow2];
                apArrow3Line = [apArrow3Line; apMarker1 + ai*apArrow3];
            end
            apArrow3Lines{markerInd} = apArrow3Line;
            if printLevel > 1
                pcshow(arrow1Line, 'r', 'MarkerSize', 12);
                pcshow(arrow2Line, 'r', 'MarkerSize', 12);
                pcshow(apArrow3Line, 'g', 'MarkerSize', 12);
            end
            % lat
            latMarker1 = latCorrectedDcmMarkers{markerInd}.World - [0,latDy,latDz];
            latMarker1(1) = latDx;
            latCorrectedDcmMarkers_withOffsetCorrection(markerInd, :) = latMarker1;
            latPCMin = min(latPcLoc,[],1);
            latPCMax = max(latPcLoc,[],1);
            latPCAvg = mean(latPcLoc, 1);
            latArrow1 = [0, latPCMin(2)-latMarker1(2), latPCMax(3)-latMarker1(3)];
            latArrow2 = [0, latPCMax(2)-latMarker1(2), latPCMax(3)-latMarker1(3)];
            % get projection line
            latArrow3 = cross(latArrow1, latArrow2);
            latArrow3 = 350*latArrow3/norm(latArrow3);
            
            % plot arrows
            arrow1Line = [];
            arrow2Line = [];
            latArrow3Line = [];
            for ai=0:0.05:1
                arrow1Line = [arrow1Line; latMarker1 + ai*latArrow1];
                arrow2Line = [arrow2Line; latMarker1 + ai*latArrow2];
                latArrow3Line = [latArrow3Line; latMarker1 + ai*latArrow3];
            end
            latArrow3Lines{markerInd} = latArrow3Line;
            if printLevel > 1
                pcshow(arrow1Line, 'r', 'MarkerSize', 12);
                pcshow(arrow2Line, 'r', 'MarkerSize', 12);
                pcshow(latArrow3Line, 'g', 'MarkerSize', 12);
            end
            % get intersection
            apIntersect = [apMarker1(1), mean([apMarker1(2),latMarker1(2)]), latMarker1(3)];
            if printLevel > 1
                scatter3(apIntersect(1), apIntersect(2), apIntersect(3), 64, 'x', 'MarkerFaceColor', 'b', 'MarkerEdgeColor', 'b', 'LineWidth', 2);
            end
        end
        if printLevel > 1
            view(0,-89);
            xlabel('x');
            ylabel('y');
            zlabel('z');
        end
    end
    
    %% find transformation
    % TODO from 2022b use estgeotform3d
    pcMarkersMatRep = repmat(pcMarkersMat, 3, 1);
    apIntersectsRep = repmat(apIntersects, 3, 1);
    [tformEst,inlierIndex, status] = estimateGeometricTransform3D(pcMarkersMatRep, apIntersectsRep,'rigid', 'Confidence', 99, 'MaxDistance', 100);
    
    tFormPcMarkers = pctransform(pointCloud(pcMarkersMat), tformEst);
    tFormPcLinePts = pctransform(pointCloud(pcLinePts), tformEst);
    tFormPc = pctransform(pc, tformEst);
    
    if printLevel > 1
        figure;
        pcshow(tFormPc);
        hold on;
        pcshow(tFormPcMarkers.Location, 'r', 'MarkerSize', 128);
        pcshow(latPcLoc, uint8(latImgColors), 'MarkerSize', 12);
        pcshow(apPcLoc, uint8(apImgColors), 'MarkerSize', 12);
        for markerInd=1:numOfMarkers
            pcshow(apCorrectedDcmMarkers_withOffsetCorrection(markerInd, :), 'b', 'MarkerSize', 128);
            pcshow(latCorrectedDcmMarkers_withOffsetCorrection(markerInd, :), 'b', 'MarkerSize', 128);
            pcshow(apArrow3Lines{markerInd}, 'g', 'MarkerSize', 12);
            pcshow(latArrow3Lines{markerInd}, 'g', 'MarkerSize', 12);
            scatter3(apIntersects(markerInd,1), apIntersects(markerInd,2), apIntersects(markerInd,3), 64, 'x', 'MarkerFaceColor', 'b', 'MarkerEdgeColor', 'b', 'LineWidth', 2);
        end
    end
    
    % results from estimateGeometricTransform3D is not perfect but close => icp
    [tFormIcp,~,rmse] = pcregistericp(tFormPcMarkers, pointCloud(apIntersects));
    
    tFormPcMarkersIcp = pctransform(tFormPcMarkers, tFormIcp);
    tFormPcLinePtsIcp = pctransform(tFormPcLinePts, tFormIcp);
    tFormPcIcp = pctransform(tFormPc, tFormIcp);
    
    if printLevel > 0.49
        fig3 = figure;
        % cut some for figure
        tFormPcIcpLoc = tFormPcIcp.Location;
        tFormPcIcpCols = tFormPcIcp.Color;
        % find lower bound of markers, either average of SIPS (3 and 4)
        % or L5 (2)
        lowerMarkersBound = 0.5*(pcMarkers(3).World(2)+pcMarkers(4).World(2));
        if pcMarkers(2).World(2)>lowerMarkersBound
            lowerMarkersBound = pcMarkers(2).World(2);
        end
        inds2 = tFormPcIcpLoc(:,2)<pcMarkers(1).World(2)-50 | tFormPcIcpLoc(:,2)>lowerMarkersBound+50;
        tFormPcIcpLoc(inds2, :) = [];
        if ~isempty(tFormPcIcpCols)
            tFormPcIcpCols(inds2, :) = [];
            pcshow(tFormPcIcpLoc, tFormPcIcpCols);
        else
            pcshow(tFormPcIcpLoc, 'MarkerSize',128);
        end
        hold on;
        pcshow(tFormPcMarkersIcp.Location, 'k', 'MarkerSize', 128);

        % cut some for figure
        lowerMarkersBound = 0.5*(pcMarkers(3).World(2)+pcMarkers(4).World(2));
        if pcMarkers(2).World(2)>lowerMarkersBound
            lowerMarkersBound = pcMarkers(2).World(2);
        end
        inds2 = latPcLoc(:,2)<pcMarkers(1).World(2)-50 | latPcLoc(:,2)>lowerMarkersBound+50;
        latPcLoc(inds2, :) = [];
        latImgColors(inds2, :) = [];
        pcshow(latPcLoc, uint8(latImgColors), 'MarkerSize', 56);

        % cut some for figure
        inds2 = apPcLoc(:,2)<pcMarkers(1).World(2)-50 | apPcLoc(:,2)>lowerMarkersBound+50;
        apPcLoc(inds2, :) = [];
        apImgColors(inds2, :) = [];
        pcshow(apPcLoc, uint8(apImgColors), 'MarkerSize', 56);

        for markerInd=1:numOfMarkers
            mColor = 'b';
            pcshow(apCorrectedDcmMarkers_withOffsetCorrection(markerInd, :), mColor, 'MarkerSize', 64);
            pcshow(latCorrectedDcmMarkers_withOffsetCorrection(markerInd, :), mColor, 'MarkerSize', 64);

            if printLevel > 1
                pcshow(apArrow3Lines{markerInd}, 'g', 'MarkerSize', 12);
                pcshow(latArrow3Lines{markerInd}, 'g', 'MarkerSize', 12);
                scatter3(apIntersects(markerInd,1), apIntersects(markerInd,2), apIntersects(markerInd,3), 64, 'x', 'MarkerFaceColor', 'b', 'MarkerEdgeColor', 'b', 'LineWidth', 2);
            end
        end
    end

    pcLinePts = tFormPcLinePtsIcp.Location;
    if dataset == "IRCCS"
        % IRCCS external line is already correct
        pcPolyLinePts = pcLinePts;
    else
        % fit polynomial for external line
        % make y evenly spaced
        tmpVar = pcLinePts;
        deltaY = (max(tmpVar(:,2))-min(tmpVar(:,2)))/length(tmpVar);
        yy = min(tmpVar(:,2)):deltaY:max(tmpVar(:,2))+deltaY/4;

        if useSmoothingSpline
            px = fit(pcLinePts(:,2), pcLinePts(:,1), 'smoothingspline', 'SmoothingParam',SmoothingSplineParam);
            xx = feval(px,yy)';
            pz = fit(pcLinePts(:,2), pcLinePts(:,3), 'smoothingspline', 'SmoothingParam',SmoothingSplineParam);
            zz = feval(pz,yy)';
        else
            px = polyfit(pcLinePts(:,2),pcLinePts(:,1),6);
            xx = polyval(px,yy);
            pz = polyfit(pcLinePts(:,2),pcLinePts(:,3),6);
            zz = polyval(pz,yy);
        end
        pcPolyLinePts = [xx',yy',zz'];
        % cut y to original data
    end
    if printLevel > 0
        pcshow(pcLinePts, 'y', 'MarkerSize', 12);
        pcPolyLinePts(:,3) = pcPolyLinePts(:,3)+10;
        pcshow(pcPolyLinePts, 'y', 'MarkerSize', 32);
    end

    % project pcPolyLinePts into xray coordinate system
    apProjectedPcPolyLinePts = [pcPolyLinePts(:,1)+apDx pcPolyLinePts(:,2)+apDy zeros(size(pcPolyLinePts,1),1)];
    apProjectedPcPolyLinePts(:,1) = (apProjectedPcPolyLinePts(:,1)+apDcmMarkers(1).World(1))/apDeltaXAvg-apDcmMarkers(1).World(1);
    apProjectedPcPolyLinePts(:,2) = (apProjectedPcPolyLinePts(:,2)+apDcmMarkers(1).World(2))/apDeltaYAvg-apDcmMarkers(1).World(2);
    latProjectedPcPolyLinePts = [zeros(size(pcPolyLinePts,1),1) pcPolyLinePts(:,2)+latDy pcPolyLinePts(:,3)+latDz];
    latProjectedPcPolyLinePts(:,2) = (latProjectedPcPolyLinePts(:,2)+latDcmMarkers(1).World(2))/latDeltaYAvg-latDcmMarkers(1).World(2);
    latProjectedPcPolyLinePts(:,3) = (latProjectedPcPolyLinePts(:,3)+latDcmMarkers(1).World(3))/latDeltaZAvg-latDcmMarkers(1).World(3);
    % save in world and pixel space
    clearvars pcApLinePts pcLatLinePts;
    for aplpi=1:size(apProjectedPcPolyLinePts, 1)
        pcApLinePts(aplpi).Pixel = [-apProjectedPcPolyLinePts(aplpi,1)/apImgResX, apProjectedPcPolyLinePts(aplpi,2)/apImgResY];
        pcApLinePts(aplpi).World = apProjectedPcPolyLinePts(aplpi,:);
    end
    for lplpi=1:size(latProjectedPcPolyLinePts, 1)
        pcLatLinePts(lplpi).Pixel = [-latProjectedPcPolyLinePts(lplpi,3)/latImgResX, latProjectedPcPolyLinePts(lplpi,2)/latImgResY];
        pcLatLinePts(lplpi).World = latProjectedPcPolyLinePts(lplpi,:);
    end

    if printLevel > 1
        pcshow([pcPolyLinePts(:,1), pcPolyLinePts(:,2), ones(size(pcPolyLinePts,1),1)*apDz], 'm', 'MarkerSize', 12);
        pcshow([ones(size(pcPolyLinePts,1),1)*latDx, pcPolyLinePts(:,2), pcPolyLinePts(:,3)], 'm', 'MarkerSize', 12);
    end

    % fit polynomial for dcm lines
    % ap
    apCorrectedDcmLinePts_withOffsetCorrection = [];
    for ni=1:length(apCorrectedDcmLine)
        apPt1 = apCorrectedDcmLine{ni}.World - [apDx,apDy,0];
        apPt1(3) = apDz;
        apCorrectedDcmLinePts_withOffsetCorrection(ni,:) = apPt1;
    end
    
    % make y evenly spaced
    tmpVar = apCorrectedDcmLinePts_withOffsetCorrection;
    deltaY = (max(tmpVar(:,2))-min(tmpVar(:,2)))/length(tmpVar);
    deltaY = deltaY/2; % increase resolution
    yy = min(tmpVar(:,2)):deltaY:max(tmpVar(:,2))+deltaY/4;
    
    if useSmoothingSpline
        px = fit(apCorrectedDcmLinePts_withOffsetCorrection(:,2), apCorrectedDcmLinePts_withOffsetCorrection(:,1), 'smoothingspline', 'SmoothingParam',SmoothingSplineParam);
        xx = feval(px,yy)';
        pz = fit(apCorrectedDcmLinePts_withOffsetCorrection(:,2), apCorrectedDcmLinePts_withOffsetCorrection(:,3), 'smoothingspline', 'SmoothingParam',SmoothingSplineParam);
        zz = feval(pz,yy)';
    else
        px = polyfit(apCorrectedDcmLinePts_withOffsetCorrection(:,2),apCorrectedDcmLinePts_withOffsetCorrection(:,1),6);
        pz = polyfit(apCorrectedDcmLinePts_withOffsetCorrection(:,2),apCorrectedDcmLinePts_withOffsetCorrection(:,3),1);
        xx = polyval(px,yy);
        zz = polyval(pz,yy);
    end
    apPolyLinePts = [xx',yy',zz'];

    % project apPolyLinePts back into xray coordinate system
    apProjectedPolyLinePts = [apPolyLinePts(:,1)+apDx apPolyLinePts(:,2)+apDy zeros(size(apPolyLinePts,1),1)];
    apProjectedPolyLinePts(:,1) = (apProjectedPolyLinePts(:,1)+apDcmMarkers(1).World(1))/apDeltaXAvg-apDcmMarkers(1).World(1);
    apProjectedPolyLinePts(:,2) = (apProjectedPolyLinePts(:,2)+apDcmMarkers(1).World(2))/apDeltaYAvg-apDcmMarkers(1).World(2);
    % save in world and pixel space
    clearvars apProjectedLinePts;
    for aplpi=1:size(apProjectedPolyLinePts, 1)
        apProjectedLinePts(aplpi).Pixel = [-apProjectedPolyLinePts(aplpi,1)/apImgResX, apProjectedPolyLinePts(aplpi,2)/apImgResY];
        apProjectedLinePts(aplpi).World = apProjectedPolyLinePts(aplpi,:);
    end

    if printLevel > 0
        pcshow(apCorrectedDcmLinePts_withOffsetCorrection, 'y', 'MarkerSize', 12);
        apPolyLinePts(:,3) = apPolyLinePts(:,3)+3;
        pcshow(apPolyLinePts, 'r', 'MarkerSize', 8);
    end
    
    % lat
    latCorrectedDcmLinePts_withOffsetCorrection = [];
    for ni=1:length(latCorrectedDcmLine)
        latPt1 = latCorrectedDcmLine{ni}.World - [0,latDy,latDz];
        latPt1(1) = latDx;
        latCorrectedDcmLinePts_withOffsetCorrection(ni,:) = latPt1;
    end
    
    tmpVar = latCorrectedDcmLinePts_withOffsetCorrection;
    deltaY = (max(tmpVar(:,2))-min(tmpVar(:,2)))/length(tmpVar);
    deltaY = deltaY/2; % increase resolution
    yy = min(tmpVar(:,2)):deltaY:max(tmpVar(:,2))+deltaY/4;

    if useSmoothingSpline
        px = fit(latCorrectedDcmLinePts_withOffsetCorrection(:,2), latCorrectedDcmLinePts_withOffsetCorrection(:,1), 'smoothingspline', 'SmoothingParam',SmoothingSplineParam);
        xx = feval(px,yy)';
        pz = fit(latCorrectedDcmLinePts_withOffsetCorrection(:,2), latCorrectedDcmLinePts_withOffsetCorrection(:,3), 'smoothingspline', 'SmoothingParam',SmoothingSplineParam);
        zz = feval(pz,yy)';
    else
        px = polyfit(latCorrectedDcmLinePts_withOffsetCorrection(:,2),latCorrectedDcmLinePts_withOffsetCorrection(:,1),1);
        pz = polyfit(latCorrectedDcmLinePts_withOffsetCorrection(:,2),latCorrectedDcmLinePts_withOffsetCorrection(:,3),6);
        xx = polyval(px,yy);
        zz = polyval(pz,yy);
    end
    latPolyLinePts = [xx',yy',zz'];

    % project latPolyLinePts back into xray coordinate system
    latProjectedPolyLinePts = [zeros(size(latPolyLinePts,1),1) latPolyLinePts(:,2)+latDy latPolyLinePts(:,3)+latDz];
    latProjectedPolyLinePts(:,2) = (latProjectedPolyLinePts(:,2)+latDcmMarkers(1).World(2))/latDeltaYAvg-latDcmMarkers(1).World(2);
    latProjectedPolyLinePts(:,3) = (latProjectedPolyLinePts(:,3)+latDcmMarkers(1).World(3))/latDeltaZAvg-latDcmMarkers(1).World(3);
    % save in world and pixel space
    clearvars latProjectedLinePts;
    for lplpi=1:size(latProjectedPolyLinePts, 1)
        latProjectedLinePts(lplpi).Pixel = [-latProjectedPolyLinePts(lplpi,3)/latImgResX, latProjectedPolyLinePts(lplpi,2)/latImgResY];
        latProjectedLinePts(lplpi).World = latProjectedPolyLinePts(lplpi,:);
    end

    if printLevel > 0
        pcshow(latCorrectedDcmLinePts_withOffsetCorrection, 'y', 'MarkerSize', 12);
        latPolyLinePts(:,1) = latPolyLinePts(:,1)-3;
        pcshow(latPolyLinePts, 'r', 'MarkerSize', 8);
    end

    % draw internal line from x-ray lines
    internalLineIntersects = [];
    latDiffs = [];
    for latInd = 2:length(latPolyLinePts)
        latDiffs = [latDiffs, norm(latPolyLinePts(latInd,:)-latPolyLinePts(latInd-1,:))];
    end
    latDiffAvg = mean(latDiffs);
    counter = 1;
    maxYDist = 0;
    avgYDist = 0;
    avgYMeanDist = 0;
    for apInd = 1:length(apPolyLinePts)
        
        % find closest value in other dicom image according to y values
        yErrors = abs(latPolyLinePts(:,2)-apPolyLinePts(apInd,2));
        [yMin,yMinInd] = min(yErrors);
        inds(1) = yMinInd;
        yMinm1 = inf;
        yMinp1 = inf;
        if yMinInd>1
            yMinm1 = yErrors(yMinInd-1);
        end
        if yMinInd<length(yErrors)
            yMinp1 = yErrors(yMinInd+1);
        end
        if yMinm1<yMinp1
            inds(2) = yMinInd-1;
        else
            inds(2) = yMinInd+1;
        end

        % quality check for upper and lower bound
        yDist = abs(latPolyLinePts(inds(1), 2)-apPolyLinePts(apInd,2));
        if yDist > maxYDist
            maxYDist = yDist;
        end
        avgYDist = avgYDist+yDist;
        if yDist>3*latDiffAvg
            disp('Warning: large y distance, can lead to error!');
        end
        % if y value is bigger than both or smaller than both (means not in
        % between), use close one
        if apPolyLinePts(apInd,2)>=latPolyLinePts(inds(1),2) && apPolyLinePts(apInd,2)>=latPolyLinePts(inds(2),2) ...
            || apPolyLinePts(apInd,2)<=latPolyLinePts(inds(1),2) && apPolyLinePts(apInd,2)<=latPolyLinePts(inds(2),2)
            latPt = latPolyLinePts(inds(1), :);
        % else use both (middle) % TODO use weighted middle
        else
            latPt = latPolyLinePts(inds(1),:) + 0.5*(latPolyLinePts(inds(2),:)-latPolyLinePts(inds(1), :));
        end
        yMeanDiff = abs(apPolyLinePts(apInd,2)-latPt(1,2));
        avgYMeanDist = avgYMeanDist+yMeanDiff;
        apIntersect = [apPolyLinePts(apInd,1), mean([apPolyLinePts(apInd,2),latPt(1,2)]), latPt(1,3)];
        internalLineIntersects(counter, :) = apIntersect;
        counter=counter+1;
    end
    avgYDist = avgYDist/length(apPolyLinePts);
    avgYMeanDist = avgYMeanDist/length(apPolyLinePts);
    
    if printLevel > 0
        pcshow(internalLineIntersects, 'r', 'MarkerSize', 32);
    end

    if printLevel>2
        figure;
        overallImg = [apImg, latImg];
        imshow(overallImg, [], 'Border','tight');
                  
        hold on;
        for j=1:length(pcApLinePts)
            rectangle('Position',[pcApLinePts(j).Pixel(1)-5,pcApLinePts(j).Pixel(2)-5,10,10], 'FaceColor','r', 'LineStyle','none');
        end
        for j=1:length(apProjectedLinePts)
            rectangle('Position',[apProjectedLinePts(j).Pixel(1)-5,apProjectedLinePts(j).Pixel(2)-5,10,10], 'FaceColor','c', 'LineStyle','none');
        end
        for j=1:length(pcLatLinePts)
            rectangle('Position',[pcLatLinePts(j).Pixel(1)-5+latOffsetX,pcLatLinePts(j).Pixel(2)-5,10,10], 'FaceColor','r', 'LineStyle','none');
        end
        for j=1:length(latProjectedLinePts)
            rectangle('Position',[latProjectedLinePts(j).Pixel(1)-5+latOffsetX,latProjectedLinePts(j).Pixel(2)-5,10,10], 'FaceColor','c', 'LineStyle','none');
        end
    end

    % save coordinate transformation from point cloud to X-ray coordinate
    % system
    totalTForm = tFormIcp.T*tformEst.T;
    
    nowString = datestr(now,'yyyymmdd_HHMMSSFFF');
    % save lines
    jsonObject.subjectName = subjectName;
    jsonObject.eslLinePts = pcPolyLinePts;
    jsonObject.islLinePts = internalLineIntersects;
    jsonObject.pcApProjectedPolyLinePts = pcApLinePts;
    jsonObject.pcLatProjectedPolyLinePts = pcLatLinePts;
    jsonObject.apProjectedPolyLinePts = apProjectedLinePts;
    jsonObject.latProjectedPolyLinePts = latProjectedLinePts;
    jsonObject.Pc2XrayTForm = totalTForm;
    jsonString = jsonencode(jsonObject);
    fid=fopen(append(outputPath, "\", subjectName, "_Markers2_", nowString, ".json"), 'w');
    fprintf(fid, jsonString);
    fclose(fid);
    
    % save resulting figure
    if printLevel > 0.5
        %saveas(fig3, append(outputPath, "\", subjectName, "_Results_", nowString, ".fig"))
    end
    if doMarkerRegistrationErrorEval
        figure;
        pcshow(tFormPcMarkersIcp.Location, 'g', 'MarkerSize', 128);
        hold on;
        for markerInd=1:numOfMarkers
            mColor = 'r';
            scatter3(apIntersects(markerInd,1), apIntersects(markerInd,2), apIntersects(markerInd,3), 64, 'x', 'MarkerFaceColor', 'b', 'MarkerEdgeColor', 'b', 'LineWidth', 2);
        end
        [~, markerDists] = knnsearch(tFormPcMarkersIcp.Location, apIntersects);
        markerDistRmse = sqrt(sum(markerDists.^2)/length(markerDists));
        markerDistSd = std(markerDists);
        markerDistRmses = [markerDistRmses; markerDistRmse];
        markerDistSds = [markerDistSds; markerDistSd];
    end

    if doESLAlignmentEval
        if printLevel<0.49
            disp("Warning: ESL Alignment evaluation requires printLevel 0.5 or higher")
            keyboard;
        end
        % do a full projection into 2D and compare with X-ray
        tFormPcIcpLoc2 = tFormPcIcpLoc;
        lowerMarkersBound = 0.5*(pcMarkers(3).World(2)+pcMarkers(4).World(2));
        if pcMarkers(2).World(2)>lowerMarkersBound
            lowerMarkersBound = pcMarkers(2).World(2);
        end
        inds2 = tFormPcIcpLoc2(:,2)<pcMarkers(1).World(2)-5 | tFormPcIcpLoc2(:,2)>lowerMarkersBound+5;
        tFormPcIcpLoc2(inds2, :) = [];
        % lat
        tFormPcIcpLocLat = tFormPcIcpLoc2;
        tFormPcIcpLocLat(:,1) = 0;
        inds3 = sum(latImgColors,2)>=10;
        latPcLocLat = latPcLoc(inds3, :);
        inds2 = latPcLocLat(:,2)<pcMarkers(1).World(2)-5 | latPcLocLat(:,2)>lowerMarkersBound+5;
        latPcLocLat(inds2,:) = [];
        latPcLocLat(:,1) = 0;
        latImgColorsLat = latImgColors(inds3, :);
        latImgColorsLat(inds2, :) = [];
        latImgColorsLat(:,[2,3]) = 0;
        if printLevel > 3
            figure;
            pcshow(latPcLocLat, uint8(latImgColorsLat), 'MarkerSize', 12);
            hold on;
            pcshow(tFormPcIcpLocLat, 'w');
        end
        % regularize for image
        minZ = min([tFormPcIcpLocLat(:,3);latPcLocLat(:,3)]);
        if dataset == "IRCCS"
            resolutionY = 5;
            resolutionZ = 2;
            rangeRadius = 5.2;
        else
            resolutionY = 2;
            resolutionZ = 2;
            rangeRadius = 2.2;
        end
        [X,Y] = meshgrid(minZ:resolutionZ:minZ+200, pcMarkers(1).World(2)-5:resolutionY:lowerMarkersBound+5);
        xyPts = [X(:), Y(:)];

        [indices,~] = rangesearch(tFormPcIcpLocLat(:,[3,2]), xyPts, rangeRadius);
        pcImageLat = zeros(size(X));
        maxInds = [];
        for ii=1:size(indices,1)
            if length(indices{ii,1})>0
                maxInds = [maxInds length(indices{ii,1})];
            end
        end
        maxInds = quantile(maxInds, 0.9);
        for xiInd = 1:size(indices,1)
            if ~isempty(indices{xiInd})
                [row,col] = ind2sub(size(X),xiInd);
                % weight the color a bit
                tempInds = length(indices{xiInd, 1});
                pcImageLat(row,col) = 255*tempInds/maxInds;
            end
        end
        if printLevel > 0
            f818 = figure;
            imshow(uint8(pcImageLat), 'Border','tight');
        end
        pcImageLatBorderPixels = nan(1,size(pcImageLat, 1));
        for xi=1:size(pcImageLat, 1)
            for yi=1:size(pcImageLat,2)-1
                if pcImageLat(xi,yi)>pcImageLineThreshold1 && pcImageLat(xi,yi+1)>pcImageLineThreshold1
                    pcImageLatBorderPixels(xi) = yi;
                    if printLevel > 0
                        hold on;
                        %rectangle('Position', [yi,xi,1,1], 'FaceColor', 'b');
                    end
                    break;
                end
            end
            % now go backward with lower threshold
            if ~isnan(pcImageLatBorderPixels(xi))
                for yi=pcImageLatBorderPixels(xi):-1:2
                    if pcImageLat(xi,yi)<pcImageLineThreshold2 && (yi-1<1 || pcImageLat(xi,yi-1)<pcImageLineThreshold2)
                        pcImageLatBorderPixels(xi) = yi;
                        if printLevel > 0
                            hold on;
                            rectangle('Position', [yi,xi,1,1], 'FaceColor', 'r');
                        end
                        break;
                    end
                end
            end
        end
        if printLevel > 0
            drawnow();
            f818.Position = [0 50 960 950];
        end

        [indices,dists] = rangesearch(latPcLocLat(:,[3,2]), xyPts, rangeRadius);
        latDcmImageLat = zeros(size(X));
        for xiInd = 1:size(indices,1)
            if ~isempty(indices{xiInd})
                [row,col] = ind2sub(size(X),xiInd);
                colorVal = latImgColorsLat(indices{xiInd},1);
                latDcmImageLat(row,col) = mean(colorVal);
            end
        end
        if printLevel > 0
            f848 = figure;
            imshow(uint8(latDcmImageLat), 'Border','tight');
        end
        disp("Percentage error: " + num2str(sum(sum(abs(pcImageLat-latDcmImageLat)))/length(X(:))*100, "%3.1f") + "%")
        latDcmImageLatBorderPixels = nan(1,size(latDcmImageLat, 1));
        for xi=1:size(latDcmImageLat, 1)
            for yi=1:size(latDcmImageLat,2)-1
                if latDcmImageLat(xi,yi)>dicomImageLineThreshold1 && latDcmImageLat(xi,yi+1)>dicomImageLineThreshold1
                    latDcmImageLatBorderPixels(xi) = yi;
                    if printLevel > 0
                        hold on;
                        %rectangle('Position', [yi,xi,1,1], 'FaceColor', 'b');
                    end
                    break;
                end
            end
            if ~isnan(latDcmImageLatBorderPixels(xi))
                for yi=latDcmImageLatBorderPixels(xi):-1:2
                    if latDcmImageLat(xi,yi)<dicomImageLineThreshold2 && (yi-1<1 || latDcmImageLat(xi,yi-1)<dicomImageLineThreshold2)
                        latDcmImageLatBorderPixels(xi) = yi;
                        if printLevel > 0
                            hold on;
                            rectangle('Position', [yi,xi,1,1], 'FaceColor', 'r');
                        end
                        break;
                    end
                end
            end
        end
        if printLevel > 0
            drawnow();
            f848.Position = [960 50 960 950];
            pause(3);
        end
        % calculate line error
        latDiffsT = [];
        for xi=1:length(pcImageLatBorderPixels)
            latDiffT = abs(pcImageLatBorderPixels(xi)-latDcmImageLatBorderPixels(xi))*resolutionZ; % error in mm
            latDiffsT = [latDiffsT, latDiffT];
        end
        latDiffsTMedian = median(latDiffsT, 'omitnan');
        latDiffsTIqr = iqr(latDiffsT);
        latDiffsTMean = mean(latDiffsT, 'omitnan');
        latDiffsTStd = std(latDiffsT, 'omitnan');
        latDiffsTMedians = [latDiffsTMedians latDiffsTMedian];
        latDiffsTMeans = [latDiffsTMeans latDiffsTMean];
        latDiffsTIqrs = [latDiffsTIqrs latDiffsTIqr];
        latDiffsTStds = [latDiffsTStds latDiffsTStd];
        latDiffsTs = [latDiffsTs latDiffsT];
        % ap
        tFormPcIcpLocAp = tFormPcIcpLoc2;
        tFormPcIcpLocAp(:,3) = 0;
        inds3 = sum(apImgColors,2)>=10;
        apPcLocAp = apPcLoc(inds3, :);
        inds2 = apPcLocAp(:,2)<pcMarkers(1).World(2)-5 | apPcLocAp(:,2)>lowerMarkersBound+5;
        apPcLocAp(inds2,:) = [];
        apPcLocAp(:,3) = 0;
        apImgColorsAp = apImgColors(inds3, :);
        apImgColorsAp(inds2, :) = [];
        apImgColorsAp(:,[2,3]) = 0;
        if printLevel > 3
            figure;
            pcshow(apPcLocAp, uint8(apImgColorsAp), 'MarkerSize', 12);
            hold on;
            pcshow(tFormPcIcpLocAp, 'w');
        end
        % regularize for image
        minX = min([tFormPcIcpLocAp(:,1);apPcLocAp(:,1)]);
        maxX = max([tFormPcIcpLocAp(:,1);apPcLocAp(:,1)]);
        if dataset == "IRCCS"
            resolutionY = 5;
            resolutionX = 2;
            rangeRadius = 5.2;
        else
            resolutionY = 2;
            resolutionX = 2;
            rangeRadius = 2.2;
        end
        [X,Y] = meshgrid(minX:resolutionX:maxX, pcMarkers(1).World(2)-5:resolutionY:lowerMarkersBound+5);
        xyPts = [X(:), Y(:)];

        [indices,~] = rangesearch(tFormPcIcpLocAp(:,[1,2]), xyPts, rangeRadius);
        pcImageAp = zeros(size(X));
        maxInds = [];
        for ii=1:size(indices,1)
            if length(indices{ii,1})>0
                maxInds = [maxInds length(indices{ii,1})];
            end
        end
        maxInds = quantile(maxInds, 0.9);
        for xiInd = 1:size(indices,1)
            if ~isempty(indices{xiInd})
                [row,col] = ind2sub(size(X),xiInd);
                % weight the color a bit
                tempInds = length(indices{xiInd, 1});
                pcImageAp(row,col) = 255*tempInds/maxInds;
            end
        end
        if printLevel > 2
            f923 = figure;
            imshow(uint8(pcImageAp), 'Border','tight');
        end
        pcImageApBorderPixelsLower = nan(1,size(pcImageAp, 1));
        pcImageApBorderPixelsUpper = nan(1,size(pcImageAp, 1));
        for xi=1:size(pcImageAp, 1)
            for yi=1:size(pcImageAp,2)-1
                if pcImageAp(xi,yi)>pcImageLineThreshold1 && pcImageAp(xi,yi+1)>pcImageLineThreshold1
                    pcImageApBorderPixelsLower(xi) = yi;
                    if printLevel > 2
                        hold on;
                        rectangle('Position', [yi,xi,1,1], 'FaceColor', 'b');
                    end
                    break;
                end
            end
            if ~isnan(pcImageApBorderPixelsLower(xi))
                for yi=pcImageApBorderPixelsLower(xi):-1:2
                    if pcImageAp(xi,yi)<pcImageLineThreshold2 && (yi-1<1 || pcImageAp(xi,yi-1)<pcImageLineThreshold2)
                        pcImageApBorderPixelsLower(xi) = yi;
                        if printLevel > 2
                            hold on;
                            rectangle('Position', [yi,xi,1,1], 'FaceColor', 'r');
                        end
                        break;
                    end
                end
            end
            for yi=size(pcImageAp,2):-1:2
                if pcImageAp(xi,yi)>pcImageLineThreshold1 && pcImageAp(xi,yi-1)>pcImageLineThreshold1
                    pcImageApBorderPixelsUpper(xi) = yi;
                    if printLevel > 2
                        hold on;
                        rectangle('Position', [yi,xi,1,1], 'FaceColor', 'b');
                    end
                    break;
                end
            end
            if ~isnan(pcImageApBorderPixelsUpper(xi))
                for yi= pcImageApBorderPixelsUpper(xi):size(pcImageAp,2)-1
                    if pcImageAp(xi,yi)<pcImageLineThreshold2 && (yi+1>size(pcImageAp,2) ||  pcImageAp(xi,yi+1)<pcImageLineThreshold2)
                        pcImageApBorderPixelsUpper(xi) = yi;
                        if printLevel > 2
                            hold on;
                            rectangle('Position', [yi,xi,1,1], 'FaceColor', 'r');
                        end
                        break;
                    end
                end
            end
        end
        if printLevel > 2
            drawnow();
            f923.Position = [0 50 960 950];
        end

        [indices,dists] = rangesearch(apPcLocAp(:,[1,2]), xyPts, rangeRadius);
        apDcmImageAp = zeros(size(X));
        for xiInd = 1:size(indices,1)
            if ~isempty(indices{xiInd})
                [row,col] = ind2sub(size(X),xiInd);
                colorVal = apImgColorsAp(indices{xiInd},1);
                apDcmImageAp(row,col) = mean(colorVal);
            end
        end
        if printLevel > 2
            f963 = figure;
            imshow(uint8(apDcmImageAp), 'Border','tight');
        end
        disp("Percentage error: " + num2str(sum(sum(abs(pcImageAp-apDcmImageAp)))/length(X(:))*100, "%3.1f") + "%")
        apDcmImageApBorderPixelsLower = nan(1,size(apDcmImageAp, 1));
        apDcmImageApBorderPixelsUpper = nan(1,size(apDcmImageAp, 1));
        for xi=1:size(apDcmImageAp, 1)
            for yi=1:size(apDcmImageAp,2)-1
                if apDcmImageAp(xi,yi)>dicomImageLineThreshold1 && apDcmImageAp(xi,yi+1)>dicomImageLineThreshold1
                    apDcmImageApBorderPixelsLower(xi) = yi;
                    if printLevel > 2
                        hold on;
                        rectangle('Position', [yi,xi,1,1], 'FaceColor', 'b');
                    end
                    break;
                end
            end
            if ~isnan(apDcmImageApBorderPixelsLower(xi))
                for yi=apDcmImageApBorderPixelsLower(xi):-1:2
                    if apDcmImageAp(xi,yi)<dicomImageLineThreshold2 && (yi-1<1 ||  apDcmImageAp(xi,yi-1)<dicomImageLineThreshold2)
                        apDcmImageApBorderPixelsLower(xi) = yi;
                        if printLevel > 2
                            hold on;
                            rectangle('Position', [yi,xi,1,1], 'FaceColor', 'r');
                        end
                        break;
                    end
                end
            end
            for yi=size(apDcmImageAp,2):-1:2
                if apDcmImageAp(xi,yi)>dicomImageLineThreshold1 && apDcmImageAp(xi,yi-1)>dicomImageLineThreshold1
                    apDcmImageApBorderPixelsUpper(xi) = yi;
                    if printLevel > 2
                        hold on;
                        rectangle('Position', [yi,xi,1,1], 'FaceColor', 'b');
                    end
                    break;
                end
            end
            if ~isnan(apDcmImageApBorderPixelsUpper(xi))
                for yi=apDcmImageApBorderPixelsUpper(xi):size(apDcmImageAp,2)-1
                    if apDcmImageAp(xi,yi)<dicomImageLineThreshold2 && (yi+1>size(apDcmImageAp,2) || apDcmImageAp(xi,yi+1)<dicomImageLineThreshold2)
                        apDcmImageApBorderPixelsUpper(xi) = yi;
                        if printLevel > 2
                            hold on;
                            rectangle('Position', [yi,xi,1,1], 'FaceColor', 'r');
                        end
                        break;
                    end
                end
            end
        end
        if printLevel > 2
            drawnow();
            f963.Position = [960 50 960 950];
        end
        % calculate line error
        apDiffsT = [];
        for xi=1:length(apDcmImageApBorderPixelsUpper)
            apDiffTLower = abs(pcImageApBorderPixelsLower(xi)-apDcmImageApBorderPixelsLower(xi))*resolutionX; % error in mm
            apDiffTUpper = abs(pcImageApBorderPixelsUpper(xi)-apDcmImageApBorderPixelsUpper(xi))*resolutionX; % error in mm
            apDiffsT = [apDiffsT, [apDiffTLower apDiffTUpper]];
        end
        apDiffsTMedian = median(apDiffsT, 'omitnan');
        apDiffsTStd = std(apDiffsT, 'omitnan');
        apDiffsTMedians = [apDiffsTMedians apDiffsTMedian];
        apDiffsTStds = [apDiffsTStds apDiffsTStd];

    end
        
    if printLevel > 1
        fig4 = figure;
        pcshow(tFormPcIcpLoc, 'w');
        hold on;
        inds3 = sum(latImgColors,2)<10;
        latPcLoc(inds3, :) = [];
        latImgColors(inds3, :) = [];
        latImgColors(:,[2,3]) = 0;
        pcshow(latPcLoc, uint8(latImgColors), 'MarkerSize', 12);
        inds3 = sum(apImgColors,2)<10;
        apPcLoc(inds3, :) = [];
        apImgColors(inds3, :) = [];
        apImgColors(:,[2,3]) = 0;
        pcshow(apPcLoc, uint8(apImgColors), 'MarkerSize', 12);
        %saveas(fig4, append(outputPath, "\", subjectName, "_Results_", nowString, "_alignment.fig"))
    end
end

latDiffsTMediansMedian = quantile(latDiffsTMedians, 0.75);
latDiffsTMediansMedian = median(latDiffsTMedians);
latDiffsTMediansMedian = 10;
disp("Subjects with low alignment error:")
for i=1:length(latDiffsTMedians)
    if latDiffsTMedians(i)<latDiffsTMediansMedian
        disp(dirList(i).name);
    end
end

%% show box plots of alignments
if ~drawOnly
if printLevel > 0
    outputPath = append(basePath, "\Output");
    if ~exist(outputPath, 'dir')
        mkdir(outputPath);
    end
    f1 = figure;
    boxplot([latDiffsTMedians' latDiffsTStds' apDiffsTMedians' apDiffsTStds'], 'Labels', ["lat median errors", "lat errors stds", "ap median errors", "ap errors stds"])
    title("Alignment errors lateral/anterior-posterior (view)")
    ylabel("Error in [mm]")
    saveas(f1, append(outputPath, "\AlignmentErrorsAPLat_"+dataset+".fig"))
    ax = gca;
    exportgraphics(ax, append(outputPath, "\AlignmentErrorsAPLat_"+dataset+".png"),"Resolution",600)
    save(append(outputPath, "\AlignmentErrorsAPLat_"+dataset+".mat"), "latDiffsTMedians", "latDiffsTStds", "apDiffsTMedians", "apDiffsTStds");

    f2 = figure;
    boxplot([latDiffsTMedians' latDiffsTIqrs'], 'Labels', ["median errors", "errors IQR"])
    title("Alignment errors lateral (view)")
    ylabel("Error in [mm]")
    saveas(f2, append(outputPath, "\AlignmentErrorsLat_MedianIqr_"+dataset+".fig"))
    ax = gca;
    exportgraphics(ax, append(outputPath, "\AlignmentErrorsLat_MedianIqr_"+dataset+".png"),"Resolution",600)
    save(append(outputPath, "\AlignmentErrorsLat_MedianIqr_"+dataset+".mat"), "latDiffsTMedians", "latDiffsTIqrs");

    f3 = figure;
    CustomBoxPlot([latDiffsTMeans' latDiffsTStds'], 'Labels', ["RMSE", "SD"])
    title("Alignment errors lateral (view)")
    ylabel("Error [mm]")
    saveas(f3, append(outputPath, "\AlignmentErrorsAPLat_MeanSD_"+dataset+".fig"))
    ax = gca;
    exportgraphics(ax, append(outputPath, "\AlignmentErrorsAPLat_MeanSD_"+dataset+".png"),"Resolution",600)
    save(append(outputPath, "\AlignmentErrorsAPLat_MeanSD_"+dataset+".mat"), "latDiffsTMeans", "latDiffsTStds");

    % median on original data
    f4 = figure;
    boxplot(latDiffsTs', 'Labels', ["errors"])
    title("Alignment errors lateral (view)")
    ylabel("Error in [mm]")
    saveas(f4, append(outputPath, "\AlignmentErrorsAPLat_All_"+dataset+".fig"))
    ax = gca;
    exportgraphics(ax, append(outputPath, "\AlignmentErrorsAPLat_All_"+dataset+".png"),"Resolution",600)
    disp(iqr(latDiffsTs))
    save(append(outputPath, "\AlignmentErrorsAPLat_All_"+dataset+".mat"), "latDiffsTs");

    f5 = figure;
    CustomBoxPlot([markerDistRmses, markerDistSds], 'Labels', ["marker RMSE", "marker SD"])
    title("Marker RMSE and SD after 3D registraion")
    ylabel("Error in [mm]")
    saveas(f5, append(outputPath, "\MarkerDistRmseSDs_"+dataset+".fig"))
    ax = gca;
    exportgraphics(ax, append(outputPath, "\MarkerDistRmseSDs_"+dataset+".png"),"Resolution",600)
    save(append(outputPath, "\MarkerDistRmseSDs_"+dataset+".mat"), "markerDistRmses", "markerDistSds");
end
end
if drawOnly
    close all;
    msgbox("All done!");
end