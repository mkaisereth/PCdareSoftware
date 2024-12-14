clearvars -except loopCounter; close all; clc;
printLevel = 0;
saveOutput = 1;
createAsymMap=true;

loadLastFiles = false;

% Version
% 4 - flip according to ESL and icp register
asymmetryVersion = 4;

evalSubset=1:30;

allowShift = 2; % 1 or 2

%/% Balgrist
global subFolder;
subFolder = "";
% AsymMap paper - Upright
basePath1 = "./Data/Upright";
xmlPath = "./Data/CobbAngles.csv";
csvPath = [];
commonOutputPath = append(basePath1, "/Output");
groupName = "Balgrist";
plyFilter = "/Photoneo_*cut_ds.ply";
downSample= 2/1000; % 0.002 %2mm
useMarkersToCut=false;

basePaths = basePath1;
addpath('Utils');

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
        if printLevel>1
            close all;
        end
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
    
            rmse = 0;
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
                end
                
                pcLinePts = jsonObject.pcLinePts;
                pLine = pcLinePts; % TODO I think pcLinePts is drawn points, pLine should be polynomial/spline fit
                pcLoc = pc.Location;
                pcLoc = pc.Location*1000;
                pc = pointCloud(pcLoc, "Color", pc.Color);
                pc2xrayTform = rigid3d(jsonObject.Pc2XrayTForm);

                % use PCDicom app transformation to xray coordinates
                pc = pctransform(pc, pc2xrayTform);
                pLine = pctransform(pointCloud(pLine), pc2xrayTform).Location;
                pcMarkers = [jsonObject.pcMarkers(1:4).World]';

                if printLevel > 1
                    figure;
                    pcshow(pc);
                    hold on;
                    pcshow(pLine, 'r', 'MarkerSize', 64);
                end

                %% use pLine
                pLineMean = mean(pLine);
                pc_pLine1 = pc.Location-pLineMean;
                pLine1 = pLine-pLineMean;
        
                % downsample large pointclouds
                pcTemp = pcdownsample(pointCloud(pc_pLine1), "gridAverage", downSample);
                pc_pLine1 = pcTemp.Location;

                % mirror pc
                pc_pLine2 = pc_pLine1;
                pc_pLine2(:,3) = -pc_pLine2(:,3);
        
                rotyAngle = 180;
                Rz =[cosd(rotyAngle) 0 sind(rotyAngle); 0 1 0; -sind(rotyAngle) 0 cosd(rotyAngle)];
                pc_pLine2 = (Rz * pc_pLine2')';
        
                if printLevel > 1
                    figure;
                    pcshow(pc_pLine1, 'r', 'MarkerSize', 24);
                    hold on;
                    pcshow(pc_pLine2, 'g', 'MarkerSize', 24);
                    view(0,-90);
                    set(gcf,'color','w');
                    set(gca,'color','w');
                    axis off
                    axis equal
                    if printLevel>3
                        doSaveCurrentImage("AsymMapFull_B24", commonOutputPath)
                    end
                end
                %% now use this to get the cut point cloud

                cutPercentile=0.75;
                maxX_pcpl1 = quantile(pc_pLine1(:,1),0.9);
                maxX_pcpl1 = cutPercentile*maxX_pcpl1(1);
                minX_pcpl1 = quantile(pc_pLine1(:,1),0.1);
                minX_pcpl1 = cutPercentile*minX_pcpl1(1);
                maxX_pcpl1 = min(abs(maxX_pcpl1), abs(minX_pcpl1));
                minX_pcpl1 = - maxX_pcpl1;
                pc_pLine1_cut = pc_pLine1;
                pc_pLine1_cut(pc_pLine1_cut(:,1)>maxX_pcpl1, :) = [];
                
                pc_pLine1_cut(pc_pLine1_cut(:,1)<minX_pcpl1, :) = [];
                pc_pLine2_cut = pc_pLine2;
                pc_pLine2_cut(pc_pLine2_cut(:,1)>maxX_pcpl1, :) = [];
                pc_pLine2_cut(pc_pLine2_cut(:,1)<minX_pcpl1, :) = [];
                
                % test cut above and below
                % use markers vs line
                if useMarkersToCut
                    maxY_pl1 = min(pcMarkers(3,2), pcMarkers(4,2))-30;
                    minY_pl1 = pcMarkers(1,2)+50;
                else
                    maxY_pl1 = max(pLine1(:,2));
                    minY_pl1 = min(pLine1(:,2));
                end
                pc_pLine1_cut(pc_pLine1_cut(:,2)>maxY_pl1, :) = [];
                pc_pLine1_cut(pc_pLine1_cut(:,2)<minY_pl1, :) = [];
                pc_pLine2_cut(pc_pLine2_cut(:,2)>maxY_pl1, :) = [];
                pc_pLine2_cut(pc_pLine2_cut(:,2)<minY_pl1, :) = [];

                if printLevel > 1
                    figure;
                    pcshow(pc_pLine1_cut, 'r');
                    hold on;
                    pcshow(pc_pLine2_cut, 'g');
                    title("pc before icp")
                end
        
                %% now do registration
                rmse_pcpl = inf;
                for pcicpind=1:1
                    [~, pcReg2_pcpl_t, rmse_pcpl_t] = pcregistericp(pointCloud(pc_pLine2_cut), pointCloud(pc_pLine1_cut), "MaxIterations", 10);
                    if rmse_pcpl_t<rmse_pcpl
                        rmse_pcpl = rmse_pcpl_t;
                        pcReg2_pcpl = pcReg2_pcpl_t;
                    end
                end
                %pcReg2_pcpl = pointCloud(pc_pLine2_cut);
                [~, rmse_pcpl, ~, ~] = pcrmse_fast(pcReg2_pcpl,pointCloud(pc_pLine1_cut), 0, [],[],[]);
                if printLevel > 0
                    f207 = figure;
                    pcshow(pc_pLine1_cut, 'r', 'MarkerSize', 32);
                    hold on;
                    pcshow(pcReg2_pcpl.Location, 'g', 'MarkerSize', 32);
                    title("pc after icp")
                    view(0,-90);
                    set(gcf,'color','w');
                    set(gca,'color','w');
                    axis off
                    axis equal
                    if saveOutput>2
                        subjectOutputPath = append(subjectPath, "/Output");
                        mkdir(subjectOutputPath);
                        saveas(f207, append(subjectOutputPath, '/Subject_asymmPc.fig'));
                    end
                    if printLevel>3
                        doSaveCurrentImage("AsymMapIcp_B24", commonOutputPath)
                    end
                end
                rmse = rmse_pcpl;
                
                if createAsymMap
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
                        if saveOutput>2
                            subjectOutputPath = append(subjectPath, "/Output");
                            mkdir(subjectOutputPath);
                            saveas(fig170, append(subjectOutputPath, '/Subject_asymmMap.fig'));
                        end
                    end
                end
                if saveOutput>0
                    outputFolder = append(subjectPath, '/Output');
                    if ~exist(outputFolder, 'dir')
                        mkdir(outputFolder);
                    end
                    jsonObject.SubjectNr = subjectNr;
                    jsonObject.AsymmetryMean = rmse;
                    jsonString = jsonencode(jsonObject);
                    fid=fopen(append(outputFolder, "/AsymmetryVals",string(asymmetryVersion),"_",string(j),".json"), 'w');
                    fprintf(fid, jsonString);
                    fclose(fid);

                    % save the two point clouds as well for later use
                    pcwrite(pointCloud(pc_pLine1_cut), append(outputFolder, "/AsymmetryPc1_",string(asymmetryVersion),"_",string(j),".ply"), "Encoding", "binary");
                    pcwrite(pcReg2_pcpl, append(outputFolder, "/AsymmetryPc2_",string(asymmetryVersion),"_",string(j),".ply"), "Encoding", "binary");
                end
            end

            asymmetryVal{num}.Mean = rmse;
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
        filetext = fileread(append(outputFolder, "/AsymmetryVals",string(asymmetryVersion),"_1.json")); % TODO this only evals first ply
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
                xlsPrimaryCobbAngles = GetRedCapCobbAngles(xmlPath, true);
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
    ylabel("Cobb angle [°]")
    % plot correlation plot
    figure;
    % cut missing data
    dataLength = min(length(asymmMeans), length(xlsPrimaryCobbAngles));
    plotAsymmMeans = asymmMeans(1:dataLength);
    plotXlsPrimaryCobbAngles = xlsPrimaryCobbAngles(1:dataLength);
    plot(plotAsymmMeans,plotXlsPrimaryCobbAngles, '*');
    title("Relation between Asymmetry values and Cobb angles")
    xlabel("Asymmetry value")
    ylabel("Cobb angle [°]")
else
    plotAsymmMeans = asymmMeans;
end

%% eval groups

if exist('xlsPrimaryCobbAngles', 'var')
    % correlation plot
    figure;
    [R, PValue] = corrplotSingle([plotAsymmMeans',plotXlsPrimaryCobbAngles'], 'varNames', ["Asymmetry index", "Cobb angle [°]"]);
    set(gcf,'color','w');
    title(append("Asymmetry index: ", string(asymmetryVersion), " vs Cobb angle"));
    if saveOutput>1
        if ~exist(commonOutputPath, 'dir')
            mkdir(commonOutputPath)
        end
        saveas(gcf, append(commonOutputPath, "/AsymMapUpright_CorrplotAsymIndsCobbAngles_",groupName,".fig"))
        exportgraphics(gca, append(commonOutputPath, "/AsymMapUpright_CorrplotAsymIndsCobbAngles_",groupName,".png"),"Resolution",600)
    end
    lm = fitlm(plotAsymmMeans', plotXlsPrimaryCobbAngles');
    intercept = lm.Coefficients{1,1};
    slope = lm.Coefficients{2,1};
    % now predict cobb angles with linear model and calc errors
    linearCobbAngles = intercept+slope*plotAsymmMeans;
    figure;
    boxplot([abs(linearCobbAngles-plotXlsPrimaryCobbAngles)'])
    title("Absolute error estimated Cobb angle - Cobb angle")
    if saveOutput>1
        if ~exist(commonOutputPath, 'dir')
            mkdir(commonOutputPath)
        end
        saveas(gcf, append(commonOutputPath, "/AsymMapUpright_DiffAsymValsCobbAngles_",groupName,".fig"))
        exportgraphics(gca, append(commonOutputPath, "/AsymMapUpright_DiffAsymValsCobbAngles_",groupName,".png"),"Resolution",600)
    end
    disp(append("Median: ", string(median([linearCobbAngles-plotXlsPrimaryCobbAngles], 'omitnan'))));
    disp(append("MAD(median) : ", string(mad([linearCobbAngles-plotXlsPrimaryCobbAngles], 1))));
    disp(append("MAD(mean): ", string(mad([linearCobbAngles-plotXlsPrimaryCobbAngles]))));
    disp(append("SD: ", string(std([linearCobbAngles-plotXlsPrimaryCobbAngles], 'omitnan'))));
    disp(append("IQR: ", string(iqr([linearCobbAngles-plotXlsPrimaryCobbAngles]))));
    % save them to file
    outputFolder = append(basePath1, '/Output');
    if ~exist(outputFolder, 'dir')
        mkdir(outputFolder);
    end
    writematrix(linearCobbAngles, append(outputFolder, "/LinearEstimatedCobbAngles_",string(asymmetryVersion),".csv"))
end

% box plot between groups
figure;
boxplot(asymmMeans');
set(gcf,'color','w');
xlabel(groupName);
ylabel("asymmetry index");
title(append("Asymmetry index: ", string(asymmetryVersion)));

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

%% start evaluation of regions
% region left/right and number of vertical regions (3 = ThSp, LSp, Sac)
% TODO find statistical distributions of ThSp, LSp and Sac
% custom rmse for full map (compare to cpd rmse)
addpath("Utils")
pcAsymmsRmses = nan(1,maxSubjectNr);
pcAsymmsStds = nan(1,maxSubjectNr);
for i=folderList
    close all;
    subjectPath = append(dirlist(i).folder,'/',dirlist(i).name);
    subjectNr = dirlist(i).name;
    outputPath = append(subjectPath, "/Output");

    for j=1:100
        pc1Path = append(outputPath, "/AsymmetryPc1_",string(asymmetryVersion),"_",string(j),".ply");
        pc2Path = append(outputPath, "/AsymmetryPc2_",string(asymmetryVersion),"_",string(j),".ply");
        if ~exist(pc1Path, 'file') || ~exist(pc2Path, 'file')
            break;
        end
        pc1 = pcread(pc1Path);
        pc2 = pcread(pc2Path);
        tic
        [closeRatio, asymmPcRmse, asymmPcStd] = pcrmse_fast(pc1, pc2, 0.05*1000, [], [], []); % 5cm threshold, no downsampling
        if isnan(asymmPcRmse)
            keyboard;
        end
        pcAsymmsRmses(str2num(subjectNr)) = asymmPcRmse;
        pcAsymmsStds(str2num(subjectNr)) = asymmPcStd;
        toc
    end
end

% compare how well this rmse correlates to rmse from pcdregister
if printLevel > 2
    figure;
    corrplotSingle([asymmMeans',pcAsymmsRmses'], 'varNames', ["Asymmetry index", "Asymmetry rmse"]);
    set(gcf,'color','w');
    title(append("Asymmetry index: ", string(asymmetryVersion), " vs asymmetry rmse"));

    % compare whether asymmStd also correlates
    figure;
    corrplotSingle([pcAsymmsRmses',pcAsymmsStds'], 'varNames', ["Asymmetry rmse", "Asymmetry std"]);
    set(gcf,'color','w');
    title(append("Asymmetry rmse: ", string(asymmetryVersion), " vs asymmetry std"));

end
%% evaluate 6 regions, left/right, ThSp, LSp, Sac

% custom rmse for full map (compare to cpd rmse)
addpath("Utils")
pcLeftAsymmsRmses = [];
pcRightAsymmsRmses = [];
pcLeftDirValues = [];
pcRightDirValues = [];
for i=folderList
    close all;
    subjectPath = append(dirlist(i).folder,'/',dirlist(i).name);
    subjectNr = dirlist(i).name;
    outputPath = append(subjectPath, "/Output");

    for j=1:100
        pc1Path = append(outputPath, "/AsymmetryPc1_",string(asymmetryVersion),"_",string(j),".ply");
        pc2Path = append(outputPath, "/AsymmetryPc2_",string(asymmetryVersion),"_",string(j),".ply");
        if ~exist(pc1Path, 'file') || ~exist(pc2Path, 'file')
            break;
        end
        pc1 = pcread(pc1Path);
        pc2 = pcread(pc2Path);
        tic
        % split into parts
        pc1Left = pointCloud(pc1.Location(pc1.Location(:,1)<0, :));
        pc2Left = pointCloud(pc2.Location(pc2.Location(:,1)<0, :));
        pc1Right = pointCloud(pc1.Location(pc1.Location(:,1)>0, :));
        pc2Right = pointCloud(pc2.Location(pc2.Location(:,1)>0, :));
        [~, asymmPcLeftRmse, ~, leftDirValue] = pcrmse_fast(pc1Left, pc2Left, 0.05*1000, [], [], [0 0 1]); % 5cm threshold, no downsampling
        [~, asymmPcRightRmse, ~, rightDirValue] = pcrmse_fast(pc1Right, pc2Right, 0.05*1000, [], [], [0 0 1]); % 5cm threshold, no downsampling
        pcLeftDirValues(str2num(subjectNr)) = leftDirValue;
        pcRightDirValues(str2num(subjectNr)) = rightDirValue;
        pcLeftAsymmsRmses(str2num(subjectNr)) = sign(leftDirValue)*asymmPcLeftRmse;
        pcRightAsymmsRmses(str2num(subjectNr)) = sign(rightDirValue)*asymmPcRightRmse;
        toc
    end
end

%% read cobb angles and directions
if xmlPath ~= ""
    if groupName == "Balgrist"
        if endsWith(xmlPath,".xml")
            subjectEosExam = ReadCobbAnglesFromRedCapXml(xmlPath, printLevel);
        else
            addpath("Utils")
            subjectEosExam = GetRedCapCobbAngles(xmlPath, true);
            subjectEosExam = subjectEosExam';
        end
    end

    % get a signed Cobb angle (right positive, left negative)
    plotPcRightAsymmsRmses = pcRightAsymmsRmses;
    plotPcLeftAsymmsRmses = pcLeftAsymmsRmses;
    
    % correlation plot left right asymmetry rmse
    if printLevel > 2
        figure;
        % make right positive, left negative
        inds = pcRightAsymmsRmses<0;
        pcRightAsymmsRmsesAbs = pcRightAsymmsRmses;
        pcRightAsymmsRmsesAbs(inds) = -pcRightAsymmsRmses(inds);
        inds = pcLeftAsymmsRmses<0;
        pcLeftAsymmsRmsesAbs = pcLeftAsymmsRmses;
        pcLeftAsymmsRmsesAbs(inds) = -pcLeftAsymmsRmses(inds);
        [R, PValue] = corrplotSingle([pcLeftAsymmsRmsesAbs',pcRightAsymmsRmsesAbs'], 'varNames', ["Left asymmetry index", "Right asymmetry index"]);
        set(gcf,'color','w');
        title(append("Left Asymmetry index: ", string(asymmetryVersion), " vs Right side"));
    end
end

%% sweep approach
% custom rmse for full map (compare to cpd rmse)
addpath("Utils")
pcLeftAsymmsRmses = [];
pcRightAsymmsRmses = [];
pcLeftDirValues = [];
pcRightDirValues = [];
pcLeftsAsymmsRmses = [];
pcRightsAsymmsRmses = [];
islRxs = [];
islRxsMediumLarge = [];
islRxsLarge = [];
largeRxSubjectNrs = [];
largeCobbAngle10SubjectNrs = find(xlsPrimaryCobbAngles>10);
largeCobbAngle20SubjectNrs = find(xlsPrimaryCobbAngles>20);
largeCobbAngle40SubjectNrs = find(xlsPrimaryCobbAngles>40);
islCobbLarge10 = nan(1,maxSubjectNr);
islCobbLarge20 = nan(1,maxSubjectNr);
islCobbLarge40 = nan(1,maxSubjectNr);

for i=folderList
    close all;
    subjectPath = append(dirlist(i).folder,'/',dirlist(i).name);
    subjectNr = dirlist(i).name;
    outputPath = append(subjectPath, "/Output");

    % TODO copy from above
    % use manual symmetry line
    % read pc ESL from Marker file
    markerFiles = dir(append(outputPath,'/',subjectNr,'_Markers2_*.json'));
    % use last one
    markerFile = markerFiles(size(markerFiles, 1));
    filetext = fileread(append(markerFile.folder, "/", markerFile.name));
    jsonObject = jsondecode(filetext);
    if strcmp(jsonObject.subjectName,subjectNr) == 0
        disp('Warning: this data does not belong to this subject!')
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

    for j=1:100
        pc1Path = append(outputPath, "/AsymmetryPc1_",string(asymmetryVersion),"_",string(j),".ply");
        pc2Path = append(outputPath, "/AsymmetryPc2_",string(asymmetryVersion),"_",string(j),".ply");
        if ~exist(pc1Path, 'file') || ~exist(pc2Path, 'file')
            break;
        end
        pc1 = pcread(pc1Path);
        pc2 = pcread(pc2Path);
        % split into parts
        pc1Left = pointCloud(pc1.Location(pc1.Location(:,1)<0, :));
        pc2Left = pointCloud(pc2.Location(pc2.Location(:,1)<0, :));
        pc1Right = pointCloud(pc1.Location(pc1.Location(:,1)>0, :));
        pc2Right = pointCloud(pc2.Location(pc2.Location(:,1)>0, :));
        minY = min(pc1.YLimits(1), pc2.YLimits(1));
        maxY = max(pc1.YLimits(2), pc2.YLimits(2));
        % sweep
        sweepSteps = 1:12;
        pcLeftsAsymmsRmsesTemp = [];
        pcRightsAsymmsRmsesTemp = [];
        tic
        for swi=sweepSteps
            % cut region
            deltaY = (maxY-minY)/length(sweepSteps);
            lowerY = minY+(swi-1)*deltaY;
            upperY = minY+(swi)*deltaY;
            pc1LeftT = pointCloud(pc1Left.Location(pc1Left.Location(:,2)>lowerY & pc1Left.Location(:,2)<upperY, :));
            pc2LeftT = pointCloud(pc2Left.Location(pc2Left.Location(:,2)>lowerY & pc2Left.Location(:,2)<upperY, :));
            pc1RightT = pointCloud(pc1Right.Location(pc1Right.Location(:,2)>lowerY & pc1Right.Location(:,2)<upperY, :));
            pc2RightT = pointCloud(pc2Right.Location(pc2Right.Location(:,2)>lowerY & pc2Right.Location(:,2)<upperY, :));

            [a2, asymmPcLeftRmse, b2, leftDirValue] = pcrmse_fast(pc1LeftT, pc2LeftT, 0.05*1000, [], [], [0 0 1]); % 5cm threshold, no downsampling
            [~, asymmPcRightRmse, ~, rightDirValue] = pcrmse_fast(pc1RightT, pc2RightT, 0.05*1000, [], [], [0 0 1]); % 5cm threshold, no downsampling
            try
            pcLeftsAsymmsRmsesTemp(swi) = sign(leftDirValue)*asymmPcLeftRmse;
            pcRightsAsymmsRmsesTemp(swi) = sign(rightDirValue)*asymmPcRightRmse;
            catch
                keyboard;
            end
        end
        toc
        pcLeftsAsymmsRmses(str2num(subjectNr), 1:length(sweepSteps)) = pcLeftsAsymmsRmsesTemp;
        pcRightsAsymmsRmses(str2num(subjectNr), 1:length(sweepSteps)) = pcRightsAsymmsRmsesTemp;
        if printLevel > 1
            figure;
            imagesc([pcLeftsAsymmsRmsesTemp' pcRightsAsymmsRmsesTemp'])
        end
        pcAsymmsRmsesDiff = pcRightsAsymmsRmsesTemp-pcLeftsAsymmsRmsesTemp;

        % check correlation with pLine (ISL)
        % bring isl line to same number of samples
        islMinY = min(islLine(:,2));
        islMaxY = max(islLine(:,2));
        deltaY = (islMaxY-islMinY)/length(sweepSteps);
        islLineMeansX = [];
        for swi=sweepSteps
            % cut region
            lowerY = islMinY+(swi-1)*deltaY;
            upperY = islMinY+(swi)*deltaY;
            islLineTMeanX = mean(islLine(islLine(:,2)>lowerY & islLine(:,2)<upperY, 1));
            islLineMeansX(swi) = islLineTMeanX;
        end

        % TODO combine Asymm map & ESL?
        eslMinY = min(eslLine(:,2));
        eslMaxY = max(eslLine(:,2));
        deltaYe = (eslMaxY-eslMinY)/length(sweepSteps);
        eslLineMeansX = [];
        for swi=sweepSteps
            % cut region
            lowerYe = eslMinY+(swi-1)*deltaYe;
            upperYe = eslMinY+(swi)*deltaYe;
            eslLineTMeanX = mean(eslLine(eslLine(:,2)>lowerYe & eslLine(:,2)<upperYe, 1));
            eslLineMeansX(swi) = eslLineTMeanX;
        end

        lineUnderInvestigation = pcAsymmsRmsesDiff;
        %lineUnderInvestigation = eslLineMeansX;
        [islRx,~,~,~] = corrcoef(islLineMeansX, lineUnderInvestigation);
        islRx21 = islRx(2,1);
        % shape correlation
        [islRx1,~,~,~] = corrcoef(islLineMeansX(1:end-1), lineUnderInvestigation(2:end));
        [islRx2,~,~,~] = corrcoef(islLineMeansX(1:end-2), lineUnderInvestigation(3:end));
        [islRx3,~,~,~] = corrcoef(islLineMeansX(2:end), lineUnderInvestigation(1:end-1));
        [islRx4,~,~,~] = corrcoef(islLineMeansX(3:end), lineUnderInvestigation(1:end-2));
        % calc error in mm as well
        islRx1mm = abs(islLineMeansX(1:end-1)- lineUnderInvestigation(2:end));
        islRx2mm = abs(islLineMeansX(1:end-2)- lineUnderInvestigation(3:end));
        islRx3mm = abs(islLineMeansX(2:end)- lineUnderInvestigation(1:end-1));
        islRx4mm = abs(islLineMeansX(3:end)- lineUnderInvestigation(1:end-2));
        if allowShift>0
            islRx21 = max([islRx(2,1),islRx1(2,1),islRx3(2,1)]);
        end
        if allowShift>1
            islRx21 = max([islRx(2,1),islRx1(2,1),islRx2(2,1),islRx3(2,1),islRx4(2,1)]);
        end
        if islRx21<0.3 && islRx21>0.2
            disp("islRx21<0.3 && islRx21>0.2")
            %keyboard;
        end
        islRxs(str2num(subjectNr)) = islRx21;
        if max(abs(islLineMeansX))>20
            largeRxSubjectNrs = [largeRxSubjectNrs str2num(subjectNr)];
            islRxsLarge(str2num(subjectNr)) = islRx21;
            if isnan(islRxsLarge(str2num(subjectNr)))
                keyboard;
            end
        else
            islRxsLarge(str2num(subjectNr)) =nan;
        end
        if max(abs(islLineMeansX))>9
            islRxsMediumLarge(str2num(subjectNr)) = islRx21;
        else
            islRxsMediumLarge(str2num(subjectNr)) =nan;
        end
        if sum(str2num(subjectNr)==largeCobbAngle10SubjectNrs)>0
            islCobbLarge10(str2num(subjectNr)) = islRx21;
            if isnan(islCobbLarge10(str2num(subjectNr)))
                keyboard;
            end
        else
            islCobbLarge10(str2num(subjectNr)) =nan;
        end
        if sum(str2num(subjectNr)==largeCobbAngle20SubjectNrs)>0
            islCobbLarge20(str2num(subjectNr)) = islRx21;
            if isnan(islCobbLarge20(str2num(subjectNr)))
                keyboard;
            end
        else
            islCobbLarge20(str2num(subjectNr)) =nan;
        end
        if sum(str2num(subjectNr)==largeCobbAngle40SubjectNrs)>0
            islCobbLarge40(str2num(subjectNr)) = islRx21;
            if isnan(islCobbLarge40(str2num(subjectNr)))
                keyboard;
            end
        else
            islCobbLarge40(str2num(subjectNr)) =nan;
        end
        if printLevel > 1
            figure;
            plot(islLineMeansX, 1:12)
            hold on
            plot(pcAsymmsRmsesDiff, 1:12)
            set ( gca, 'ydir', 'reverse' )
            figure;
            plot(islLineMeansX(1:end-2), 1:10)
            hold on
            plot(lineUnderInvestigation(3:end), 1:10)
            set ( gca, 'ydir', 'reverse' )
            disp("")
        end
    end
end

% check correlation with ISL
figure;
boxplot([islRxs']);
xticklabels(["coronal"]);
title("Correlation between AsymMap-X / coronal ISL")
if saveOutput>1
    if ~exist(commonOutputPath, 'dir')
        mkdir(commonOutputPath)
    end
    saveas(gcf, append(commonOutputPath, "/AsymMapUpright_CorrplotAsymMapXIslX_",groupName,".fig"))
    exportgraphics(gca, append(commonOutputPath, "/AsymMapUpright_CorrplotAsymMapXIslX_",groupName,".png"),"Resolution",600)
end

if printLevel > 1
    figure;
    boxplot([islRxsMediumLarge']);
    xticklabels(["frontal"]);
    title("Correlation between AsymmMap-X / ISL-X lines (>9 deviations")
    
    figure;
    boxplot([islRxsLarge']);
    xticklabels(["frontal"]);
    title("Correlation between AsymmMap-X / ISL-X lines (only large deviations)")
end

figure;
boxplot([islCobbLarge10']);
xticklabels(["coronal"]);
title("Correlation between AsymMap-X / coronal ISL (Cobb angles > 10°)")
if saveOutput>1
    if ~exist(commonOutputPath, 'dir')
        mkdir(commonOutputPath)
    end
    saveas(gcf, append(commonOutputPath, "/AsymMapUpright_CorrplotAsymMapXIslX10_",groupName,".fig"))
    exportgraphics(gca, append(commonOutputPath, "/AsymMapUpright_CorrplotAsymMapXIslX10_",groupName,".png"),"Resolution",600)
end

figure;
boxplot([islCobbLarge20']);
xticklabels(["coronal"]);
title("Correlation between AsymMap-X / coronal ISL (Cobb angles > 20°)")
if saveOutput>1
    if ~exist(commonOutputPath, 'dir')
        mkdir(commonOutputPath)
    end
    saveas(gcf, append(commonOutputPath, "/AsymMapUpright_CorrplotAsymMapXIslX20_",groupName,".fig"))
    exportgraphics(gca, append(commonOutputPath, "/AsymMapUpright_CorrplotAsymMapXIslX20_",groupName,".png"),"Resolution",600)
end

figure;
boxplot([islCobbLarge40']);
xticklabels(["coronal"]);
title("Correlation between AsymMap-X / coronal ISL (Cobb angles > 40°)")
if saveOutput>1
    if ~exist(commonOutputPath, 'dir')
        mkdir(commonOutputPath)
    end
    saveas(gcf, append(commonOutputPath, "/AsymMapUpright_CorrplotAsymMapXIslX40_",groupName,".fig"))
    exportgraphics(gca, append(commonOutputPath, "/AsymMapUpright_CorrplotAsymMapXIslX40_",groupName,".png"),"Resolution",600)
end

%% functions
function doSaveCurrentImage(name, commonOutputPath)
saveas(gcf, append(commonOutputPath, "/",name,".fig"))
exportgraphics(gca, append(commonOutputPath, "/",name,".png"),"Resolution",600)
end