function bp = CustomBoxPlot(varargin)

varargin2 = varargin;
if sum(strcmp('Symbol', varargin2))<=0
    varargin{end+1} = 'Symbol';
    varargin{end+1} = '.k';
end
if sum(strcmp('OutlierSize', varargin2))<=0
    varargin{end+1} = 'OutlierSize';
    varargin{end+1} = 16;
end

boxplot(varargin{:})
colors = [hex2rgb('619CFF'); hex2rgb('F8766D'); hex2rgb('00BA38'); hex2rgb('CC79A7')]; %c("#999999", "#E69F00", "#56B4E9", "#009E73", "#F0E442", "#0072B2", "#D55E00", "#CC79A7")
h = findobj(gca,'Tag','Box');
for j=1:length(h)
    patch(get(h(j),'XData'),get(h(j),'YData'),colors(j, :),'FaceAlpha',0.5);
end
% remove boxplot again
lines = findobj(gcf, 'type', 'line');
for line=lines
    delete(line);
end
hold on;
bp = boxplot(varargin{:});
medLine = findobj(gcf, 'type', 'line', 'Tag', 'Median');
set(medLine, 'LineWidth', 1.1);
set(medLine, 'Color', 'k');
lines = findobj(gcf, 'type', 'line');
h = findobj(gca,'Tag','Box');
for j=1:length(h)
    set(h(j), 'Color', 'k');
end

%% functions
function rgb = hex2rgb(hexString)
	if size(hexString,2) ~= 6
		error('invalid input: not 6 characters');
	else
		r = double(hex2dec(hexString(1:2)))/255;
		g = double(hex2dec(hexString(3:4)))/255;
		b = double(hex2dec(hexString(5:6)))/255;
		rgb = [r, g, b];
	end
end
end