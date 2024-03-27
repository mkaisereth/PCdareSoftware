function [apDicomMarkers, apImgInfo, latDicomMarkers, latImgInfo, fig1, apLinePts, latLinePts, hLinePoints] = DicomMarkerApp(apDcmPath, latDcmPath, numOfMarkers, dataset, useImcontrast)

global automaticMarkerOptimization;
global automaticMarkerOptimizationTemp;
automaticMarkerOptimizationTemp = automaticMarkerOptimization;

if ~exist("useImcontrast", "var")
    useImcontrast = false;
end

[apImgInfo, latImgInfo] = ReadDicomInformation(apDcmPath, latDcmPath);

% AP
global apImg;
apImg = apImgInfo.Image;
apImgResY = apImgInfo.ResY;
apImgResX = apImgInfo.ResX;
global lastApLineIndex;
lastApLineIndex = -1;
global lastApIndex;
lastApIndex = 1;
global apDicomMarkers;
apDicomMarkers = struct;
global apDicomMarkerColors;
apDicomMarkerColors = struct;
global numOfMarkersAP;
numOfMarkersAP = numOfMarkers;
global datasetName;
datasetName = dataset;

% lat
global latImg;
latImg = latImgInfo.Image;
latImgResY = latImgInfo.ResY;
latImgResX = latImgInfo.ResX;

global fig1;
fig1 = figure;
global fig1ApLat;
fig1ApLat = 'ap';
fig1.WindowState = 'maximized';
set(fig1,'WindowKeyPressFcn',{@DicomEscPressed});

global drawingHLines;
drawingHLines = true;
global hPoints;
hPoints = [];

% show images together
global overallImg;
overallImg = [apImg, latImg];
if useImcontrast
    if size(overallImg,3)>1
        overallImg = rgb2gray(overallImg);
    end
end
imshow(overallImg, [], 'Border', 'loose');
global allowImageOptimization;
allowImageOptimization = true;

% some layouting
drawnow();
ax = gca;
set(ax,'XTick',[], 'YTick', []);
%set(ax,'Unit','normalized','Position',[0 0 1 1]);
set(fig1,'menubar','none');
set(fig1,'ToolBar','figure');
if useImcontrast
    imgMinVal = min(min(overallImg));
    imgMaxVal = max(max(overallImg));
    fig = uifigure("Position",[0 135 300 120]);
    g = uigridlayout(fig);
    g.RowHeight = {'1x', '1x'};
    g.ColumnWidth = {'1x'};
    global upperSliderVal;
    upperSliderVal = imgMaxVal;
    global lowerSliderVal;
    lowerSliderVal = imgMinVal;
    sld1 = uislider(g,"ValueChangedFcn",@(src,event)updateUpperLimit(src,event), "Limits",[double(imgMinVal), double(imgMaxVal)], "Value", double(imgMaxVal));
    sld.Layout.Row = 1;
    sld.Layout.Column = 1;
    sld2 = uislider(g,"ValueChangedFcn",@(src,event)updateLowerLimit(src,event), "Limits",[double(imgMinVal), double(imgMaxVal)], "Value", double(imgMinVal));
    sld.Layout.Row = 2;
    sld.Layout.Column = 1;
    %imcontrast(fig1);
end

% draw horizontal lines first
global hLineNum;
hLineNum = 1;
global hLines;
AddInstructions("Click with left mouse, then press l key to draw horizontal line for C7 (vertebra center)")
drawnow();
fig1.WindowState = 'maximized';
drawnow();
WaitForSpace();
drawingHLines = false;
% no contrast allowed anymore
allowImageOptimization = false;
if useImcontrast
    close(fig);
end

for i=1:size(hPoints, 1)
    % can be ap OR lat
    if hPoints(i,1)<=size(apImg,2)
        % ap
        hLinePoints(i).Pixel = hPoints(i,:);
        hLinePoints(i).World = [-hPoints(i,1)*apImgResX, hPoints(i,2)*apImgResY, 0];
    else
        % lat - remove ap image width
        xLocal = hPoints(i,1)-size(apImg,2);
        y = hPoints(i,2);
        % matlab pixels are from top left corner
        hLinePoints(i).Pixel = [xLocal,y];
        hLinePoints(i).World = [0, y*latImgResY, -xLocal*latImgResX];
    end
end

% zoom image according to C7 and L5
global useMarkerZoom;
if useMarkerZoom
    if ~isempty(hLines) && length(hLines)>1
        markersMinY = min(hLines);
        markersMaxY = max(hLines);
        ax = gca;
        ax.YLim = [max(markersMinY-100,0), min(markersMaxY+300,size(overallImg,1))];
    end
