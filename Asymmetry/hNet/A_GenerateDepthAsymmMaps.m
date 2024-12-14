close all; clear all; clc;

basePath = "../Data/hNet";
subfolder = "Sample";
pcNameFilter = '*Photoneo_*.ply';

% balgrist
subjectNrs = 1:30;

printLevel = 0;
% how fast the target shape (ESL, ISL) should decay
decayInt = 50;

% with target for training
withTarget = true;

totalNum = length(subjectNrs);
inc = 0;
startTime = now;

% force fixed dimensions
maxDimX = 480; % TODO think about this
maxDimY = 480;

%% calc depth maps
if printLevel>0
    f1 = figure("Position",[100 500 500 500]);
    f2 = figure("Position",[700 500 500 500]);
    f3 = figure("Position",[1300 500 500 500]);
end
for i=1:totalNum
    
    if i > 1
        eta = ((now-startTime)/(i-1)*(totalNum-i))*24*60;
    else
        eta = 0;
    end
    disp(i + "/" + totalNum + " eta: " + round(eta,1) + " min");

    % check whether this is a valid subject
    subjectNr = subjectNrs(i);
    subjectFolderPath = append(basePath, "/", string(subjectNr), "/", subfolder);
    if ~exist(subjectFolderPath, "dir")
        disp("Warning: subject folder does NOT exist: " + string(subjectNr))
        continue;
    end
    plyFiles = dir(append(subjectFolderPath, "/", pcNameFilter));
    if length(plyFiles)<1
        disp("Warning: subject plys do NOT exist: " + string(subjectNr))
        continue;
    else
        for pi=1:length(plyFiles)
            plyFilePath = append(plyFiles(pi).folder, "/", plyFiles(pi).name);
            pc = pcread(plyFilePath); % point cloud is in m
            if withTarget
                % now read ESL file
                jsonFilePath = append(plyFiles(pi).folder, "/Output/", plyFiles(pi).name);
                eslFilePath = replace(jsonFilePath, ".ply", "_PcLinePts.json");
                fid = fopen(eslFilePath); 
                raw = fread(fid,inf); 
                str = char(raw'); 
                fclose(fid); 
                jsonData = jsondecode(str);
                eslPts = jsonData.pcLinePts; % ESL points are in mm
            end

            % TODO
            minX = pc.XLimits(1);
            maxX = pc.XLimits(2);
            minY = pc.YLimits(1);
            maxY = pc.YLimits(2);
            deltaX = (maxX-minX)/maxDimX;
            deltaY = (maxY-minY)/maxDimY;

            depthMap = nan(maxDimY,maxDimX);
            textureMap = nan(maxDimY,maxDimX);
            eslDepthMap = nan(maxDimY,maxDimX);
            % get nearest neighbors for all points
            [depthMapIndsX,depthMapIndsY] = meshgrid(minX:deltaX:maxX-0.1*deltaX, minY:deltaY:maxY-0.1*deltaY);
            depthMapIndsX = reshape(depthMapIndsX, maxDimX*maxDimY, 1);
            depthMapIndsY = reshape(depthMapIndsY, maxDimX*maxDimY, 1);
            depthMapIndsXY = [depthMapIndsX depthMapIndsY];
            [Ids,Dists] = knnsearch(pc.Location(:,1:2), depthMapIndsXY);
            ptCounter=1;
            for xi=1:maxDimX
                for yi=1:maxDimY
                    if Dists(ptCounter)<0.002
                        depthMap(yi,xi) = pc.Location(Ids(ptCounter),3);
                        if ~isempty(pc.Color)
                            textureMap(yi,xi) = pc.Color(Ids(ptCounter),1);
                        end
                    end
                    ptCounter = ptCounter+1;
                end
            end
            if printLevel>0
                figure(f1);
                hold off;
                imshow((textureMap-min(textureMap(:)))./(max(textureMap(:)-min(textureMap(:)))));
            end
            depthMapNormalized = (depthMap-min(depthMap(:)))./(max(depthMap(:)-min(depthMap(:))));
            if printLevel>0
                figure(f2);
                hold off;
                imshow(depthMapNormalized);
            end
            depthMapNormalized = 2*(depthMap-min(depthMap(:)))./(max(depthMap(:)-min(depthMap(:))))-1;

            if withTarget
                % project ESL (get x,y values in pixel space)
                normalizedEslXValues = rescale(eslPts(:,1)/1000, 1, maxDimX, 'InputMin',min(depthMapIndsX(:)),'InputMax',max(depthMapIndsX(:)));
                normalizedEslYValues = rescale(eslPts(:,2)/1000, 1, maxDimY, 'InputMin',min(depthMapIndsY(:)),'InputMax',max(depthMapIndsY(:)));
                % interpolate such that each x value inbetween is present
                normalizedEslYValues_ip = (round(min(normalizedEslYValues)):round(max(normalizedEslYValues)))';
                Ids = knnsearch(normalizedEslYValues, normalizedEslYValues_ip);
                normalizedEslXValues_ip = round(normalizedEslXValues(Ids));
                % draw into texture map
                if printLevel>0
                    figure(f1);
                    hold on;
                    for eslInd=1:length(normalizedEslXValues_ip)
                        rectangle('Position', [normalizedEslXValues_ip(eslInd)-1 normalizedEslYValues_ip(eslInd)-1 2 2], 'FaceColor', 'r', 'LineStyle','none');
                    end
                end
                siCounter = 1;
                for yi=normalizedEslYValues_ip'
                    xi = normalizedEslXValues_ip(siCounter);
    
                    zValue = 50; % use max as indicator for ESL location
                    eslDepthMap(yi, xi) = zValue;
                    % decrease until 0 (I think better for machine learning)
                    decayArr = gaussmf(-decayInt:decayInt, [decayInt*0.3,0]);
                    for edmi=1:decayInt
                        if xi+edmi > maxDimX
                            break;
                        end
                        eslDepthMap(yi, xi+edmi) = zValue*decayArr(decayInt+1-edmi);
                    end
                    for edmi=1:decayInt
                        if xi-edmi < 1
                            break;
                        end
                        eslDepthMap(yi, xi-edmi) = zValue*decayArr(decayInt+1-edmi);
                    end
                    
                    siCounter=siCounter+1;
                end
        
                % show point cloud for validation
                if printLevel > 1
                    figure(f3);
                    hold off;
                    surf(depthMapNormalized', 'LineStyle','none');
                    hold on;
                    surf(eslDepthMap', 'Marker','*');
                    view(90,90)
                end
            end
    
            % now save it to be used later
            writematrix(single(depthMapNormalized), replace(plyFilePath, ".ply", "_nanDepthMap.csv"))
    
            if withTarget
                % only for testing
                %eslDepthMap = depthMap+100;
                writematrix(single(eslDepthMap), replace(plyFilePath, ".ply", "_nanEslDepthMap.csv"))
            end
        end
    end
end