basePath = "../Data/hNet";
folderPath2 = "./AsymMapPaperData";
subfolder = "Sample";

% balgrist
subjectNrs = 1:30;

% make absolute paths
[~,info] = fileattrib(append(pwd, "/", basePath));
basePath = info.Name
if ~exist(append(pwd, "/", folderPath2))
    mkdir(append(pwd, "/", folderPath2))
end
[~,info] = fileattrib(append(pwd, "/", folderPath2));
folderPath2 = info.Name

if ~exist(folderPath2,"dir")
    mkdir(folderPath2)
end
numOfSuccess = 0;
for subjectNr=subjectNrs
    % check if folder is empty, then delete
    csvPaths = append(basePath, "/", string(subjectNr), "/", subfolder, "/*DepthMap.csv");
    csvList = dir(csvPaths);
    for j=1:length(csvList)
        destFolder = replace(csvList(j).folder, basePath, folderPath2);
        if ~isempty(subfolder) && subfolder ~= ""
            destFolder = replace(destFolder, append("\",subfolder), "");
            destFolder = replace(destFolder, append("/",subfolder), "");
        end
        if ~exist(destFolder, 'dir')
            mkdir(destFolder);
        end
        status = copyfile(append(csvList(j).folder, "/", csvList(j).name), append(destFolder, "/", csvList(j).name));
        if status == 1
            numOfSuccess=numOfSuccess+1;
        end
        if status == 0
            disp("failed")
        end
    end
end
disp(append("Number of success: ", string(numOfSuccess)));