end

if automaticMarkerOptimization>0 && automaticMarkerOptimizationTemp<1
    automaticMarkerOptimizationTemp=automaticMarkerOptimizationTemp+1;
end

% now draw on first again
hold on;
if numOfMarkers>0
    while true
        switch lastApIndex
            case 1
                AddInstructions("Press right arrow and select AP marker for C7 (spinous process)")
                drawnow();
            case 2
                if datasetName == "Milano"
                    AddInstructions("Press right arrow and select AP marker for gluteal cleft")
                else
                    AddInstructions("Press right arrow and select AP marker for L5 (spinous process)")
                end
                drawnow();
            case 3
                AddInstructions("Press right arrow and select AP marker for SIPS right (left in image)")
                drawnow();
            case 4
                AddInstructions("Press right arrow and select AP marker for SIPS left (right in image)")
                drawnow();
            otherwise
                if lastApIndex>numOfMarkers
                    AddInstructions("Press right arrow and draw AP spine midline from C7 (middle) to L5 (lower endplate)")
                    drawnow();
                else
                    AddInstructions(append("Press right arrow and select AP marker ", string(lastApIndex)))
                    drawnow();
                end
        end
        WaitForSpace();
        if automaticMarkerOptimization>0 && automaticMarkerOptimizationTemp<1
            automaticMarkerOptimizationTemp=automaticMarkerOptimizationTemp+1;
        end
        if lastApIndex>numOfMarkers
            break;
        end
        [x,y] = ginputWhite(1);
        if automaticMarkerOptimizationTemp>0
            [x,y] = FindOptimalMarkerSpot(x,y,overallImg);
        end
        % matlab pixels are from top left corner
        apDicomMarkers(lastApIndex).Pixel = [x,y];
        apDicomMarkers(lastApIndex).World = [-x*apImgResX, y*apImgResY, 0];
    
        % save to be able to undo
        apDicomMarkerColors(lastApIndex).Position = [floor(x)-5,floor(y)-5,10,10];
        r = rectangle('Position',apDicomMarkerColors(lastApIndex).Position, 'FaceColor','r', 'LineStyle','none');
        apDicomMarkerColors(lastApIndex).R = r;
        % draw line
        if lastApIndex<=2
            apDicomMarkerColors(lastApIndex).Lines = [];
            apDicomMarkerColors(lastApIndex).Rs = [];
            for xi=1:4:size(apImg,2)
                apDicomMarkerColors(lastApIndex).Lines(xi, :) = [floor(xi)-2,floor(y)-2,4,4];
                r = rectangle('Position',apDicomMarkerColors(lastApIndex).Lines(xi, :), 'FaceColor','r', 'LineStyle','none');
                apDicomMarkerColors(lastApIndex).Rs = [apDicomMarkerColors(lastApIndex).Rs, r];
            end
        end
        lastApIndex = lastApIndex+1;
    end
end

lastApLineIndex = 1;
global moveData;
% reset moveData (Val 0 means no drawing, Val 1 means drawing (mouseDown))
moveData.Val = 0;
% the points
moveData.Pts = [];
% the rectangles (visualization)
moveData.Rs = [];
set(gcf,'WindowButtonDownFcn', {@mouseDown});
set(gcf,'WindowButtonUpFcn', {@mouseUp});
set (gcf, 'WindowButtonMotionFcn', {@mouseMove});
AddInstructions("Draw AP spine midline from C7 (middle) to L5 (lower endplate), then press right arrow to continue to LAT image")
drawnow();
WaitForSpace();
if automaticMarkerOptimization>0 && automaticMarkerOptimizationTemp<1
    automaticMarkerOptimizationTemp=automaticMarkerOptimizationTemp+1;
end
apLinePts = struct;
for i=1:size(moveData.Pts, 1)
    apLinePts(i).Pixel = moveData.Pts(i,:);
    apLinePts(i).World = [-moveData.Pts(i,1)*apImgResX, moveData.Pts(i,2)*apImgResY, 0];
end

% lateral
global lastLatLineIndex;
lastLatLineIndex = -1;
global lastLatIndex;
lastLatIndex = 1;
global latDicomMarkers;
latDicomMarkers = struct;
global latDicomMarkerColors;
latDicomMarkerColors = struct;
global numOfMarkersLAT;
numOfMarkersLAT = numOfMarkers;

