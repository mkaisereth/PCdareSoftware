clear all; close all;

basePath = "AsymMapPaperData";
outputFolder = "Output_AsymMapPaperData";
basePlyPaths = ["../Data/hNet"];
commonOutputPath = append(basePath, "/Output");

datasetName = "AsymMapPaperData";
subfolder = "";
plySubfolders = ["", "Sample"];

printLevel = 1;
dataFilter = [];

subjectNrs = 1:30;

dirList = dir(basePath);
if printLevel>0
    f1 = figure;
    f2 = figure;
    f3 = figure;
    f4 = figure;
end
errors = [];
medianErrors = [];
rmseErrors = [];
largeOutliers = [];
errorOrder = [];
errors_fit = [];
medianErrors_fit = [];
rmseErrors_fit = [];
largeOutliers_fit = [];
nowString = datestr(now,'yyyymmdd_HHMMSSFFF');
for i=subjectNrs
%     if ~dirList(i).isdir || strcmp(dirList(i).name, "Output")
%         continue;
%     end
    disp(i)%dirList(i).name);
    % get all depth maps
    nanDepthMaps = dir(append(dirList(i).folder, "/", string(i), "/",subfolder,"/*_nanDepthMap.csv"));
    nanESLDepthMaps = dir(append(dirList(i).folder, "/", string(i), "/",subfolder,"/*nanEslDepthMap.csv"));
    for j=1%length(nanDepthMaps)

        if ~isempty(dataFilter)
            % check whether this is in the filter, else continue
            if sum(ismember(nanDepthMaps(j).name, dataFilter))<1
                continue;
            end
        end
        nanDepthMapMat = readmatrix(append(nanDepthMaps(j).folder, "/", nanDepthMaps(j).name));
        nanEslDepthMapMat = readmatrix(append(nanESLDepthMaps(j).folder, "/", nanESLDepthMaps(j).name));
        % transform them into 3d depthmap
        [X,Y] = meshgrid(1:480, 1:480);
        nanDepthMapMat_3d = [X(:), Y(:), nanDepthMapMat(:)*40];
        nanEslDepthMapMat_3d = [X(:), Y(:), nanEslDepthMapMat(:)];
        nanEslDepthMapMat_3d_nz = nanEslDepthMapMat_3d;
        nanEslDepthMapMat_3d_nz(:,3) = -nanEslDepthMapMat_3d_nz(:,3);
        nanEslDepthMapMat_3d_nz(nanEslDepthMapMat_3d_nz(:,3)>-10,:) = [];

        % get the corresponding results
        eslResFilePath = append(outputFolder, "/ESL_", datasetName, "_",  string(i), "_", replace(nanESLDepthMaps(j).name, "_nanEslDepthMap.csv", "_5.txt"));
        eslResDepthMapMat = readmatrix(eslResFilePath);
        tempX = eslResDepthMapMat(:,1);
        eslResDepthMapMat(:,1) = 479-eslResDepthMapMat(:,2);
        eslResDepthMapMat(:,2) = tempX;
        eslResDepthMapMat_nz = eslResDepthMapMat;
        eslResDepthMapMat_nz(:,3) = -eslResDepthMapMat_nz(:,3);
        eslResDepthMapMat_nz(eslResDepthMapMat_nz(:,3)>-10,:) = [];
        
        % show the pointcloud
        yMin = min(nanEslDepthMapMat_3d_nz(~isnan(nanEslDepthMapMat_3d_nz(:,3)),2))-10;
        yMax = max(nanEslDepthMapMat_3d_nz(~isnan(nanEslDepthMapMat_3d_nz(:,3)),2))+10;
        pcDm = pointCloud(nanDepthMapMat_3d(nanDepthMapMat_3d(:,2)>yMin&nanDepthMapMat_3d(:,2)<yMax, :));
        pcEdm = pointCloud(nanEslDepthMapMat_3d_nz(nanEslDepthMapMat_3d_nz(:,2)>yMin&nanEslDepthMapMat_3d_nz(:,2)<yMax, :));
        pcEr = pointCloud(eslResDepthMapMat_nz(eslResDepthMapMat_nz(:,2)>yMin&eslResDepthMapMat_nz(:,2)<yMax, :));

        if printLevel>0
            figure(f1);
            hold off;
            pcshow(pcDm);
            hold on;
            pcshow(pcEdm.Location, 'r');
            pcshow(pcEr.Location, 'g');
            set(gcf,'color','w');
            set(gca,'color','w');
            axis off
            axis equal
        end

        % max is ESL
        nanEslDepthMapMat_3d_3 = reshape(nanEslDepthMapMat_3d(:,3), 480,480,1);
        eslResDepthMapMat_3 = reshape(eslResDepthMapMat(:,3), 480, 480,1);
        xiMaxInds = nan(480,1);
        xiMaxPc = nan(480,3);
        xiResMaxInds = nan(480,1);
        xiResMaxPc = nan(480,3);
        for yi=1:480
            yiMaxVal = 10;
            xiMaxInd = nan;
            yiResMaxVal = 10;
            xiResMaxInd = nan;
            for xi=1:480
                if nanEslDepthMapMat_3d_3(yi, xi)>yiMaxVal
                    yiMaxVal = nanEslDepthMapMat_3d_3(yi,xi);
                    xiMaxInd = xi;
                end
                if eslResDepthMapMat_3(xi, yi)>yiResMaxVal
                    yiResMaxVal = eslResDepthMapMat_3(xi,yi);
                    xiResMaxInd = xi;
                end
            end
            xiMaxInds(yi) = xiMaxInd;
            if ~isnan(xiMaxInd)
                xiMaxPc(yi,:) = [xiMaxInd, yi, -yiMaxVal];
            end
            xiResMaxInds(yi) = xiResMaxInd;
            if ~isnan(xiResMaxInd)
                xiResMaxPc(yi,:) = [xiResMaxInd, yi, -yiResMaxVal];
            end
        end
        if printLevel>0
            pcshow(xiMaxPc, 'c', 'MarkerSize', 64);
            pcshow(xiResMaxPc, 'm', 'MarkerSize', 64);
            view(0,-90);
        end

        % now transform back into original 3D point cloud coordinate system
        origPc = [];
        for basePlyPath=basePlyPaths
            for plySubfolder=plySubfolders
                origPlyPath = append(basePlyPath, "/", string(i), "/",plySubfolder, "/", replace(nanDepthMaps(j).name, "_nanDepthMap.csv", ".ply"));
                if exist(origPlyPath, "file")
                    origPc = pcread(origPlyPath);
                    break;
                end
            end
            if ~isempty(origPc)
                break;
            end
        end
        if isempty(origPc)
            keyboard;
        end

        maxDimX = 480; % TODO think about this
        maxDimY = 480;
        minX = origPc.XLimits(1);
        maxX = origPc.XLimits(2);
        minY = origPc.YLimits(1);
        maxY = origPc.YLimits(2);
        deltaX = (maxX-minX)/maxDimX;
        deltaY = (maxY-minY)/maxDimY;

        xiMaxPcLine = xiMaxPc;
        xiMaxPcLine(isnan(xiMaxPcLine(:,3)), :) = [];
        for pci=1:length(xiMaxPcLine)
            xiMaxPcLine(pci,1) = minX+xiMaxPcLine(pci,1)*deltaX;
            xiMaxPcLine(pci,2) = minY+xiMaxPcLine(pci,2)*deltaY;
            xiMaxPcLine(pci,3) = origPc.ZLimits(1);
        end
        xiResMaxPcLine = xiResMaxPc;
        xiResMaxPcLine(isnan(xiResMaxPcLine(:,3)), :) = [];
        for pci=1:length(xiResMaxPcLine)
            xiResMaxPcLine(pci,1) = minX+xiResMaxPcLine(pci,1)*deltaX;
            xiResMaxPcLine(pci,2) = minY+xiResMaxPcLine(pci,2)*deltaY;
            xiResMaxPcLine(pci,3) = origPc.ZLimits(1);
        end

        if printLevel>0
            origPc_ds = pcdownsample(origPc, 'gridAverage', 2/1000);
            yMin = min(xiMaxPcLine(:,2))-0.01;
            yMax = max(xiMaxPcLine(:,2))+0.01;
            inds = origPc_ds.Location(:,2)>yMin&origPc_ds.Location(:,2)<yMax;
            figure(f2);
            hold off;
            if isempty(origPc_ds.Color)
                pcshow(origPc_ds.Location(inds, :), 'MarkerSize',57);
            else
                pcshow(origPc_ds.Location(inds, :), origPc_ds.Color(inds, :), 'MarkerSize',57);                
            end
            hold on;
            pcshow(xiMaxPcLine-[0 0 0.003], 'r', 'MarkerSize', 64);
            pcshow(xiResMaxPcLine-[0 0 0.003], 'g', 'MarkerSize', 64);
            view(0,-90);
            set(gcf,'color','w');
            set(gca,'color','w');
            axis off
            axis equal
        end

        % now find the projection onto the point cloud
        origPc2d = origPc.Location;
        origPc2d(:,3) = 0;
        xiMaxPcLine2d = xiMaxPcLine;
        xiMaxPcLine2d(:,3) = 0;
        xiResMaxPcLine2d = xiResMaxPcLine;
        xiResMaxPcLine2d(:,3) = 0;
        Idx1 = knnsearch(origPc2d, xiMaxPcLine2d);
        xiMaxPcLine(:,3) = origPc.Location(Idx1,3);
        Idx2 = knnsearch(origPc2d, xiResMaxPcLine2d);
        xiResMaxPcLine(:,3) = origPc.Location(Idx2,3);

        % use smoothing fit
        tmpVar = xiMaxPcLine;
        px = fit(tmpVar(:,2), tmpVar(:,1), 'smoothingspline', 'SmoothingParam',0.99999);
        xx = feval(px,tmpVar(:,2))';
        pz = fit(tmpVar(:,2), tmpVar(:,3), 'smoothingspline', 'SmoothingParam',0.99999);
        zz = feval(pz,tmpVar(:,2))';
        xiMaxPcLine_fit = [xx',xiMaxPcLine(:,2), zz'];
        tmpVar = xiResMaxPcLine;
        px = fit(tmpVar(:,2), tmpVar(:,1), 'smoothingspline', 'SmoothingParam',0.99999);
        xx = feval(px,tmpVar(:,2))';
        pz = fit(tmpVar(:,2), tmpVar(:,3), 'smoothingspline', 'SmoothingParam',0.99999);
        zz = feval(pz,tmpVar(:,2))';
        xiResMaxPcLine_fit = [xx',xiResMaxPcLine(:,2), zz'];

        if printLevel>0
            origPc_ds = pcdownsample(origPc, 'gridAverage', 2/1000);
            yMin = min(xiMaxPcLine(:,2))-0.01;
            yMax = max(xiMaxPcLine(:,2))+0.01;
            inds = origPc_ds.Location(:,2)>yMin&origPc_ds.Location(:,2)<yMax;
            figure(f3);
            hold off;
            if isempty(origPc_ds.Color)
                pcshow(origPc_ds.Location(inds, :), 'MarkerSize',57);
            else
                pcshow(origPc_ds.Location(inds, :), origPc_ds.Color(inds, :), 'MarkerSize',57);
            end
            hold on;
            pcshow(xiMaxPcLine-[0 0 0.003], 'r', 'MarkerSize', 64);
            pcshow(xiResMaxPcLine-[0 0 0.003], 'g', 'MarkerSize', 64);
            view(0,-90);
            set(gcf,'color','w');
            set(gca,'color','w');
            axis off
            axis equal

            figure(f4);
            hold off;
            if isempty(origPc_ds.Color)
                pcshow(origPc_ds.Location(inds, :), 'MarkerSize',57);
            else
                pcshow(origPc_ds.Location(inds, :), origPc_ds.Color(inds, :), 'MarkerSize',57);
            end
            hold on;
            pcshow(xiMaxPcLine_fit-[0 0 0.003], 'r', 'MarkerSize', 64);
            pcshow(xiResMaxPcLine_fit-[0 0 0.003], 'g', 'MarkerSize', 64);
            view(0,-90);
            set(gcf,'color','w');
            set(gca,'color','w');
            axis off
            axis equal
        end

        % now calculate the rmse
        [~, dists1] = knnsearch(xiResMaxPcLine, xiMaxPcLine);
        [~, dists2] = knnsearch(xiMaxPcLine, xiResMaxPcLine);
        errors = [errors; [dists1; dists2]];
        if max([dists1; dists2])>25/1000
            largeOutliers = [largeOutliers, string(nanDepthMaps(j).name)];
        end
        medianError = median([dists1; dists2]);
        medianErrors = [medianErrors; medianError];
        rmseError = sqrt(sum([dists1;dists2].^2)/length([dists1;dists2]));
        rmseErrors = [rmseErrors; rmseError];
        errorOrder  = [errorOrder, string(nanDepthMaps(j).name)];
        % error calc with smoothing fit
        [~, dists1_fit] = knnsearch(xiResMaxPcLine_fit, xiMaxPcLine_fit);
        [~, dists2_fit] = knnsearch(xiMaxPcLine_fit, xiResMaxPcLine_fit);
        errors_fit = [errors_fit; [dists1_fit; dists2_fit]];
        if max([dists1_fit; dists2_fit])>20/1000
            largeOutliers_fit = [largeOutliers_fit, string(nanDepthMaps(j).name)];
        end
        medianError_fit = median([dists1_fit; dists2_fit]);
        medianErrors_fit = [medianErrors_fit; medianError_fit];
        rmseError_fit = sqrt(sum([dists1_fit;dists2_fit].^2)/length([dists1_fit;dists2_fit]));
        rmseErrors_fit = [rmseErrors_fit; rmseError_fit];

        if printLevel>1
            disp("Median / RMSE error in mm: " + string(medianError*1000) + " " + string(rmseError*1000));
        end
    end
