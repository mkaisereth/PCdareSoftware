function [depthMap, avgX, avgY] = GetDepthMap(pc)

%[avgX,avgY] = GetPcAverageXYSpacing(pc);
avgX=5;
avgY=5;
XLimits = pc.XLimits;
YLimits = pc.YLimits;
xis = XLimits(1):avgX:XLimits(2);
yis = YLimits(1):avgY:YLimits(2);
width = length(xis);
height = length(yis);
depthMap = nan(height,width);
pcapc2d = pc.Location;
pcapc2d(:,3) = 0;
pcapc2d = pointCloud(pcapc2d);
for xi=1:width
    for yi=1:height
        [inds,~] = findNeighborsInRadius(pcapc2d, [xis(xi),yis(yi),0], avgX+avgY, 'Sort',true);
        if ~isempty(inds)
            numOfPts = min(3,length(inds));
            depthMap(yi,xi) = mean(pc.Location(inds(1:numOfPts),3)); % take mean of three closest points
        end
    end
end

end