function pcLoc = TransformUKBBCoord(ukbbpts)

% UKBB: transform coordinate system
pcLoc = ukbbpts;
pcLoc(:,2) = -pcLoc(:,2);
pcLoc(:,3) = -pcLoc(:,3);

end