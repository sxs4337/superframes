% Signature: 
%   output = xx_track_detect(Models,im,prev,option)
%
% Dependence:
%   OpenCV2.4 above, mexopencv
%   mexopencv can be downloaded here:
%   http://www.cs.stonybrook.edu/~kyamagu/mexopencv/
%   
%   You do not need the above two packages unless you want to build OpenCV
%   on yourself or re-compile mexopencv. All DLLs and mex functions are
%   included in this package.
%
% Usage:
%   This function detects or tracks one face in a given image depending on 
%   the input. The function also optionally returns the head pose estimated 
%   from those tracked points.
%
% Params:
%   Models.DM - detection model, 
%   Models.TM - tracking model,
%   im - image (RGB or graysclae)
%   prev - [] or [x,y,w,h] or [49x2] 
%     when prev = [], OpenCV face detector is used to locate the face region.
%     when prev = [x,y,w,h] (face region), face alignment is performed on 
%     the given rectangle. [x,y] is the upper left corner, [w,h] are the 
%     width and height of the rectangle. When prev = [49x2] (prediction 
%     from previous frame), it does tracking.
%   option - tracker parameters
%     .detector_offset - the offset between your face detector output and OpenCV's. 
%     Say the output of your face detector is (x,y,w,h). After applying the offset,
%     it becomes (x+offset.x, y+offset.y, w*offset.width, h*offset.height).
%     Default: [0 0 1 1].
%
%     .face_score - threshold ([0,1]) on confidence score determining 
%     whether the tracked face is lost. The lower the value the more 
%     tolerated it becomes.
%
%     .min_neighbors - OpenCV face detector parameter (>0). The lower the more 
%     likely to find a face as well as false positives.
%
%     .min_face_image_ratio - minimum face size for OpenCV face detector.
%
%     .compute_pose - flag indicating whether to compute head pose.
%
% Return:
%   output.pred - predicted landmarks (49 x 2) or [] if no face detected(or not reliable) 
%   output.pose - head pose struct
%     output.pose.angle  1x3 - rotation angle, [pitch, yaw, roll]
%     output.pose.rot    3x3 - rotation matrix
%   output.conf - confidence score of the prediction
%
% Authors: 
%   Xuehan Xiong, xiong828@gmail.com
%   Zehua Huang, huazehuang@gmail.com
%   Fernando De la Torre, ftorre@cs.cmu.edu
%
% Citation: 
%   Xuehan Xiong, Fernando de la Torre, Supervised Descent Method and Its
%   Application to Face Alignment. CVPR, 2013
%
% Creation Date: 4/7/2014
%
