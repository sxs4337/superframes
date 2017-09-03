%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Superframe segmentation
%%%%%%%%
% This is a copy-paste from demo.m, then modified to do an ablation 
% analysis on the sumMe dataset
%%%%%%%%

clear
cd C:\Users\rwpeec\Desktop\rwpeec\research\published_work\2016_EMNLP\superframes_v01

faces=1;
if faces
    addpath C:\Users\rwpeec\Desktop\rwpeec\research\face_detection\FacialFeatureDetection&Tracking_v1.4% load model and parameters, type 'help xx_initialize' for more details
    cd C:\Users\rwpeec\Desktop\rwpeec\research\face_detection\FacialFeatureDetection&Tracking_v1.4
    [Models,option] = xx_initialize;
    cd C:\Users\rwpeec\Desktop\rwpeec\research\published_work\2016_EMNLP\superframes_v01
end
%%%%% Video 
HOMEIMAGES='c:/users/rwpeec/desktop/rwpeec/datasets/summe/avg_frames';

outf = dir(HOMEIMAGES);
for dv=3:length(outf)   % for each of the  input directories
    v = dv-2;  %1 based offset for results
    fprintf('working on dir %s\n',outf(dv).name);
    homedir{v} = outf(dv).name;
    %collect corresponding gt
    filegt = load(sprintf('%s/%s','c:/users/rwpeec/desktop/rwpeec/datasets/summe',outf(dv).name));
    gt{:,v} = filegt.sum;



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

% Read in the images
images=dir(fullfile([HOMEIMAGES '/' homedir{v}],'*.jpg'));
imageList=cellfun(@(X)(fullfile([HOMEIMAGES '/' homedir{v}],X)),{images(:).name},'UniformOutput',false);
AllNumFrames(v) = length(imageList);

%% Run Superframe segmentation
tic
Params.Models = Models; %for faceDetection
Params.option = option; %for faceDetection
%note Contrast, Saturation, Sharpness, Faces added by rwp on May 2016
[superFrames,motion_magnitude_of,Contrast,Saturation,Sharpness,FaceImpact] = summe_superframeSegmentation(imageList,FPS,Params);
toc

%% Plot motion magnitude and cuts
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

clear cutRegion* y
gtvec = gt{:,v}';
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
    y(i) = mean(gtvec(superFrames(i,1):superFrames(i,2)));
end
alpha=0.7;
cutRegionAttention = (alpha*cutRegionMotion)+(1-alpha)*cutRegionVariance
cutRegionContrast
cutRegionSaturation
cutRegionSharpness
cutRegionFaceImpact

%At this point, for each superframe, we have:
% avgSuperFrameCutScore
% cutRegionAttention 
% cutRegionContrast
% cutRegionSaturation
% cutRegionSharpness
% cutRegionFaceImpact
% We need to first calculate the ground truth for each superframe
% Then do an ablation analysis to see which is performing best
MM = [ ones(length(cutRegionAttention),1) avgSuperFrameCutScore cutRegionAttention' cutRegionContrast' cutRegionSaturation' cutRegionSharpness' cutRegionFaceImpact'];
y=y';

%%  Use sequentialfs to find top coeffs (ablation analysis)

[numSamples,numFeatures] = size(MM);
fun = @(MM,y,Xt,Yt) ...
    sum((y- MM * (((MM'*MM)\MM')*y) ).^2);
opts = statset('display','iter');
c = cvpartition(y,'k',2);
[r,c] = size(MM);
fskeep = logical(zeros(1,c)); fskeep(1)=1; %only keep bias
%[fs,history] = sequentialfs(fun,MM,y,'cv',c,'options',opts,'nfeatures',30,'KeepIn',fskeep);
%may have to do this with 'nfeatures',1 to find top feature
% then with 'nfeatures',2 to find second most important feature, and so on
%[fs,history] = sequentialfs(fun,MM,y,'cv','none','options',opts,'nfeatures',30,'KeepIn',fskeep);
[fs,history] = sequentialfs(fun,MM,y,'cv','none','options',opts,'nfeatures',numFeatures);

columnDesc = { 'bias' 'CutScore' 'Attention' 'Contrast' 'Saturation' 'Sharpness' 'FaceImpact'};

%Note,history.Crit is essentially the avgSqErr as calcualted below
% clear avgSqErr
% for histIndex=1:numFeatures
%     M = MM(:,history.In(histIndex,:));
%     w = ((M'*M)\M')*y;
%     avgSqErr(histIndex)=sum((y-M*w).^2)./length(y); 
% end
%Extract the order in which each feature is added
TopFeatures = find (history.In(1,:) == 1);
for histIndex=2:numFeatures
    indexFeatures = find (history.In(histIndex,:) == 1);
    for ii=1:length(indexFeatures)
        found=0;
        for jj=1:length(TopFeatures)
            if indexFeatures(ii) == TopFeatures(jj)
                found=1;
            end
        end
        if found == 0
            TopFeatures = [TopFeatures ; indexFeatures(ii)];
            break;
        end
    end
end
for ii=1:numFeatures
    fprintf('%s (%d), MeanSqErr=%7.4f\n',columnDesc{TopFeatures(ii)},TopFeatures(ii),history.Crit(ii));
end

AllTopFeatures(v,:) = TopFeatures;
AllMeanSqErr(v,:) = history.Crit';

end  %for each of the input directories

%Find mean position for each feature
for vv=1:v
    for ii=1:numFeatures
        FeatPos(vv,ii) = find(AllTopFeatures(vv,:)==ii);
    end
end

columnDesc
FeatPos_mean = mean(FeatPos)
FeatPos_std = std(FeatPos)

[ii_value, ii_index] = sort(FeatPos_mean)

for ii=1:numFeatures
    fprintf('%s : mean rank position %7.2f +/- %7.2f\n',columnDesc{ii_index(ii)},FeatPos_mean(ii_index(ii)),FeatPos_std(ii_index(ii)));
end

fprintf('For the %d videos, minNumFrames=%d, maxNumFrames=%d, meanNumFrames=%7.4f', ...
    v,min(AllNumFrames),max(AllNumFrames),mean(AllNumFrames));

fprintf('Number of times each feature came in first:\n');
for ii=1:numFeatures
    fprintf('%s : %d\n',columnDesc{ii},length(find(AllTopFeatures(:,1) == ii)));  
end

fprintf('Number of times each feature came in first or second:\n');
for ii=1:numFeatures
    fprintf('%s : %d\n',columnDesc{ii},length(find(AllTopFeatures(:,1) == ii))+length(find(AllTopFeatures(:,2) == ii)));  
end

fprintf('Number of times each feature came in first, second, or third:\n');
for ii=1:numFeatures
    fprintf('%s : %d\n',columnDesc{ii},length(find(AllTopFeatures(:,1) == ii))+length(find(AllTopFeatures(:,2) == ii))+length(find(AllTopFeatures(:,3) == ii)));  
end