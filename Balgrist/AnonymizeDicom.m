dirList = ["10", "11", "12"];

for i=dirList
    dcmList = dir(append(pwd, "\", i, "\*.dcm"));
    for dcmP = dcmList'
        if ~contains(dcmP.name, "_anon")
            values.StudyDate = '';
            values.StudyTime = '';
            dicomanon(append(dcmP.folder, "\", dcmP.name), append(dcmP.folder, "\", replace(dcmP.name, ".dcm", "_anon.dcm")), "update", values);
        end
    end
end

%% now blur the images
for i=dirList
    dcmList = dir(append(pwd, "\", i, "\*_anon.dcm"));
    for dcmP = dcmList'
        dcmImg = dicomread(append(dcmP.folder, "\", dcmP.name));
        dcmImg = imgaussfilt(dcmImg,20);
        figure;
        imshow(dcmImg);
        dicomwrite(dcmImg, append(dcmP.folder, "\", replace(dcmP.name, ".dcm", "2.dcm")), 'CompressionMode', 'JPEG2000 lossless');
        disp("");
    end
end