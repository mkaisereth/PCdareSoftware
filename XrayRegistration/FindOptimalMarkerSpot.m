function [xo,yo] = FindOptimalMarkerSpot(x,y,image)

% use a section around the point
deltaI = 30;
yMin = max(y-deltaI, 0);
yMax = min(y+deltaI,size(image,1));
xMin = max(x-deltaI,0);
xMax = min(x+deltaI,size(image,2));
subimg = image(yMin:yMax, xMin:xMax);

threshold = quantile(subimg(:),0.96);
subimg(subimg<threshold)=0;
subimg(subimg>=threshold)=1;
cc = bwconncomp(subimg)
% get the largest one
numPixels = cellfun(@numel,cc.PixelIdxList);
[~,idx] = max(numPixels);

S = regionprops(cc,'Centroid')
biggestCentroid = round(S(idx).Centroid)
xo = biggestCentroid(1) + xMin;
yo = biggestCentroid(2) + yMin;
end