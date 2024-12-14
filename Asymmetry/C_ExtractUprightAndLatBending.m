close all; clear all; clc;

staticCapId = [];%"01";
dynamicCapId = "04";

dynamicStartInd = 2;
if isempty(staticCapId)
    dynamicStartInd = 1;
end

% extract all required data from zips
basePath = "I:/ETH/BalgristStudyData";
targetPath = "./Data/Lateral";

% subjectNrs
subjectNrs = 1:30;

addpath("Utils")

doExtract = true;
doCleanNSample = true;
doClean = true;
onlyExtractUprightMinMax = true;
doUseLinearSampling = true;
doUseManualSampling = false;
doShowCleanSamples = false;
doOverwriteAutoMax = true;
doSelectMaxManually = false;
doShowManualMax = false;

if doExtract
    dirlist = dir(append(basePath, "/*.zip"));
    for captureId = [staticCapId dynamicCapId]
        for i=1:length(dirlist)
            zipName = append(dirlist(i).folder, "/", dirlist(i).name);
            zipNameSplit = split(dirlist(i).name, "_");
            subjectNr = zipNameSplit{1};
            try
                if isempty(str2num(subjectNr))
                    continue;
                end
            catch
                continue;
            end
            if  sum(subjectNrs==str2num(subjectNr))==0
                continue;
            end
        
            targetSubjectPath = append(targetPath, "/", subjectNr);
            mkdir(targetSubjectPath);
        
            status = ExtractFilesFromZip(zipName, [], captureId+"_Photoneo", ".json", targetSubjectPath, captureId, true);
            if status == false
                % try again if zipped by hand
                status = ExtractFilesFromZip(zipName, replace(dirlist(i).name, ".zip", ""), append(captureId,"_Photoneo"), ".json", targetSubjectPath, captureId, true);
            end
            status = ExtractFilesFromZip(zipName, captureId, "Photoneo", ".ply", targetSubjectPath, captureId, true);
            if status == false
                % try again if zipped by hand
                status = ExtractFilesFromZip(zipName, append(replace(dirlist(i).name, ".zip", ""), "/", captureId), "Photoneo", ".ply", targetSubjectPath, captureId, true);
            end
        end
    end
end

%% now go through everything again, check that ply is clean, compressed and do a random selection of lateral bending (+max bending)

