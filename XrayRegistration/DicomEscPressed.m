function DicomEscPressed(~,evnt)
global allowImageOptimization;
if strcmp(evnt.Key,'l')==1
    global hPoints;
    allowImageOptimization = false;
    % draw help line
    global apImg;
    apImgWidth = size(apImg,2);
    global latImg;
    latImgWidth = size(latImg,2);
    C = get (gca, 'CurrentPoint');
    hPoints = [hPoints; [C(1,1),C(1,2)]];
    C_floor = floor([0, C(1,2)-3,apImgWidth+latImgWidth,6]);
    global hRectangle;
    hRectangle = rectangle('Position',C_floor, 'FaceColor','g', 'LineStyle','none');
    global hLineNum;
    global hLines;
    hLines(hLineNum,:) = C(1,2);
    hLineNum = hLineNum+1;
    switch hLineNum
        case 2
            AddInstructions("Click with left mouse, then press l key to draw horizontal line for T12 (vertebra center)")
        case 3
            AddInstructions("Click with left mouse, then press l key to draw horizontal line for L5 (lower endplate, middle), then press right arrow to continue")
    end
end
if strcmp(evnt.Key,'escape')==1
    fprintf('key event is: %s\n',evnt.Key);
    % undo last operation
    global fig1ApLat;
    if strcmp(fig1ApLat,'ap')==1
        % check whether drawing hLines
        global drawingHLines;
        if drawingHLines
            % revert last hLine
            global hLineNum;
            if hLineNum>1
                hLineNum = hLineNum-1;
                global hLines;
                hLines(hLineNum,:) = [];
                global hRectangle;
                delete(hRectangle);
                switch hLineNum
                    case 1
                        AddInstructions("Click with left mouse, then press l to draw horizontal line for C7 (vertebra center)")
                    case 2
                        AddInstructions("Click with left mouse, then press l key to draw horizontal line for T12 (vertebra center)")
                    case 3
                        AddInstructions("Click with left mouse, then press l key to draw horizontal line for L5 (lower endplate, middle), then press right arrow to continue")
                end
                drawnow();
            end
        else
            global apDicomMarkers;
            global lastApLineIndex;
            global lastApIndex;
            global moveData;
            % if already drawing line
            if lastApLineIndex > 0 && ~isempty(moveData.Pts)
                % revert line
                global apImg;
                for pi=1:size(moveData.Rs,2)
                    delete(moveData.Rs(pi));
                end
                moveData.Rs = [];
                moveData.Pts = [];
            elseif lastApIndex > 1
                % switch off automatic marker optimization
                global automaticMarkerOptimizationTemp;
                automaticMarkerOptimizationTemp = -1;
                % revert last marker
                lastApIndex = lastApIndex-1;
                apDicomMarkers(lastApIndex).Pixel = [];
                apDicomMarkers(lastApIndex).World = [];
                global apImg;
                global apDicomMarkerColors;
                delete(apDicomMarkerColors(lastApIndex).R);
                apDicomMarkerColors(lastApIndex).R = [];
    
                if lastApIndex<=2
                    for ri=1:size(apDicomMarkerColors(lastApIndex).Rs, 2)
                        delete(apDicomMarkerColors(lastApIndex).Rs(ri));
                    end
                    apDicomMarkerColors(lastApIndex).Rs = [];
                end
                global numOfMarkersAP;
                global datasetName;
                switch lastApIndex
                    case 1
                        AddInstructions("Press space and select AP marker for C7 (spinous process)")
                        drawnow();
                    case 2
                        if datasetName == "Milano"
                            AddInstructions("Press space and select AP marker for gluteal cleft")
                        else
                            AddInstructions("Press space and select AP marker for L5 (spinous process)")
                        end
                        drawnow();
                    case 3
                        AddInstructions("Press space and select AP marker for SIPS right (left in image)")
                        drawnow();
                    case 4
                        AddInstructions("Press space and select AP marker for SIPS left (right in image)")
                        drawnow();
                    otherwise
                        if lastApIndex>numOfMarkersAP
                            AddInstructions("Press space and draw AP spine midline from C7 (middle) to L5 (lower endplate)")
                            drawnow();
                        else
                            AddInstructions(append("Press space and select AP marker ", string(lastApIndex)))
                            drawnow();
                        end
                end
            end
        end
    elseif strcmp(fig1ApLat,'lat')==1
        global latDicomMarkers;
        global lastLatLineIndex;
        global lastLatIndex;
        global moveData;
        % if already drawing line
        if lastLatLineIndex > 0 && ~isempty(moveData.Pts)
            % revert line
            global latImg;
            for pi=1:size(moveData.Rs,2)
                delete(moveData.Rs(pi));
            end
            moveData.Rs = [];
            moveData.Pts = [];
        elseif lastLatIndex > 1
            % switch off automatic marker optimization
            global automaticMarkerOptimizationTemp;
            automaticMarkerOptimizationTemp = -1;
            % revert last marker
            lastLatIndex = lastLatIndex-1;
            latDicomMarkers(lastLatIndex).Pixel = [];
            latDicomMarkers(lastLatIndex).World = [];
            global latImg;
            global latDicomMarkerColors;
            delete(latDicomMarkerColors(lastLatIndex).R);
            latDicomMarkerColors(lastLatIndex).R = [];
            if lastLatIndex<=2
                for ri=1:size(latDicomMarkerColors(lastLatIndex).Rs, 2)
                    delete(latDicomMarkerColors(lastLatIndex).Rs(ri));
                end
                latDicomMarkerColors(lastLatIndex).Rs = [];
            end
            global numOfMarkersLAT;
            global datasetName;
            switch lastLatIndex
                case 1
                    AddInstructions("Press space and select LAT marker for C7 (spinous process)")
                    drawnow();
                case 2
                    if datasetName == "Milano"
                        AddInstructions("Press space and select LAT marker for gluteal cleft")
                    else
                        AddInstructions("Press space and select LAT marker for L5 (spinous process)")
                    end
                    drawnow();
                case 3
                    AddInstructions("Press space and select LAT marker for SIPS right (back in image)")
                    drawnow();
                case 4
                    AddInstructions("Press space and select LAT marker for SIPS left (front in image)")
                    drawnow();
                otherwise
                    if lastLatIndex>numOfMarkersLAT
                        AddInstructions("Press space and draw LAT spine midline from C7 (middle) to L5 (lower endplate)")
                        drawnow();
                    else
                        AddInstructions(append("Press space and select LAT marker ", string(lastLatIndex)))
                        drawnow();
                    end
            end
        end
    end
end
if allowImageOptimization
    if strcmp(evnt.Key,'i')==1
        global overallImg;
        global fig1;
        overallImg_imadjust = imadjust(overallImg);
        imshow(overallImg_imadjust);
        fig1.WindowState = 'maximized';
    end
    if strcmp(evnt.Key,'o')==1
        global overallImg;
        global fig1;
        overallImg_histeq = histeq(overallImg);
        imshow(overallImg_histeq);
        fig1.WindowState = 'maximized';
    end
    if strcmp(evnt.Key,'p')==1
        global overallImg;
        global fig1;
        overallImg_adapthisteq = adapthisteq(overallImg);
        imshow(overallImg_adapthisteq);
        fig1.WindowState = 'maximized';
    end
    if strcmp(evnt.Key,'u')==1
        global overallImg;
        global fig1;
        imshow(overallImg);
        fig1.WindowState = 'maximized';
    end
end

end