close all; clear all; clc

basePath = "I:/ETH/BalgristStudyData";
dicomBasePath = "I:/ETH/BalgristStudyData_Dicom";

% upright
targetPath = "./Data/Upright";
subFolder = "01";
distZ=1.6;

patientsNum = 1:30;

addpath("Utils")

for pi=patientsNum
    % check whether folder exists
    subjectTargetPath = append(targetPath, "/", string(pi))
    if ~exist(subjectTargetPath)
        mkdir(subjectTargetPath);
    end
    % get upright posture from zip
    zipFolder = dir(append(basePath, "/", string(pi), "_*.zip"));
    zipName = append(zipFolder(1).folder, "/", zipFolder(1).name);
    ExtractFileFromZip(zipName, subFolder, "Photoneo_", ".ply", subjectTargetPath, [], replace(zipFolder(1).name, ".zip", ""), false);
    %% cleanup the ply a bit
    plyFileName = dir(append(subjectTargetPath, "/Photoneo_*.ply"));
    if isempty(plyFileName)&&(subFolder=="03"||subFolder=="50")
        % skip adams without second photoneo (first ones missing)
        continue;
    end
    plyFilePath = append(plyFileName(1).folder, "/", plyFileName(1).name);
    pc = pcread(plyFilePath);
    if isempty(pc.Location)&&(subFolder=="50")
        % skip adams without second photoneo (first ones missing)
        continue;
    end
    pcLoc = pc.Location;
    pcCol = pc.Color;
    inds = pcLoc(:,3)<0.5 | pcLoc(:,3)>distZ;
    pcLoc(inds, :) = [];
    pcCol(inds, :) = [];
    pc = pointCloud(pcLoc, "Color", pcCol);
    figure;
    pcshow(pc);
    view(0,-90);
    [labels, numClusters] = pcsegdist(pc, 0.02);
    % find large cluster with mean value around 0
    clusterSizes = [];
    for ci=1:numClusters
        clusterSize = sum(labels==ci);
        clusterSizes = [clusterSizes, clusterSize];
    end
    % sort according to size
    [sortedClusterSizes, sortInds] = sort(clusterSizes, 'descend');
    biggestCluster = pc.Location(labels==sortInds(1), :);
    biggestColors = pc.Color(labels==sortInds(1), :);
    biggestPc = pointCloud(biggestCluster, "Color",biggestColors);
    figure;
    pcshow(biggestPc);
    view(0,-90);
    pcMean = mean(biggestCluster);
    pcMean(:,3) = pcMean(:,3)-1.1;
    if norm(pcMean)>0.15
        disp("Warning: Largest cluster not in middle")
    end
    pcwrite(biggestPc, plyFilePath, "Encoding","binary");
    %%

    % get dicom images
    dicomImagePath = append(dicomBasePath, "/ID", string(pi));
    dicomImages = dir(append(dicomImagePath, "/ID", string(pi), "_*_*.dcm"));
    for di=1:length(dicomImages)
        dicomImg = append(dicomImages(di).folder, "/", dicomImages(di).name);
        if contains(dicomImg, "_ap")
            dicomImagePath_ap = dicomImg;
            dicomImageName_ap = dicomImages(di).name;
        elseif contains(dicomImg, "_lat")
            dicomImagePath_lat = dicomImg;
            dicomImageName_lat = dicomImages(di).name;
        else
            disp("Warning: dicom image ignored: " + dicomImg);
        end
    end
    copyfile(dicomImagePath_ap, append(subjectTargetPath, "/", dicomImageName_ap))
    copyfile(dicomImagePath_lat, append(subjectTargetPath, "/", dicomImageName_lat))
end