autoMaxMatPath = append(targetPath, "/maxLeftRightIndsAuto.txt");
manMaxMatPath = append(targetPath, "/maxLeftRightIndsManual.txt");
if doCleanNSample
    maxPlyIndsAuto = zeros(length(subjectNrs),2);
    for sni=1:length(subjectNrs)
        subjectNr=subjectNrs(sni)
        targetSubjectPath = append(targetPath, "/", string(subjectNr));
    
        % get first ply (static)
        allPlys = dir(append(targetSubjectPath, "/*.ply"));
        if isempty(staticCapId)
            staticPly = [];
        else
            staticPly = allPlys(1);
        end

        % get remaining ply (dynamic)
        dynamicPlys = allPlys(dynamicStartInd:end);
    
        % clean
        if doClean
            for plyInd=1:length(allPlys)
                
                pcPath = append(allPlys(plyInd).folder, "/", allPlys(plyInd).name);
                pc = pcread(pcPath);
        
                pcLoc = pc.Location;
                pcCol = pc.Color;
                inds = pcLoc(:,3)>1.35 | pcLoc(:,3)<0.2;
                inds = inds | pcLoc(:,1)>0.54 | pcLoc(:,1)<-0.54;
                pcLoc(inds, :) = [];
                pcCol(inds, :) = [];
                pc = pointCloud(pcLoc, "Color", pcCol);
        
                pcsegdistThres = 0.01;
                [labels,numClusters] = pcsegdist(pc, pcsegdistThres); %2cm
                maxLabelInd=1;
                maxClusterNum = sum(labels==1);
                for mli=2:numClusters
                    if sum(labels==mli)>maxClusterNum
                        maxLabelInd = mli;
                        maxClusterNum = sum(labels==mli);
                    end
                end
                inlierInds = 1:size(pc.Location,1);
                pc2 = select(pc, inlierInds(labels==maxLabelInd));
        
                %pcshow(pc2);
                %view(0,-89);
        
                pcwrite(pc2, pcPath, "Encoding","binary");
                %drawnow();
            end
        end
        % now find min max
        [maxPlyIndsAuto, maxLeftPlyInd, maxRightPlyInd, qDiffs] = FindMinMaxBending(allPlys, maxPlyIndsAuto, subjectNr);
        if doUseManualSampling
            maxPlyIndsManual = readmatrix(manMaxMatPath);
            maxLeftPlyInd = maxPlyIndsManual(subjectNr,1);
            maxRightPlyInd = maxPlyIndsManual(subjectNr,2);
        end

        % keep upright, first dynamic upright, max left, max right & random
        samplePath = append(targetSubjectPath, "/Sample");
        if ~exist(samplePath,"dir")
            mkdir(samplePath);
        end
        samplePlys = dir(append(samplePath, "/*.ply"));
        for spi=1:length(samplePlys)
            spPath = append(samplePlys(spi).folder, "/", samplePlys(spi).name);
            delete(spPath);
        end
        % sample some random positions in between
        % switch left and right if the user bend first to right side
        if maxLeftPlyInd>maxRightPlyInd
            tempMaxLeftPlyInd = maxRightPlyInd;
            tempMaxRightPlyInd = maxLeftPlyInd;
        else
            tempMaxLeftPlyInd = maxLeftPlyInd;
            tempMaxRightPlyInd = maxRightPlyInd;
        end
        figure;
        plot(qDiffs);
        hold on;
        plot(tempMaxLeftPlyInd, qDiffs(tempMaxLeftPlyInd),'Marker','*');
        plot(tempMaxRightPlyInd, qDiffs(tempMaxRightPlyInd),'Marker','*');
        drawnow();
        if onlyExtractUprightMinMax == false
            % linear sampling approach
            if doUseLinearSampling
                minX = min(qDiffs);
                maxX = max(qDiffs);
                randomSample1 = (0.2+0.7*rand(1))*minX;
                randomSample2 = (0.2+0.7*rand(1))*maxX;
                % now find the closest value 
                [~,sInd1] = min(abs(randomSample1-qDiffs));
                [~,sInd2] = min(abs(randomSample2-qDiffs));
                sInd3 = [];
                sInd4 = [];
                figure;
                plot(qDiffs);
                hold on;
                plot(sInd1, qDiffs(sInd1),'Marker','*');
                plot(sInd2, qDiffs(sInd2),'Marker','*');
                drawnow();
            else
                sInd1 = round(rand(1)*(tempMaxLeftPlyInd-4)+3);
                middleInd = round((tempMaxRightPlyInd+tempMaxLeftPlyInd)/2);
                sInd2 = round(rand(1)*(middleInd-(tempMaxLeftPlyInd+1))+tempMaxLeftPlyInd);
                sInd3 = round(rand(1)*(tempMaxRightPlyInd-(middleInd+1))+middleInd);
                endInd = length(allPlys);
                sInd4 = round(rand(1)*(endInd-(tempMaxRightPlyInd+1))+tempMaxRightPlyInd);
            end
            sampledPlyinds = [dynamicStartInd tempMaxLeftPlyInd tempMaxRightPlyInd sInd1 sInd2 sInd3 sInd4];
        else
            sampledPlyinds = [dynamicStartInd tempMaxLeftPlyInd tempMaxRightPlyInd];
        end
        if ~isempty(staticPly)
            pcPath = append(staticPly(1).folder, "/", staticPly(1).name);
            pcTargetPath = append(samplePath, "/", staticPly(1).name);
            copyfile(pcPath, pcTargetPath);
        end
        for sPlyInd=sampledPlyinds
            pcPath = append(allPlys(sPlyInd).folder, "/", allPlys(sPlyInd).name);
            pcTargetPath = append(samplePath, "/", allPlys(sPlyInd).name);
            copyfile(pcPath, pcTargetPath);
        end
    end
    writematrix(maxPlyIndsAuto, autoMaxMatPath);
