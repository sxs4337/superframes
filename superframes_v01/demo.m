%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Superframe segmentation
%%%%%%%%
% This shows how to use superframes as a temporal segmentation. 
% The code is a modified version of the one used in the initial
% publication: Gygli et al. - Creating Summaries from User Videos, ECCV 2014
% https://people.ee.ethz.ch/~gyglim/vsum/#sf_code
%
% The modifications include the addition of:
% Contrast Saturation Sharpness FaceImpact 
% and is the basis for Sah et al., WACV 2017
% 
% Ray Ptucha and Shagan Sah, Rochester Institute of Technology, 2017
% 
% If you use this code, please cite the following three references:
%
%   Gygli, Michael, Helmut Grabner, Hayko Riemenschneider, and Luc Van Gool. 
%   "Creating summaries from user videos." In European conference on computer 
%   vision, pp. 505-520. Springer, Cham, 2014.
%
%   Xuehan Xiong, Fernando de la Torre, Supervised Descent Method and Its
%   Application to Face Alignment. CVPR, 2013.
%  
%   Sah, Shagan, Sourabh Kulhare, Allison Gray, Subhashini Venugopalan, 
%   Emily Prud'Hommeaux, and Raymond Ptucha. "Semantic Text Summarization 
%   of Long Videos." In Applications of Computer Vision (WACV), 2017 IEEE 
%   Winter Conference on, pp. 989-997. IEEE, 2017.
%
%%%%%%%%

% 1) Copy the files:
% demo.m, demo_sunMe_ablation, getLengthPrior, sunme_computeMotion,
% sunme_scoreSuperframes, sunme_superframeSegmentatoin into a single
% directory, and set home to that location
home = 'C:\Users\sxs4337\Downloads\superframes_v01\superframes_v01';
cd(home);

% 2) If you are using FaceImpact, you will need to first install the
% Intraface software: http://www.humansensing.cs.cmu.edu/intraface/index.php
% Download the maltab functions onto your computer and set facepath to this
% download directory.  Note: depending on your computer, you may have to
% compile this code to get this work.
% 
faces=1;
if faces
    %facepath = 'C:\Users\rwpeec\Desktop\rwpeec\research\face_detection\FacialFeatureDetection&Tracking_v1.4';
    facepath = 'C:\Users\sxs4337\Downloads\FacialFeatureDetection&Tracking_v1.4\FacialFeatureDetection&Tracking_v1.4';
    addpath (facepath)% load model and parameters, type 'help xx_initialize' for more details
    cd (facepath);
    [Models,option] = xx_initialize;
    cd(home);
end

% 3) Download your favorite video dataset
% If MULTIVIDEO=0, then  (dataset only has one video)
%    HOMEIMAGES should be organized such that it contains extracted JPEG images, 
%    one JPEG image per frame of the video.
% Else If MULTIVIDEO=1, then (dataset has many videos)
%    HOMEIMAGES should be organized such that there is one sub directory per
%    video, and each subdirectory contains extracted JPEG images, one JPEG
%    image per frame of the video.
% End If
%
% Note, you will set HOMEIMAGES in step '5)'
MULTIVIDEO=0;

% 4) set videoData to a descriptive name of your dataset
videoData = 'bunny'; %default from superframe software demo
%videoData = 'facetest'; %handful of frames with faces for face testing
%videoData = 'dy01_orig'; %Disney test set from VideoSet - orig 16K
%videoData = 'dy01'; %Disney test set from VideoSet  - updated to 32K
%videoData = 'gr03'; %everyday life events test set from VideoSet 
%videoData = 'tv04'; %TV episode test set from VideoSet 
%videoData = 'dy01_new'; %Disney test set from VideoSet - new on 6/3/16
%videoData = 'gr03_new'; %everyday life events test set from VideoSet - new on 6/3/16
%videoData = 'tv04_new'; %TV episode test set from VideoSet - new on 6/3/16

