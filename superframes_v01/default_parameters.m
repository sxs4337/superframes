%% Motion estimation
Params.num_tracks=100;  % Desired numbers of keypoints for tracking
Params.min_tracks=5;    % Minimum tracks required for motion estimation
Params.minQual=0.2;     % Quality for the FAST interest points
Params.stepSize=5;      % Length of tracks for motion estimation
Params.Smoothing=0.5;   % sigma for the gaussian smoothing of the motion curve

%% Superframe parameters
Params.DeltaInit=0.25;  % The initial step size for the SF segmentation (percentage of SF length)
Params.gamma=1;         % weighting of the cut cost (see paper)

% Lognormal probability with parameters estimated from the SumMe annotation
% (See paper for more information)
Params.lognormal.mu=1.16571;
Params.lognormal.sigma=0.742374;