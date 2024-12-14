clear all; close all;

basePlyPaths = ["../Data/hNet"]; 
outputFolder = append("Output_AsymMapPaperData");
plySubfolder = "Sample";

printLevel = 0;
dataFilter = [];

if printLevel>0
    f1 = figure;
end

txtFiles = dir(append(outputFolder, "\*_5.txt"));
nowString = datestr(now,'yyyymmdd_HHMMSSFFF');
for i=1:length(txtFiles)
    disp(txtFiles(i).name);
    splitArr = split(txtFiles(i).name, "_");
    subjectName = splitArr(3);
    plyString = append(splitArr(4), "_", splitArr(5));

    for basePlyPath=basePlyPaths
        origPlyPath = append(basePlyPath, "\", subjectName, "/",plySubfolder, "\", plyString, ".ply");
        if exist(origPlyPath, "file")
            origPc = pcread(origPlyPath);
            break;
        end
    end

    % get the corresponding results
    eslResFilePath = append(txtFiles(i).folder, "\", txtFiles(i).name);
    eslResDepthMapMat = readmatrix(eslResFilePath);
    tempX = eslResDepthMapMat(:,1);
    eslResDepthMapMat(:,1) = 479-eslResDepthMapMat(:,2);
    eslResDepthMapMat(:,2) = tempX;
    eslResDepthMapMat_nz = eslResDepthMapMat;
    eslResDepthMapMat_nz(:,3) = -eslResDepthMapMat_nz(:,3);
    eslResDepthMapMat_nz(eslResDepthMapMat_nz(:,3)>-10,:) = [];
    
    % max is ESL
    eslResDepthMapMat_3 = reshape(eslResDepthMapMat(:,3), 480, 480,1);
    xiResMaxInds = nan(480,1);
    xiResMaxPc = nan(480,3);
    for yi=1:480
        yiResMaxVal = 10;
        xiResMaxInd = nan;
        for xi=1:480
            if eslResDepthMapMat_3(xi, yi)>yiResMaxVal
                yiResMaxVal = eslResDepthMapMat_3(xi,yi);
                xiResMaxInd = xi;
            end
        end
        xiResMaxInds(yi) = xiResMaxInd;
        if ~isnan(xiResMaxInd)
            xiResMaxPc(yi,:) = [xiResMaxInd, yi, -yiResMaxVal];
        end
    end

    maxDimX = 480; % TODO think about this
    maxDimY = 480;
    minX = origPc.XLimits(1);
    maxX = origPc.XLimits(2);
    minY = origPc.YLimits(1);
    maxY = origPc.YLimits(2);
    deltaX = (maxX-minX)/maxDimX;
    deltaY = (maxY-minY)/maxDimY;

    xiResMaxPcLine = xiResMaxPc;
    xiResMaxPcLine(isnan(xiResMaxPcLine(:,3)), :) = [];
    for pci=1:length(xiResMaxPcLine)
        xiResMaxPcLine(pci,1) = minX+xiResMaxPcLine(pci,1)*deltaX;
        xiResMaxPcLine(pci,2) = minY+xiResMaxPcLine(pci,2)*deltaY;
        xiResMaxPcLine(pci,3) = origPc.ZLimits(1);
    end

    % now find the projection onto the point cloud
    origPc2d = origPc.Location;
    origPc2d(:,3) = 0;
    xiResMaxPcLine2d = xiResMaxPcLine;
    xiResMaxPcLine2d(:,3) = 0;
    Idx2 = knnsearch(origPc2d, xiResMaxPcLine2d);
    xiResMaxPcLine(:,3) = origPc.Location(Idx2,3);

    if printLevel>0
        figure(f1);
        hold off;
        pcshow(origPc);
        hold on;
        pcshow(xiResMaxPcLine, 'g', 'MarkerSize', 64);
        view(0,-90);
        drawnow;
    end

    % save it as json for later use
    jsonObject.subjectName = subjectName;
    jsonObject.pcLinePts = xiResMaxPcLine;
    jsonString = jsonencode(jsonObject, PrettyPrint=true);

    markersPath = replace(origPlyPath, ".ply", append("_PcLinePts_hNet_", nowString, ".json"));
    outputDirPath = append(fileparts(origPlyPath), "\Output");
    markersPath = replace(markersPath, "\Photoneo_", append("\Output\Photoneo_"));
    if ~exist(outputDirPath, 'dir')
        mkdir(outputDirPath);
    end

    fid=fopen(markersPath, 'w');
    fprintf(fid, jsonString);
    fclose(fid);

end

%% check the results

f5 = figure;
for basePlyPath=basePlyPaths
    dirList = dir(basePlyPath);    
    for i=3:length(dirList)
        if ~dirList(i).isdir || strcmp(dirList(i).name, "Output")
            continue;
        end
        disp(dirList(i).name);
        % get all depth maps
        plyPaths = dir(append(basePlyPath, "\", dirList(i).name, "\", plySubfolder, "\*.ply"));
        for j=1:length(plyPaths)

            origPlyPath = append(basePlyPath, "\", dirList(i).name, "\", plySubfolder, "\", plyPaths(j).name);
            pcLinePtsPath = dir(append(basePlyPath, "\", dirList(i).name, "\", plySubfolder, "\Output\",replace(plyPaths(j).name, ".ply", "*.json")));
            if isempty(pcLinePtsPath)
                disp("warning: json not found: " + append(dirList(i).name, "\", plySubfolder, "\", plyPaths(j).name))
                continue;
            end
            origPc = pcread(origPlyPath);
            jsonString = fileread(append(pcLinePtsPath(end).folder, "\", pcLinePtsPath(end).name));
            jsonObject = jsondecode(jsonString);
            figure(f5);
            hold off;
            pcshow(origPc);
            hold on;
            pcshow(jsonObject.pcLinePts, 'r', 'MarkerSize', 64);
            view(0,-90);
            drawnow
        end
    end
end