% 5) set HOMEIMAGES to the root directory of your dataset.  Note how this
% version of the code uses a switch statement.  Yes, this is a hack!
% Feel free to modify to your liking! 
switch videoData
    case{'bunny'}
        HOMEIMAGES='./example_frames'; % Directory containing video frames
    case{'facetest'}
        HOMEIMAGES='./example_frames2'; % Directory containing video frames w/faces
    case{'dy01_orig'}
        HOMEIMAGES='C:\Users\rwpeec\Desktop\rwpeec\datasets\processedVideoSet\dy01_orig';
    case{'dy01'}
        HOMEIMAGES='C:\Users\rwpeec\Desktop\rwpeec\datasets\processedVideoSet\dy01';
    case{'gr03'}
        HOMEIMAGES='C:\Users\rwpeec\Desktop\rwpeec\datasets\processedVideoSet\gr03';
    case{'tv04'}
        HOMEIMAGES='C:\Users\rwpeec\Desktop\rwpeec\datasets\processedVideoSet\tv04';
    case{'dy01_new'}
        HOMEIMAGES='C:\Users\rwpeec\Desktop\rwpeec\datasets\processedVideoSet\dy01';
    case{'gr03_new'}
        HOMEIMAGES='C:\Users\rwpeec\Desktop\rwpeec\datasets\processedVideoSet\gr03';
    case{'tv04_new'}
        HOMEIMAGES='C:\Users\rwpeec\Desktop\rwpeec\datasets\processedVideoSet\tv04';
    case{'TACoS'}
        HOMEIMAGES='Y:\datasets\tacos\images\trainval';
        %HOMEIMAGES='Y:\datasets\tacos\images\test';
        MULTIVIDEO=1;
    otherwise
        disp('Unknown videData!')
end

%
% Keep the rest of the parameters in this cell/section as is to reproduce
% the data from WACV'17
%
%%%%% Video parameters  %%%%%
FPS=29; % Needed to use be able to compute the optimal segment length

%%%%% Method parameters %%%%%
% Default
default_parameters;

% Length prior parameters (optional, otherwise we take the ones learnt)
% Use can use this to change the length of the superframes
% See paper for more information
Params.lognormal.mu=1.16571;
Params.lognormal.sigma=0.742374;

%% Read in the images
if MULTIVIDEO == 1
    outD = dir(HOMEIMAGES);
    numDirs = length(outD)-2;  %-2 for . and ..
else
    numDirs = 3;
end

