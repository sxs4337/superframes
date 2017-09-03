function [superFrames,motion_magnitude_of,Contrast,Saturation,Sharpness,FaceImpact] = summe_superframeSegmentation(imageList,FPS,Params,frameRange,motion_file)
%summe_superframeSegmentation Teporally segments a video into "superframes"
% For more information see: "Creating Summaries from User Videos: ECCV 2014
% frameRange: optional subrange of the video used to compute the
% superframes (format: [startFrame, endFrame])

Models = Params.Models; %for faceDetection
option = Params.option; %for faceDetection
    if exist('frameRange','var')
        lastFrame=frameRange(2);
        assert(lastFrame <= length(imageList),'error, frame range is invalid');
    else    
        lastFrame=length(imageList);
        frameRange=[1 lastFrame];
    end

    if exist('motion_file','var') && exist('motion_file','file')
        load(motion_file)
    else
        % Compute motion
        [motion_magnitude,motion_magnitude_back,Contrast,Saturation,Sharpness,FaceImpact]= summe_computeMotion(imageList,frameRange,FPS,Params, Models, option);

        % Smooth motion
        motion_magnitude_of=conv((motion_magnitude+motion_magnitude_back)./2,normpdf([-3:3],0,0.5),'same');
                
        if exist('motion_file','var')
            save(motion_file,'motion_magnitude_of')
        end
    end

    %% Now do superframe segmentation
    fprintf('Compute superframes\n\n');
    % Params
    global lookupT;
    lookupT=-ones(1000,1);
    
    % Compute number and length of superframes
    shot_length=lastFrame-frameRange(1)+1;
    [~,bestLength]=getLengthPrior(-1,Params.lognormal);  %getting 1.85 by default
    delta=round(Params.DeltaInit*FPS);
    bestLength=round(bestLength*FPS);   %getting 54 for FPS=29, by default
    nbOfSuperFrames=shot_length./bestLength;
    nbOfSuperFrames=max(1,round(nbOfSuperFrames));
    lengthSF=round((lastFrame-frameRange(1)+1)./nbOfSuperFrames);
    
    % Initialize equally distributed SF
    superFrames=zeros(nbOfSuperFrames,2);
    
    for sfIdx=1:nbOfSuperFrames
        if (sfIdx-1)*lengthSF>=lastFrame
            superFrames=superFrames(1:end-1,:);
            nbOfSuperFrames=nbOfSuperFrames-1;
            continue;
        end
        superFrames(sfIdx,:)=[max(1,(sfIdx-1)*lengthSF+1) sfIdx*lengthSF];
        if sfIdx==nbOfSuperFrames
            superFrames(sfIdx,:)=[(sfIdx-1)*lengthSF+1 lastFrame-frameRange(1)+1];
        end
    end
    superFrames=round(superFrames);
    assert(min(superFrames(:))>0)
    assert(max(superFrames(:))<=shot_length)
    if nbOfSuperFrames==1;
        return;
    end
    
    %%%%%%%%%%%%%%%%
    % Now comes the main algorithm: Local hillclimbing algorithm using the
    % length prior as a regularizer
    isDone=zeros(nbOfSuperFrames,1);
    
    while delta >= 1 % Iterate until convergance
        isDone(:)=0;
        isDone(end)=1; % the last SF has no boundary to its right, so it is not touched
        
        % Get scores for each SF
        motion_magnitude_of(end+1:max(superFrames(:,2)))=0;
        [ score,score_Add_left,score_Rem_left, score_Add_right,score_Rem_right] = summe_scoreSuperframes( superFrames,motion_magnitude_of,FPS, delta, Params );
        
        for sfIdx=nbOfSuperFrames-1:-1:1
            if isDone(sfIdx)==1
                continue;
            end
            
            % Scores for a boundary movement
            scoreMoveRight=score_Add_right(sfIdx)+score_Rem_left(sfIdx+1);
            scoreMoveLeft=score_Rem_right(sfIdx)+score_Add_left(sfIdx+1);
            scoreCurr=score(sfIdx)+score(sfIdx+1);         % Score for the current state
            
            
            % Get the best action
            [bestScore,bestAction] =max([scoreMoveRight,scoreMoveLeft]);
            
            % We can climb
            if bestScore > scoreCurr
                if bestAction==1 %% move the boundary to the right
                    superFrames(sfIdx,2)=superFrames(sfIdx,2)+delta;
                    superFrames(sfIdx+1,1)=superFrames(sfIdx+1,1)+delta;
                elseif bestAction==2 %% move the boundary to the left
                    superFrames(sfIdx,2)=superFrames(sfIdx,2)-delta;
                    superFrames(sfIdx+1,1)=superFrames(sfIdx+1,1)-delta;
                else
                    isDone(sfIdx)=true;
                end
                [ score,score_Add_left,score_Rem_left, score_Add_right,score_Rem_right] = summe_scoreSuperframes( superFrames,motion_magnitude_of,FPS, delta, Params );
                isDone(sfIdx+1)=0;
            else
                isDone(sfIdx)=1;
            end
        end
        
        if nnz(isDone)==length(isDone)
            delta=delta-1;
        end
    end
end








