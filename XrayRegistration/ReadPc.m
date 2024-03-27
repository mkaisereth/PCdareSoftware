function pc = ReadPc(pcPath)

if endsWith(pcPath, ".stl")
    stl = stlread(pcPath);
    pc = pointCloud(stl.Points);
    % UKBB: transform coordinate system
    addpath("UKBB");
    pcLoc = TransformUKBBCoord(pc.Location);
    pc = pointCloud(pcLoc);
else
    pc = pcread(pcPath);
end

end