function [pc, fig1, pcLinePts] = PcMarkerApp(pcPath, numOfMarkers, useColor, MarkerSize)

if ~exist('useColor', 'var')
    useColor = false;
end
if ~exist('MarkerSize', 'var')
    MarkerSize = [];
end

pc = ReadPc(pcPath);

global invertLeftBending;
if ~isempty(invertLeftBending) && invertLeftBending ~= 0
    qDiff = GetLeftBendingValue(pc)
end

global pcMarkers;
pcMarkers = struct;

fig1 = figure('WindowState','maximized');
set(fig1,'WindowKeyPressFcn',@PcEscPressed);
if useColor
    if isempty(MarkerSize)
        pcshow(pc);
    else
        pcshow(pc, 'MarkerSize', MarkerSize);
    end
else
    pcshow(pc.Location, [1 1 1]);
end

view([0 -89]);
hold on;

if numOfMarkers>0
global lastPcIndex;
lastPcIndex = 1;

while true
    switch lastPcIndex
        case 1
            AddInstructions("Press space and select C7 marker")
        case 2
            AddInstructions("Press space and select L5 marker")
        case 3
            AddInstructions("Press space and select marker for SIPS right (right in image)")
        case 4
            AddInstructions("Press space and select marker for SIPS left (left in image)")
        otherwise
            if lastPcIndex>numOfMarkers
                AddInstructions("Press space and draw external spinal line from C7 to L5")
            else
                AddInstructions(append("Press space and select marker ", string(lastPcIndex)))
            end
    end
    drawnow();
    WaitForSpace();
    if lastPcIndex>numOfMarkers
        break;
    end
    [~, circlePt] = SelectPointFromPc(pc.Location', true);
    hold on;
    h = plot3(circlePt(:,1), circlePt(:,2), circlePt(:,3), 'r.', 'MarkerSize', 12);
    view([0 -89]);
    
    pcMarkers(lastPcIndex).World = circlePt;
    pcMarkers(lastPcIndex).H = h;
    lastPcIndex = lastPcIndex+1;
end
lastPcIndex = -1;

if ~useColor
    % cut the point cloud to region of interest
    pcCutLoc = pc.Location;
    pcCutLoc(pcCutLoc(:,2)<pcMarkers(1).World(2)-20, :) = [];
    pcCutLoc(pcCutLoc(:,2)>pcMarkers(2).World(2)+20, :) = [];
    pcCutLoc(pcCutLoc(:,1)>pcMarkers(3).World(1)+20, :) = [];
    pcCutLoc(pcCutLoc(:,1)<pcMarkers(4).World(1)-20, :) = [];
    pcCut = pointCloud(pcCutLoc);
    addpath('..\');
    % color the point cloud for helping drawing the line
    cutColorPts = CalculateHorizontalColors(pcCut, 0);
    
    pcshow(pcCut.Location, cutColorPts);
    hold on;
    % redraw markers
    for i=1:numOfMarkers    
        pcshow(pcMarkers(i).World, 'r', 'MarkerSize', 128);
    end
    view([0 -89]);
    end
end

% zoom image according to C7 and L5
global useMarkerZoom;
if ~isempty(useMarkerZoom) && useMarkerZoom
    markersMinY = pcMarkers(1).World(2);
    markersMaxY = min(pcMarkers(2).World(2), min(pcMarkers(3).World(2), pcMarkers(4).World(2)));
    ax = gca;
    ax.YLim = [markersMinY-0.1, markersMaxY+0.1];
end

% rotate only for drawing line
if ~isempty(invertLeftBending) && invertLeftBending ~= 0    
    % invert x axis for left bending or right bending
    if (invertLeftBending>0 && qDiff>invertLeftBending) || (invertLeftBending<0 && qDiff<invertLeftBending)
        h1 = gca;
        set(h1, 'Xdir', 'reverse')
    end
end


rotate3d off;
global moveData;
moveData.Val = 0;
moveData.Pts = [];
moveData.Hs = [];
set(gcf,'WindowButtonDownFcn', {@pcMouseDown, pc});
set(gcf,'WindowButtonUpFcn', {@pcMouseUp});
AddInstructions("Draw external spinal line from C7 to L5, then press space to continue")
drawnow();
WaitForSpace();
pcLinePts = moveData.Pts;
AddInstructions("Close both figures to proceed")
drawnow();


function [qDiff] = GetLeftBendingValue(pc)

% now find min max
qUpperY = quantile(pc.Location(:,2),0.6);
qLowerY = quantile(pc.Location(:,2),0.4);
pcUpperLoc = pc.Location(pc.Location(:,2)>=qUpperY);
pcLowerLoc = pc.Location(pc.Location(:,2)<=qLowerY);
qu = mean(pcUpperLoc(:,1));
ql = mean(pcLowerLoc(:,1));
qDiff = qu-ql;

end

end