for dirCountIndex=1:numDirs
%for dirCount=4:numDirs
    dirCount= dirCountIndex+2;
    if MULTIVIDEO == 1
        clear imagesNew
        images=dir(fullfile([HOMEIMAGES '\' outD(dirCount).name],'*.jpg'));
        jj=0;
        for j = 1:10:length(images)
            jj = jj+1;
            imagesNew(jj) = images(j);
        end
        images = imagesNew';
        fprintf('Multivideo: Starting processing directory %s:  %d of %d\n',outD(dirCount).name,dirCountIndex,numDirs);
        imageList=cellfun(@(X)(fullfile([HOMEIMAGES '\' outD(dirCount).name],X)),{images(:).name},'UniformOutput',false);
    else
        images=dir(fullfile(HOMEIMAGES,'*.jpg'));
        imageList=cellfun(@(X)(fullfile(HOMEIMAGES,X)),{images(:).name},'UniformOutput',false);
    end
     
    
    % Run Superframe segmentation along with other salient features
    tic
    Params.Models = Models; %for faceDetection
    Params.option = option; %for faceDetection
    %note Contrast, Saturation, Sharpness, Faces added by rwp on May 2016
    [superFrames,motion_magnitude_of,Contrast,Saturation,Sharpness,FaceImpact] = summe_superframeSegmentation(imageList,FPS,Params);
    toc
    
    %%  Note: much of the plotting here is just for debug purposes... 
    % Plot motion magnitude and cuts
    h = figure(1);
    hold off
    pos=get(gcf,'Position');
    pos(3:4)=[1024 300];
    set(h, 'Position', pos);
    plot(motion_magnitude_of,'LineWidth',3,'Color','Black'); hold on;
    cuts=zeros(length(motion_magnitude_of),1);
    cuts(superFrames(:))=max(motion_magnitude_of);
    uniform=zeros(length(motion_magnitude_of),1);
    step=round(length(motion_magnitude_of)./length(superFrames));
    uniform(1:step:end)=max(motion_magnitude_of);
    bar(cuts,'FaceColor','Red','Edgecolor','Red'); hold on;
    bar(uniform,'FaceColor','Blue','Edgecolor','Blue'); hold on;
    legend('Motion Magnitude','Superframes cuts','Uniform cuts','Location','northwest')
    xlabel('Frame Number')
    ylabel('Avarage point displacement [%]')
    axis([1 length(cuts) 0 max(motion_magnitude_of)]);
    
    
    
    %%
    % Foreach superframe, generate scores for:
    %   Attention favors frames with more motion in the middle of a superframe
    %   Contrast is the std of low res grayscale
    %   Saturation is the mean saturation from low res HSV image
    %   Sharpness is the max of std on hi res grayscale
    %   Blend- this is the superframe score, which favors less motion in and out of the video cut
    % The normalized values force all to fall in 0:1 range:
    % cutRegionAttentionNorm, cutRegionContrastNorm , cutRegionSaturationNorm , cutRegionSharpnessNorm , cutRegionSuperFrameBlendNorm
    % The raw values for the above are:
    % cutRegionAttention,  cutRegionContrast, cutRegionSaturation, cutRegionSharpness, avgSuperFrameCutScore
    
    delta=1;
    delta=round(Params.DeltaInit*FPS);
    [ score,score_Add_left,score_Rem_left, score_Add_right,score_Rem_right ] = summe_scoreSuperframes( superFrames,motion_magnitude_of,FPS, delta, Params );
    
    score_Add_left(find(score_Add_left(:)<0))=score(find(score_Add_left(:)<0));
    score_Rem_left(find(score_Rem_left(:)<0))=score(find(score_Rem_left(:)<0));
    score_Add_right(find(score_Add_right(:)<0))=score(find(score_Add_right(:)<0));
    score_Rem_right(find(score_Rem_right(:)<0))=score(find(score_Rem_right(:)<0));
    %the cut score favors frames with less motion on cut boundaries
    avgSuperFrameCutScore = (score+score_Add_left+score_Rem_left+ score_Add_right+score_Rem_right)/5
    
    clear cutRegionMotion cutRegionVariance cutRegionContrast cutRegionSaturation cutRegionSharpness  cutRegionFaceImpact
    for i=1:length(superFrames)
        cutRegion= motion_magnitude_of(superFrames(i,1):superFrames(i,2));
        len = length(cutRegion);
        mid = round(len/2);
        %cutRegionMotion(i) = mean(cutRegion(5:end-4))/(mean([cutRegion(1:2)' cutRegion(end-1:end)']) +0.1 );
        cutRegionMotion(i) = mean(cutRegion(5:end-4));
        cutRegionVariance(i) = var(cutRegion);
        cutRegionContrast(i) = mean(Contrast(superFrames(i,1):superFrames(i,2)));
        cutRegionSaturation(i) = mean(Saturation(superFrames(i,1):superFrames(i,2)));
        cutRegionSharpness(i) = mean(Sharpness(superFrames(i,1):superFrames(i,2)));
        cutRegionFaceImpact(i) = mean(FaceImpact(superFrames(i,1):superFrames(i,2)));
    end
    alpha=0.7;
    cutRegionAttention = (alpha*cutRegionMotion)+(1-alpha)*cutRegionVariance
    cutRegionContrast
    cutRegionSaturation
    cutRegionSharpness
    cutRegionFaceImpact
    
    % note the 0.2+0.8*, changes range from 0:1 to 0.2:1
    cutRegionAttentionNorm = 0.2+0.8*(cutRegionAttention-min(cutRegionAttention))/(max(cutRegionAttention)-min(cutRegionAttention))
    cutRegionContrastNorm = 0.2+0.8*(cutRegionContrast-min(cutRegionContrast))/(max(cutRegionContrast)-min(cutRegionContrast))
    cutRegionSaturationNorm = 0.2+0.8*(cutRegionSaturation-min(cutRegionSaturation))/(max(cutRegionSaturation)-min(cutRegionSaturation))
    cutRegionSharpnessNorm = 0.2+0.8*(cutRegionSharpness-min(cutRegionSharpness))/(max(cutRegionSharpness)-min(cutRegionSharpness))
    cutRegionFaceImpactNorm = 0.2+0.8*(cutRegionFaceImpact-min(cutRegionFaceImpact))/(max(cutRegionFaceImpact)-min(cutRegionFaceImpact))
    cutRegionSuperFrameBlendNorm = 0.2+0.8*(avgSuperFrameCutScore-min(avgSuperFrameCutScore))/(max(avgSuperFrameCutScore)-min(avgSuperFrameCutScore))
    
    % baseline = cutRegionSuperFrameBlendNorm'.*cutRegionAttentionNorm.*cutRegionContrastNorm.*cutRegionSharpnessNorm;
    % cutRegionOverall = baseline + 0.2.*baseline.*cutRegionSaturationNorm + 0.35.*baseline.*cutRegionFaceImpactNorm;
    
    baseline = cutRegionAttentionNorm.*cutRegionContrastNorm.*cutRegionSharpnessNorm;
    cutRegionOverall = baseline + 0.35.*baseline.*cutRegionSuperFrameBlendNorm' + 0.2.*baseline.*cutRegionSaturationNorm + 0.35.*baseline.*cutRegionFaceImpactNorm;
    
    h = figure(2);
    hold off;
    pos=get(gcf,'Position');
    pos(3:4)=[1024 300];
    set(h, 'Position', pos);
    barData = [cutRegionSuperFrameBlendNorm'; cutRegionAttentionNorm; cutRegionContrastNorm ;  cutRegionSharpnessNorm ; cutRegionSaturationNorm ; cutRegionFaceImpactNorm ]';
    bar(barData)
    legend('Boundary','Attention','Contrast', 'Sharpness', 'Saturation', 'FaceImpact' );
    hold on; plot(cutRegionOverall*0.8/max(cutRegionOverall),'kp-','linewidth',3)
    xlabel('Superframe cut');
    
    cutRegionOverallNorm = cutRegionOverall/max(cutRegionOverall);
    % cutRegionOverall_Top_index = find(cutRegionOverallNorm>0.5);
    % cutoff at 50% of total energy
    [sorted,idx] = sort(cutRegionOverallNorm,'descend');
    cutRegionOverall_Top_index=[];
    for i=1:length(superFrames)
        cutRegionOverall_Top_index = [cutRegionOverall_Top_index ; idx(i)];
        if sum(cutRegionOverallNorm(cutRegionOverall_Top_index))/sum(cutRegionOverallNorm) > 0.5
            break
        end
    end
    cutRegionOverall_Top = cutRegionOverall(cutRegionOverall_Top_index);
    %cutRegionOverall_Top_sf_idx = 1:length(cutRegionOverallNorm);  %superframe index values
    %cutRegionOverall_Top_sf_idx = cutRegionOverall_Top_sf_idx(cutRegionOverall_Top_index);
    cutRegionOverall_Top_sf_idx=cutRegionOverall_Top_index';
    hold on; plot(cutRegionOverall_Top_sf_idx,cutRegionOverall_Top*0.8/max(cutRegionOverall_Top),'rp','linewidth',3);
    cutRegionOverall_Top_lpf_idx = superFrames(cutRegionOverall_Top_sf_idx,:); %corresponding frame region from low pass filtered and sampled video
    cutRegionOverall_Top_f_idx = (cutRegionOverall_Top_lpf_idx-1)*10+1; %corresponding frame region in original video
    %note, above assumes 10 frame averaging, or
    %frames 1:10 go to lpf 1
    %frames 11:20 go to lpf 2
    %frames 21:30 go to lpf 3
    %...
    %frames 91:100 go to lpf 10
    %frames 101:110 go to lpf 11
    %frames 111:120 go to lpf 12
    %...
    %[1000*(cutRegionOverall_Top*0.8/max(cutRegionOverall_Top))' cutRegionOverall_Top_index cutRegionOverall_Top_lpf_idx cutRegionOverall_Top_f_idx]
    imp = cutRegionOverall_Top*0.8/max(cutRegionOverall_Top);
    disp(videoData)
    fprintf('Importance, SF Cut, LP_Frame Start/Stop,  OrigVideo Start/Stop\n');
    for i=1:length(cutRegionOverall_Top_index)
        fprintf('%8.5f %7d %7d %7d %7d %7d\n',imp(i),cutRegionOverall_Top_index(i), ...
            cutRegionOverall_Top_lpf_idx(i,1), cutRegionOverall_Top_lpf_idx(i,2), ...
            cutRegionOverall_Top_f_idx(i,1), cutRegionOverall_Top_f_idx(i,2));
    end
    max(cutRegionOverall_Top_f_idx(:,2))
    min(cutRegionOverall_Top_f_idx(:,1))
    
    switch videoData
        case{'bunny','facetest'}
            ;
        case{'dy01_new'}
            figure(1); print -dpng dy01_new_superframeBoundary.png
            figure(2); print -dpng dy01_new_superframeImpact.png
            save dy01_new.mat cut* superFrames motion_magnitude_of Contrast Saturation Sharpness FaceImpact HOMEIMAGES imageList videoData
            save dy01_new_sfx.asc cutRegionOverall_Top_f_idx -ascii
            %Importance, SF Cut, LP_Frame Start/Stop,  OrigVideo Start/Stop
            save dy01_new_sfx_detail.asc imp cutRegionOverall_Top_index cutRegionOverall_Top_lpf_idx cutRegionOverall_Top_f_idx -ascii
        case{'gr03_new'}
            figure(1); print -dpng gr03_new_superframeBoundary.png
            figure(2); print -dpng gr03_new_superframeImpact.png
            save gr03_new.mat cut* superFrames motion_magnitude_of Contrast Saturation Sharpness FaceImpact HOMEIMAGES imageList videoData
            save gr03_new_sfx.asc cutRegionOverall_Top_f_idx -ascii
            %Importance, SF Cut, LP_Frame Start/Stop,  OrigVideo Start/Stop
            save gr03_new_sfx_detail.asc imp cutRegionOverall_Top_index cutRegionOverall_Top_lpf_idx cutRegionOverall_Top_f_idx -ascii
        case{'tv04_new'}
            figure(1); print -dpng tv04_new_superframeBoundary.png
            figure(2); print -dpng tv04_new_superframeImpact.png
            save tv04_new.mat cut* superFrames motion_magnitude_of Contrast Saturation Sharpness FaceImpact HOMEIMAGES imageList videoData
            save tv04_new_sfx.asc cutRegionOverall_Top_f_idx -ascii
            %Importance, SF Cut, LP_Frame Start/Stop,  OrigVideo Start/Stop
            save tv04_new_sfx_detail.asc imp cutRegionOverall_Top_index cutRegionOverall_Top_lpf_idx cutRegionOverall_Top_f_idx -ascii
        case{'dy01'}
            figure(1); print -dpng dy01_superframeBoundary.png
            figure(2); print -dpng dy01_superframeImpact.png
            save dy01.mat cut* superFrames motion_magnitude_of Contrast Saturation Sharpness FaceImpact HOMEIMAGES imageList videoData
            save dy01_sfx.asc cutRegionOverall_Top_f_idx -ascii
            %Importance, SF Cut, LP_Frame Start/Stop,  OrigVideo Start/Stop
            save dy01_sfx_detail.asc imp cutRegionOverall_Top_index cutRegionOverall_Top_lpf_idx cutRegionOverall_Top_f_idx -ascii
        case{'gr03'}
            figure(1); print -dpng gr03_superframeBoundary.png
            figure(2); print -dpng gr03_superframeImpact.png
            save gr03.mat cut* superFrames motion_magnitude_of Contrast Saturation Sharpness FaceImpact HOMEIMAGES imageList videoData
            save gr03_sfx.asc cutRegionOverall_Top_f_idx -ascii
            %Importance, SF Cut, LP_Frame Start/Stop,  OrigVideo Start/Stop
            save gr03_sfx_detail.asc imp cutRegionOverall_Top_index cutRegionOverall_Top_lpf_idx cutRegionOverall_Top_f_idx -ascii
        case{'tv04'}
            figure(1); print -dpng tv04_superframeBoundary.png
            figure(2); print -dpng tv04_superframeImpact.png
            save tv04.mat cut* superFrames motion_magnitude_of Contrast Saturation Sharpness FaceImpact HOMEIMAGES imageList videoData
            save tv04_sfx.asc cutRegionOverall_Top_f_idx -ascii
            %Importance, SF Cut, LP_Frame Start/Stop,  OrigVideo Start/Stop
            save tv04_sfx_detail.asc imp cutRegionOverall_Top_index cutRegionOverall_Top_lpf_idx cutRegionOverall_Top_f_idx -ascii
        case{'TACoS'}   
            if strcmpi(HOMEIMAGES,'Y:\datasets\tacos\images\trainval')
                outdir = [home '\results\TACoS\trainval'];
            else
                outdir = [home '\results\TACoS\test'];
            end
            if ~exist(outdir,'dir')
                mkdir(outdir);
            end
            basename = [outdir '\' outD(dirCount).name];
        
            figure(1); eval(['print -dpng ' basename '_superframeBoundary.png']);
            figure(2); eval(['print -dpng ' basename '_superframeImpact.png']);
            
            eval(['save ' basename '.mat cut* superFrames motion_magnitude_of Contrast Saturation Sharpness FaceImpact HOMEIMAGES imageList videoData']);
            eval(['save ' basename '_sfx.asc cutRegionOverall_Top_lpf_idx -ascii']);
            eval(['save ' basename '_sfx_every10thFrame.asc cutRegionOverall_Top_f_idx -ascii']);
            %Importance, SF Cut, LP_Frame Start/Stop,  OrigVideo Start/Stop
            eval(['save ' basename '_sfx_detail.asc imp cutRegionOverall_Top_index cutRegionOverall_Top_lpf_idx cutRegionOverall_Top_f_idx -ascii']);
            fprintf('TACoS, finished processing directory %s:  %d of %d\n',outD(dirCount).name,dirCountIndex,numDirs);
            
        otherwise
            disp('Unknown videData!')
    end
end

%%  This is the end.
%  The rest of this file is just for debug purposes
%

%% Now display the superframes
if (0)
disp('Press key to view the video cut into superframes')
pause
figure(2);
for sfIdx=1:length(superFrames)
    for frameNr=superFrames(sfIdx,1):superFrames(sfIdx,2)
        imshow(imread(imageList{frameNr}))
        pause(0.02);
    end
    if sfIdx < length(superFrames)
        disp('Press key to show next superframe')
        pause
    end
end
end
%% If picking up from an older session...

if (0)
cd C:\Users\rwpeec\Desktop\rwpeec\research\published_work\2016_EMNLP\superframes_v01

load tv04.mat

h = figure(1);
pos=get(gcf,'Position');
pos(3:4)=[1024 300];
set(h, 'Position', pos);
plot(motion_magnitude_of,'LineWidth',3,'Color','Black'); hold on;
cuts=zeros(length(motion_magnitude_of),1);
cuts(superFrames(:))=max(motion_magnitude_of);
uniform=zeros(length(motion_magnitude_of),1);
step=round(length(motion_magnitude_of)./length(superFrames));
uniform(1:step:end)=max(motion_magnitude_of);
bar(cuts,'FaceColor','Red','Edgecolor','Red'); hold on;
bar(uniform,'FaceColor','Blue','Edgecolor','Blue'); hold on;
legend('Motion Magnitude','Superframes cuts','Uniform cuts','Location','northwest')
xlabel('Frame Number')
ylabel('Avarage point displacement [%]')
axis([1 length(cuts) 0 max(motion_magnitude_of)]);

h = figure(2);
pos=get(gcf,'Position');
pos(3:4)=[1024 300];
set(h, 'Position', pos);
barData = [cutRegionSuperFrameBlendNorm'; cutRegionAttentionNorm; cutRegionContrastNorm ;  cutRegionSharpnessNorm ; cutRegionSaturationNorm ; cutRegionFaceImpactNorm ]';
bar(barData)
legend('Boundary','Attention','Contrast', 'Sharpness', 'Saturation', 'FaceImpact' );
hold on; plot(cutRegionOverall*0.8/max(cutRegionOverall),'kp-','linewidth',3)
xlabel('Superframe cut');
hold on; plot(cutRegionOverall_Top_sf_idx,cutRegionOverall_Top*0.8/max(cutRegionOverall_Top),'rp','linewidth',3);

end
%% Recreate plot for EMNLP
if (0)
cd C:\Users\rwpeec\Desktop\rwpeec\research\published_work\2016_EMNLP\superframes_v01

load tv04.mat

%for i=10:10:100
for i=60:10:60
    fprintf('range goes from %d to %d\n',i,i+10);
figure(3)
start_sf = i;
end_sf = i+10;
start_lpf = superFrames(start_sf,1);  %first low pass frame of first superframe
end_lpf = superFrames(end_sf,2);  %last low pass frame of last superframe
subplot(2,1,1); hold off
lpFnum = 1:length(motion_magnitude_of);
plot(lpFnum(start_lpf:end_lpf),motion_magnitude_of(start_lpf:end_lpf),'LineWidth',3,'Color','Black'); hold on;
cuts=zeros(length(motion_magnitude_of),1);
cuts(superFrames(:))=max(motion_magnitude_of);
uniform=zeros(length(motion_magnitude_of),1);
step=round(length(motion_magnitude_of)./length(superFrames));
uniform(1:step:end)=max(motion_magnitude_of);
bar(lpFnum(start_lpf:end_lpf),cuts(start_lpf:end_lpf),'FaceColor','Red','Edgecolor','Red'); hold on;
bar(lpFnum(start_lpf:end_lpf),uniform(start_lpf:end_lpf),'FaceColor','Blue','Edgecolor','Blue'); hold on;
xlabel('LP Frame Number')
ylabel('Frame Motion')
axis([100*floor(start_lpf/100) 100*ceil(end_lpf/100) 0 max(motion_magnitude_of)]);

subplot(2,1,2); hold off
barData = [cutRegionSuperFrameBlendNorm'; cutRegionAttentionNorm; cutRegionContrastNorm ;  cutRegionSharpnessNorm ; cutRegionSaturationNorm ; cutRegionFaceImpactNorm ]';
bar(start_sf:end_sf,barData(start_sf:end_sf,:))
hold on; plot(start_sf:end_sf,cutRegionOverall(start_sf:end_sf)*0.8/max(cutRegionOverall),'kp-','linewidth',3)
xlabel('Superframe cut');
idx = find(cutRegionOverall_Top_sf_idx >= start_sf & cutRegionOverall_Top_sf_idx <= end_sf);
hold on; plot(cutRegionOverall_Top_sf_idx(idx),cutRegionOverall_Top(idx)*0.8/max(cutRegionOverall_Top),'rp','linewidth',3);
axis([start_sf-1 end_sf+1 0 1]);

%pause
end
print -dpng superframeCutPlot_noLegend.png
subplot(2,1,1);
legend('Motion Magnitude','Superframes cuts','Uniform cuts','Location','northwest');
subplot(2,1,2);
legend('Boundary','Attention','Contrast', 'Sharpness', 'Saturation', 'FaceImpact' );
print -dpng superframeCutPlot_wLegend.png

end
