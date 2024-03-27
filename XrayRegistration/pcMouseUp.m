function pcMouseDown (object, eventdata)
disp(append(get(gcf,'SelectionType'), " up"));
global moveData;
moveData.Val = 0;
end