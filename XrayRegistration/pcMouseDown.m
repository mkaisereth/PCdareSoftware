function pcMouseDown (object, eventdata, pc)

disp(append(get(gcf,'SelectionType'), " down"));
global moveData;
moveData.Val = 1;
set (gcf, 'WindowButtonMotionFcn', {@pcMouseMove, pc.Location'});

end