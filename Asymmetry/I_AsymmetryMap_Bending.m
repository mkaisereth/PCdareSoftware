clearvars -except doOverwriteAdams loopCounter; close all; clc;
printLevel = 0;
saveOutput = 1;

loadLastFiles = false;

% Version
% 4 - flip according to ESL and icp register
asymmetryVersion = 4;

evalSubset=1:30;

allowShift = 2; % 0,1 or 2

% Balgrist
global subFolder;
subFolder = "";
if exist('doOverwriteAdams', 'var')
    doAdams = doOverwriteAdams;
else
    doAdams = false;
end
doForward = ~doAdams;
if doAdams
    % AsymMap paper - Adams
    basePath1 = "./Data/"+subFolder+"/Adams"
    basePath1u = "./Data/"+subFolder+"/Upright"
    basePath2 = [];
    basePath2u = [];
    xmlPath = "./Data/"+subFolder+"/CobbAngles.csv";
    csvPath = [];
    outName = "a";
end
if doForward
    % AsymMap paper - Forward TODO
    basePath1 = "./Data/"+subFolder+"/Forward"
    basePath1u = "./Data/"+subFolder+"/Upright"
    basePath2 = [];
    basePath2u = [];
    xmlPath = "./Data/"+subFolder+"/CobbAngles.csv";
    csvPath = [];
    outName = "f";
end
commonOutputPath = append(basePath1, "/Output");

if doAdams
    plyFilter = "/Photoneo2_*ds.ply"; % TODO if merged Photoneo12
end
if doForward
    plyFilter = "/Photoneo2_*.ply"; % TODO if merged Photoneo12
end
basePaths = [basePath1];
basePathsUpright = [basePath1u];
groupName = "Balgrist";

% eval all base paths: preparation
counter=1;
for basePath=basePaths
    dirlistTemp = dir(basePath);
    if ~isempty(dirlistTemp)
        % skip Output folder
        for i=1:size(dirlistTemp, 1)
            if dirlistTemp(i).isdir && dirlistTemp(i).name ~= "Output" && dirlistTemp(i).name ~= "." && dirlistTemp(i).name ~= ".."
                dirlist(counter) = dirlistTemp(i);
                counter=counter+1;
            end
        end
    end
