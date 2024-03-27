function mouseMove (object, eventdata)
C = get (gca, 'CurrentPoint');
global moveData;
if moveData.Val == 1
    % make pixel red
    C_floor = floor([C(1,1), C(1,2)]);
    % don't allow duplicates
    if moveData.Pts(end,:)~=C_floor
        r = rectangle('Position',[C_floor-5, 10,10], 'FaceColor','r', 'LineStyle','none');
        moveData.Pts = [moveData.Pts; [C(1,1),C(1,2)]];
        moveData.Rs = [moveData.Rs, r];
    end
end
end