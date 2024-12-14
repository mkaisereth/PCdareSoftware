clear all; close all;

firstName = "hNetESL_first";

% % read point cloud from hNet.py (paper example)
mat = readmatrix("Output/"+firstName+"_5.txt");
% show the pointcloud
pc = pointCloud(mat);
f1 = figure;
pcshow(pc);
title('PC from validation (result)');
savefig('Output/PC_output.fig');
saveas(f1, 'Output/PC_output.jpg')

mat = readmatrix("Input/Z_train_1.txt");
% show the pointcloud
pc = pointCloud(mat);
f1 = figure;
pcshow(pc);
title('Input PC');
savefig('Input/PC_input.fig');
saveas(f1, 'Input/PC_input.jpg')