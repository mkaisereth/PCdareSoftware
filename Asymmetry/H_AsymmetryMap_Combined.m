clearvars -except loopCounter; close all; clc;
printLevel = 0;
saveOutput=1;

loadLastFiles = false;

% Version
% 4 - flip according to ESL and icp register
asymmetryVersion = 4;

evalSubset=1:30;

% Balgrist
global subFolder;
subFolder="";
% AsymMap paper
basePath1 = "./Data/"+subFolder+"/Upright"
xmlPath = "./Data/"+subFolder+"/CobbAngles.csv";
csvPath = [];
commonOutputPath = append(basePath1, "/Output");

basePaths = basePath1;
groupName = "Balgrist";
plyFilter = "/*_cut_ds.ply";

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
            if j>=2
                keyboard
            end
            pcPath = append(plyFiles(j).folder,'/',plyFiles(j).name);
    
            pc = pcread(pcPath);
    
            rmse1 = 0;
            rmse2 = 0;
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
                sampleRatio = 0.002; % 2mm
                pcTemp = pcdownsample(pointCloud(pc_pLine1), "gridAverage", sampleRatio);
                pc_pLine1 = pcTemp.Location;

                % mirror pc
                pc_pLine2 = pc_pLine1;
                pc_pLine2(:,3) = -pc_pLine2(:,3);
        
                rotyAngle = 180;
                Rz =[cosd(rotyAngle) 0 sind(rotyAngle); 0 1 0; -sind(rotyAngle) 0 cosd(rotyAngle)];
                pc_pLine2 = (Rz * pc_pLine2')';
        
                if printLevel > 1
                    figure;
                    pcshow(pc_pLine1, 'r');
                    hold on;
                    pcshow(pc_pLine2, 'g');
                end
                %% now use this to get the cut point cloud
        
                maxX_pcpl1 = quantile(pc_pLine1(:,1),0.9);
                maxX_pcpl1 = 0.75*maxX_pcpl1(1);
                minX_pcpl1 = quantile(pc_pLine1(:,1),0.1);
                minX_pcpl1 = 0.75*minX_pcpl1(1);
                maxX_pcpl1 = min(abs(maxX_pcpl1), abs(minX_pcpl1));
                minX_pcpl1 = - maxX_pcpl1;
                pc_pLine1_cut = pc_pLine1;
                pc_pLine1_cut(pc_pLine1_cut(:,1)>maxX_pcpl1, :) = [];
                
                pc_pLine1_cut(pc_pLine1_cut(:,1)<minX_pcpl1, :) = [];
                pc_pLine2_cut = pc_pLine2;
                pc_pLine2_cut(pc_pLine2_cut(:,1)>maxX_pcpl1, :) = [];
                pc_pLine2_cut(pc_pLine2_cut(:,1)<minX_pcpl1, :) = [];
                % test cut above and below
                maxY_pl1 = max(pLine1(:,2));
                minY_pl1 = min(pLine1(:,2));
                pc_pLine1_cut(pc_pLine1_cut(:,2)>maxY_pl1, :) = [];
                pc_pLine1_cut(pc_pLine1_cut(:,2)<minY_pl1, :) = [];
                pc_pLine2_cut(pc_pLine2_cut(:,2)>maxY_pl1, :) = [];
                pc_pLine2_cut(pc_pLine2_cut(:,2)<minY_pl1, :) = [];
        
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
                    pcshow(pc_pLine1_cut, 'r');
                    hold on;
                    pcshow(pcReg2_pcpl.Location, 'g');
                    if saveOutput>2
                        subjectOutputPath = append(subjectPath, "/Output");
                        mkdir(subjectOutputPath);
                        saveas(f207, append(subjectOutputPath, '/Subject_asymmPc.fig'));
                    end
                end
                rmse1 = rmse_pcpl;
                
                % create asymmetry map
                pcLoc2d = pc_pLine1_cut;
                pcLoc2d(:,3) = 0;
                minPcRegLoc2d = pcReg2_pcpl.Location;
                minPcRegLoc2d(:,3) = 0;
                minPcReg2d = pointCloud(minPcRegLoc2d);
                [Idx, Dx] = knnsearch(minPcRegLoc2d, pcLoc2d);

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
                
                %% asymmetry Version 4 (Version 4.2)
                if asymmetryVersion == 4
        
                    %% upsampling esl
                    % get eslLinePts for rotation
                    eslLineP = jsonObject.eslLinePts;
                    if contains(subjectPath,"Upright2022")
                        eslLineP = pctransform(pointCloud(eslLineP), pc2xrayTform).Location;
                    end
                    pc_eslLineP = pointCloud(eslLineP);
                    pc_eslLineP = pc_eslLineP.Location;
        
        
                    % apply a spline to eslLinePts for upsampling of the points
                    SmoothingSplineParam = 0;          % this parameter indicates whether the smoothingParam is linear or polynomial    % 0.0001;
                    tmpVar = pc_eslLineP;
                    % y gets evenly spaced
                    deltaY = (max(tmpVar(:,2))-min(tmpVar(:,2)))/length(tmpVar);        % parameters for y-values
                    deltaY = deltaY/2;       % increases the resolution
                    yy = min(tmpVar(:,2)):deltaY:max(tmpVar(:,2))+deltaY/4;
        
        
                    px = fit(pc_eslLineP(:,2), pc_eslLineP(:,1), 'cubicinterp');
                    %             px = fit(eslLineP(:,2),eslLineP(:,1),'cubicspline');
                    xx = feval(px,yy)';
                    pz = fit(pc_eslLineP(:,2), pc_eslLineP(:,3), 'cubicinterp');
                    %             pz = fit(eslLineP(:,2),eslLineP(:,3),'cubicspline');
                    zz = feval(pz,yy)';
        
                    % cut y to original data
                    eslLinePupsampled = tmpVar;%[xx',yy',zz'];
        
        
                    if printLevel > 2
                        figure;
                        pcshow(pc);
                        hold on;
                        pcshow(pc_eslLineP, 'm', 'MarkerSize', 60);
                        hold on;
                        pcshow(eslLinePupsampled, 'c', 'MarkerSize', 60);
                    end
        
                    eslLinePts = eslLinePupsampled;% pctransform(pointCloud(eslLinePupsampled),pc2xrayTform).Location;
        
                    if printLevel > 2
                        figure;
                        pcshow(pc);
                        hold on;
                        pcshow(eslLinePts, 'm','MarkerSize', 60);
                    end
        
                    %% pre-cut point cloud
                    % here we make a pre-cut point cloud where it's just cut in y-direction (C7-L5)
                    pc_pre_cut = pc.Location;
                    maxY_esl = max(eslLinePts(:,2));
                    minY_esl = min(eslLinePts(:,2));
                    pc_pre_cut(pc_pre_cut(:,2)>maxY_esl,:) = [];
                    pc_pre_cut(pc_pre_cut(:,2)<minY_esl,:) = [];
                    pc_pre_cut = pointCloud(pc_pre_cut);
        
                    if printLevel > 4
                        figure;
                        pcshow(pc_pre_cut);
                    end
        
                    %% sweep steps loop
                    % get the max and min Y values through the YLimits
                    maxY = max(pc_pre_cut.YLimits);
                    minY = min(pc_pre_cut.YLimits);
        
                    % choose the number of sweep steps to be performed, define the Y range to determine how big each segment will be
                    sweepSteps = 1:12;
                    YRange = maxY - minY;
                    YInterval = YRange/max(sweepSteps);          % use this to get segment size
        
                    % add counter & tic
                    tic;
                    counter = counter+1;
        
                    for swi = sweepSteps
                        segmentUpper = maxY - (YInterval*(swi-1));       % start at upper Ylimit and go down by YInterval for each sweep step
                        segmentLower = maxY - (YInterval*swi);           % go down from upper Ylimit by YInterval + previous amount of times the YInterval has been used (YInterval*sweepSteps)
        
                        % the point cloud gets segmented according to the upper and lower Y-limits of the segment
                        pc_segmented = pointCloud(pc_pre_cut.Location(pc_pre_cut.Location(:,2)>segmentLower& pc_pre_cut.Location(:,2)<segmentUpper,:));
                        if printLevel > 2
                            figure;
                            pcshow(pc_segmented);
                        end
        
                        % YLimits for each segment
                        pc_segm_upperY = max(pc_segmented.YLimits);
                        pc_segm_lowerY = min(pc_segmented.YLimits);
        
                        % segment the esl
                        pc_esl = pointCloud(eslLinePts);
                        pc_esl_segm = pointCloud(pc_esl.Location(pc_esl.Location(:,2)>pc_segm_lowerY & pc_esl.Location(:,2)<pc_segm_upperY,:));
        
                        %                 figure;
                        %                 pcshow(pc_esl);
                        %
                        %                 figure;
                        %                 pcshow(pc_esl_segm);
        
                        % calculate the mean and subtract it from the segment
                        mean_esl_segm = mean(pc_esl_segm.Location(:,1));  %just x value
                        pc_segmented1 = pc_segmented.Location - [mean_esl_segm,0,0];
        
                        if printLevel > 2
                            figure;
                            pcshow(pc_esl_segm.Location,'m');
                            hold on;
                            pcshow(pc_segmented1);
                        end
        
        
                        % cut each segment only in x-direction
                        maxX_pc = quantile(pc_segmented1(:,1),0.9);
                        maxX_pc = 0.75*maxX_pc(1);
                        minX_pc = quantile(pc_segmented1(:,1),0.9);
                        minxX_pc = 0.75*minX_pc(1);
                        maxX_pc = min(abs(maxX_pc), abs(minX_pc));
                        minX_pc = - maxX_pc;
                        pc_segmented_cut = pc_segmented1;
                        pc_segmented_cut(pc_segmented_cut(:,1)>maxX_pc,:) = [];
                        pc_segmented_cut(pc_segmented_cut(:,1)<minX_pc,:) = [];
        
        
                        if printLevel > 2
                            figure;
                            pcshow(pc_segmented_cut);
                        end
        
                        % set the rotation angle
                        rotationangle = 180;
                        Ry = [cosd(rotationangle) 0 sind(rotationangle); 0 1 0; -sind(rotationangle) 0 cosd(rotationangle)];
        
                        % rotation of the segment
                        pc_segmented2 = pc_segmented_cut;
                        pc_segmented2(:,3) = - pc_segmented2(:,3);
                        pc_segmented_rot = (Ry * pc_segmented2')';
        
                        if printLevel > 3
                            figure;
                            pcshow(pc_segmented_cut,'r');
                            hold on;
                            pcshow(pc_segmented_rot,'c');
                        end
        
                        %% icp
                        % icp is done for each segment
                        %                 [~, pcReg_icp, rmse_pc] = pcregistericp(pointCloud(pc_segmented_rot),pointCloud(pc_segmented_cut),"MaxIterations",30,"Metric","pointToPoint",Tolerance=[0.01 0.1]);        %"MaxInlierDistance",1 --> originally used
                        [~, pcReg_icp, rmse_pc] = pcregistericp(pointCloud(pc_segmented_rot),pointCloud(pc_segmented_cut),"MaxIterations",30,Tolerance=[0.01 0.1]);
                        if printLevel > 1
                            figure;
                            pcshow(pc_segmented_cut,'r');
                            hold on;
                            pcshow(pcReg_icp.Location,'c');
                        end
        
        
                        % split pcReg_icp into left & right
                        pcReg_icpLeft = pointCloud(pcReg_icp.Location(pcReg_icp.Location(:,1)<0,:));
                        pcReg_icpRight = pointCloud(pcReg_icp.Location(pcReg_icp.Location(:,1)>0,:));
        
                        % split pc_segmented_cut into left & right
                        pc_segmented_cut = pointCloud(pc_segmented_cut);
                        pc_segmented_cutLeft = (pc_segmented_cut.Location(pc_segmented_cut.Location(:,1)<0,:));
                        pc_segmented_cutRight = (pc_segmented_cut.Location(pc_segmented_cut.Location(:,1)>0,:));
                        % turn into point cloud again so pcrmse will work
                        pc_segmented_cutLeft = pointCloud(pc_segmented_cutLeft);
                        pc_segmented_cutRight = pointCloud(pc_segmented_cutRight);
        
                        % also cut max again
                        maxX_left = max(min(pcReg_icpLeft.Location(:,1)),min(pc_segmented_cutLeft.Location(:,1)));
                        minX_right = min(max(pcReg_icpRight.Location(:,1)),max(pc_segmented_cutRight.Location(:,1)));
                        pcReg_icpLeft = pointCloud(pcReg_icpLeft.Location(pcReg_icpLeft.Location(:,1)>maxX_left,:));
                        pcReg_icpRight = pointCloud(pcReg_icpRight.Location(pcReg_icpRight.Location(:,1)<minX_right,:));
                        pc_segmented_cutLeft = (pc_segmented_cutLeft.Location(pc_segmented_cutLeft.Location(:,1)>maxX_left,:));
                        pc_segmented_cutRight = (pc_segmented_cutRight.Location(pc_segmented_cutRight.Location(:,1)<minX_right,:));
                        pc_segmented_cutLeft = pointCloud(pc_segmented_cutLeft);
                        pc_segmented_cutRight = pointCloud(pc_segmented_cutRight);
        
                        if printLevel > 1
                            figure;
                            pcshow(pcReg_icpLeft.Location,'r');
                            hold on;
                            pcshow(pcReg_icpRight.Location,'r');
                            pcshow(pc_segmented_cutLeft.Location,'c');
                            pcshow(pc_segmented_cutRight.Location,'c');
                        end
        
                        % calculate rmse
                        [asymmPcLeftRmse, ~, ~, leftDirValue] = pcrmse3(pc_segmented_cutLeft,pcReg_icpLeft, 0.05*1000, 0, [0 0 1]);
                        [asymmPcRightRmse, ~, ~, rightDirValue] = pcrmse3(pc_segmented_cutRight,pcReg_icpRight, 0.05*1000, 0, [0 0 1]);
                        pcLeftAsymmRmsesTemp(swi) = sign(leftDirValue)*asymmPcLeftRmse;
                        pcRightAsymmRmsesTemp(swi) = sign(rightDirValue)*asymmPcRightRmse;
                    end
        
        
                    %% asymmetry map & asymmetry index
                    % create the figure for the asymmetry map
                    pcLeftAsymmRmses(str2num(subjectNr), 1:length(sweepSteps)) = pcLeftAsymmRmsesTemp;
                    pcRightAsymmRmses(str2num(subjectNr), 1:length(sweepSteps)) = pcRightAsymmRmsesTemp;
        
                    % create asymmetry map
                    if printLevel > 0
                        figure;
                        imagesc([pcLeftAsymmRmsesTemp' pcRightAsymmRmsesTemp']);
                    end
        
                    % calculate the asymmetry index    -> you need to use Temp values!!!!!
                    asymmetryIndexSumLeft = sum(abs(pcLeftAsymmRmsesTemp));
                    asymmetryIndexSumRight = sum(abs(pcRightAsymmRmsesTemp));
        
                    asymmetryIndexMeanLeft = mean(abs(pcLeftAsymmRmsesTemp));
                    asymmetryIndexMeanRight = mean(abs(pcRightAsymmRmsesTemp));
        
                    asymmetryIndexMaxLeft = max(abs(pcLeftAsymmRmsesTemp));
                    asymmetryIndexMaxRight = max(abs(pcRightAsymmRmsesTemp));
        
                    % save the asymmetry value for each subject
                    %asymmetryVal{num}.Index = asymmetryIndexMeanRight;
                    %asymmetryVal{num}.SubjectNr = subjectNr;
                    rmse2 = asymmetryIndexMeanRight;
        
                    % toc & counter display
                    toc;
                    disp(counter+"/"+numTotal);
                end

                if saveOutput>0
                    outputFolder = append(subjectPath, '/Output');
                    if ~exist(outputFolder, 'dir')
                        mkdir(outputFolder);
                    end
                    jsonObject.SubjectNr = subjectNr;
                    jsonObject.AsymmetryMean = rmse1;
                    jsonObject.AsymmetryMean2 = rmse2;
                    jsonString = jsonencode(jsonObject);
                    fid=fopen(append(outputFolder, "/AsymmetryVals",string(asymmetryVersion),"c_",string(j),".json"), 'w');
                    fprintf(fid, jsonString);
                    fclose(fid);

                    % save the two point clouds as well for later use
                    %pcwrite(pointCloud(pc_pLine1_cut), append(outputFolder, "/AsymmetryPc1_",string(asymmetryVersion),"_",string(j),".ply"), "Encoding", "binary");
                    %pcwrite(pcReg2_pcpl, append(outputFolder, "/AsymmetryPc2_",string(asymmetryVersion),"_",string(j),".ply"), "Encoding", "binary");
                end

            end
            
            asymmetryVal{num}.Mean = rmse1;
            asymmetryVal{num}.Mean2 = rmse2;
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
        filetext = fileread(append(outputFolder, "/AsymmetryVals",string(asymmetryVersion),"c_1.json")); % TODO this only evals first ply
        jsonObject = jsondecode(filetext);
        asymmetryVal{num}.Mean = jsonObject.AsymmetryMean;
        asymmetryVal{num}.Mean2 = jsonObject.AsymmetryMean2;
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
asymmMeans2 = nan(1, maxSubjectNr);
for i=1:length(asymmetryVal)
    asymmMeans(str2num(asymmetryVal{i}.SubjectNr)) = asymmetryVal{i}.Mean;
    asymmMeans2(str2num(asymmetryVal{i}.SubjectNr)) = asymmetryVal{i}.Mean2;
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
    plotAsymmMeans2 = asymmMeans2(1:dataLength);
    plotXlsPrimaryCobbAngles = xlsPrimaryCobbAngles(1:dataLength);
    plot(plotAsymmMeans,plotXlsPrimaryCobbAngles, '*');
    title("Relation between asymmetry means and primary Cobb angle")
    xlabel("asymmetrie mean")
    ylabel("Cobb angle [°]")
else
    plotAsymmMeans = asymmMeans;
    plotAsymmMeans2 = asymmMeans2;
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
        saveas(gcf, append(commonOutputPath, "/AsymMapCombined_CorrplotAsymIndsCobbAngles_",groupName,".fig"))
        exportgraphics(gca, append(commonOutputPath, "/AsymMapCombined_CorrplotAsymIndsCobbAngles_",groupName,".png"),"Resolution",600)
    end
    [R, PValue, RL, RU] = corrcoef([plotAsymmMeans',plotXlsPrimaryCobbAngles'], 'Rows', 'complete')

    % correlation plot
    figure;
    [R2, PValue2] = corrplotSingle([plotAsymmMeans2',plotXlsPrimaryCobbAngles'], 'varNames', ["Asymmetry index 2", "Cobb angle"]);
    set(gcf,'color','w');
    title(append("Asymmetry index 2: ", string(asymmetryVersion), " vs Cobb angle"));
    if saveOutput>1
        if ~exist(commonOutputPath, 'dir')
            mkdir(commonOutputPath)
        end
        saveas(gcf, append(commonOutputPath, "/AsymMapCombined_CorrplotAsymInds2CobbAngles_",groupName,".fig"))
        exportgraphics(gca, append(commonOutputPath, "/AsymMapCombined_CorrplotAsymInds2CobbAngles_",groupName,".png"),"Resolution",600)
    end
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

% now bring them together
mdl1 = fitlm(double(plotAsymmMeans)', plotXlsPrimaryCobbAngles')
mdl1CobbAngles = mdl1.feval(double(plotAsymmMeans));

mdl2 = fitlm(double(plotAsymmMeans2)', plotXlsPrimaryCobbAngles')
mdl2CobbAngles = mdl2.feval(double(plotAsymmMeans2));
mdlCobbAngles = (mdl1CobbAngles + mdl2CobbAngles)/2;

figure;
corrplotSingle([mdlCobbAngles',plotXlsPrimaryCobbAngles'], 'varNames', ["Combined Asymmetry angle", "Cobb angle"]);
set(gcf,'color','w');
title(append("Combined Asymmetry angle: ", string(asymmetryVersion), " vs Cobb angle"));
if saveOutput>1
    if ~exist(commonOutputPath, 'dir')
        mkdir(commonOutputPath)
    end
    saveas(gcf, append(commonOutputPath, "/AsymMapCombined_CorrplotAsymAnglesCobbAngles_",groupName,".fig"))
    exportgraphics(gca, append(commonOutputPath, "/AsymMapCombined_CorrplotAsymAnglesCobbAngles_",groupName,".png"),"Resolution",600)
end

rmse1 = rmse(mdl1CobbAngles, plotXlsPrimaryCobbAngles, 'omitnan');
[R1, PValue1, RL1, RU1] = corrcoef([mdl1CobbAngles',plotXlsPrimaryCobbAngles'], 'Rows', 'complete');
disp(num2str(rmse1, '%.2f') + " " + num2str(R1(1,2), '%.2f') + " " + num2str(PValue1(1,2),'%.2f')+ " " + num2str(RL1(1,2),'%.2f')+ " " + num2str(RU1(1,2),'%.2f'))
rmse2 = rmse(mdl2CobbAngles, plotXlsPrimaryCobbAngles, 'omitnan');
[R2, PValue2, RL2, RU2] = corrcoef([mdl2CobbAngles',plotXlsPrimaryCobbAngles'], 'Rows', 'complete');
disp(num2str(rmse2, '%.2f') + " " + num2str(R2(1,2), '%.2f') + " " + num2str(PValue2(1,2),'%.2f')+ " " + num2str(RL2(1,2),'%.2f')+ " " + num2str(RU2(1,2),'%.2f'))
rmsec = rmse(mdlCobbAngles, plotXlsPrimaryCobbAngles, 'omitnan');
[Rc, PValuec, RLc, RUc] = corrcoef([mdlCobbAngles',plotXlsPrimaryCobbAngles'], 'Rows', 'complete');
disp(num2str(rmsec, '%.2f') + " " + num2str(Rc(1,2), '%.2f') + " " + num2str(PValuec(1,2),'%.2f')+ " " + num2str(RLc(1,2),'%.2f')+ " " + num2str(RUc(1,2),'%.2f'))

%% functions
function RMSE = rmse(V_out,V_exp,nanflag)
RMSE = sqrt(mean((V_exp - V_out).^2, nanflag));
end