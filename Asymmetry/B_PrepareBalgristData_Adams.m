close all; clear all; clc

basePath = "I:/ETH/BalgristStudyData";
% adams
targetPath = "./Data/Adams";
subFolder = "03";

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
    ExtractFileFromZip(zipName, subFolder, "Photoneo2", ".ply", subjectTargetPath, [], replace(zipFolder(1).name, ".zip", ""), false);
    %% cleanup the ply a bit
    plyFileName = dir(append(subjectTargetPath, "/Photoneo2_*.ply"));
    if isempty(plyFileName)&&(subFolder=="50")
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
    inds = pcLoc(:,3)<0.5 | pcLoc(:,3)>1.8 | pcLoc(:,1)<-0.5;
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
    pcMean(:,3) = pcMean(:,3)-1.4;
    if norm(pcMean)>0.15
        disp("Warning: Largest cluster not in middle")
    end
    pcwrite(biggestPc, plyFilePath, "Encoding","binary");
end