end
dirlist = natsortfiles(dirlist');    % to use natsortfiles: download "Natural-Order Filename Sort" from the Matlab file exchange (https://ch.mathworks.com/matlabcentral/fileexchange/47434-natural-order-filename-sort)
if ~isempty(evalSubset)
    dirlist = dirlist(evalSubset);
end
disp(append("Evaluating until patient: ", dirlist(end).name));

num = 0;
numTotal = size(dirlist, 1);
startTime = now;

folderList = 1:size(dirlist,1);
    
rmses = {};

%% read point cloud
if ~loadLastFiles
    for i=folderList
        close all;
        subjectPath = append(dirlist(i).folder,'/',dirlist(i).name);
        subjectNr = dirlist(i).name;
        
        num = num+1;
        if num > 1
            eta = ((now-startTime)/(num-1)*(numTotal-num))*24*60;
        else
            eta = 0;
        end
        disp(num + "/" + numTotal + " eta: " + round(eta,1) + " min");
    
        plyFiles = dir(append(subjectPath, plyFilter));
        for j=1:length(plyFiles)
            pcPath = append(plyFiles(j).folder,'/',plyFiles(j).name);
    
            pc = pcread(pcPath);
    
            rmse_t = 0;
            if asymmetryVersion == 4
                % use manual symmetry line
                outputPath = append(subjectPath, "/Output");
                % read pc ESL from Marker file
                markerFiles = dir(append(outputPath,'/',subjectNr,'_Markers2_*.json'));
                % use last one
                markerFile = markerFiles(size(markerFiles, 1));
                filetext = fileread(append(markerFile.folder, "/", markerFile.name));
                jsonObject = jsondecode(filetext);
                if strcmp(jsonObject.subjectName,subjectNr) == 0
                    disp('Warning: this data does not belong to this subject!')
                    keyboard;
                end
                
                pcLinePts = jsonObject.pcLinePts;
                pLine = pcLinePts; % TODO I think pcLinePts is drawn points, pLine should be polynomial/spline fit
                pc = pointCloud(pc.Location*1000, "Color", pc.Color);
                if isfield(jsonObject, "Pc2XrayTForm")
                    pc2xrayTform = rigid3d(jsonObject.Pc2XrayTForm);
    
                    % use PCDicom app transformation to xray coordinates
                    pc = pctransform(pc, pc2xrayTform);
                    pLine = pctransform(pointCloud(pLine), pc2xrayTform).Location;
                end
                if printLevel > 1
                    origPc_ds = pcdownsample(pc, 'gridAverage', 2);
                    yMin = min(pLine(:,1))-10;
                    yMax = max(pLine(:,1))+10;
                    inds = origPc_ds.Location(:,1)>yMin&origPc_ds.Location(:,1)<yMax;
                    pcshow(origPc_ds.Location(inds, :), origPc_ds.Color(inds, :), 'MarkerSize',57);
                    hold on;
                    pcshow(pLine-[0 0 3], 'r', 'MarkerSize', 64);
                    view(-90,-90);
                    set(gcf,'color','w');
                    set(gca,'color','w');
                    axis off
                    axis equal
                    if printLevel>3
                        doSaveCurrentImage("Bending"+outName+"_B24", commonOutputPath)
                    end
                end
                %% use pLine
                pLineMean = mean(pLine);
                pc_pLine1 = pc.Location-pLineMean;
                pLine1 = pLine-pLineMean;
        
                % downsample large pointclouds
                sampleRatio = 0.002; % 2mm
                pcTemp = pcdownsample(pointCloud(pc_pLine1), "gridAverage", sampleRatio);
                pc_pLine1 = pcTemp.Location;
        
                % mirror pc
                pc_pLine2 = pc_pLine1;
                pc_pLine2(:,3) = -pc_pLine2(:,3);
        
                rotyAngle = 180;
                Rz =rotx(rotyAngle);
                pc_pLine2 = (Rz * pc_pLine2')';
        
                if printLevel > 1
                    figure;
                    pc_pLine1_ds = pcdownsample(pointCloud(pc_pLine1), 'gridAverage', 2);
                    pc_pLine1_ds = pc_pLine1_ds.Location;
                    pc_pLine2_ds = pcdownsample(pointCloud(pc_pLine2), 'gridAverage', 2);
                    pc_pLine2_ds = pc_pLine2_ds.Location;
                    yMin = min(pLine1(:,1))-10;
                    yMax = max(pLine1(:,1))+10;
                    inds = pc_pLine1_ds(:,1)>yMin&pc_pLine1_ds(:,1)<yMax;
                    pcshow(pc_pLine1_ds(inds, :), 'r', 'MarkerSize', 57);
                    hold on;
                    inds = pc_pLine2_ds(:,1)>yMin&pc_pLine2_ds(:,1)<yMax;
                    pcshow(pc_pLine2_ds(inds, :), 'g', 'MarkerSize', 57);
                    view(-90,-90)
                    set(gcf,'color','w');
                    set(gca,'color','w');
                    axis off
                    axis equal
                    if printLevel>3
                        doSaveCurrentImage("AsymMapFullBending"+outName+"_B24", commonOutputPath)
                    end
                end
                %% now use this to get the cut point cloud
        
                maxX_pcpl1 = quantile(pc_pLine1(:,2),0.9);
                maxX_pcpl1 = 0.75*maxX_pcpl1;
                minX_pcpl1 = quantile(pc_pLine1(:,2),0.1);
                minX_pcpl1 = 0.75*minX_pcpl1;
                maxX_pcpl1 = min(abs(maxX_pcpl1), abs(minX_pcpl1));
                minX_pcpl1 = - maxX_pcpl1;
                pc_pLine1_cut = pc_pLine1;
                pc_pLine1_cut(pc_pLine1_cut(:,2)>maxX_pcpl1, :) = [];
                
                pc_pLine1_cut(pc_pLine1_cut(:,2)<minX_pcpl1, :) = [];
                pc_pLine2_cut = pc_pLine2;
                pc_pLine2_cut(pc_pLine2_cut(:,2)>maxX_pcpl1, :) = [];
                pc_pLine2_cut(pc_pLine2_cut(:,2)<minX_pcpl1, :) = [];
                % test cut above and below
                maxY_pl1 = max(pLine1(:,1));
                minY_pl1 = min(pLine1(:,1));
                pc_pLine1_cut(pc_pLine1_cut(:,1)>maxY_pl1, :) = [];
                pc_pLine1_cut(pc_pLine1_cut(:,1)<minY_pl1, :) = [];
                pc_pLine2_cut(pc_pLine2_cut(:,1)>maxY_pl1, :) = [];
                pc_pLine2_cut(pc_pLine2_cut(:,1)<minY_pl1, :) = [];
        
                if printLevel > 1
                    figure;
                    pcshow(pc_pLine1_cut, 'r');
                    hold on;
                    pcshow(pc_pLine2_cut, 'g');
                end
        
                %% now do registration
                [~, pcReg2_pcpl, rmse_pcpl] = pcregistericp(pointCloud(pc_pLine2_cut), pointCloud(pc_pLine1_cut), "MaxIterations", 30);
                if printLevel > 0
                    f207 = figure;
                    pc_pLine1_cut_ds = pcdownsample(pointCloud(pc_pLine1_cut), 'gridAverage', 2);
                    pc_pLine1_cut_ds = pc_pLine1_cut_ds.Location;
                    pcReg2_pcpl_ds = pcdownsample(pcReg2_pcpl, 'gridAverage', 2);
                    pcReg2_pcpl_ds = pcReg2_pcpl_ds.Location;
                    pcshow(pc_pLine1_cut_ds, 'r', 'MarkerSize', 57);
                    hold on;
                    pcshow(pcReg2_pcpl_ds, 'g', 'MarkerSize', 57);
                    view(-90,-90)
                    set(gcf,'color','w');
                    set(gca,'color','w');
                    axis off
                    axis equal
                    if printLevel>3
                        doSaveCurrentImage("AsymMapIcpBending"+outName+"_B24", commonOutputPath)
                    end

                    if saveOutput>2
                        subjectOutputPath = append(subjectPath, "/Output");
                        mkdir(subjectOutputPath);
                        saveas(f207, append(subjectOutputPath, '/Subject_asymmPc.fig'));
                    end
                end
                rmse_t = rmse_pcpl;

                if saveOutput>2
                    % create asymmetry map
                    pcLoc2d = pc_pLine1_cut;
                    pcLoc2d(:,3) = 0;
                    minPcRegLoc2d = pcReg2_pcpl.Location;
                    minPcRegLoc2d(:,3) = 0;
                    minPcReg2d = pointCloud(minPcRegLoc2d);
                    [Idx, Dx] = knnsearch(minPcRegLoc2d, pcLoc2d);

                    %[inds,dists] = findNearestNeighbors(minPcReg2d, pcLoc2d(pi,:), 1);
                    realDist = pc_pLine1_cut(:,3)-pcReg2_pcpl.Location(Idx,3);
                    diffPcLoc = [pcLoc2d(:,1), pcLoc2d(:,2), realDist];

                    addpath("Utils")
                    asymmMap = GetDepthMap(pointCloud(diffPcLoc));
            
                    if printLevel>1
                        figure;
                        mindm = min(min(asymmMap));
                        maxdm = max(max(asymmMap));
                        imshow((asymmMap-mindm)*1.0/(maxdm-mindm));
                    end
                    if printLevel > 0
                        fig170 = figure;
                        colormap('hot');
                        imagesc(asymmMap);
                        colorbar;
                        axis equal;
                        subjectOutputPath = append(subjectPath, "/Output");
                        mkdir(subjectOutputPath);
                        saveas(fig170, append(subjectOutputPath, '/Subject_asymmMap.fig'));
                    end
                end
                if saveOutput>0
                    outputFolder = append(subjectPath, '/Output');
                    if ~exist(outputFolder, 'dir')
                        mkdir(outputFolder);
                    end
                    jsonObject.SubjectNr = subjectNr;
                    jsonObject.AsymmetryMean = rmse_t;
                    jsonString = jsonencode(jsonObject);
                    fid=fopen(append(outputFolder, "/AsymmetryVals",string(asymmetryVersion),outName,"_",string(j),".json"), 'w');
                    fprintf(fid, jsonString);
                    fclose(fid);

                    % save the two point clouds as well for later use
                    if saveOutput>0
                        pcwrite(pointCloud(pc_pLine1_cut), append(outputFolder, "/AsymmetryPc1_",string(asymmetryVersion),"_",string(j),".ply"), "Encoding", "binary");
                        pcwrite(pcReg2_pcpl, append(outputFolder, "/AsymmetryPc2_",string(asymmetryVersion),"_",string(j),".ply"), "Encoding", "binary");
                    end
                end
            end
            
            if abs(rmse_t)<0.01
                keyboard;
            end
            asymmetryVal{num}.Mean = rmse_t;
            asymmetryVal{num}.SubjectNr = subjectNr;
    
        end
    end
end

%% make some statistics for asymmetryVal

% if asymmetryVal does not exist, read from files
if ~exist("asymmetryVal", 'var')
    num = 0;
    for i=folderList
        num=num+1;
        subjectPath = append(dirlist(i).folder,'/',dirlist(i).name);
        subjectNr = dirlist(i).name;
        outputFolder = append(subjectPath, '/Output');
        filetext = fileread(append(outputFolder, "/AsymmetryVals",string(asymmetryVersion),outName,"_1.json")); % TODO this only evals first ply
        jsonObject = jsondecode(filetext);
        asymmetryVal{num}.Mean = jsonObject.AsymmetryMean;
        asymmetryVal{num}.SubjectNr = subjectNr;
    end
end

% max subject number
maxSubjectNr = 0;
for i=1:length(asymmetryVal)
    maxSubjectNr_t = str2num(asymmetryVal{i}.SubjectNr);
    if maxSubjectNr_t>maxSubjectNr
        maxSubjectNr = maxSubjectNr_t;
    end
end

% if asymmetryVal does not exist, read from files
if xmlPath ~= ""
    if ~exist('xlsPrimaryCobbAngles', 'var')
        xlsPrimaryCobbAngles = nan(1,maxSubjectNr);
        if groupName == "Balgrist"
            if endsWith(xmlPath,".xml")
                xlsPrimaryCobbAngles = ReadCobbAnglesFromRedCapXml(xmlPath, printLevel);
            else
                addpath("Utils")
                xlsPrimaryCobbAngles = GetRedCapCobbAngles(xmlPath, true); %ReadCobbAnglesFromRedCapXml(xmlPath, printLevel);
                xlsPrimaryCobbAngles = xlsPrimaryCobbAngles';
            end
        end
    end
end


% get all means
asymmMeans = nan(1, maxSubjectNr);
for i=1:length(asymmetryVal)
    asymmMeans(str2num(asymmetryVal{i}.SubjectNr)) = asymmetryVal{i}.Mean;
end

figure;
plot(asymmMeans);
hold on;
plot([1,length(asymmMeans)], [0,0]);
title("Distribution of asymmetry mean values")

if exist('xlsPrimaryCobbAngles', 'var')
    % get all cobb angles
    figure;
    plot(xlsPrimaryCobbAngles);
    title("Distribution of primary Cobb angles (reference)")
    
    % plot correlation plot
    figure;
    % cut missing data
    dataLength = min(length(asymmMeans), length(xlsPrimaryCobbAngles));
    plotAsymmMeans = asymmMeans(1:dataLength);
    plotXlsPrimaryCobbAngles = xlsPrimaryCobbAngles(1:dataLength);
    plot(plotAsymmMeans,plotXlsPrimaryCobbAngles, '*');
    title("Relation between asymmetry means and primary Cobb angle")
    xlabel("asymmetrie mean")
    ylabel("Cobb angle [°]")
else
    plotAsymmMeans = asymmMeans;
end

%% eval groups

if exist('xlsPrimaryCobbAngles', 'var')
    % correlation plot
    figure;
    [R, PValue] = corrplotSingle([plotAsymmMeans',plotXlsPrimaryCobbAngles'], 'varNames', ["Asymmetry index", "Cobb angle"]);
    set(gcf,'color','w');
    title(append("Asymmetry index: ", string(asymmetryVersion), " vs Cobb angle"));
    if saveOutput>1
        if ~exist(commonOutputPath, 'dir')
            mkdir(commonOutputPath)
        end
        saveas(gcf, append(commonOutputPath, "/AsymMapBending",outName,"_CorrplotAsymIndsCobbAngles_",groupName,".fig"))
        exportgraphics(gca, append(commonOutputPath, "/AsymMapBending",outName,"_CorrplotAsymIndsCobbAngles_",groupName,".png"),"Resolution",600)
    end
end

% box plot between groups
figure;
boxplot(asymmMeans');
set(gcf,'color','w');
xlabel(groupName);
ylabel("asymmetry index");
title(append("Asymmetry index: ", string(asymmetryVersion), " ", groupName));

if exist('xlsPrimaryCobbAngles', 'var')
    % scatter plot between groups
    figure;
    plot(plotAsymmMeans,plotXlsPrimaryCobbAngles, '*');
    hold on;
    set(gcf,'color','w');
    xlabel("asymmetry index");
    ylabel("primary cobb angle");
    title(append("Asymmetry index: ", string(asymmetryVersion), " vs Cobb angle"));
    legend(groupName);
end

%% sweep approach
% custom rmse for full map (compare to cpd rmse)
addpath("Utils")

% find optimal conversion factor to mm
medianislRD3smm = [];
for conversionFactormmx=0.5
for conversionFactormmz=1.3

pcLeftsAsymmsRmses = nan(1, maxSubjectNr);
pcRightsAsymmsRmses = nan(1, maxSubjectNr);
islRxs = nan(1, maxSubjectNr);
islRxs_p = nan(1, maxSubjectNr);
islRxsmm = nan(1, maxSubjectNr);
islRxsmm_p = nan(1, maxSubjectNr);
islRD3smm = nan(1,maxSubjectNr);
islRxsMediumLarge = nan(1, maxSubjectNr);
islRxsLarge = nan(1, maxSubjectNr);
largeRxSubjectNrs = nan(1, maxSubjectNr);
largeCobbAngle10SubjectNrs = find(xlsPrimaryCobbAngles>=10);
largeCobbAngle20SubjectNrs = find(xlsPrimaryCobbAngles>=25);
largeCobbAngle40SubjectNrs = find(xlsPrimaryCobbAngles>=45);
pcAsymmsRmsesMaxDiffs = nan(1, maxSubjectNr);
islCobbLarge10 = nan(1, maxSubjectNr);
islCobbLarge20 = nan(1, maxSubjectNr);
islCobbLarge40 = nan(1, maxSubjectNr);
islCobbLarge10_p = nan(1, maxSubjectNr);
islCobbLarge20_p = nan(1, maxSubjectNr);
islCobbLarge40_p = nan(1, maxSubjectNr);
% actually for ISL we need upright

counter=1;
for basePath=basePathsUpright
    dirlistUprightTemp = dir(basePath);
    if length(dirlistUprightTemp) > 0
        % skip Output folder
        for i=1:size(dirlistUprightTemp, 1)
            if dirlistUprightTemp(i).isdir && dirlistUprightTemp(i).name ~= "Output" && dirlistUprightTemp(i).name ~= "." && dirlistUprightTemp(i).name ~= ".."
                dirlistUpright(counter) = dirlistUprightTemp(i);
                counter=counter+1;
            end
        end
    end
end
dirlistUpright = dirlistUpright';

for i=folderList
    if i>length(dirlist) || i>length(dirlistUpright)
        break;
    end
    close all;
    subjectPath = append(dirlist(i).folder,'/',dirlist(i).name);
    subjectNr = dirlist(i).name;
    outputPath = append(subjectPath, "/Output");
    subjectPathUpright = append(dirlistUpright(i).folder,'/',subjectNr);
    subjectNrUpright = subjectNr;
    outputPathUpright = append(subjectPathUpright, "/Output");
    if strcmp(subjectNr, subjectNrUpright) == 0
        disp("Warning: you are not comparing same subjects!")
        keyboard;
    end

    % TODO copy from above
    % use manual symmetry line
    % read pc ESL from Marker file
    markerFiles = dir(append(outputPathUpright,'/',subjectNr,'_Markers2_*.json'));
    if isempty(markerFiles)
        disp(append("Warning: upright Markers file missing for ", subjectNr))
        continue;
    end
    % use last one
    markerFile = markerFiles(size(markerFiles, 1));
    filetext = fileread(append(markerFile.folder, "/", markerFile.name));
    jsonObject = jsondecode(filetext);
    if strcmp(jsonObject.subjectName,subjectNr) == 0
        disp('Warning: this data does not belong to this subject!')
        keyboard;
    end
    
    if isfield(jsonObject, 'islLinePts')
        islLinePts = jsonObject.islLinePts;
        islLine = islLinePts;
        islLineMean = mean(islLine);
        islLine = islLine-islLineMean;
    else
        islLinePts = jsonObject.eslLinePts;
        islLine = islLinePts;
        islLineMean = mean(islLine);
        islLine = islLine-islLineMean;
    end

    eslLinePts = jsonObject.eslLinePts;
    eslLine = eslLinePts;
    eslLineMean = mean(eslLine);
    eslLine = eslLine-eslLineMean;

    addpath("Utils")
    for j=1:100
        tic
        pc1Path = append(outputPath, "/AsymmetryPc1_",string(asymmetryVersion),"_",string(j),".ply");
        pc2Path = append(outputPath, "/AsymmetryPc2_",string(asymmetryVersion),"_",string(j),".ply");
        if ~exist(pc1Path, 'file') || ~exist(pc2Path, 'file')
            break;
        end
        pc1 = pcread(pc1Path);
        pc2 = pcread(pc2Path);
        % split into parts
        pc1Left = pointCloud(pc1.Location(pc1.Location(:,2)<0, :));
        pc2Left = pointCloud(pc2.Location(pc2.Location(:,2)<0, :));
        pc1Right = pointCloud(pc1.Location(pc1.Location(:,2)>0, :));
        pc2Right = pointCloud(pc2.Location(pc2.Location(:,2)>0, :));
        minX = min(pc1.XLimits(1), pc2.XLimits(1));
        maxX = max(pc1.XLimits(2), pc2.XLimits(2));
        % sweep
        sweepSteps = 1:17;%1:12;
        pcLeftsAsymmsRmsesTemp = [];
        pcRightsAsymmsRmsesTemp = [];
        for swi=sweepSteps
            % cut region
            deltaX = (maxX-minX)/length(sweepSteps);
            lowerX = minX+(swi-1)*deltaX;
            upperX = minX+(swi)*deltaX;
            pc1LeftT = pointCloud(pc1Left.Location(pc1Left.Location(:,1)>lowerX & pc1Left.Location(:,1)<upperX, :));
            pc2LeftT = pointCloud(pc2Left.Location(pc2Left.Location(:,1)>lowerX & pc2Left.Location(:,1)<upperX, :));
            pc1RightT = pointCloud(pc1Right.Location(pc1Right.Location(:,1)>lowerX & pc1Right.Location(:,1)<upperX, :));
            pc2RightT = pointCloud(pc2Right.Location(pc2Right.Location(:,1)>lowerX & pc2Right.Location(:,1)<upperX, :));

            [~, asymmPcLeftRmse, ~, leftDirValue] = pcrmse_fast(pc1LeftT, pc2LeftT, 0.05*1000, [], [], [0 0 1]); % 5cm threshold, no downsampling
            [~, asymmPcRightRmse, ~, rightDirValue] = pcrmse_fast(pc1RightT, pc2RightT, 0.05*1000, [], [], [0 0 1]); % 5cm threshold, no downsampling
            try
            pcLeftsAsymmsRmsesTemp(swi) = sign(leftDirValue)*asymmPcLeftRmse;
            pcRightsAsymmsRmsesTemp(swi) = sign(rightDirValue)*asymmPcRightRmse;
            catch
                keyboard;
            end
        end
        pcLeftsAsymmsRmses(str2num(subjectNr), 1:length(sweepSteps)) = pcLeftsAsymmsRmsesTemp;
        pcRightsAsymmsRmses(str2num(subjectNr), 1:length(sweepSteps)) = pcRightsAsymmsRmsesTemp;
        toc
        if printLevel > 1
            figure;
            imagesc([pcLeftsAsymmsRmsesTemp' pcRightsAsymmsRmsesTemp'])
            set(gcf,'color','w');
            set(gca,'color','w');
            if printLevel>3
                doSaveCurrentImage("AsymMap"+outName+"_B24", commonOutputPath)
            end
        end
        %conversionFactormm = 0.5;
        pcAsymmsRmsesDiff = conversionFactormmx *(pcRightsAsymmsRmsesTemp-pcLeftsAsymmsRmsesTemp);
        maxPcAsymmsRmsesDiff = pcAsymmsRmsesDiff(3:end-2); % ignore borders (TODO play around with this)
        maxPcAsymmsRmsesDiff = max(abs(maxPcAsymmsRmsesDiff))
        if isnan(pcAsymmsRmsesMaxDiffs(str2num(subjectNr))) || maxPcAsymmsRmsesDiff > pcAsymmsRmsesMaxDiffs(str2num(subjectNr))
            pcAsymmsRmsesMaxDiffs(str2num(subjectNr)) = maxPcAsymmsRmsesDiff;
        end
        % check correlation with pLine (ISL)
        % bring isl line to same number of samples
        islMinY = min(islLine(:,2));
        islMaxY = max(islLine(:,2));
        deltaY = (islMaxY-islMinY)/length(sweepSteps);
        islLineMeansX = [];
        islLineMeansZ = [];
        for swi=sweepSteps
            % cut region
            lowerY = islMinY+(swi-1)*deltaY;
            upperY = islMinY+(swi)*deltaY;
            islLineTMeanX = mean(islLine(islLine(:,2)>lowerY & islLine(:,2)<upperY, 1));
            islLineMeansX(swi) = -islLineTMeanX;
            islLineTMeanZ = mean(islLine(islLine(:,2)>lowerY & islLine(:,2)<upperY, 3));
            islLineMeansZ(swi) = islLineTMeanZ;
        end
        % do same for esl line
        % TODO combine Asymm map & ESL?
        eslMinY = min(eslLine(:,2));
        eslMaxY = max(eslLine(:,2));
        deltaYe = (eslMaxY-eslMinY)/length(sweepSteps);
        eslLineMeansX = [];
        eslLineMeansZ = [];
        for swi=sweepSteps
            % cut region
            lowerYe = eslMinY+(swi-1)*deltaYe-deltaYe*0.1;
            upperYe = eslMinY+(swi)*deltaYe+deltaYe*0.1;
            eslLineTMeanX = mean(eslLine(eslLine(:,2)>lowerYe & eslLine(:,2)<upperYe, 1));
            eslLineMeansX(swi) = eslLineTMeanX;
            eslLineTMeanZ = mean(eslLine(eslLine(:,2)>lowerYe & eslLine(:,2)<upperYe, 3));
            eslLineMeansZ(swi) = eslLineTMeanZ;
        end

        lineUnderInvestigation = pcAsymmsRmsesDiff;
        %lineUnderInvestigation = eslLineMeansX;
        %lineUnderInvestigation = pcAsymmsRmsesDiff-eslLineMeansX;
        [islRx,islPx,islRLx,islRUx] = corrcoef(islLineMeansX, lineUnderInvestigation);
        islRx21 = islRx(2,1);
        % shape correlation
        [islRx1,~,~,~] = corrcoef(islLineMeansX(1:end-1), lineUnderInvestigation(2:end));
        [islRx2,~,~,~] = corrcoef(islLineMeansX(1:end-2), lineUnderInvestigation(3:end));
        [islRx3,~,~,~] = corrcoef(islLineMeansX(2:end), lineUnderInvestigation(1:end-1));
        [islRx4,~,~,~] = corrcoef(islLineMeansX(3:end), lineUnderInvestigation(1:end-2));
        % calc error in mm as well
        islRxmm = rmse(islLineMeansX, lineUnderInvestigation);
        islRx21mm = islRxmm;
        % calc error in 3D
        islR3mm = rmse3d([islLineMeansX' islLineMeansZ'], [pcAsymmsRmsesDiff' conversionFactormmz*eslLineMeansZ']);
        islRD3mm = islR3mm;
        % calc error if shift allowed
        islRx1mm = rmse(islLineMeansX(1:end-1), lineUnderInvestigation(2:end));
        islRx2mm = rmse(islLineMeansX(1:end-2), lineUnderInvestigation(3:end));
        islRx3mm = rmse(islLineMeansX(2:end), lineUnderInvestigation(1:end-1));
        islRx4mm = rmse(islLineMeansX(3:end), lineUnderInvestigation(1:end-2));
        % procrustes
        [~,islRxmm_p] = procrustes([[1:length(islLineMeansX)]', islLineMeansX'], [[1:length(lineUnderInvestigation)]', lineUnderInvestigation'], 'reflection',0, 'scaling',0);
        islRxmm_p = islRxmm_p(:,2)';
        islRx21mm_p = rmse(islLineMeansX, islRxmm_p);
        
        [islRx_p,islPx_p,islRLx_p,islRUx_p] = corrcoef(islLineMeansX, islRxmm_p);
        islRx21_p = islRx_p(2,1);
        % don't allow shift for mm?
        if allowShift>0
            islRx21 = max([islRx(2,1),islRx1(2,1),islRx3(2,1)]);
            %islRx21mm = min([islRxmm, islRx1mm, islRx3mm]);
        end
        if allowShift>1
            islRx21 = max([islRx(2,1),islRx1(2,1),islRx2(2,1),islRx3(2,1),islRx4(2,1)]);
            %islRx21mm = min([islRxmm, islRx1mm, islRx2mm, islRx3mm, islRx4mm]);
        end
        if islRx21<0.3 && islRx21>0.2
            %keyboard;
        end
        if sum(isnan(islRx21))>0
            keyboard;
        end
        islRxs(str2num(subjectNr)) = islRx21;
        islRxs_p(str2num(subjectNr)) = islRx21_p;
        islRxsmm(str2num(subjectNr)) = islRx21mm;
        islRxsmm_p(str2num(subjectNr)) = islRx21mm_p;
        islRD3smm(str2num(subjectNr)) = islRD3mm;
        if max(abs(islLineMeansX))>20
            largeRxSubjectNrs = [largeRxSubjectNrs str2num(subjectNr)];
            islRxsLarge(str2num(subjectNr)) = islRx21;
            if isnan(islRxsLarge(str2num(subjectNr)))
                keyboard;
            end
        else
            islRxsLarge(str2num(subjectNr)) =nan;
        end
        if sum(str2num(subjectNr)==largeCobbAngle10SubjectNrs)>0
            islCobbLarge10(str2num(subjectNr)) = islRx21;
            if isnan(islCobbLarge10(str2num(subjectNr)))
                keyboard;
            end
            islCobbLarge10_p(str2num(subjectNr)) = islRx21_p;
            if isnan(islCobbLarge10_p(str2num(subjectNr)))
                keyboard;
            end
        else
            islCobbLarge10(str2num(subjectNr)) =nan;
            islCobbLarge10_p(str2num(subjectNr)) =nan;
        end
        if sum(str2num(subjectNr)==largeCobbAngle20SubjectNrs)>0
            islCobbLarge20(str2num(subjectNr)) = islRx21;
            if isnan(islCobbLarge20(str2num(subjectNr)))
                keyboard;
            end
            islCobbLarge20_p(str2num(subjectNr)) = islRx21_p;
            if isnan(islCobbLarge20_p(str2num(subjectNr)))
                keyboard;
            end
        else
            islCobbLarge20(str2num(subjectNr)) =nan;
            islCobbLarge20_p(str2num(subjectNr)) =nan;
        end
        if sum(str2num(subjectNr)==largeCobbAngle40SubjectNrs)>0
            islCobbLarge40(str2num(subjectNr)) = islRx21;
            if isnan(islCobbLarge40(str2num(subjectNr)))
                keyboard;
            end
            islCobbLarge40_p(str2num(subjectNr)) = islRx21_p;
            if isnan(islCobbLarge40_p(str2num(subjectNr)))
                keyboard;
            end
        else
            islCobbLarge40(str2num(subjectNr)) =nan;
            islCobbLarge40_p(str2num(subjectNr)) =nan;
        end
        if max(abs(islLineMeansX))>9
            islRxsMediumLarge(str2num(subjectNr)) = islRx21;
        else
            islRxsMediumLarge(str2num(subjectNr)) =nan;
        end
        
        figure;
        plot(islLineMeansX, 1:17)
        hold on
        plot(pcAsymmsRmsesDiff, 1:17)
        set(gca,'YDir','reverse');
        set(gcf,'color','w');
        set(gca,'color','w');
        legend(["ISL","AsymMap-X"], 'Location', 'northwest')
        if printLevel>3
            doSaveCurrentImage("AsymMapXISLX"+outName+"_B24", commonOutputPath)
        end
        disp("")
    end
end

% check correlation with ISL
figure;
CustomBoxPlot([islRxs']);
xticklabels(["coronal"]);
title("Correlation between AsymmMap-X / ISL-X lines")
if saveOutput>1
    if ~exist(commonOutputPath, 'dir')
        mkdir(commonOutputPath)
    end
    saveas(gcf, append(commonOutputPath, "/AsymMapBending",outName,"_CorrplotAsymMapXIslX_",groupName,".fig"))
    exportgraphics(gca, append(commonOutputPath, "/AsymMapBending",outName,"_CorrplotAsymMapXIslX_",groupName,".png"),"Resolution",600)
end
iqr1 = iqr(islRxs)

figure;
boxplot([islRxsmm']);
xticklabels(["coronal"]);
title("Rmse between AsymmMap-X / ISL-X lines [mm]")
if saveOutput>1
    if ~exist(commonOutputPath, 'dir')
        mkdir(commonOutputPath)
    end
    saveas(gcf, append(commonOutputPath, "/AsymMapBending",outName,"_RmseAsymMapXIslX_",groupName,".fig"))
    exportgraphics(gca, append(commonOutputPath, "/AsymMapBending",outName,"_RmseAsymMapXIslX_",groupName,".png"),"Resolution",600)
end

figure;
boxplot([islRxsmm_p']);
xticklabels(["coronal"]);
title("Rmse between Shape (Procrustes) AsymmMap-X / ISL-X lines [mm]")
if saveOutput>1
    if ~exist(commonOutputPath, 'dir')
        mkdir(commonOutputPath)
    end
    saveas(gcf, append(commonOutputPath, "/AsymMapBending",outName,"_ShapeRmseAsymMapXIslX_",groupName,".fig"))
    exportgraphics(gca, append(commonOutputPath, "/AsymMapBending",outName,"_ShapeRmseAsymMapXIslX_",groupName,".png"),"Resolution",600)
end

medianislRD3smm = [medianislRD3smm median(islRD3smm, 'omitnan')];
figure;
CustomBoxPlot([islRD3smm']);
xticklabels(["3D"]);
title("3D Rmse between estimated and reference ISL [mm]")
if saveOutput>1
    if ~exist(commonOutputPath, 'dir')
        mkdir(commonOutputPath)
    end
    saveas(gcf, append(commonOutputPath, "/AsymMapBending",outName,"_3DRmseAsymMapIsl_",groupName,".fig"))
    exportgraphics(gca, append(commonOutputPath, "/AsymMapBending",outName,"_3DRmseAsymMapIsl_",groupName,".png"),"Resolution",600)
end
iqr1 = iqr(islRD3smm)

end
end

if printLevel>2
    figure;
    boxplot([islRxsMediumLarge']);
    xticklabels(["coronal"]);
    title("Correlation between AsymmMap-X / ISL-X lines (>9 deviations")
    
    figure;
    boxplot([islRxsLarge']);
    xticklabels(["coronal"]);
    title("Correlation between AsymmMap-X / ISL-X lines (only large deviations [>20mm])")
end

figure;
boxplot([islCobbLarge10']);
xticklabels(["coronal"]);
title("Correlation between AsymmMap-X / ISL-X lines (Cobb angles >= 10°)", "Interpreter","none");
if saveOutput>1
    if ~exist(commonOutputPath, 'dir')
        mkdir(commonOutputPath)
    end
    saveas(gcf, append(commonOutputPath, "/AsymMapBending",outName,"_CorrplotAsymMapXIslX10_",groupName,".fig"))
    exportgraphics(gca, append(commonOutputPath, "/AsymMapBending",outName,"_CorrplotAsymMapXIslX10_",groupName,".png"),"Resolution",600)
end
iqr1 = iqr(islCobbLarge10)

figure;
boxplot([islCobbLarge20']);
xticklabels(["coronal"]);
title("Correlation between AsymmMap-X / ISL-X lines (only large Cobb angles [>=25°])")
if saveOutput>1
    if ~exist(commonOutputPath, 'dir')
        mkdir(commonOutputPath)
    end
    saveas(gcf, append(commonOutputPath, "/AsymMapBending",outName,"_CorrplotAsymMapXIslX20_",groupName,".fig"))
    exportgraphics(gca, append(commonOutputPath, "/AsymMapBending",outName,"_CorrplotAsymMapXIslX20_",groupName,".png"),"Resolution",600)
end
iqr1 = iqr(islCobbLarge20)

figure;
boxplot([islCobbLarge40']);
xticklabels(["coronal"]);
title("Correlation between AsymmMap-X / ISL-X lines (only large Cobb angles [>=45°])")
if saveOutput>1
    if ~exist(commonOutputPath, 'dir')
        mkdir(commonOutputPath)
    end
    saveas(gcf, append(commonOutputPath, "/AsymMapBending",outName,"_CorrplotAsymMapXIslX40_",groupName,".fig"))
    exportgraphics(gca, append(commonOutputPath, "/AsymMapBending",outName,"_CorrplotAsymMapXIslX40_",groupName,".png"),"Resolution",600)
end
iqr1 = iqr(islCobbLarge40)

figure;
plotPcAsymmsRmsesMaxDiffs = pcAsymmsRmsesMaxDiffs(1:length(plotXlsPrimaryCobbAngles));
[R, PValue] = corrplotSingle([plotPcAsymmsRmsesMaxDiffs',plotXlsPrimaryCobbAngles'], 'varNames', ["Asymmetry index", "Cobb angle"]);
set(gcf,'color','w');
title(append("Asymmetry map ", string(asymmetryVersion), ": Index vs Cobb angle"));
if saveOutput>1
    if ~exist(commonOutputPath, 'dir')
        mkdir(commonOutputPath)
    end
    saveas(gcf, append(commonOutputPath, "/AsymMapBending",outName,"_CorrplotAsymAnglesCobbAngles_",groupName,".fig"))
    exportgraphics(gca, append(commonOutputPath, "/AsymMapBending",outName,"_CorrplotAsymAnglesCobbAngles_",groupName,".png"),"Resolution",600)
end
[R, PValue, RL, RU] = corrcoef([plotPcAsymmsRmsesMaxDiffs',plotXlsPrimaryCobbAngles'], 'Rows', 'complete')

%% functions

function r=rmse(data,estimate)
% Function to calculate root mean square error from a data vector or matrix 
% and the corresponding estimates.
% Usage: r=rmse(data,estimate)
% Note: data and estimates have to be of same size
% Example: r=rmse(randn(100,100),randn(100,100));
% delete records with NaNs in both datasets first
I = ~isnan(data) & ~isnan(estimate); 
data = data(I); estimate = estimate(I);
r=sqrt(sum((data(:)-estimate(:)).^2)/numel(data));
end

function r=rmse3d(data,estimate)
r = sqrt(immse(data,estimate));
end

function doSaveCurrentImage(name, commonOutputPath)
if ~exist(commonOutputPath, 'dir')
    mkdir(commonOutputPath)
end
saveas(gcf, append(commonOutputPath, "/",name,".fig"))
exportgraphics(gca, append(commonOutputPath, "/",name,".png"),"Resolution",600)
end