end

%% plot
addpath("Utils")
if ~exist(commonOutputPath, 'dir')
    mkdir(commonOutputPath)
end

figure;
CustomBoxPlot(errors*1000);
title("Error: pred ESL - ref ESL")
ylabel("[mm]");
saveas(gcf, append(commonOutputPath, "/ErrorsPredRefESL.fig"))
exportgraphics(gca, append(commonOutputPath, "/ErrorsPredRefESL.png"),"Resolution",600)
save(append(commonOutputPath, "/ErrorsPredRefESL.mat"), "errors");

figure;
CustomBoxPlot(medianErrors*1000);
title("Median error: pred ESL - ref ESL");
ylabel("[mm]");
saveas(gcf, append(commonOutputPath, "/MedianErrorsPredRefESL.fig"))
exportgraphics(gca, append(commonOutputPath, "/MedianErrorsPredRefESL.png"),"Resolution",600)
save(append(commonOutputPath, "/MedianErrorsPredRefESL.mat"), "errors");

figure;
CustomBoxPlot(rmseErrors*1000);
title("RMSE error: pred ESL - ref ESL");
ylabel("[mm]");
saveas(gcf, append(commonOutputPath, "/RMSEErrorsPredRefESL.fig"))
exportgraphics(gca, append(commonOutputPath, "/RMSEErrorsPredRefESL.png"),"Resolution",600)
save(append(commonOutputPath, "/RMSEErrorsPredRefESL.mat"), "errors");

