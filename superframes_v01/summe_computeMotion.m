function [ motion_magnitude,motion_magnitude_back,Contrast,Saturation,Sharpness,FaceImpact ] = summe_computeMotion(imageList,frameRange,FPS,Params, Models, option )
%summe_computeMotion Computes the motion magnitude over a range of frames   

    fprintf('Compute forward motion\n');    
    frames=imageList(frameRange(1):frameRange(2));
    
    [motion_magnitude]=getMagnitude(frames,Params,FPS);
    [Contrast,Saturation,Sharpness,FaceImpact]=getContrastSaturationSharpnessFaces(frames, Models, option);
    
    fprintf('Compute backward motion\n')    
    frames=imageList(frameRange(2):-1:frameRange(1));    
    motion_magnitude_back=getMagnitude(frames,Params,FPS);
    motion_magnitude_back=flip(motion_magnitude_back);
    
end
  
% Contrast, Saturation, Sharpness added by rwp on 5/23/16
function [Contrast,Saturation,Sharpness,FaceImpact]=getContrastSaturationSharpnessFaces(imageList, Models, option)

    fprintf('Compute ContrastSaturationSharpnessFaces\n') ;
    numImages = length(imageList);
    for frameNum=1:numImages
        fprintf('On image %d of %d\r',frameNum,numImages);
        % Load the first image
        frame = imread(imageList{frameNum});
      
        [h,w,c] = size(frame);
        
        bwImagehiRes=rgb2gray(frame);
        %extract noise from center and four corners
        %in center and four corners take avg std dev of a few regions
        %sharpness will be max of those averages
        for i=1:7
            for j=1:7
                hh = round(h*(2+i)/10);  %this 2+ and /10 just utilizes center area of image
                ww = round(w*(2+j)/10);
                sharp(i,j) = median([std(double(bwImagehiRes(hh-2:hh+2,ww-2:ww+2))) ...
                                     std(double(bwImagehiRes(hh-3:hh+1,ww-3:ww+1))) ...
                                     std(double(bwImagehiRes(hh-1:hh+3,ww-1:ww+3)))]);
            end
        end
        Sharpness(frameNum) = max(sharp(:));
        
        lowRes = imresize(frame,[64 64*w/h]);
        bwImagelowRes=rgb2gray(lowRes);
        Contrast(frameNum) = std(double(bwImagelowRes(:)));

        hsvImage = rgb2hsv(lowRes);
        SatValue = hsvImage(:,:,2); %saturation plane only
        Saturation(frameNum) = mean(SatValue(:));
        
        
        %extract Faces
        vgaRes = imresize(frame,[512 512*w/h]);
        [imageHeight,imageWidth,imageChannels] = size(vgaRes);
        %cd C:\Users\rwpeec\Desktop\rwpeec\research\face_detection\FacialFeatureDetection&Tracking_v1.4
        faces = Models.DM{1}.fd_h.detect(vgaRes,'MinNeighbors',option.min_neighbors,'ScaleFactor',1.2,'MinSize',[20 20]);
        %cd C:\Users\rwpeec\Desktop\rwpeec\research\published_work\2016_EMNLP\superframes_v01
        faceBox=faces;
        doPLot=0;
        if doPLot 
            imshow(vgaRes); hold on;
        end
        F_Impact=0;
        for i = 1:length(faces)
            iFaceBox = faces{i}; 
            if doPLot
                rectangle('Position', iFaceBox);
            end
            %C:\Users\rwpeec\Desktop\rwpeec\research\face_detection\FacialFeatureDetection&Tracking_v1.4
            %See detect_image.m if you want to get facial feature points
            %See detect_face.m if you want to do extra checking, normalize
            %    face, and extract more facial features%For faces:
            
            %extract face location:
            InterOcularDist = round((iFaceBox(3)+ iFaceBox(4))/4); %avg faceWidth/2
            faceWidth = 2*InterOcularDist;
            faceSize = ((faceWidth).^2 ) ./ (imageWidth * imageHeight);  %
            SizeAttribute = -72.382*faceSize.^3 + 27.151*faceSize.^2 - 0.2647*faceSize +0.5;
            
            faceCentroid_X = iFaceBox(1) + InterOcularDist;
            faceCentroid_Y = iFaceBox(2) + InterOcularDist;
            sx = 2*imageWidth/3;
            sy = imageHeight/2;
            dx = abs(faceCentroid_X-imageWidth/2);
            dy = abs(faceCentroid_Y-3*imageHeight/5);
            %CentralityAttribute = (1/(2*pi*sx*sy)).*exp(-(dx.^2./sx.^2 + dy.^2./sy.^2)./2);
            CentralityAttribute = exp(-(dx.^2./sx.^2 + dy.^2./sy.^2)./2);
            
            F_Impact = F_Impact + SizeAttribute*CentralityAttribute;
            
        end
        FaceImpact(frameNum) = F_Impact;
        
        
        
        
        
    end
end

function [motion_magnitude]=getMagnitude(imageList,Params,FPS)
    motion_magnitude=zeros(length(imageList),1);
    for startFrame=1:Params.stepSize:length(imageList)-Params.stepSize
        % Load the first image
        frame = imread(imageList{startFrame});
    
        if ~exist('frameSize','var')
            frameSize=sqrt(size(frame,1)*size(frame,2));
        end
        if ~exist('new_points','var')
            old_points=zeros(0,2);
        else
            old_points=new_points(points_validity,:);
        end


        % Detect points
        minQual=Params.minQual;
        points=[];
        tries=0;
        while (size(old_points,1)+size(points,1)) < Params.num_tracks*0.95 && tries<5 % we reinitialize only, if we have too little points
            points=detectFASTFeatures(rgb2gray(frame),'MinQuality',minQual);
            minQual=minQual/5;
            tries=tries+1;
        end        
        if numel(points) > 0
            old_points=[old_points; points.Location];
        end
    
        if size(old_points,1) > Params.num_tracks
            indices=randperm(size(old_points,1));
            old_points=old_points(indices(1:Params.num_tracks),:);
        end


        % Compute magnitude
        if (length(old_points) >= Params.min_tracks) % if at least k points are detected
            % Initialize tracker
            pointTracker = vision.PointTracker;
            initialize(pointTracker,old_points,frame);
            for frameNr=1:Params.stepSize-1
                frame = imread(imageList{startFrame+frameNr});
                [new_points,points_validity] = step(pointTracker,frame);
            end

            diff=new_points(points_validity,:)-old_points(points_validity,:);
            diff=mean(norm(diff));

            % add it to the array and normalize by frame size
            motion_magnitude(startFrame:startFrame+Params.stepSize-1)=(FPS/Params.stepSize)*diff./frameSize;
        end
    end
end

