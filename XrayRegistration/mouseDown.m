function mouseDown (object, eventdata)
disp(append(get(gcf,'SelectionType'), " down"));
global moveData;
moveData.Val = 1;
C = get (gca, 'CurrentPoint');
% make pixel red
C_floor = floor([C(1,1), C(1,2)]);
r = rectangle('Position',[C_floor-5, 10,10], 'FaceColor','r', 'LineStyle','none');
moveData.Pts = [moveData.Pts; [C(1,1),C(1,2)]];
moveData.Rs = [moveData.Rs, r];
end