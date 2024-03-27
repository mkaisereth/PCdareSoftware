function t = TransposeJsonStruct(jsonT, hasPixel)

t = jsonT';
for i=1:size(t, 2)
    if hasPixel
        t(i).Pixel = t(i).Pixel';
    end
    t(i).World = t(i).World';
end

end