clearvars -except loopCounter; close all; clc;
groupName = 'Balgrist';
saveOutput = 1;

% Version
% 4 - flip according to ESL and icp register
asymmetryVersion = 4;

evalSubset=1:30;

% ply filter to get the correct ply files
plyFilter = "/*.ply";

downSampleVal = 4/1000; % 6mm (point clouds should be already at 2mm, starting with 3mm code runs fast)
% 3mm: 0.0115 sum error - 4mm: 0.0208 - 5mm: 0.0333 - 6mm: 0.0437
study = groupName;
%
global subFolder;
subFolder = "";
if study == "Balgrist"
    % Balgrist
    basepath = "./Data/"+subFolder+"/Lateral";
    basepath2 = "./Data/"+subFolder+"/Lateral";
    csvPath = "./Data/"+subFolder+"/CobbAngles.csv";
    outputPath2 = "./Data/"+subFolder+"/Lateral";

    % list folders in basepath
    dirlist = dir(basepath);
    dirlist = dirlist([dirlist.isdir]==1); % only folders
    dirlist = (dirlist(3:end));
    dirlist = natsortfiles(dirlist);    % to use natsortfiles: download "Natural-Order Filename Sort" from the Matlab file exchange (https://ch.mathworks.com/matlabcentral/fileexchange/47434-natural-order-filename-sort)
    if ~isempty(evalSubset)
        dirlist = dirlist(evalSubset);
    end
    disp(append("Evaluating until patient: ", dirlist(end).name));
    folderList = 1:size(dirlist,1);

    % do the same for basepath2
    dirlist2 = dir(basepath2);
    dirlist2 = dirlist2([dirlist2.isdir]==1); % only folders
    dirlist2 = (dirlist2(3:end));
    dirlist2 = natsortfiles(dirlist2);
    if ~isempty(evalSubset)
        dirlist2 = dirlist2(evalSubset);
    end
    disp(append("Evaluating until patient: ", dirlist2(end).name));
    folderList2 = 1:size(dirlist2,1);
end
commonOutputPath = append(basepath, "/Output");

% overview printLevels:
% 0 - no figures except correlation plots and boxplots at the end
% ...
    % 6 - shows every esl for the subject (this gives you 300+ figures per subject!!!)
printLevel = 0;

num = 0;
numTotal = size(dirlist, 1);
counter = 0;

manualValidation = false;

%% set ply file path, add for loop
for i = folderList

    % for subject path for the ply files
    subjectPath = append(dirlist(i).folder,'/',dirlist(i).name);            % folder: basepath; name = folder number
    subjectNr = dirlist(i).name;

    % increase num by one for each iteration
    num = num+1;

    minXMean = inf;             % for left bending
    minPlyPath = "";
    maxXMean = -inf;            % for right bending
    maxPlyPath = "";
    userMinPlyPath = "";        % TODO: do I even need these two lines?
    userMaxPlyPath = "";
    minJsonPath = "";
    minJsonName = "";
    maxJsonPath = "";
    maxJsonName = "";

    % get all ply files
    plyFiles = dir(append(dirlist(i).folder, "/", dirlist(i).name, plyFilter));
    % get all json files
    jsonFiles = dir(append(dirlist2(i).folder, "/", dirlist2(i).name,"/Output/Photoneo_*.json"));

    tic;
    counter = counter+1;

    %figure
    for j = 1: length(jsonFiles)
        % add the json path
        jsonPath = append(jsonFiles(j).folder,'/',jsonFiles(j).name);
        jsonPaths = fileread(jsonPath);
        json = jsondecode(jsonPaths);

        esl = json.pcLinePts;

        % apply a smoothing spline to the esl
        esl = SmoothingSpline_esl(esl);

        % offset correction
        esl_offsetcorr = offsetCorrection(esl);
        %pcshow(esl_offsetcorr)
        %view(0,-90)
        %drawnow
        % get the new min & max y values, calculate the difference to figure out if bending goes left or right using the x-values that belong to those y-values
        diffMaxMinEsl = diff_max_min(esl_offsetcorr);

        if diffMaxMinEsl < minXMean
            minXMean = diffMaxMinEsl;
            minJsonPath = jsonPath;
            minJsonName = jsonFiles(j).name;
            eslMin = esl_offsetcorr;
            eslMin_ind = j;
            eslFileFilterMin = regexp(minJsonPath,'Photoneo_[0-9]*',"match");
        end

        if diffMaxMinEsl > maxXMean
            maxXMean = diffMaxMinEsl;
            maxJsonPath = jsonPath;
            maxJsonName = jsonFiles(j).name;
            eslMax = esl_offsetcorr;
            eslMax_ind = j;
            eslFileFilterMax = regexp(maxJsonPath,'Photoneo_[0-9]*',"match");
        end
    end

    toc;

    disp(counter+"/"+numTotal);

    pcMinPath =  append(plyFiles(1).folder,"/",eslFileFilterMin,'.ply');
    pcMaxPath =  append(plyFiles(1).folder,"/",eslFileFilterMax,'.ply');
    pcMinPath2 = append(outputPath2, "/", subjectNr, "/", eslFileFilterMin,'.ply');
    pcMaxPath2 = append(outputPath2, "/", subjectNr, "/", eslFileFilterMax,'.ply');
    if ~exist(pcMinPath2, 'file')
        if ~exist(append(outputPath2, "/", subjectNr), "dir")
            mkdir(append(outputPath2, "/", subjectNr));
        end
        copyfile(pcMinPath, pcMinPath2);
    end
    if ~exist(pcMaxPath2, 'file')
        if ~exist(append(outputPath2, "/", subjectNr), "dir")
            mkdir(append(outputPath2, "/", subjectNr));
        end
        copyfile(pcMaxPath, pcMaxPath2);
    end
    minJsonPath2 = append(outputPath2, "/", subjectNr, "/Output/", minJsonName);
    if ~exist(minJsonPath2, 'file')
        if ~exist(append(outputPath2,"/", subjectNr, "/Output/"), 'dir')
            mkdir(append(outputPath2,"/", subjectNr, "/Output/"));
        end
        copyfile(minJsonPath, minJsonPath2);
    end
    maxJsonPath2 = append(outputPath2, "/", subjectNr, "/Output/", maxJsonName);
    if ~exist(maxJsonPath2, 'file')
        if ~exist(append(outputPath2,"/", subjectNr, "/Output/"), 'dir')
            mkdir(append(outputPath2,"/", subjectNr, "/Output/"));
        end
        copyfile(maxJsonPath, maxJsonPath2);
    end
    pcMin = pcread(pcMinPath2);
    pcMax = pcread(pcMaxPath2);
    if ~isempty(downSampleVal)
        pcMin = pcdownsample(pcMin, 'gridAverage', downSampleVal);
        pcMax = pcdownsample(pcMax, 'gridAverage', downSampleVal);
    end

    if printLevel > 2
        figure;
        pcshow(pcMin);
        title(append("Participant ",subjectNr," pcMin"));
        view (0,-89.9);
        figure;
        pcshow(pcMax);
        title(append("Participant ",subjectNr," pcMax"));
        view (0,-89.9);
    end

    if printLevel > 2
        figure;
        pcshow(eslMax, 'm', 'Markersize', 60);
        title(append("Participant ",subjectNr," esl Min & Max"));
        view (0,-89.9);
        hold on;
        pcshow(eslMin, 'c', 'Markersize', 60);
        view (0,-89.9);
    end

    %% manual validation of the maximum selection
    if manualValidation == true
        % the manual validation only happens if manualValidation is set to true at the beginning of the code

        targetSubjectPath = append(basepath, "/", string(subjectNr));

        % get first ply (static)
        allPlys = dir(append(targetSubjectPath, "/*.ply"));
        pcs = {};
        for plyInd=1:length(allPlys)
            pcPath = append(allPlys(plyInd).folder, "/", allPlys(plyInd).name);
            pc = pcread(pcPath);
            if ~isempty(downSampleVal)
                pc = pcdownsample(pc, 'gridAverage', downSampleVal);
            end
            pcs{plyInd} = pc;
        end

        fig1 = figure;
        set(fig1,'WindowKeyPressFcn',@FigureSpacePressed);
        global spaceKey;
        spaceKey = 0;
        maxPlyInds = [];

        targetSubjectPath = append(basepath, "/", string(subjectNr));

        % get first ply (static)
        allPlys = dir(append(targetSubjectPath, "/*.ply"));
        % clean & find min max
        maxPlyCounter = 1;
        % start with max and let user adjust
        plyInd2 = 1;
        for plyInd=1:2
            plyInd2 = eslMin_ind;
            if plyInd == 2
                plyInd2 = eslMax_ind;
            end
            pc = pcs{plyInd2};
            pcshow(pc);
            view(0,-89);
            rotate3d off;
            while true
                waitforbuttonpress();
                if spaceKey==1
                    maxPlyInds(subjectNr, maxPlyCounter) = plyInd2;
                    [maxPlyNames{subjectNr, maxPlyCounter}] = deal(allPlys(plyInd2).name);
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
                        pc = pcs{plyInd2};
                        pcshow(pc);
                        view(0,-89);
                        rotate3d off;
                    end
                    if strcmp(arrowKey,'rightarrow')==1
                        if plyInd2+1<=length(allPlys)
                            plyInd2=plyInd2+1;
                        end
                        pc = pcs{plyInd2};
                        pcshow(pc);
                        view(0,-89);
                        rotate3d off;
                    end
                    arrowKey = '';
                end
            end
        end
    end

    %% rmse calculation for eslMin & eslMax with all esls
    % we know that eslMin always bends to the left and eslMax always bends to the right --> for eslMin we look at all the right bending esls & for eslMax we look at all the left bending esls
    % temporarily convert eslMin & eslMax to point cloud to use pcrmse3 function
    eslMinpc = pointCloud(eslMin);
    eslMaxpc = pointCloud(eslMax);

    %% read in all esl files, smoothe them, invert the x-values of the esl, calculate rmse and save values
    % then I can go through the list, select the smallest rmse since that will be for the esl which has the most similar bending to my eslMin/eslMax
    jsonFilesList = dir(append(dirlist2(i).folder, "/", dirlist2(i).name,"/Output/Photoneo_*.json"));

    % index counter to go through json files
    numb = 0;
    for k = 1:length(jsonFilesList)
        subjectPath2 = append(dirlist2(i).folder,'/', dirlist2(i).name);
        outputPath = append(subjectPath2,"/Output");
        fileMarkers3 = dir(append(outputPath,'/','Photoneo_*.json'));  % use same outputPath as used the first time for calling json files
        fileMarker3 = fileMarkers3(1+numb);  % uses everything in brackets as an index ---> so we can't use size(fileMarkers3, 1) bc we will just get 73 (for subj 1) as an index
        filetextMarker3 = fileread(append(fileMarker3.folder, "/", fileMarker3.name));
        jsonMarker3 = jsondecode(filetextMarker3);
        % up the index counter by 1 for each iteration
        numb = numb+1;

        pcLinePts_other = jsonMarker3.pcLinePts;

        % for checking smoothing function
        %         figure;
        %         pcshow(pcLinePts_other);
        %         title("no smoothing");
        %         view (0,-89.9)

        % apply smoothing spline to the esl
        pcLinePts_other = SmoothingSpline_esl(pcLinePts_other);
        %         figure;
        %         pcshow(pcLinePts_other);
        %         title("smoothing");
        %         view (0,-89.9)

        if printLevel > 5
            figure
            pcshow(pcLinePts_other);
        end

        % offset correction
        pcLinePts_offsetcorr_other = offsetCorrection(pcLinePts_other);

        % get the new min & max y values, calculate the difference to figure out if bending goes left or right using the x-values that belong to those y-values
        diffMaxMin = diff_max_min(pcLinePts_offsetcorr_other);

        if diffMaxMin > 0
            % here I need to add a lable for "right"
            direction_esl(k).direction = "right";
            % add a save to right list here
            if printLevel > 4
                figure
                pcshow (pcLinePts_offsetcorr_other);
                view (0,-89.9);
                title("right");
            end

        elseif diffMaxMin < 0
            % here I need to add a lable for "left"
            direction_esl(k).direction = "left";
            % add a save to left list here
            if printLevel > 4
                figure
                pcshow (pcLinePts_offsetcorr_other);
                view (0,-89.9);
                title("left");
            end
        end

        % save the jsonPath for the esls
        direction_esl(k).jsonPath = fileMarker3.name;

        if [direction_esl(k).direction] == "right"
            % save to right struct
            direction_esl_right(k).jsonPath = fileMarker3.name;

        elseif [direction_esl(k).direction] == "left"
            % save to left struct
            direction_esl_left(k).jsonPath = fileMarker3.name;
        end
    end

    % remove all the empty fields from the structs
    fun = @ (s) all (structfun(@ isempty,s));
    id_right = arrayfun(fun, direction_esl_right);
    direction_esl_right(id_right) = [];

    id_left = arrayfun(fun, direction_esl_left);
    direction_esl_left(id_left) = [];

    for m = 1:length(direction_esl_right)
        % pcrmse3 for eslMin
        % read in all the json files going right using the jsonpath in the struct
        jsonFileName = fileread(append(outputPath,"/",direction_esl_right(m).jsonPath));
        json_esl = jsondecode(jsonFileName);
        pcLinePts_esl = json_esl.pcLinePts;
        % need to do smoothing and offset correction again for every single esl ---> surely there is a more efficient way to do this?
        pcLinePts_esl = SmoothingSpline_esl(pcLinePts_esl);
        % offset correction
        pcLinePts_offsetcorr_esl = offsetCorrection(pcLinePts_esl);
        % invert the x-values (to flip the esl to the other side so the two esls we are comparing are on the same side)
        pcLinePts_offsetcorr_esl(:,1) = - pcLinePts_offsetcorr_esl(:,1);
        % then we turn the offset corrected esl points into a point cloud
        pcLinePts_offsetcorr_esl_pc = pointCloud(pcLinePts_offsetcorr_esl);

        % now we can use pcrmse3 with eslMin to get all the rmse values
        [rmse_esl,~,~,~] = pcrmse3(eslMinpc,pcLinePts_offsetcorr_esl_pc, 0.05*1000,0,[0 0 1]);
        rmse_right(m).rmse = rmse_esl;
        rmse_right(m).jsonPath = direction_esl_right(m).jsonPath;
    end

    for n = 1:length(direction_esl_left)
        % pcrmse3 for eslMax
        % read in all the json files going right using the jsonpath in the struct
        jsonFileName = fileread(append(outputPath,"/",direction_esl_left(n).jsonPath));
        json_esl = jsondecode(jsonFileName);
        pcLinePts_esl = json_esl.pcLinePts;
        % need to do smoothing and offset correction again for every single esl ---> surely there is a more efficient way to do this?
        pcLinePts_esl = SmoothingSpline_esl(pcLinePts_esl);
        % offset correction
        pcLinePts_offsetcorr_esl = offsetCorrection(pcLinePts_esl);
        % invert the x-values
        pcLinePts_offsetcorr_esl(:,1) = - pcLinePts_offsetcorr_esl(:,1);
        % then we turn the offset corrected esl points into a point cloud
        pcLinePts_offsetcorr_esl_pc = pointCloud(pcLinePts_offsetcorr_esl);

        % now we can use pcrmse3 with eslMin to get all the rmse values
        [rmse_esl,~,~,~] = pcrmse3(eslMaxpc,pcLinePts_offsetcorr_esl_pc, 0.05*1000,0,[0 0 1]);
        rmse_left(n).rmse = rmse_esl;
        rmse_left(n).jsonPath = direction_esl_left(n).jsonPath;
    end

    % now I need to find the smallest rmse value for both conditions (eslMin & eslMax), then I need to select the smaller of those two values
    % rmse for eslMin
    rmse_list_right = [rmse_right.rmse];
    [rmse_right_sorted, sInds] = sort(rmse_list_right(:));
    min_rmse_right = rmse_right_sorted(1);
    min_rmse_right_ind = sInds(1);
    % rmse for eslMax
    rmse_list_left = [rmse_left.rmse];
    [rmse_left_sorted, sInds] = sort(rmse_list_left(:));
    min_rmse_left = rmse_left_sorted(1);
    min_rmse_left_ind = sInds(1);

    % save both to output folder
    min_rmse_left_jsonPath = append(outputPath, "/", direction_esl_left(min_rmse_left_ind).jsonPath);
    min_rmse_left_jsonPath2 = append(outputPath2,"/", subjectNr, "/Output/", direction_esl_left(min_rmse_left_ind).jsonPath);
    if ~exist(min_rmse_left_jsonPath2, 'file')
        if ~exist(append(outputPath2,"/", subjectNr, "/Output/"), 'dir')
            mkdir(append(outputPath2,"/", subjectNr, "/Output/"));
        end
        copyfile(min_rmse_left_jsonPath, min_rmse_left_jsonPath2);
    end
    min_rmse_right_jsonPath = append(outputPath, "/", direction_esl_right(min_rmse_right_ind).jsonPath);
    min_rmse_right_jsonPath2 = append(outputPath2,"/", subjectNr, "/Output/", direction_esl_right(min_rmse_right_ind).jsonPath);
    if ~exist(min_rmse_right_jsonPath2, 'file')
        if ~exist(append(outputPath2,"/", subjectNr, "/Output/"), 'dir')
            mkdir(append(outputPath2,"/", subjectNr, "/Output/"));
        end
        copyfile(min_rmse_right_jsonPath, min_rmse_right_jsonPath2);
    end
    % including ply
    min_rmse_left_esl_filefilter = regexp(direction_esl_left(min_rmse_left_ind).jsonPath,'Photoneo_[0-9]*',"match");
    min_rmse_right_esl_filefilter = regexp(direction_esl_right(min_rmse_right_ind).jsonPath,'Photoneo_[0-9]*',"match");
    min_rmse_left_pcPath = append(plyFiles(1).folder,"/",min_rmse_left_esl_filefilter,'.ply');
    min_rmse_right_pcPath = append(plyFiles(1).folder,"/",min_rmse_right_esl_filefilter,'.ply');
    min_rmse_left_pcPath2 = append(outputPath2,"/", subjectNr, "/",min_rmse_left_esl_filefilter,'.ply');
    min_rmse_right_pcPath2 = append(outputPath2,"/",subjectNr, "/", min_rmse_right_esl_filefilter,'.ply');
    if ~exist(min_rmse_left_pcPath2, 'file')
        copyfile(min_rmse_left_pcPath, min_rmse_left_pcPath2);
    end
    if ~exist(min_rmse_right_pcPath2, 'file')
        copyfile(min_rmse_right_pcPath, min_rmse_right_pcPath2);
    end

    useBoth = true;
    if useBoth
        % in this case we select eslMin
        pc_bend_min1 = pcread(pcMinPath);
        if ~isempty(downSampleVal)
            pc_bend_min1 = pcdownsample(pc_bend_min1, 'gridAverage', downSampleVal);
        end
        esljsonpath1 = minJsonPath;
        % bend_condition = -1 for pc_bend_min = eslMin
        bend_condition1 = -1;
        % find the json file for the opposite point cloud
        min_path_right = [rmse_right.rmse] == min_rmse_right;
        index_opp1 = find(min_path_right);

        temp_esl1 = rmse_right(index_opp1);
        esl_file_name1 = temp_esl1.jsonPath;
        esl_filefilter1 = regexp(esl_file_name1,'Photoneo_[0-9]*',"match");
        % in this case we select eslMax
        pc_bend_min2 = pcread(pcMaxPath);
        if ~isempty(downSampleVal)
            pc_bend_min2 = pcdownsample(pc_bend_min2, 'gridAverage', downSampleVal);
        end
        esljsonpath2 = maxJsonPath;
        % bend_condition = 1 for pc_bend_min = eslMin
        bend_condition2 = 1;
        % find the json file for the opposite point cloud
        min_path_left = [rmse_left.rmse] == min_rmse_left;
        index_opp2 = find(min_path_left);

        temp_esl2 = rmse_left(index_opp2);
        esl_file_name2 = temp_esl2.jsonPath;
        esl_filefilter2 = regexp(esl_file_name2,'Photoneo_[0-9]*',"match");
    else
        % select the smaller of the two values, get the correct esl files and corresponding ply files
        if min_rmse_right < min_rmse_left             % <
            % in this case we select eslMin
            pc_bend_min = pcread(pcMinPath);
            if ~isempty(downSampleVal)
                pc_bend_min = pcdownsample(pc_bend_min, 'gridAverage', downSampleVal);
            end
            esljsonpath = minJsonPath;
            % bend_condition = -1 for pc_bend_min = eslMin
            bend_condition = -1;
            % find the json file for the opposite point cloud
            min_path_right = [rmse_right.rmse] == min_rmse_right;
            index_opp = find(min_path_right);
    
            temp_esl = rmse_right(index_opp);
            esl_file_name = temp_esl.jsonPath;
            esl_filefilter = regexp(esl_file_name,'Photoneo_[0-9]*',"match");
    
        elseif min_rmse_right > min_rmse_left           % >
            % in this case we select eslMax
            pc_bend_min = pcread(pcMaxPath);
            if ~isempty(downSampleVal)
                pc_bend_min = pcdownsample(pc_bend_min, 'gridAverage', downSampleVal);
            end
            esljsonpath = maxJsonPath;
            % bend_condition = 1 for pc_bend_min = eslMin
            bend_condition = 1;
            % find the json file for the opposite point cloud
            min_path_left = [rmse_left.rmse] == min_rmse_left;
            index_opp = find(min_path_left);
    
            temp_esl = rmse_left(index_opp);
            esl_file_name = temp_esl.jsonPath;
            esl_filefilter = regexp(esl_file_name,'Photoneo_[0-9]*',"match");
    
        elseif min_rmse_right == min_rmse_left
            % if the rmse values are identical we select the esl with the smaller mean (for x-values)
            meaneslMin = mean(eslMin(:,1));
            meaneslMax = mean(eslMax(:,1));
            if meaneslMin < meaneslMax
                pc_bend_min = pcread(pcMinPath);
                if ~isempty(downSampleVal)
                    pc_bend_min = pcdownsample(pc_bend_min, 'gridAverage', downSampleVal);
                end
                bend_condition = - 1;
                esljsonpath = minJsonPath;
                esl_filefilter = regexp(esljsonpath,'Photoneo_[0-9]*',"match");
            else
                pc_bend_min = pcread(pcMaxPath);
                if ~isempty(downSampleVal)
                    pc_bend_min = pcdownsample(pc_bend_min, 'gridAverage', downSampleVal);
                end
                bend_condition = 1;
                esljsonpath = maxJsonPath;
                esl_filefilter = regexp(esljsonpath,'Photoneo_[0-9]*',"match");
            end
        end
    end

    if printLevel > 2
        figure;
        pcshow(pc_bend_min1);
        hold on;
        pcshow(pc_bend_min2);
        title(append("Participant ",subjectNr, " pc bend min"));
        view (0,-89.9);
    end

    % now I can call my ply file that matches the filter
    newplyPath1 = append(plyFiles(1).folder,"/",esl_filefilter1,'.ply');
    pc_opp1 = pcread(newplyPath1); % does this need an offset correction?
    if ~isempty(downSampleVal)
        pc_opp1 = pcdownsample(pc_opp1, 'gridAverage', downSampleVal);
    end
    newplyPath2 = append(plyFiles(1).folder,"/",esl_filefilter2,'.ply');
    pc_opp2 = pcread(newplyPath2); % does this need an offset correction?
    if ~isempty(downSampleVal)
        pc_opp2 = pcdownsample(pc_opp2, 'gridAverage', downSampleVal);
    end

    if printLevel > 2
        figure;
        pcshow(pc_opp1);
        hold on;
        pcshow(pc_opp2);
        title(append("Participant ",subjectNr," pc opp"));
        view (0,-89.9);
    end

    % find the matching json file for the esl that goes with pc_opp
    fileMarkers1 = dir(append(outputPath,'/',esl_filefilter1,'*.json'));
    fileMarker1 = fileMarkers1(1);
    fileMarkerPath1 = append(fileMarker1.folder, "/", fileMarker1.name);
    filetextMarker1 = fileread(fileMarkerPath1);
    jsonMarker_opp1 = jsondecode(filetextMarker1);
    pcLinePts_opp1 = jsonMarker_opp1.pcLinePts;
    fileMarkers2 = dir(append(outputPath,'/',esl_filefilter2,'*.json'));
    fileMarker2 = fileMarkers2(1);
    fileMarkerPath2 = append(fileMarker2.folder, "/", fileMarker2.name);
    filetextMarker2 = fileread(fileMarkerPath2);
    jsonMarker_opp2 = jsondecode(filetextMarker2);
    pcLinePts_opp2 = jsonMarker_opp2.pcLinePts;

    % apply a smoothing spline to the esl
    pcLinePts_opp1 = SmoothingSplineRegularized(pcLinePts_opp1);
    pcLinePts_opp2 = SmoothingSplineRegularized(pcLinePts_opp2);

    % offset correction
    pcLinePts_offsetcorr_opp1 = offsetCorrection(pcLinePts_opp1);
    pcLinePts_offsetcorr_opp2 = offsetCorrection(pcLinePts_opp2);

    %% rotation and matching of the esls (pcLinePts_offsetcorr & pcLinePts_offsetcorr_opp)
    % select the correct esl depending on which side the minimum max bending is
    pcLinePts_offsetcorr1 = eslMin;
    pcLinePts_offsetcorr2 = eslMax;

    if printLevel > 2
        figure;
        pcshow(pcLinePts_offsetcorr1);
        title(append("Participant ", subjectNr," offset corrected esl & esl opp"));
        view (0,-89.9);
        hold on;
        pcshow(pcLinePts_offsetcorr_opp1);
        view (0,-89.9);
        figure;
        pcshow(pcLinePts_offsetcorr2);
        title(append("Participant ", subjectNr," offset corrected esl & esl opp"));
        view (0,-89.9);
        hold on;
        pcshow(pcLinePts_offsetcorr_opp2);
        view (0,-89.9);
    end

    % apply the smoothing spline to pcLinePts_offsetcorr
    pcLinePts_offsetcorr1 = SmoothingSplineRegularized(pcLinePts_offsetcorr1);
    % if I do a smoothing spline I need to do another offset correction afterwards!!!
    pcLinePts_offsetcorr1 = offsetCorrection(pcLinePts_offsetcorr1);
    pc_bend_min_offsetcorr1 = offsetCorrPointCloud(pc_bend_min1, pcLinePts_offsetcorr1,esljsonpath1);
    if printLevel > 3
        figure; pcshow(pc_bend_min_offsetcorr1); hold on; pcshow(pcLinePts_offsetcorr1.Location,'r'); title("offset corrected pc bend min");
    end
    pcLinePts_offsetcorr2 = SmoothingSplineRegularized(pcLinePts_offsetcorr2);
    % if I do a smoothing spline I need to do another offset correction afterwards!!!
    pcLinePts_offsetcorr2 = offsetCorrection(pcLinePts_offsetcorr2);
    pc_bend_min_offsetcorr2 = offsetCorrPointCloud(pc_bend_min2, pcLinePts_offsetcorr2,esljsonpath2);
    if printLevel > 3
        figure; pcshow(pc_bend_min_offsetcorr2); hold on; pcshow(pcLinePts_offsetcorr2.Location,'r'); title("offset corrected pc bend min");
    end

    if printLevel > 2
        figure;
        pcshow(pc_bend_min_offsetcorr1);
        hold on;
        pcshow (pcLinePts_offsetcorr1,'r');
        figure;
        pcshow(pc_bend_min_offsetcorr2);
        hold on;
        pcshow (pcLinePts_offsetcorr2,'r');
    end

    % rotate the esl for pc_opp
    rotationangle = 180;
    Ry = [cosd(rotationangle) 0 sind(rotationangle); 0 1 0; -sind(rotationangle) 0 cosd(rotationangle)];

    esl1 = pcLinePts_offsetcorr_opp1;
    esl1(:,3) = -esl1(:,3);
    esl_opp_rot1 = (Ry * esl1')';
    esl2 = pcLinePts_offsetcorr_opp2;
    esl2(:,3) = -esl2(:,3);
    esl_opp_rot2 = (Ry * esl2')';

    if printLevel > 2
        figure;
        pcshow (esl_opp_rot1);
        title(append("Participant ", subjectNr," esl opp rot"));
        view(0,-89.9);

        figure;
        pcshow(pcLinePts_offsetcorr1, 'c');
        view(0,-89.9);
        hold on;
        pcshow(esl_opp_rot1,'r');
        view(0,-89.9);
        title("pcLinePts offsetcorr & esl opp rot");

        figure;
        pcshow (esl_opp_rot2);
        title(append("Participant ", subjectNr," esl opp rot"));
        view(0,-89.9);

        figure;
        pcshow(pcLinePts_offsetcorr2, 'c');
        view(0,-89.9);
        hold on;
        pcshow(esl_opp_rot2,'r');
        view(0,-89.9);
        title("pcLinePts offsetcorr & esl opp rot");
    end

    %% estgeotform3d with normal z values
    % tic;
    pcLinePts_offsetcorr1 = pointCloud(pcLinePts_offsetcorr1);
    esl_opp_rot1 = pointCloud(esl_opp_rot1);
    % estgeotform3d ---> checks for a transformation from matchedPoints1(pcLinePts_offsetcorr) to matchedPoints2(esl_opp_rot) -> then calculates the distance btwn the matched points in each pair after applying the transformation
    [tformEst1,inlierIndex1, status1] = estimateGeometricTransform3D(pcLinePts_offsetcorr1.Location,esl_opp_rot1.Location,'rigid', 'Confidence', 99, 'MaxDistance', 0.03);
    pcLinePts_offsetcorr2 = pointCloud(pcLinePts_offsetcorr2);
    esl_opp_rot2 = pointCloud(esl_opp_rot2);
    [tformEst2,inlierIndex2, status2] = estimateGeometricTransform3D(pcLinePts_offsetcorr2.Location,esl_opp_rot2.Location,'rigid', 'Confidence', 99, 'MaxDistance', 0.03);
    
    toc;
    disp('estgeotform3d done')

    % apply the transformation to pcLinePts_offsetcorr & visualize in same figure as esl_opp_rot
    % pcLinePts_offsetcorr_tform = pctransform(pcLinePts_offsetcorr,tformEst);
    % figure;
    % pcshow(pcLinePts_offsetcorr_tform.Location,'r');
    % hold on;
    % pcshow(esl_opp_rot.Location, 'c');

    %% rotation of pc_opp
    % the point clouds need to be offset corrected by the same amount as the esls
    pc_opp_offsetcorr1 = offsetCorrPointCloud_opp(pc_opp1, pcLinePts_offsetcorr_opp1,pcLinePts_opp1);
    if printLevel > 3
        figure; pcshow(pc_opp_offsetcorr1); hold on; pcshow(pcLinePts_offsetcorr_opp1,'r'); title("offset corrected pc opp");
    end
    pc_opp_offsetcorr2 = offsetCorrPointCloud_opp(pc_opp2, pcLinePts_offsetcorr_opp2,pcLinePts_opp2);
    if printLevel > 3
        figure; pcshow(pc_opp_offsetcorr2); hold on; pcshow(pcLinePts_offsetcorr_opp2,'r'); title("offset corrected pc opp");
    end

    % now we rotate pc_opp by 180 degrees
    % calculate mean & subtract from individual pc points
    mean_pcLinePts_opp1 = mean(pcLinePts_offsetcorr_opp1(:,1));
    pc1 = pc_opp_offsetcorr1.Location - [mean_pcLinePts_opp1 0 0];
    mean_pcLinePts_opp2 = mean(pcLinePts_offsetcorr_opp2(:,1));
    pc2 = pc_opp_offsetcorr2.Location - [mean_pcLinePts_opp2 0 0];

    %     figure;
    %     pcshow(pc_bend_min.Location, 'r');
    %     hold on
    %     pcshow(pc_opp.Location,'c');

    % set rotation angle
    rotationangle = 180;
    Ry = [cosd(rotationangle) 0 sind(rotationangle); 0 1 0; -sind(rotationangle) 0 cosd(rotationangle)];

    % rotate the point cloud
    pc12 = pc1;
    pc12(:,3) = - pc12(:,3);
    pc_opp_rot1 = (Ry * pc12')';
    pc22 = pc2;
    pc22(:,3) = - pc22(:,3);
    pc_opp_rot2 = (Ry * pc22')';

    %% apply the transformation to the fixed point cloud
    pc_opp_rot1 = pointCloud(pc_opp_rot1);
    pc_opp_rot2 = pointCloud(pc_opp_rot2);

    pc_bend_min_offsetcorr1 = pctransform (pc_bend_min_offsetcorr1, tformEst1);
    pc_bend_min_offsetcorr2 = pctransform (pc_bend_min_offsetcorr2, tformEst2);

    %     if printLevel > 2
    %         figure;
    %         pcshow(pc_bend_min_offsetcorr.Location,'r');
    %         view(0,-89.9);
    %         hold on;
    %         pcshow(pc_opp_rot.Location,'c');
    %         view(0,-89.9);
    %         title("estgeotform3d transformation applied");
    %     end

    % apply the tformEst to pcLinePts_offsetcorr
    pcLinePts_offsetcorr_tform1 = pctransform(pcLinePts_offsetcorr1, tformEst1);
    pcLinePts_offsetcorr_tform2 = pctransform(pcLinePts_offsetcorr2, tformEst2);
    %     figure;
    %     pcshow(pc_bend_min_offsetcorr);
    %     hold on;
    %     pcshow(pcLinePts_offsetcorr.Location,'r');

    %      distance_saved = selectDistanceforCutting(plyFiles(1).name, subjectPath, subjectNr, study);
    
    %% do an icp for the uncut point clouds
    tic;
    [tformICP1, pcReg_icp1, rmse_pc1] = pcregistericp(pc_opp_rot1, pc_bend_min_offsetcorr1,"MaxIterations",30,Tolerance=[0.01 0.1]);
    [tformICP2, pcReg_icp2, rmse_pc2] = pcregistericp(pc_opp_rot2, pc_bend_min_offsetcorr2,"MaxIterations",30,Tolerance=[0.01 0.1]);
    if printLevel > 1
        figure;
        pcshow(pc_bend_min_offsetcorr1.Location,'r');
        view(0,-89.9);
        hold on;
        pcshow(pcReg_icp1.Location,'c');
        view(0,-89.9);
        hold on;
        pcshow(pcLinePts_offsetcorr_tform1.Location,'y');
        view(0,-89.9);
        title("icp");
        figure;
        pcshow(pc_bend_min_offsetcorr2.Location,'r');
        view(0,-89.9);
        hold on;
        pcshow(pcReg_icp2.Location,'c');
        view(0,-89.9);
        hold on;
        pcshow(pcLinePts_offsetcorr_tform2.Location,'y');
        view(0,-89.9);
        title("icp");
    end
    toc;
    disp('icp for uncut point clouds done')

    %% set the distance for cutting the point cloud
    matfilter = '.mat';
    Distance_savedBalgrist = append(outputPath2,'/Distance_savedBalgrist_');
    if exist(append(Distance_savedBalgrist,subjectNr,matfilter), "file")
        load(append(Distance_savedBalgrist,subjectNr,matfilter));
    else
        distance_saved = selectDistanceforCutting(plyFiles(1).name, subjectPath, subjectNr, study);
    end

    %% cutting point clouds
    pc_bend_min_offsetcorr_cut1 = cutPointCloud(pcLinePts_offsetcorr_tform1,esl_opp_rot1, pc_bend_min_offsetcorr1, subjectNr, study, outputPath2);
    pcReg_icp_cut1 = cutPointCloud(pcLinePts_offsetcorr_tform1,esl_opp_rot1,pcReg_icp1, subjectNr, study, outputPath2);
    pc_bend_min_offsetcorr_cut2 = cutPointCloud(pcLinePts_offsetcorr_tform2,esl_opp_rot2, pc_bend_min_offsetcorr2, subjectNr, study, outputPath2);
    pcReg_icp_cut2 = cutPointCloud(pcLinePts_offsetcorr_tform2,esl_opp_rot2,pcReg_icp2, subjectNr, study, outputPath2);

    %% second icp of the point clouds (now cut) needs to go here
    % apply it to cut pc_bend_min_offsetcorr & cut pcReg_icp
    [~, pcReg_icp21, rmse_pc1] = pcregistericp(pcReg_icp_cut1, pc_bend_min_offsetcorr_cut1,"MaxIterations",30,Tolerance=[0.01 0.1]);
    [~, pcReg_icp22, rmse_pc2] = pcregistericp(pcReg_icp_cut2, pc_bend_min_offsetcorr_cut2,"MaxIterations",30,Tolerance=[0.01 0.1]);
    if printLevel > 0
        figure;
        pcshow(pc_bend_min_offsetcorr_cut1.Location,'r');
        view(0,-89.9);
        hold on;
        pcshow(pcReg_icp21.Location,'c');
        view(0,-89.9);
        hold on;
        pcshow(pcLinePts_offsetcorr_tform1.Location,'y');
        view(0,-89.9);
        title("icp");
        figure;
        pcshow(pc_bend_min_offsetcorr_cut2.Location,'r');
        view(0,-89.9);
        hold on;
        pcshow(pcReg_icp22.Location,'c');
        view(0,-89.9);
        hold on;
        pcshow(pcLinePts_offsetcorr_tform2.Location,'y');
        view(0,-89.9);
        title("icp");
    end
    toc;
    disp('icp for cut point clouds done')

    %% calculate the rmse
    % use pcrmse3
    tic;
    %         [asymm_pc_rmse,~,~,dirvalue] = pcrmse3(pc_bend_min_offsetcorr_cut,pcReg_icp_cut, 0.05*1000,0,[0 0 1]);                  %pcrmse3(pc_bend_min_offsetcorr,pcReg_icp, 0.05*1000,0,[0 0 1]);
    [asymm_pc_rmse1,~,~,dirvalue1] = pcrmse3(pc_bend_min_offsetcorr_cut1,pcReg_icp21, 0.05*1000,0,[0 0 1]); %---> this for when cutting is finished
    [asymm_pc_rmse2,~,~,dirvalue2] = pcrmse3(pc_bend_min_offsetcorr_cut2,pcReg_icp22, 0.05*1000,0,[0 0 1]); %---> this for when cutting is finished
    asymm_pc_rmse = mean([asymm_pc_rmse1,asymm_pc_rmse2]);
    toc;
    disp('pcrmse3 done')

    if study == "Balgrist"
        % save the asymmetry index ----> my rmse is my asymmetry index
        asymmetryValBal{num}.Index = asymm_pc_rmse;
        asymmetryValBal{num}.SubjectNr = subjectNr;
        save(append(outputPath2,'/BalgristValues'), 'asymmetryValBal');
        if saveOutput>0
            if ~exist(outputPath, 'dir')
                mkdir(outputPath);
            end
            jsonObject.SubjectNr = subjectNr;
            jsonObject.AsymmetryMean = asymm_pc_rmse;
            jsonString = jsonencode(jsonObject);
            fid=fopen(append(outputPath, "/AsymmetryVals",string(asymmetryVersion),"l_",string(j),".json"), 'w');
            fprintf(fid, jsonString);
            fclose(fid);
        end
    end

    % needed if running more than one subject at the time
    clear direction_esl;
    clear direction_esl_left;
    clear direction_esl_right;
    clear rmse_left;
    clear rmse_right;
end

%% load the asymmetry values for Balgrist if they exist
if exist (append(outputPath2, '/BalgristValues.mat'), 'file')
    load(append(outputPath2, '/BalgristValues.mat'))
end

origValuesPath = append(outputPath2, "/BalgristValues_Orig.mat");
if exist(origValuesPath, 'file')
    load(origValuesPath)
    sum1 = 0;
    for avbi=1:length(asymmetryValBal)
        tempVal = asymmetryValBal_Orig{avbi}.Index-asymmetryValBal{avbi}.Index;
        disp(tempVal)
        sum1 = sum1 + abs(tempVal);
    end
    disp(sum1)
end

% Cobb angles Balgrist
addpath("Utils")
PrimaryCobbAngles = GetRedCapCobbAngles(csvPath, true);
PrimaryCobbAngles = PrimaryCobbAngles';

figure;
boxplot(PrimaryCobbAngles)
title("Primary Cobb angle distribution [°]")

MaxSubjNr = 0;
for i_Balg= 1:length(asymmetryValBal)
    subNrt = str2double(asymmetryValBal{i_Balg}.SubjectNr);
    if subNrt>MaxSubjNr
        MaxSubjNr = subNrt;
    end
end
% asymmetry mean values, extract the SubjectNr that belongs to the asymmetry values
asymmMeans = nan(1,MaxSubjNr);
for i_Balg= 1:length(asymmetryValBal)
    asymmMeans(str2double(asymmetryValBal{i_Balg}.SubjectNr)) = asymmetryValBal{i_Balg}.Index;
end

% make the correlation plot with the new Cobb angles
dataLength = min(length(asymmMeans),length(PrimaryCobbAngles));
plotPrimaryCobbAngles = PrimaryCobbAngles(1:dataLength);
plotAsymmMeans = asymmMeans;

% plotPrimaryCobbAngles(3,1) = 12;
if exist('PrimaryCobbAngles', 'var')
    % correlation plot
    figure;
    [R, PValue] = corrplotSingle([plotAsymmMeans',plotPrimaryCobbAngles'], 'varNames', ["Asymmetry index", "Cobb angle"]);         % don't transpose plotAsymmMeans or plotPrimaryCobbAngles because the plot wont' work otherwise
    set(gcf,'color','w');
    title("Asymmetry index vs Cobb angle");
end
if saveOutput>1
    if ~exist(commonOutputPath, 'dir')
        mkdir(commonOutputPath)
    end
    saveas(gcf, append(commonOutputPath, "/AsymMapLateral_CorrplotAsymIndsCobbAngles_",groupName,".fig"))
    exportgraphics(gca, append(commonOutputPath, "/AsymMapLateral_CorrplotAsymIndsCobbAngles_",groupName,".png"),"Resolution",600)
end
[R_confint,P,RL,RU] = corrcoef([plotAsymmMeans',plotPrimaryCobbAngles'], 'Rows', 'complete');

%% boxplot asymmetry values Balgrist

figure;
boxplot(plotAsymmMeans,'Positions',1,Notch='on');
set(gcf,'color','w');
xlabel("groups");
ylabel("asymmetry index");
title("Asymmetry Index: Balgrist");

%% boxplot for asymmetry values for Balgrist Cobb angles > 10 ° & <= 10°
decisionVal = 13;
% put the Cobb and the asymmMeans together -> this way the correct asymm values can be selected for each Cobb angle
CobbandAsymm = [plotPrimaryCobbAngles',plotAsymmMeans'];
% need to split my data into groups for smaller and larger than 10° (up to 10°, larger than 10°)
smallerInds = CobbandAsymm(:,1)<decisionVal;
largerInds = CobbandAsymm(:,1)>=decisionVal;
asymmVals_smaller = CobbandAsymm(smallerInds, 2);
asymmVals_larger = CobbandAsymm(largerInds, 2);

% make the boxplot
figure;
boxplot(asymmVals_smaller,'Positions',1,Notch='on');
set(gcf,'color','w');
xlabel("groups");
ylabel("asymmetry index");
title(append("Asymmetry Index: Cobb angles < ",string(decisionVal),"° vs >= ",string(decisionVal),"°"));
hold on;
boxplot(asymmVals_larger,'Positions',2,Notch='on');
set(gcf,'color','w');
xlabel("groups");
ylabel("asymmetry index");
set(gca(),'XTick',[1 2],'XTickLabels',{append("Cobb angle < ",string(decisionVal),"°"),append("Cobb angle >= ",string(decisionVal),"°")})


%% functions
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

function pcLinePts = SmoothingSpline_esl(pcLinePts_esl)

SmoothingSplineParam = 0.999999;          % this parameter indicates whether the smoothingParam is linear or polynomial     % 0.0001 --> more linear;
tmpVar = pcLinePts_esl;
% y gets evenly spaced
deltaY = (max(tmpVar(:,2))-min(tmpVar(:,2)))/length(tmpVar);        % parameters for y-values
yy = min(tmpVar(:,2)):deltaY:max(tmpVar(:,2))+deltaY/4;
px = fit(pcLinePts_esl(:,2), pcLinePts_esl(:,1), 'smoothingspline','SmoothingParam',SmoothingSplineParam);
xx = feval(px,yy)';
pz = fit(pcLinePts_esl(:,2), pcLinePts_esl(:,3), 'smoothingspline','SmoothingParam',SmoothingSplineParam);
zz = feval(pz,yy)';
% cut y to original data
pcLinePts = [xx',yy',zz'];

end

function distance_saved = selectDistanceforCutting(plyFile_x, subjectPath, subjectNr,study)

% get the point cloud for upright standing
plyPath = append(subjectPath,'/',plyFile_x);
ply = pcread(plyPath);
% select the left point, only click once, then hit enter!
figure;
ax = pcshow(ply);
ax.View = [0,-89.9];
roi1 = images.roi.Polygon(ax);
draw(roi1)
% select the right point, only click once, then hit enter!
roi2 = images.roi.Polygon(ax);
draw(roi2)

% select the values of the selected points
roi_left = roi1.Position;
roi_right = roi2.Position;

% calculate the distance between the two points
full_dist = norm(roi_left - roi_right);
distance = (abs(full_dist))/2;

% save the distance for the subject with subjectNr and study condition
if study == "Balgrist"
    distValues.Distance = distance;
    distValues.SubjectNr = subjectNr;
    distValues.Study = study;

    distance_saved = distValues;
    Distance_savedBalgrist = append(outputPath2,'/Distance_savedBalgrist_');
    save(append(Distance_savedBalgrist,subjectNr), 'distance_saved');
end

end

function pc_cut = cutPointCloud(esl, esl_rot, pc,subjectNr,study, outputPath2)

% input both esls & loop through all values to calculate the mean btwn the points, both esls are 200x3 double
temp_num = 1;
for i_temp = 1:length(esl.Location)
    % calculate mean btwn point of esl & esl_rot
    mean_value = mean([esl.Location(temp_num,:) ; esl_rot.Location(temp_num,:)]);
    mean_values_cell{i_temp} = mean_value;
    temp_num = temp_num + 1;
end
mean_values = mean_values_cell';
mean_values_esl = cell2mat(mean_values); % I could also use: mean_values_esl = cell2mat(mean_values_cell');

%     figure;
%     pcshow(mean_values_esl, 'r');
%     hold on;
%     pcshow(pc);
%

% get the distance belonging to the correct subject!
matfilter = '.mat';
Distance_savedBalgrist = append(outputPath2,'/Distance_savedBalgrist_');
if study == "Balgrist"
    if exist(append(Distance_savedBalgrist,subjectNr,matfilter), "file")
        load(append(Distance_savedBalgrist,subjectNr,matfilter));
    end
end

distance = distance_saved.Distance;

% CUTTING WITH RADIUS
for i_cut = 1:length(pc.Location)
    ix= pc.Location(i_cut,:);
    for j_cut = 1:length(mean_values_esl)
        jx = mean_values_esl(j_cut,:);
        % calculate the difference of ix and jx, then norm the difference
        difference_ix_jx = ix - jx;
        dist3d = norm(difference_ix_jx);
        % compare distances
        if dist3d <= distance
            % get the index of the point within the range and save it
            saved_ix{i_cut} = ix(1,:);
        end
    end
end
% turn cell into array & array into point cloud
saved = saved_ix';
saved = saved(~cellfun('isempty',saved));
pc_cut = cell2mat(saved);
pc_cut = pointCloud(pc_cut);
%         figure;
%         pcshow(pc_cut);
%         hold on;
%         pcshow(mean_values_esl, 'r');

% cut head and bottom with a large diameter
minESL = mean_values_esl(1, :);
maxESL = mean_values_esl(end,:);
last2Ind=-1;
lastInd = -1;
currInd = length(mean_values_esl)/2;
while true
    currPt = mean_values_esl(currInd, :);
    dist2min = norm(minESL-currPt);
    dist2max = norm(maxESL-currPt);
    if dist2min>dist2max
        % go towards min
        currInd=currInd-1;
    else
        currInd=currInd+1;
    end
    if lastInd==currInd || last2Ind==currInd
        break;
    end
    last2Ind=lastInd;
    lastInd=currInd;
end
circleRadius = mean([dist2min, dist2max]);
% now cut
% CUTTING WITH RADIUS
saved_ix2=[];
for i_cut = 1:length(pc_cut.Location)
    ix= pc_cut.Location(i_cut,:);
    jx = mean_values_esl(currInd,:);
    % calculate the difference of ix and jx, then norm the difference
    difference_ix_jx = ix - jx;
    dist3d = norm(difference_ix_jx);
    % compare distances
    if dist3d <= circleRadius
        % get the index of the point within the range and save it
        saved_ix2 = [saved_ix2; ix];
    end
end
% turn into point cloud
pc_cut = pointCloud(saved_ix2);
%         figure;
%         pcshow(pc_cut);
%         hold on;
%         pcshow(mean_values_esl, 'r');

end

function pcLinePts_offsetcorr = offsetCorrection(pcLinePts)

[~, maxYind_pcLinePts] = max(pcLinePts(:,2));
pcLinePts_offsetcorr = pcLinePts - pcLinePts(maxYind_pcLinePts,:);

end

function pc_offsetcorr = offsetCorrPointCloud (pc, pcLinePts_offsetcorr, path)

% read the correct esl from the given json path and use that as pcLinePts
json = fileread(path);
esl = jsondecode(json);
pcLinePts = esl.pcLinePts;
pcLinePts = SmoothingSpline_esl(pcLinePts);

[~, maxYind_pcLinePts] = max(pcLinePts(:,2));
offset = pcLinePts(maxYind_pcLinePts,:);
pc_offsetcorr = pc.Location - offset;
pc_offsetcorr = pointCloud(pc_offsetcorr);

%     figure;
%     pcshow(pcLinePts_offsetcorr, 'r');
%     hold on;
%     pcshow(pc_offsetcorr);

end

function pc_offsetcorr = offsetCorrPointCloud_opp(pc, pcLinePts_offsetcorr, path)

pcLinePts = path;

[~, maxYind_pcLinePts] = max(pcLinePts(:,2));
offset = pcLinePts(maxYind_pcLinePts,:);
pc_offsetcorr = pc.Location - offset;
pc_offsetcorr = pointCloud(pc_offsetcorr);

%     figure;
%     pcshow(pcLinePts_offsetcorr, 'r');
%     hold on;
%     pcshow(pc_offsetcorr);

end

function pcLinePts_offsetrev = reverseOffsetCorr(pcLinPts_offsetcorr, pcLinePts)            % pcLinePts is the original esl(?)

[~, maxYind_pcLinePts] = max(pcLinePts(:,2));
offset = pcLinePts(maxYind_pcLinePts,:);
pcLinePts_offsetrev = pcLinPts_offsetcorr + offset;

end

function diffMaxMin = diff_max_min(pcLinePts)

% get the new min & max y values, calculate the difference to figure out if bending goes left or right using the x-values that belong to those y-values
[~, indYmin] = min(pcLinePts(:,2));
[~, indYmax] = max(pcLinePts(:,2));

minYrow_new = pcLinePts(indYmin,:);
maxYrow_new = pcLinePts(indYmax,:);

diffMaxMin = minYrow_new(:,1) - maxYrow_new(:,1);

end

function pcLinePts = SmoothingSplineRegularized(pcLinePtsesl)

tmpVar = pcLinePtsesl;

N = 200; % select amount of points
q = curvspace(tmpVar,N);

%     figure
%     pcshow(tmpVar, 'g', 'MarkerSize', 12)
%     hold on;
%     pcshow(q, 'r', 'MarkerSize', 12)

% check spacing
dists = 0;
for i=2:N
    dist = dists(end) + norm(q(i,:)-q(i-1,:));
    dists = [dists; dist];
end

%     figure
%     plot(dists)
SmoothingSplineParam = 0.0001;

xyz = q';
[ndim,npts]=size(xyz);
xyzp=zeros(size(xyz));
for k=1:ndim
    xyzp(k,:)=ppval(csaps(1:npts,xyz(k,:), SmoothingSplineParam),1:npts);              % smoothing factor (0.0001)
end
pcLinePts = xyzp';

%     figure
%     pcshow(q, 'g', 'MarkerSize', 12)
%     hold on;
%     pcshow(xyzp', 'r', 'MarkerSize', 12)

    function q = curvspace(p,N)
        % CURVSPACE Evenly spaced points along an existing curve in 2D or 3D.
        %   CURVSPACE(P,N) generates N points that interpolates a curve
        %   (represented by a set of points) with an equal spacing. Each
        %   row of P defines a point, which means that P should be a n x 2
        %   (2D) or a n x 3 (3D) matrix.
        %
        %   (Example)
        %   x = -2*pi:0.5:2*pi;
        %   y = 10*sin(x);
        %   z = linspace(0,10,length(x));
        %   N = 50;
        %   p = [x',y',z'];
        %   q = curvspace(p,N);
        %   figure;
        %   plot3(p(:,1),p(:,2),p(:,3),'*b',q(:,1),q(:,2),q(:,3),'.r');
        %   axis equal;
        %   legend('Original Points','Interpolated Points');
        %
        %   See also LINSPACE.
        %
        %   22 Mar 2005, Yo Fukushima
        %/% initial settings
        currentpt = p(1,:); % current point
        indfirst = 2; % index of the most closest point in p from curpt
        len = size(p,1); % length of p
        q = currentpt; % output point
        k = 0;
        %/% distance between points in p
        for k0 = 1:len-1
            dist_bet_pts(k0) = distance(p(k0,:),p(k0+1,:));
        end
        totaldist = sum(dist_bet_pts);
        %/% interval
        intv = totaldist./(N-1);
        %/% iteration
        for k = 1:N-1
            newpt = []; distsum = 0;
            ptnow = currentpt;
            kk = 0;
            pttarget = p(indfirst,:);
            remainder = intv; % remainder of distance that should be accumulated
            while isempty(newpt)
                % calculate the distance from active point to the most
                % closest point in p
                disttmp = distance(ptnow,pttarget);
                distsum = distsum + disttmp;
                % if distance is enough, generate newpt. else, accumulate
                % distance
                if distsum >= intv
                    newpt = interpintv(ptnow,pttarget,remainder);
                else
                    remainder = remainder - disttmp;
                    ptnow = pttarget;
                    kk = kk + 1;
                    if indfirst+kk > len
                        newpt = p(len,:);
                    else
                        pttarget = p(indfirst+kk,:);
                    end
                end
            end

            % add to the output points
            q = [q; newpt];

            % update currentpt and indfirst
            currentpt = newpt;
            indfirst = indfirst + kk;

        end
    end

    function l = distance(x,y)
        % DISTANCE Calculate the distance.
        %   DISTANCE(X,Y) calculates the distance between two
        %   points X and Y. X should be a 1 x 2 (2D) or a 1 x 3 (3D)
        %   vector. Y should be n x 2 matrix (for 2D), or n x 3 matrix
        %   (for 3D), where n is the number of points. When n > 1,
        %   distance between X and all the points in Y are returned.
        %
        %   (Example)
        %   x = [1 1 1];
        %   y = [1+sqrt(3) 2 1];
        %   l = distance(x,y)
        %
        % 11 Mar 2005, Yo Fukushima
        %/% calculate distance
        if size(x,2) == 2
            l = sqrt((x(1)-y(:,1)).^2+(x(2)-y(:,2)).^2);
        elseif size(x,2) == 3
            l = sqrt((x(1)-y(:,1)).^2+(x(2)-y(:,2)).^2+(x(3)-y(:,3)).^2);
        else
            error('Number of dimensions should be 2 or 3.');
        end
    end

    function newpt = interpintv(pt1,pt2,intv)
        % Generate a point between pt1 and pt2 in such a way that
        % the distance between pt1 and new point is intv.
        % pt1 and pt2 should be 1x3 or 1x2 vector.
        dirvec = pt2 - pt1;
        dirvec = dirvec./norm(dirvec);
        l = dirvec(1); m = dirvec(2);
        newpt = [intv*l+pt1(1),intv*m+pt1(2)];
        if length(pt1) == 3
            n = dirvec(3);
            newpt = [newpt,intv*n+pt1(3)];
        end
    end

end