fig1ApLat = 'lat';
if numOfMarkers>0
    while true
        switch lastLatIndex
            case 1
                AddInstructions("Press right arrow and select LAT marker for C7 (spinous process)")
                drawnow();
            case 2
                if datasetName == "Milano"
                    AddInstructions("Press right arrow and select LAT marker for gluteal cleft")
                else
                    AddInstructions("Press right arrow and select LAT marker for L5 (spinous process)")
                end
                drawnow();
            case 3
                AddInstructions("Press right arrow and select LAT marker for SIPS right (back in image)")
                drawnow();
            case 4
                AddInstructions("Press right arrow and select LAT marker for SIPS left (front in image)")
                drawnow();
            otherwise
                if lastLatIndex>numOfMarkers
                    AddInstructions("Press right arrow and draw LAT spine midline from C7 (middle) to L5 (lower endplate)")
                    drawnow();
                else
                    AddInstructions(append("Press right arrow and select LAT marker ", string(lastLatIndex)))
                    drawnow();
                end
        end
        WaitForSpace();
        if automaticMarkerOptimization>0 && automaticMarkerOptimizationTemp<1
            automaticMarkerOptimizationTemp=automaticMarkerOptimizationTemp+1;
        end
        if lastLatIndex>numOfMarkers
            break;
        end
        [x,y] = ginputWhite(1);
        if automaticMarkerOptimizationTemp>0
            [x,y] = FindOptimalMarkerSpot(x,y,overallImg);
        end
        % remove ap image width
        xLocal = x-size(apImg,2);
        % matlab pixels are from top left corner
        latDicomMarkers(lastLatIndex).Pixel = [xLocal,y];
        latDicomMarkers(lastLatIndex).World = [0, y*latImgResY, -xLocal*latImgResX];
    
        % save to be able to undo
        latDicomMarkerColors(lastLatIndex).Position = [floor(x)-5,floor(y)-5,10,10];
        r = rectangle('Position',latDicomMarkerColors(lastLatIndex).Position, 'FaceColor','r', 'LineStyle','none');
        latDicomMarkerColors(lastLatIndex).R = r;
        % draw line
        if lastLatIndex<=2
            latDicomMarkerColors(lastLatIndex).Lines = [];
            latDicomMarkerColors(lastLatIndex).Rs = [];
            for xi=1:4:size(latImg,2)
                latDicomMarkerColors(lastLatIndex).Lines(xi, :) = [floor(xi+size(apImg,2))-2,floor(y)-2,4,4];
                r = rectangle('Position',latDicomMarkerColors(lastLatIndex).Lines(xi, :), 'FaceColor','r', 'LineStyle','none');
                latDicomMarkerColors(lastLatIndex).Rs = [latDicomMarkerColors(lastLatIndex).Rs, r];
            end
        end
        lastLatIndex = lastLatIndex+1;
    end
end

lastLatLineIndex = 1;
global moveData;
moveData.Val = 0;
moveData.Rs = [];
moveData.Pts = [];
AddInstructions("Draw LAT spine midline from C7 (middle) to L5 (lower endplate), then press right arrow to continue to Point cloud")
drawnow();
WaitForSpace();
latLinePts = struct;

for i=1:size(moveData.Pts, 1)
    latLinePts(i).Pixel = [moveData.Pts(i,1)-size(apImg,2), moveData.Pts(i,2)];
    latLinePts(i).World = [0, moveData.Pts(i,2)*latImgResY, -(moveData.Pts(i,1)-size(apImg,2))*latImgResX];
end
end

%% functions
function updateUpperLimit(src,event)

global overallImg;
global upperSliderVal;
upperSliderVal = event.Value;
global lowerSliderVal;
scaledImg = overallImg;
scaledImg(scaledImg(:)<lowerSliderVal) = lowerSliderVal;
scaledImg(scaledImg(:)>upperSliderVal) = upperSliderVal;
scaledImg = reshape(scaledImg, size(overallImg));
scaledImg = rescale(scaledImg, 0, 255);
imshow(uint8(scaledImg));
global fig1;
fig1.WindowState = 'maximized';

end

function updateLowerLimit(src,event)

global overallImg;
global upperSliderVal;
global lowerSliderVal;
lowerSliderVal = event.Value;
scaledImg = overallImg;
scaledImg(scaledImg(:)<lowerSliderVal) = lowerSliderVal;
scaledImg(scaledImg(:)>upperSliderVal) = upperSliderVal;
scaledImg = reshape(scaledImg, size(overallImg));
scaledImg = rescale(scaledImg, 0, 255);
imshow(uint8(scaledImg));
global fig1;
fig1.WindowState = 'maximized';

end