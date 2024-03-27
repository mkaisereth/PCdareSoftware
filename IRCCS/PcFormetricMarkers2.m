function [pc, fig1, pcLinePtInds, pcLinePts] = PcFormetricMarkers2(subjectPath, subjectName, pcPath, fileName, fileName2)

% use formetric external line
pc = ReadPc(pcPath);
% read formetric xml (avr)
[~,name] = fileparts(pcPath);
if contains(name, "flexed")
    jsonFilePath = append(subjectPath, "\", subjectName, fileName, ".json");
else
    jsonFilePath = append(subjectPath, "\", subjectName, fileName2, ".json");
end
jsonString = fileread(jsonFilePath);
jsonObject = jsondecode(jsonString);
eslPts = jsonObject.eslLinePts;
fixPts = jsonObject.fixPts;

global pcMarkers;
pcMarkers = struct;

pcMarkers(1).World = fixPts(2,:); % C7
pcMarkers(2).World = fixPts(6,:); % L1
pcMarkers(3).World = fixPts(5,:); % SIPS right
pcMarkers(4).World = fixPts(3,:); % SIPS left

pcLinePts = eslPts;
pcLinePtInds = [];
% cut from C7 to L1
pcLinePts(pcLinePts(:,2)<fixPts(2,2),:) = [];
pcLinePts(pcLinePts(:,2)>fixPts(6,2),:) = [];
for i=1:length(pcLinePts)
    [inds,~] = findNearestNeighbors(pc, pcLinePts(i,:), 1);
    pcLinePtInds = [inds, pcLinePtInds];
end

fig1 = figure;
pcshow(pc);
hold on;
pcshow(pcLinePts, 'r', 'MarkerSize', 12);
% plot fix points
pcshow(fixPts(2,:), 'g', 'MarkerSize', 64); %C7
pcshow(fixPts(3,:), 'r', 'MarkerSize', 64); % SIPS left
pcshow(fixPts(5,:), 'b', 'MarkerSize', 64); % SIPS right
pcshow(fixPts(6,:), 'y', 'MarkerSize', 64); % L1
view([0 -89]);
title("Close both figures to proceed")

end