figure;
CustomBoxPlot(errors_fit*1000);
title("Error: pred ESL - ref ESL -fit")
ylabel("[mm]");
saveas(gcf, append(commonOutputPath, "/ErrorsPredFitRefESL.fig"))
exportgraphics(gca, append(commonOutputPath, "/ErrorsPredFitRefESL.png"),"Resolution",600)
save(append(commonOutputPath, "/ErrorsPredFitRefESL.mat"), "errors");

figure;
CustomBoxPlot(medianErrors_fit*1000);
title("Median error: pred ESL - ref ESL -fit");
ylabel("[mm]");
saveas(gcf, append(commonOutputPath, "/MedianErrorsPredFitRefESL.fig"))
exportgraphics(gca, append(commonOutputPath, "/MedianErrorsPredFitRefESL.png"),"Resolution",600)
save(append(commonOutputPath, "/MedianErrorsPredFitRefESL.mat"), "errors");

figure;
CustomBoxPlot(rmseErrors_fit*1000);
title("RMSE error: pred ESL - ref ESL -fit");
ylabel("[mm]");
saveas(gcf, append(commonOutputPath, "/RMSEErrorsPredFitRefESL.fig"))
exportgraphics(gca, append(commonOutputPath, "/RMSEErrorsPredFitRefESL.png"),"Resolution",600)
save(append(commonOutputPath, "/RMSEErrorsPredFitRefESL.mat"), "errors");

%% functions

if printLevel>0
    figure(f1)
    doSaveCurrentImage("DepthMapEstRefSPL_B24", commonOutputPath)
    figure(f2)
    doSaveCurrentImage("PC1EstRefSPL_B24", commonOutputPath)
    figure(f3)
    doSaveCurrentImage("PC2EstRefSPL_B24", commonOutputPath)
    figure(f4)
    doSaveCurrentImage("PCSmoothedEstRefSPL_B24", commonOutputPath)
end

function doSaveCurrentImage(name, commonOutputPath)
saveas(gcf, append(commonOutputPath, "/",name,".fig"))
exportgraphics(gca, append(commonOutputPath, "/",name,".png"),"Resolution",600)
end