else
    if ~doOverwriteAutoMax
        % read it from file
        maxPlyIndsAuto = readmatrix(autoMaxMatPath);
    else
        % do sampling for later
        maxPlyIndsAuto = [];
        for subjectNr=subjectNrs
            disp(subjectNr);
            targetSubjectPath = append(targetPath, "/", string(subjectNr));
        
            % get first ply (static)
            allPlys = dir(append(targetSubjectPath, "/*.ply"));
        
            [maxPlyIndsAuto] = FindMinMaxBending(allPlys, maxPlyIndsAuto, subjectNr);
        end
        % save it
        writematrix(maxPlyIndsAuto, autoMaxMatPath);
    end
end

%% now show all samples

if doShowCleanSamples
    for subjectNr=subjectNrs
        targetSubjectPath = append(targetPath, "/", string(subjectNr), "/Sample");
    
        % get first ply (static)
        samplePlys = dir(append(targetSubjectPath, "/*.ply"));
        for plyInd=1:length(samplePlys)
            pcPath = append(samplePlys(plyInd).folder, "/", samplePlys(plyInd).name);
            pc = pcread(pcPath);
            pcshow(pc);
            view(0,-89);
            drawnow();
            if pc.Count<10000
                keyboard;
            end
        end
    end
end

%% manual selection of max (validation)

if doSelectMaxManually
    fig1 = figure;
    set(fig1,'WindowKeyPressFcn',@FigureSpacePressed);
    global spaceKey;
    spaceKey = 0;
    maxPlyInds = [];
    for subjectNr=subjectNrs
        targetSubjectPath = append(targetPath, "/", string(subjectNr));
    
        % get first ply (static)
        allPlys = dir(append(targetSubjectPath, "/*.ply"));
    
        % get remaining ply (dynamic)
        dynamicPlys = allPlys(dynamicStartInd:end);
    
        % clean & find min max
        maxPlyCounter = 1;
        % start with max and let user adjust
        for plyInd= maxPlyIndsAuto(subjectNr, :)
            plyInd2 = plyInd;
            pcPath = append(allPlys(plyInd).folder, "/", allPlys(plyInd).name);
            pc = pcread(pcPath);
            pcshow(pc);
            view(0,-89);
            rotate3d off;
            while true
                waitforbuttonpress();
                if spaceKey==1
                    maxPlyInds(subjectNr, maxPlyCounter) = plyInd2;
                    maxPlyCounter = maxPlyCounter+1;
                    spaceKey=0;
                    break;
                else
                    % use arrow keys to go forward or backward
                    global arrowKey;
                    if strcmp(arrowKey,'leftarrow')==1
                        if plyInd2-1>=1
                            plyInd2=plyInd2-1;
                        end
                        pcPath = append(allPlys(plyInd2).folder, "/", allPlys(plyInd2).name);
                        pc = pcread(pcPath);
                        pcshow(pc);
                        view(0,-89);
                        rotate3d off;
                    end
                    if strcmp(arrowKey,'rightarrow')==1
                        if plyInd2+1<=length(allPlys)
                            plyInd2=plyInd2+1;
                        end
                        pcPath = append(allPlys(plyInd2).folder, "/", allPlys(plyInd2).name);
                        pc = pcread(pcPath);
                        pcshow(pc);
                        view(0,-89);
                        rotate3d off;
                    end
                    arrowKey = '';
                end
            end
        end
    end
    writematrix(maxPlyInds, manMaxMatPath);
end

%% do show manually selected maximal bendings

if doShowManualMax
    maxPlyInds = readmatrix(autoMaxMatPath);
    for subjectNr=subjectNrs
        targetSubjectPath = append(targetPath, "/", string(subjectNr));
    
        % get first ply (static)
        allPlys = dir(append(targetSubjectPath, "/*.ply"));
        for plyInd=maxPlyInds(subjectNr, :)
            pcPath = append(allPlys(plyInd).folder, "/", allPlys(plyInd).name);
            pc = pcread(pcPath);
            pcshow(pc);
            view(0,-89);
            drawnow();
            pause(0.8);
            if pc.Count<10000
                keyboard;
            end
        end
    end
