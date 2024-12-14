close all; clear all; clc;
basePath = "./Data";

basePathUpright = append(basePath, "/Upright");
basePathAdams = append(basePath, "/Adams");
basePathForward = append(basePath, "/Forward");
basePathLateral = append(basePath, "/Lateral");

patientInds = 1:30;

doMergeAdamsManually = false;

%% Show upright
figure;
for patientInd =patientInds
    disp(patientInd)
    uprightFolder = append(basePathUpright, "/", string(patientInd));
    uprightPlys = dir(append(uprightFolder, "/Photoneo_*.ply"));
    if isempty(uprightPlys)
        disp(append("Warning: ply missing for ", string(patientInd)))
    elseif length(uprightPlys)>1
        disp(append("Warning: multiple (",string(length(uprightPlys)),") ply for ", string(patientInd)))
    end
    for upPly=uprightPlys
        pc1 = pcread(append(upPly.folder, "/", upPly.name));
        pcshow(pc1)
        view(0,-90)
        pause(1)
    end
end

%% adams
if doMergeAdamsManually
    close all
    clc;
    fig1 = figure;
    fig2 = figure;
    for patientInd =patientInds
        disp(patientInd)
        adamsFolder = append(basePathAdams, "/", string(patientInd));
        adamsPly1s = dir(append(adamsFolder, "/Photoneo_*.ply"));
        adamsPly2s = dir(append(adamsFolder, "/Photoneo2_*.ply"));
        if ~isempty(adamsPly1s) && ~isempty(adamsPly2s)
            pc1 = pcread(append(adamsPly1s(1).folder, "/", adamsPly1s(1).name));
            pc2 = pcread(append(adamsPly2s(1).folder, "/", adamsPly2s(1).name));
            figure(fig1)
            subplot(1,2,1);
            pcshow(pc1)
            view(0,-90)
            title(string(patientInd))
            subplot(1,2,2);
            pcshow(pc2)
            view(-90,-90)
            title(string(patientInd))
            pc1Markers = [];
            pc2Markers = [];
            figure(fig2)
            pcshow(pc1)
            view(0,-90)
            title(string(patientInd))
            for markerInd=1:3
                WaitForSpace();
                [~, circle1Pt1] = SelectPointFromPc(pc1.Location', true);
                pc1Markers = [pc1Markers; circle1Pt1];
            end
            figure(fig2)
            pcshow(pc2)
            view(-90,-90)
            title(string(patientInd))
            for markerInd=1:3
                WaitForSpace();
                [~, circle2Pt1] = SelectPointFromPc(pc2.Location', true);
                pc2Markers = [pc2Markers; circle2Pt1];
            end
    
            % now show optimized results
            markerTForm = estimateGeometricTransform3D(pc1Markers,pc2Markers,'rigid');
            pc1MarkersT = pctransform(pointCloud(pc1Markers), markerTForm);
            pc1t = pctransform(pc1,markerTForm);
    
            figure
            pcshow(pc1t)
            hold on;
            pcshow(pc2);
            % save as new merged
            pcLocs = [pc1t.Location;pc2.Location];
            pcCols = [pc1t.Color;pc2.Color];
            mergedPc = pointCloud(pcLocs, 'Color', pcCols);
            pcwrite(mergedPc, append(adamsFolder, "/Photoneo12_1.ply"), "Encoding", "binary");
        end
    end
end

%% Show adams
close all
figure;
numOfFallBack=[];
for patientInd =patientInds
    disp(patientInd)
    adamsFolder = append(basePathAdams, "/", string(patientInd));
    adamsPlys = dir(append(adamsFolder, "/Photoneo12_1.ply"));
    if isempty(adamsPlys)
        adamsPlys = dir(append(adamsFolder, "/Photoneo12.ply"));
        if isempty(adamsPlys)
            disp("Warning: merged ply not found")
            adamsPlys = dir(append(adamsFolder, "/Photoneo2_*.ply"));
            numOfFallBack = [numOfFallBack patientInd];
        end
    end
    if isempty(adamsPlys)
        disp(append("Warning: ply missing for ", string(patientInd)))
    elseif length(adamsPlys)>1
        disp(append("Warning: multiple (",string(length(uprightPlys)),") ply for ", string(patientInd)))
    end
    for adPly=adamsPlys
        pc1 = pcread(append(adPly.folder, "/", adPly.name));
        pcshow(pc1)
        view(0,-90)
        title(string(patientInd))
        pause(1)
    end
end

%% Show forward
close all
figure;
for patientInd =patientInds
    disp(patientInd)
    forwardFolder = append(basePathForward, "/", string(patientInd));
    forwardPlys = dir(append(forwardFolder, "/Photoneo2_*.ply"));
    if isempty(forwardPlys)
        disp(append("Warning: ply missing for ", string(patientInd)))
    elseif length(forwardPlys)>1
        disp(append("Warning: multiple (",string(length(uprightPlys)),") ply for ", string(patientInd)))
    end
    for adPly=forwardPlys'
        pc1 = pcread(append(adPly.folder, "/", adPly.name));
        pcshow(pc1, 'MarkerSize',16)
        set(gcf,'color',[0.15 0.15 0.15]);
        set(gca,'color',[0.15 0.15 0.15]);
        view(0,-90)
        title(string(patientInd))
        pause(1)
    end
end

%% show lateral
close all
figure;
for patientInd =patientInds
    disp(patientInd)
    lateralFolder = append(basePathLateral, "/", string(patientInd));
    lateralPlys = dir(append(lateralFolder, "/Photoneo_*.ply"));
    if isempty(lateralPlys)
        disp(append("Warning: ply missing for ", string(patientInd)))
    elseif length(lateralPlys) ~= 3
        disp(append("Warning: unexpected (",string(length(uprightPlys)),") ply for ", string(patientInd)))
    end
    for adPly=lateralPlys(2:3)' % last two are bending
        pc1 = pcread(append(adPly.folder, "/", adPly.name));
        pcshow(pc1, 'MarkerSize',16)
        set(gcf,'color',[0.15 0.15 0.15]);
        set(gca,'color',[0.15 0.15 0.15]);
        view(0,-90)
        title(string(patientInd))
        pause(1)
    end
end