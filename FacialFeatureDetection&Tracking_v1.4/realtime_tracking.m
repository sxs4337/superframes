% Signature: 
%   realtime_tracking
%
% Usage:
%   This function demonstrates how to use xx_track_detect in realtime demo.
%   The image frame is captured from a camera.
%
% Params:
%   cameraID - select which camera to use, default 0
%
% Return: None
%
% Author: 
%   Xuehan Xiong, xiong828@gmail.com
% 


function realtime_tracking(cameraID)

if nargin < 1
  cameraID = 0;
end

disp('Initializing tracker...');
[Models,option] = xx_initialize;

frame_w = 640;
frame_h = 480;

S.fh = figure('units','pixels',...
              'position',[100 50 frame_w frame_h],...
              'menubar','none',...
              'name','INTRAFACE_TRACKER',...              
              'numbertitle','off',...
              'resize','off',...
              'renderer','painters');

S.ax = axes('units','pixels',...
            'position',[1 1 frame_w frame_h],...
            'drawmode','fast');
               
S.im_h = imshow(zeros(frame_h,frame_w,3));

set(S.fh,'KeyPressFcn',@pb_kpf);

drawnow;

stop_pressed = false;
drawed = false;
output.pred = [];
poseline = 60;
loc = [70 70];

cap = cv.VideoCapture(cameraID);
cap.set('FrameWidth',frame_w);
cap.set('FrameHeight',frame_h);
hold on;

%% tracking and detection
% press 'Esc' to quit
while ~stop_pressed
  tic;
  im = cap.read;
  if isempty(im), error('can not read stream from camera'); end
  
  output = xx_track_detect(Models,im,output.pred,option);
  set(S.im_h,'cdata',im);
  te = toc;
  if isempty(output.pred)
    if drawed, delete_handlers(); end
  else
    update_GUI();
  end
  
  drawnow;
end
close;


%% Drawing and callback functions
   % private function for deleting drawing handlers
    function delete_handlers() 
      delete(S.pts_h); 
      delete(S.time_h);
      if option.compute_pose
        delete(S.hh{1}); delete(S.hh{2}); delete(S.hh{3});
      end
      drawed = false;
    end
    % helper function for drawing head pose
    function p2D = projpose(pose,l)
      po = [0,0,0; l,0,0; 0,-l,0; 0,0,-l];
      p2D = po*pose.rot(1:2,:)' + repmat(loc,4,1);
    end
  
    % private function for updating/creating drawing
    function update_GUI()
    
      if drawed % faster to update than to creat new drawings
        % update head pose
        if option.compute_pose
          p2D  = projpose(output.pose,poseline); 
          set(S.hh{1},'xdata',[p2D(1,1) p2D(2,1)],'ydata',[p2D(1,2) p2D(2,2)]);
          set(S.hh{2},'xdata',[p2D(1,1) p2D(3,1)],'ydata',[p2D(1,2) p2D(3,2)]);
          set(S.hh{3},'xdata',[p2D(1,1) p2D(4,1)],'ydata',[p2D(1,2) p2D(4,2)]);
        end
     
        % update tracked points
        set(S.pts_h, 'xdata', output.pred(:,1), 'ydata',output.pred(:,2));
        % update frame/second
        set(S.time_h, 'string', sprintf('%d FPS',uint8(1/te)));
      else
        if option.compute_pose
          p2D  = projpose(output.pose,poseline);
          % create head pose drawing
          S.hh{1}=line([p2D(1,1) p2D(2,1)],[p2D(1,2) p2D(2,2)]);
          set(S.hh{1},'Color','r','LineWidth',2);

          S.hh{2}=line([p2D(1,1) p2D(3,1)],[p2D(1,2) p2D(3,2)]);
          set(S.hh{2},'Color','g','LineWidth',2);

          S.hh{3}=line([p2D(1,1) p2D(4,1)],[p2D(1,2) p2D(4,2)]);
          set(S.hh{3},'Color','b','LineWidth',2);
        end
        % create tracked points drawing
        S.pts_h   = plot(output.pred(:,1), output.pred(:,2), 'g*', 'markersize',2);
        
        % create frame/second drawing
        S.time_h  = text(frame_w-100,40,sprintf('%d FPS',uint8(1/te)),'fontsize',15,'color','c');
        drawed = true;
      end
    end

    % private callback function 
    function [] = pb_kpf(varargin)
      % Callback for pushbutton
      if strcmp(varargin{2}.Key, 'escape')==1
        stop_pressed = true;
      end
    end
  
end
