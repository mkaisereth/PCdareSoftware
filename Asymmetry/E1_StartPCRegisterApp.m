close all, clear all, clc;

basePath = "./Data/Lateral";
basePath = "./Data/Forward"
%basePath = "./Data/Adams"

subfolder = "";
%subfolder = "Sample";
directVersion = false;
multiplePly = false;
numOfMarkers = 4;
numOfMarkers = 6;
global useMarkerZoom;
useMarkerZoom = false;
global invertLeftBending;
% >0 for invert left (right handed people), <0 for invert right, 0 for don't
invertLeftBending = 0.02;

dataset = "Balgrist"
pcNameFilters = ["*Photoneo_*.ply"];
%pcNameFilters = ["*Photoneo12*.ply", "*Photoneo2_*.ply"];
pcNameFilters = ["*Photoneo2_*.ply"];

addpath("../XrayRegistration") % TODO

askUserToCorrectMarkers = false;

% 0.5, 1, 2, 3, 4
printLevel = 0.5;

doWaitForFigures3 = false;

if directVersion
    dirList(3,1) = basePath;
else
    dirList = dir(basePath);
end
totalNum = size(dirList,1)-2;
inc=0;
startTime = now;
for i=3:size(dirList,1)
    close all;
    if directVersion
        subjectPath = dirList(i,1);
        subjectName = "10"; % TODO
    else
        subjectPath = append(dirList(i).folder, '/', dirList(i).name);
        if ~isempty(subfolder)
            subjectPath = append(subjectPath, "/", subfolder);
        end
        subjectName = dirList(i).name;
    end
    
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

    outputPath = append(subjectPath, "/Output");

    % get file names
    isLastPly = ~multiplePly;
    numOfPlys = 1;
    for plyCounter = 1:100
        if dataset == "Balgrist"
            for pcNFInd=1:length(pcNameFilters)
                pcNameFilter_t = pcNameFilters(pcNFInd);
                pcPathFilter = dir(append(subjectPath, '/', pcNameFilter_t));
                numOfPlys = length(pcPathFilter);
                if numOfPlys>0
                    break;
                end
            end
                % just draw original ones where merhed has been drawn
%                 if pcNameFilter_t == pcNameFilters(1)
%                     pcPathFilter = dir(append(subjectPath, '/', pcNameFilters(2)));
%                     numOfPlys = length(pcPathFilter);
%                 else
%                     break;
%                 end
            pcPath = append(pcPathFilter(plyCounter).folder, "/", pcPathFilter(plyCounter).name);
        else
            pcPath = append(subjectPath, '/', subjectName, '.stl');
        end

        if (multiplePly && numOfPlys == plyCounter)
            isLastPly = true;
        end

        if dataset == "Balgrist"
            global pcMarkers;
            addpath("../XrayRegistration/")
            [pc, fig3, pcLinePtInds] = PcMarkerApp(pcPath, numOfMarkers, dataset == "Balgrist", 128);
            if dataset == "Balgrist"
                pcLoc = pc.Location*1000; % m to mm
                pc = pointCloud(pcLoc, "Color", pc.Color);
                origPc = pc;
                for pmi=1:length(pcMarkers)
                    pcMarkers(pmi).World = pcMarkers(pmi).World*1000;
                end
            end
        end
    
        % save if something changed
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
        if dataset == "Balgrist"
            pcLinePts = origPc.Location(pcLinePtInds, :);
        end
        jsonObject.pcLinePts = pcLinePts;
    
        jsonString = jsonencode(jsonObject);
        if multiplePly
            fid=fopen(append(pcPathFilter(plyCounter).folder, "/Output/", replace(pcPathFilter(plyCounter).name, ".ply", "_PcLinePts.json")), 'w');
        else
            fid=fopen(append(outputPath, "/", subjectName, "_PcLinePts_", datestr(now,'yyyymmdd_HHMMSSFFF'), ".json"), 'w');
        end
        fprintf(fid, jsonString);
        fclose(fid);
    
        if doWaitForFigures3
            waitfor(fig3);
        else
            close(fig3);
        end
        if isLastPly
            break;
        end
    end
end