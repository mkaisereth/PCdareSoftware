function WaitForSpace()
    k=0;
    while ~k
        k=waitforbuttonpress;
        if ~strcmp(get(gcf,'currentcharacter'),'')
            k=0;
        end
    end
end