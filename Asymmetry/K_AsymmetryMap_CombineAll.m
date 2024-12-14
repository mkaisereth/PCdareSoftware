close all; clearvars -except loopCounter; clc;

groupName = 'Balgrist';
saveOutput = 1;

global subFolder;
subFolder = "";
basePaths = ["./Data/"+subFolder+"\Adams"...
    ,"./Data/"+subFolder+"\Forward"...
    ,"./Data/"+subFolder+"\Lateral"...
    ,"./Data/"+subFolder+"\Upright"];
xmlPath = "./Data/"+subFolder+"\CobbAngles.csv";
commonOutputPath = append("./Data/"+subFolder, "\Output");

asymmCharDict.Adams = ["a"];
asymmCharDict.Forward = ["f"];
asymmCharDict.Lateral = ["l"];
asymmCharDict.Upright = ["c"];

maxSubjNr = 30;
evalSubset=1:30;

AsymVals.Adams = nan(1,maxSubjNr);
AsymVals.Forward = nan(1,maxSubjNr);
AsymVals.Lateral = nan(1,maxSubjNr);
AsymVals.Upright = nan(1,maxSubjNr);
AsymVals.Upright2 = nan(1,maxSubjNr);
AsymAngles.Adams = nan(1,maxSubjNr);
AsymAngles.Forward = nan(1,maxSubjNr);
AsymAngles.Lateral = nan(1,maxSubjNr);
AsymAngles.Upright = nan(1,maxSubjNr);
AsymAngles.Upright2 = nan(1,maxSubjNr);

usedFolders = [];

