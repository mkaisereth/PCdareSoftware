function PcEscPressed(~,evnt)

if strcmp(evnt.Key,'escape')==1
    fprintf('key event is: %s\n',evnt.Key);
    global pcMarkers;
    global lastPcIndex;
    if lastPcIndex>1
        lastPcIndex=lastPcIndex-1;
        pcMarkers(lastPcIndex).World = [];
        h = pcMarkers(lastPcIndex).H;
        delete(h);
        pcMarkers(lastPcIndex).H = [];

        switch lastPcIndex
            case 1
                AddInstructions("Press space and select C7 marker")
            case 2
                AddInstructions("Press space and select L5 marker")
            case 3
                AddInstructions("Press space and select marker for SIPS right (right in image)")
            case 4
                AddInstructions("Press space and select marker for SIPS left (left in image)")
            otherwise
                AddInstructions(append("Press space and select marker ", string(lastPcIndex)))
        end
        drawnow();

    elseif lastPcIndex==-1
        % revert line
        global moveData;
        for i=1:size(moveData.Hs, 2)
            delete(moveData.Hs(i))
        end
        moveData.Pts = [];
        moveData.Hs = [];
    end
end

end