function colorPts = CalculateHorizontalColors(pc,printLevel)

if ~exist('printLevel','var')
    printLevel = 2;
end
if ~exist('pc','var')
    pcLoc = stlread('1161.stl').Points;
    pc = pointCloud(pcLoc);
end
pcLoc = pc.Location;

if printLevel > 1
    figure;
    pcshow(pcLoc);
end

% regularize the point cloud
distSum = 0;
for i=1:size(pcLoc,1)
    [~,dist] = findNearestNeighbors(pc, pcLoc(i,:), 2);
    distSum = distSum + dist(2);
end
avgDist = distSum/size(pcLoc,1);
avgDist = 2*avgDist;

pcXGrid = pc.XLimits(1):avgDist:pc.XLimits(2);
pcYGrid = pc.YLimits(1):avgDist:pc.YLimits(2);
[X,Y] = meshgrid(pcXGrid,pcYGrid);

Z = [];
delta2 = 2*avgDist;
for xi = 1:size(X,1)
    for yi = 1:size(X,2)
        inds = findPointsInROI(pc, [X(xi,yi)-delta2 X(xi,yi)+delta2 Y(xi,yi)-delta2 Y(xi,yi)+delta2 -Inf Inf]);
        roiPts = pc.Location(inds,:);
        zMedian = median(roiPts(:,3));
        Z(xi,yi) = zMedian;
    end
end

% smooth again TODO use more robust gradient
kernelSizeX=3;
kernelSizeY=9;
kernelSize2=3;
K = (1/(kernelSizeX*kernelSizeY))*ones(kernelSizeY, kernelSizeX);
Z = nanconv(Z,K,'edge', 'nanout');

if printLevel > 1
    figure;
    tempZ = Z;
    surf(X,Y,reshape(tempZ,size(Z)), 'LineStyle','none');
    xlabel('x')
    ylabel('y')
    title('Smoothed point cloud rasterized')
    axis equal;
end

%% find the gradient in horizontal direction
[xu,~]     =   gradient(Z);
[xuu,~]   =   gradient(xu);
ql = quantile(xuu(:),0.05);
qu = quantile(xuu(:),0.95);
xuuTemp = xuu;
xuuTemp(xuuTemp<ql) = ql;
xuuTemp(xuuTemp>qu) = qu;

if printLevel > 1
    figure;
    surf(X,Y,Z, xuuTemp, 'LineStyle','none');
    xlabel('x')
    ylabel('y')
    axis equal;
end

%% draw the original point cloud with color
% remove all nans
inds = isnan(Z(:));
X(inds) = [];
Y(inds) = [];
Z(inds) = [];
xuuTemp(inds) = [];
regularPc = pointCloud([X(:),Y(:),Z(:)]);
colorPts = [];
for i=1:size(pc.Location, 1)
    [inds, ~] = findNearestNeighbors(regularPc,pc.Location(i,:),1);
    colorPts(end+1) = xuuTemp(inds);
end

if printLevel > 1
    figure;
    pcshow(pc.Location, colorPts);
end

end