for basePath=basePaths
    dirList = dir(basePath);
    dirList = dirList(3:end);
    dirList(~[dirList.isdir])=[];
    dirList = natsortfiles(dirList);
    if ~isempty(evalSubset)
        evalSubset_t = evalSubset;
        evalSubset_t(evalSubset_t>length(dirList))=[];
        dirList = dirList(evalSubset_t);
    end
    disp(append("Using folders ", join(string({dirList(1:end).name}))))
    if isempty(usedFolders)
        usedFolders = string({dirList(1:end).name});
    else
        if length(usedFolders) ~= length({dirList(1:end).name}) || sum(usedFolders ~= string({dirList(1:end).name}))>0
            disp(append("Warning: not using same folders ", join(string({dirList(1:end).name}))))
        end
    end
    for si=1:length(dirList)
        if strcmp(dirList(si).name, "Output")
            continue;
        end
        typeNames = split(dirList(si).folder, {'\', '/'});
        typeName = typeNames{end};
        subjectPath = append(dirList(si).folder, "\", dirList(si).name);
        subjectNr = dirList(si).name;

        jsonFilePath = append(subjectPath, "\Output\AsymmetryVals4*_*.json");
        jsonFiles = dir(jsonFilePath);
        if isempty(jsonFiles)
            keyboard;
        end
        if length(jsonFiles)>1
            % now choose
            if strcmp(typeName, "Upright")
                for jfi=1:length(jsonFiles)
                    if contains(jsonFiles(jfi).name, append("AsymmetryVals4", asymmCharDict.Upright))
                        jsonFiles = jsonFiles(jfi);
                        break;
                    end
                end
            else
                keyboard;
            end
        end
        fileText = fileread(append(jsonFiles(1).folder, "\", jsonFiles(1).name));
        jsonObject = jsondecode(fileText);
        AsymVals.(typeName)(str2num(subjectNr)) = jsonObject.AsymmetryMean;
        if isfield(jsonObject, "AsymmetryMean2")
            AsymVals.(append(typeName,"2"))(str2num(subjectNr)) = jsonObject.AsymmetryMean2;
        end
    end
end

%% now read Cobb angles
addpath("Utils")
xlsPrimaryCobbAngles = GetRedCapCobbAngles(xmlPath, true);
xlsPrimaryCobbAngles = xlsPrimaryCobbAngles';
plotXlsPrimaryCobbAngles = xlsPrimaryCobbAngles(1:maxSubjNr);

% now make linear models
typeNamesList = [];
for basePath=basePaths
    typeNames = split(basePath, {'\', '/'});
    typeName = typeNames{end};
    typeNamesList = [typeNamesList string(typeName)];
    mdl1 = fitlm(double(AsymVals.(typeName))', plotXlsPrimaryCobbAngles');
    mdl1CobbAngles = mdl1.feval(double(AsymVals.(typeName)));
    AsymAngles.(typeName) = mdl1CobbAngles;
    if isfield(AsymVals, append(typeName, "2"))
        typeName = append(typeNames{end}, "2");
        typeNamesList = [typeNamesList string(typeName)];
        mdl2 = fitlm(double(AsymVals.(typeName))', plotXlsPrimaryCobbAngles');
        mdl2CobbAngles = mdl1.feval(double(AsymVals.(typeName)));
        AsymAngles.(typeName) = mdl2CobbAngles;
    end
end

%% now check combination
CombinedAsymAngles = nan(1, maxSubjNr);

asymWeights.Adams = 3;
asymWeights.Forward = 4;
asymWeights.Lateral = 1;
asymWeights.Upright = 1;
asymWeights.Upright2 = 2;

SubjectsMedianAsymAngles = nan(1,maxSubjNr);
SubjectsMeanAsymAngles = nan(1,maxSubjNr);
SubjectsWeightedAsymAngles = nan(1,maxSubjNr);
for subjNr=1:maxSubjNr
    asymAngles_t = [];
    asymAngles_sum = [];
    usedWeights = 0;
    for typeName=typeNamesList
        asymAngles_t = [asymAngles_t AsymAngles.(typeName)(subjNr)]
        if ~isnan(AsymAngles.(typeName)(subjNr))
            usedWeights = usedWeights+asymWeights.(typeName);
        end
        asymAngles_sum = [asymAngles_sum asymWeights.(typeName)*AsymAngles.(typeName)(subjNr)]
    end
    if usedWeights>0
        asymAngles_sum = asymAngles_sum/usedWeights;
    end
    SubjectsMedianAsymAngles(subjNr) = median(asymAngles_t, 'omitnan');
    SubjectsMeanAsymAngles(subjNr) = mean(asymAngles_t, 'omitnan');
    if sum(~isnan(asymAngles_sum))>0
        SubjectsWeightedAsymAngles(subjNr) = sum(asymAngles_sum, 'omitnan');
    else
        disp("all are nan, ignore ...")
    end
end

figure;
[R, PValue] = corrplotSingle([SubjectsMedianAsymAngles',plotXlsPrimaryCobbAngles'], 'varNames', ["median Asymmetry angle", "Cobb angle"]);
set(gcf,'color','w');
title(append("Correlation median Asymmetry angle vs Cobb angle"));

figure;
[R, PValue] = corrplotSingle([SubjectsMeanAsymAngles',plotXlsPrimaryCobbAngles'], 'varNames', ["mean Asymmetry angle", "Cobb angle"]);
set(gcf,'color','w');
title(append("Correlation mean Asymmetry angle vs Cobb angle"));

figure;
[R, PValue] = corrplotSingle([SubjectsWeightedAsymAngles',plotXlsPrimaryCobbAngles'], 'varNames', ["weighted Asymmetry angle", "Cobb angle"]);
set(gcf,'color','w');
title(append("Correlation weighted Asymmetry angle vs Cobb angle"));
if saveOutput>1
    if ~exist(commonOutputPath, 'dir')
        mkdir(commonOutputPath)
    end
    saveas(gcf, append(commonOutputPath, "\AsymMapCombineAll_CorrplotWeightedAsymAnglesCobbAngles_",groupName,".fig"))
    exportgraphics(gca, append(commonOutputPath, "\AsymMapCombineAll_CorrplotWeightedAsymAnglesCobbAngles_",groupName,".png"),"Resolution",600)
end
[R,PValue,RL,RU] = corrcoef([SubjectsWeightedAsymAngles',plotXlsPrimaryCobbAngles'], 'Rows', 'complete')

figure
CustomBoxPlot(abs(SubjectsWeightedAsymAngles-plotXlsPrimaryCobbAngles))
xlabel("")
ylabel("Angle error [°]")
title("Absolute error estimated Cobb angle - Cobb angle")
if saveOutput>1
    if ~exist(commonOutputPath, 'dir')
        mkdir(commonOutputPath)
    end
    saveas(gcf, append(commonOutputPath, "\AsymMapCombineAll_DiffAsymValsCobbAngles_",groupName,".fig"))
    exportgraphics(gca, append(commonOutputPath, "\AsymMapCombineAll_DiffAsymValsCobbAngles_",groupName,".png"),"Resolution",600)
end
iqr1 = iqr(abs(SubjectsWeightedAsymAngles-plotXlsPrimaryCobbAngles))