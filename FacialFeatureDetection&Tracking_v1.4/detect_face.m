function [detectedFaces] = detect_face(inputImg,doPlot)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

if ~exist('doPlot','var')
    doPlot=0;
end

% load model and parameters, type 'help xx_initialize' for more details
[Models,option] = xx_initialize;

faces = Models.DM{1}.fd_h.detect(inputImg,'MinNeighbors',option.min_neighbors,...
    'ScaleFactor',1.2,'MinSize',[50 50]);

faceCount=0;

if (size(faces,2) >= 1)
    
    for f = 1:size(faces,2)
        iFaceBox = faces{f};
        
        output = xx_track_detect(Models,inputImg,iFaceBox,option);
        if isempty(output.pred)
            fprintf('Face %d of %d discarded as eye/mouth corner points could not be found\n',f,size(faces,2));
            continue;
        end
        faceCount=faceCount+1;
        
        iFaceBoxp1=iFaceBox+1;  %go from zero to 1 base indexing
        %detectedFace.rawFace(:,:) = inputImg(iFaceBoxp1(2):iFaceBoxp1(2)+iFaceBoxp1(4),iFaceBoxp1(1):iFaceBoxp1(1)+iFaceBoxp1(3));
        detectedFace.faceBox = iFaceBoxp1;
        
        detectedFace.points=output.pred;  %predicted landmarks (49 x 2) or [] if no face detected(or not reliable) 
        detectedFace.pose=output.pose; %head pose struct, output.pose.angle  1x3 - rotation angle, [pitch, yaw, roll], output.pose.rot    3x3 - rotation matrix
        detectedFace.conf=output.conf; %confidence score of the prediction
        detectedFace.lambda=output.lambda;
        
        
        if doPlot
            if faceCount ==1
                hold off
                imshow(inputImg);
                hold on
            end
            rectangle('Position', iFaceBox);
            
            if ~isempty(output.pred)
                if doPlot
                    %hold on; plot(output.pred(:,1),output.pred(:,2),'g*','markersize',2); hold off;
                    hold on;
                    for j=1:length(output.pred)
                        eval( ['text(double(output.pred(j,1)), double(output.pred(j,2)), ''' sprintf('%d',j)   ''');'] );
                    end
                          
                    %output.pose.angle  1x3 - rotation angle, [pitch, yaw, roll]
                    pitch = detectedFace.pose.angle(1);
                    yaw =  detectedFace.pose.angle(2);
                    roll = detectedFace.pose.angle(3);
                    
                    %Form arrow from middle of eyes  to show pose, points 20 23 26 29 are leftEyeL, leftEyeR, rightEyeL rightEyeR
                    leftEyeL_X =detectedFace.points(20,1);
                    leftEyeL_Y =detectedFace.points(20,2);
                    leftEyeR_X =detectedFace.points(23,1);
                    leftEyeR_Y =detectedFace.points(23,2);
                    rightEyeL_X =detectedFace.points(26,1);
                    rightEyeL_Y =detectedFace.points(26,2);
                    rightEyeR_X =detectedFace.points(29,1);
                    rightEyeR_Y =detectedFace.points(29,2);
                    leftEye_X = (leftEyeL_X+leftEyeR_X)/2;
                    leftEye_Y = (leftEyeL_Y+leftEyeR_Y)/2;
                    rightEye_X = (rightEyeL_X+rightEyeR_X)/2;
                    rightEye_Y = (rightEyeL_Y+rightEyeR_Y)/2;
                    
                    %looks better if bias along eye diagonal, where bias dictated by yaw
                    yawclip = yaw;
                    if (yawclip<-30) yawclip=-30;end
                    if (yawclip>30) yawclip=30; end
                    weight = ((yawclip+30)/120) + 0.25;
                    p.x = round((1-weight)*leftEye_X + weight*rightEye_X);  %eye X
                    p.y = round((1-weight)*leftEye_Y + weight*rightEye_Y);  %eye Y
                    
                    ioDist = sqrt((rightEye_X - leftEye_X)*(rightEye_X - leftEye_X) + (rightEye_Y - leftEye_Y)*(rightEye_Y - leftEye_Y));
                    
                    %looks better if raise arrow hight slightly
                    p.y = round(p.y - ioDist*0.25);
                    
                    %yaw projection
                    projXtmp = (90.0-abs(yaw));  %projection of arrow onto x
                    projXtmp2 = cos((projXtmp*pi/180));  %projection of arrow onto x
                    projX = round(2.0*ioDist*projXtmp2);  %projection of arrow onto x
                    if (yaw<0)
                        q.x = p.x + projX;
                    else
                        q.x = p.x - projX;
                    end
                    %pitch projection
                    projXtmp = (90.0-abs(pitch));  %projection of arrow onto x
                    projXtmp2 = cos((projXtmp*pi/180));  %projection of arrow onto x
                    projX = round (2.0*ioDist*projXtmp2);  %projection of arrow onto x
                    if (pitch<0)
                        q.y = p.y - projX;
                    else
                        q.y = p.y + projX;
                    end
                    options=[];
                    options.linewidth=2;  options.linecolor='g';options.arrowHeadSize=7;
                    drawArrow(p,q,options); %C:\Users\rwpeec\Desktop\rwpeec\research\matlab\ptucha
                      
                    hold off;
                end

            end
        end
        
        
        %options for load_face_regions_v2
        options.occlusion='none';
        options.doplots=0;
        options.saveplots=0;
        options.domask = 0;  %if set to one, will do individual face regions (nose, cheeks, etc) as well as entire face region
        options.norm=0;
        options.sharp=0;
        options.affine=1;
        options.edge_mag=0;
        options.edge_dir=0;
        options.doGabor = 0;
        options.doLBP = 0;
        options.doLPQ = 0;
        options.Xgrid = [1 10 20 30 40 51]; %For LPQ: these define a grid over image, each grid location will get one hist
        options.Ygrid = [1 10 20 30 40 50 60];
        
        ptsfile = output.pred;
        whichEyeMouthPts = [20 23 26 29 32 38];
        lum=load_face_regions_v2(inputImg,ptsfile,whichEyeMouthPts,options);
        detectedFace.normFace = lum.fullimg;
        detectedFaces(faceCount) = detectedFace;
    end
    if faceCount == 0
        disp('No faces detected');
        detectedFaces=[];
    end
    
else
    disp('No faces detected');
    detectedFaces=[];
end
end