end

%% compare difference between auto and manual
manMaxPlyInds = readmatrix(manMaxMatPath);
autoMaxPlyInds = readmatrix(autoMaxMatPath);
oldAutoMaxPlyInds = readmatrix(replace(autoMaxMatPath, ".txt", "_Old.txt"));
diffs = [];
autoDiffs = [];
oldDiffs = [];
for subjectNr=subjectNrs
    lowerAutoInd = min(autoMaxPlyInds(subjectNr, :));
    upperAutoInd = max(autoMaxPlyInds(subjectNr, :));
    oldLowerAutoInd = min(oldAutoMaxPlyInds(subjectNr, :));
    oldUpperAutoInd = max(oldAutoMaxPlyInds(subjectNr, :));
    lowerManualInd = min(manMaxPlyInds(subjectNr, :));
    upperManualInd = max(manMaxPlyInds(subjectNr, :));
    diffs = [diffs, [abs(lowerAutoInd-lowerManualInd), abs(upperAutoInd-upperManualInd)]];
    oldDiffs = [oldDiffs, [abs(oldLowerAutoInd-lowerManualInd), abs(oldUpperAutoInd-upperManualInd)]];
    autoDiffs = [autoDiffs, [abs(lowerAutoInd-oldLowerAutoInd), abs(upperAutoInd-oldUpperAutoInd)]];
end
figure;
boxplot(diffs);
title("Auto - Manual diff")
figure;
boxplot(oldDiffs);
title("Old auto - Manual diff")
figure;
boxplot(autoDiffs);
title("Auto - Old auto diff")


%%

function [maxPlyIndsAuto, maxLeftPlyInd, maxRightPlyInd, qDiffs] = FindMinMaxBending(allPlys, maxPlyIndsAuto, subjectNr)

% find min max
maxLeftPlyInd = -1;
maxLeftVal = inf;
maxRightPlyInd = -1;
maxRightVal = -inf;
qDiffs = [];
for plyInd=1:length(allPlys)
    pcPath = append(allPlys(plyInd).folder, "/", allPlys(plyInd).name);
    pc = pcread(pcPath);
    %pcshow(pc);
    %view(0,-89);    
    %drawnow();

    % now find min max
    qUpperY = quantile(pc.Location(:,2),0.6);
    qLowerY = quantile(pc.Location(:,2),0.4);
    pcUpperLoc = pc.Location(pc.Location(:,2)>=qUpperY, :);
    pcLowerLoc = pc.Location(pc.Location(:,2)<=qLowerY, :);
    qu01 = quantile(pcUpperLoc(:,1),0.3);
    ql01 = quantile(pcLowerLoc(:,1),0.7);
    q01Diff = qu01-ql01;
    if q01Diff < maxLeftVal
        maxLeftVal = q01Diff;
        maxLeftPlyInd = plyInd;
    end
    qu09 = quantile(pcUpperLoc(:,1),0.7);
    ql09 = quantile(pcLowerLoc(:,1),0.3);
    q09Diff = qu09-ql09;
    if q09Diff > maxRightVal
        maxRightVal = q09Diff;
        maxRightPlyInd = plyInd;
    end

    qu = mean(pcUpperLoc(:,1));
    ql = mean(pcLowerLoc(:,1));
    qDiff = qu-ql;
    qDiffs = [qDiffs qDiff];
end
maxPlyIndsAuto(subjectNr,:) = [maxLeftPlyInd maxRightPlyInd];

end

function FigureSpacePressed(~,evnt)

if strcmp(evnt.Key,'space')==1
    global spaceKey;
    spaceKey = 1;
    fprintf('key event is: %s/n',evnt.Key);
end
if strcmp(evnt.Key,'leftarrow')==1 || strcmp(evnt.Key,'rightarrow')==1
    fprintf('key event is: %s/n',evnt.Key);
    global arrowKey;
    arrowKey = evnt.Key;
end

end