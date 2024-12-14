function [primaryCobbAngles, ages, genders, heights, weights, cobb_angles_pt, cobb_angles_mt, cobb_angles_tl] = GetRedCapCobbAngles(filePath, onlyPrimary)

csvTable = readtable(filePath);
global usexlsCobbAngles;
if isempty(usexlsCobbAngles)
    usexlsCobbAngles = "primary_cobbangle";
end 
cobb_angles_primary = csvTable{:, usexlsCobbAngles};
if ~onlyPrimary
    ages = csvTable{:,"age"};
    genders = csvTable{:,"gender"};
    heights = csvTable{:,"height"};
    weights = csvTable{:,"weight"};
    cobb_angles_pt = csvTable{:, "cobb_angle_pt"};
    cobb_angles_mt = csvTable{:, "cobb_angles_mt"};
    cobb_angles_tl = csvTable{:, "cobb_angles_tl"};
    primary_cobb_angles = max([cobb_angles_pt, cobb_angles_mt, cobb_angles_tl], [], 2, "omitnan");
    diffs = abs([primary_cobb_angles-cobb_angles_primary]);
    diffs = sum(diffs, 'omitnan')
    if (diffs>0)
        disp("Warning, there is a discrepancy of Cobb angles")
    end
else
    ages = [];
    genders = [];
    heights = [];
    weights = [];
    cobb_angles_pt = [];
    cobb_angles_mt = [];
    cobb_angles_tl = [];
end
primaryCobbAngles = cobb_angles_primary;

end