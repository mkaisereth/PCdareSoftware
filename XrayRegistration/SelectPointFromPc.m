function [pointCloudIndex, selectedPoint] = SelectPointFromPc(pointCloud, useGinput)
if useGinput
    [x,y] = ginput(1);
else
end
    point = get(gca, 'CurrentPoint'); % mouse click position
    camPos = get(gca, 'CameraPosition'); % camera position
    camTgt = get(gca, 'CameraTarget'); % where the camera is pointing to
    camDir = camPos - camTgt; % camera direction
    camUpVect = get(gca, 'CameraUpVector'); % camera 'up' vector
    % build an orthonormal frame based on the viewing direction and the 
    % up vector (the "view frame")
    zAxis = camDir/norm(camDir);    
    upAxis = camUpVect/norm(camUpVect); 
    xAxis = cross(upAxis, zAxis);
    yAxis = cross(zAxis, xAxis);
    rot = [xAxis; yAxis; zAxis]; % view rotation 
    % the point cloud represented in the view frame
    rotatedPointCloud = rot * pointCloud;
    % the clicked point represented in the view frame
    rotatedPointFront = rot * point' ;
    % find the nearest neighbour to the clicked point 
    pointCloudIndex = dsearchn(rotatedPointCloud(1:2,:)', rotatedPointFront(1:2));

    selectedPoint = pointCloud(:, pointCloudIndex);
    % change order back to Matlab
    selectedPoint = selectedPoint';
end