function [apImgInfo, latImgInfo] = ReadDicomInformation(apDcmPath, latDcmPath)

% AP
apImg = dicomread(apDcmPath);
apInfo = dicominfo(apDcmPath);
apImgRows = apInfo.Rows;
apImgCols = apInfo.Columns;
apImgResY = 0.179363;%apInfo.PixelSpacing(1);
apImgResX = 0.179363;%apInfo.PixelSpacing(2);
maxValue = max(max(max(apImg)));
if maxValue>255
    apImg = uint8(floor((255.0*double(apImg))/double(maxValue)));
end
apImgInfo.Image = apImg;
apImgInfo.Info = apInfo;
apImgInfo.ResX = apImgResX;
apImgInfo.ResY = apImgResY;

latImg = dicomread(latDcmPath);
latInfo = dicominfo(latDcmPath);
latImgRows = latInfo.Rows;
latImgCols = latInfo.Columns;
latImgResY = 0.179363;%latInfo.PixelSpacing(1);
latImgResX = 0.179363;%latInfo.PixelSpacing(2);
maxValue = max(max(max(latImg)));
if maxValue>255
    latImg = uint8(floor((255.0*double(latImg))/double(maxValue)));
end
latImgInfo.Image = latImg;
latImgInfo.Info = latInfo;
latImgInfo.ResX = latImgResX;
latImgInfo.ResY = latImgResY;

end