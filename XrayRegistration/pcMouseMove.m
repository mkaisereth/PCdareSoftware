function pcMouseMove (object, eventdata, pointCloud)

global moveData;
if moveData.Val == 1
    pointCloudIndex = SelectPointFromPc(pointCloud, false);
    % don't allow duplicates
    if isempty(moveData.Pts) || moveData.Pts(end)~=pointCloudIndex
        h = plot3(pointCloud(1, pointCloudIndex), pointCloud(2, pointCloudIndex), pointCloud(3, pointCloudIndex), 'r.', 'MarkerSize', 12);
        moveData.Pts = [moveData.Pts, pointCloudIndex];
        moveData.Hs = [moveData.Hs, h];
    end
end

end