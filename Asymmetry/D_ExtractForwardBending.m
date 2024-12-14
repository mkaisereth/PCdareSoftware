close all; clear all; clc;

dynamicCapId = "08";

% extract all required data from zips
basePath = "I:/ETH/BalgristStudyData";
targetPath = "./Data/Forward";

% subjectNrs
subjectNrs = 1:30;

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
    for captureId = [dynamicCapId]
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
fig1 = figure;
fig2 = figure;
if doCleanNSample
    for sni=1:length(subjectNrs)
        subjectNr=subjectNrs(sni)
        targetSubjectPath = append(targetPath, "/", string(subjectNr));
    
        %
        allPlys = dir(append(targetSubjectPath, "/*.ply"));
    
        % clean
        if doClean
            for plyInd=1:length(allPlys)
                
                pcPath = append(allPlys(plyInd).folder, "/", allPlys(plyInd).name);
                pc = pcread(pcPath);
        
                pcLoc = pc.Location;
                pcCol = pc.Color;
                inds = pcLoc(:,3)>1.9 | pcLoc(:,3)<0.2;
                inds = inds | pcLoc(:,1)<-0.41;
                inds = inds | pcLoc(:,2)<-0.4 | pcLoc(:,2)>0.4;
                pcLoc(inds, :) = [];
                pcCol(inds, :) = [];
                pc2 = pointCloud(pcLoc, "Color", pcCol);
                figure(fig1);
                hold off;
                pcshow(pc2);
                view(0,-89);

                % calculate the bending line
                % grab the few with bending coeffs around 0, delete the rest
                minX = quantile(pcLoc(:,1),0.1);
                maxX = quantile(pcLoc(:,1),0.9);
                doDelete = true;
                if maxX-minX>0.3
                    bendingLineInds = pcLoc(:,2)<0.03 & pcLoc(:,2)>-0.03;
                    bendingLine = pcLoc(bendingLineInds, :);
                    %hold on;
                    %pcshow(bendingLine, 'r', 'MarkerSize', 12);
                    view(0,-89);
    
                    % now project to X-Z
                    bendingLineXZ = bendingLine(:,[1,3]);
                    [bendingLineZ,blzInds] = sort(bendingLineXZ(:,2));
                    bendingLineXZ = [bendingLineXZ(blzInds,1), bendingLineZ];
                    figure(fig2);
                    hold off;
                    plot(bendingLineXZ(:,1), -bendingLineXZ(:,2), 'LineStyle','none', 'Marker','*')
                    lm = fitlm(bendingLineXZ(:,1), -bendingLineXZ(:,2));
                    hold on;
                    plot(lm);
                    axis equal;
                    if abs(lm.Coefficients{2,1})<0.2
                        doDelete = false;
                        % ask user which to keep
                        doDelete = ~WaitForYesNo();
                    end
                end
                if doDelete
                    delete(pcPath)
                else
                    pcwrite(pc2, pcPath, "Encoding","binary");
                end
                drawnow();
            end            
        end
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

%%
function k = WaitForYesNo()
    k=0;
    while ~k
        k=waitforbuttonpress;
        if strcmp(get(gcf,'currentcharacter'),'y')
            k=1;
            return;
        end
        if strcmp(get(gcf,'currentcharacter'),'n')
            k=0;
            return;
        end
    end
end