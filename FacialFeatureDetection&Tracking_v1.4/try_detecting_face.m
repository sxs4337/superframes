clc;
close all;
clear all;
j = 1;
for i = 1:30
    disp(i);
input = imread(fullfile('C:\Users\TEMP\Downloads\FacialFeatureDetection&Tracking_v1.4\data',strcat(num2str(i),'.bmp')));
output = detect_face(input);
unwanted_out_size = [1,1];
if(~isequal(size(output),unwanted_out_size))
    name = strcat('out_',num2str(j),'.bmp');
    disp(name);
    j=j+1;
    imwrite(output,name);
end
end