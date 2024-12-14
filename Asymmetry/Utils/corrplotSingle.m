function varargout = corrplotSingle(varargin)
%CORRPLOT Plot variable correlations
%
% Syntax:
%
%   corrplot(X)
%   corrplot(X,param,val,...)
%   [R,PValue,H] = corrplot(...)
%   [R,PValue,H] = corrplot(ax,...)
%
% Description:
%
%   Creates a matrix of plots showing correlations among pairs of variables
%   in X. Histograms of the variables appear along the matrix diagonal;
%   scatter plots of variable pairs appear off-diagonal. The slopes of the
%   least-squares reference lines in the scatter plots are equal to the
%   displayed correlation coefficients.
%
% Input Arguments:
%
%   X - numObs-by-numVars matrix or tabular array of numObs observations on
%       numVars variables.
%
%   ax - Axes object in which to plot. If unspecified, CORRPLOT plots to
%        the current axes (gca). CORRPLOT does not support uiaxes targets.
%
% Optional Input Parameter Name/Value Pairs:
%
%   NAME        VALUE
%
%   'type'      String or character vector indicating the type of
%               correlation coefficient to compute. Values are:
%
%               'Pearson'  Pearson's linear correlation coefficient
%
%               'Kendall'  Kendall's rank correlation coefficient (tau)
%
%               'Spearman' Spearman's rank correlation coefficient (rho)
%
%               The default is 'Pearson'.
%
%   'rows'      String or character vector indicating how to treat NaN
%               values in the data. Values are:
%
%               'all'       Use all rows, regardless of NaNs
%
%               'complete'  Use only rows with no NaNs
%
%               'pairwise'  Use rows with no NaNs in column i or j to
%                           compute R(i,j)
%
%               The default is 'pairwise'.
%
%   'tail'      String or character vector indicating the alternative
%               hypothesis used to compute the PValue output. Values are:
%
%               'both'	Ha: Correlation is not zero
%
%               'right'	Ha: Correlation is greater than zero
%
%               'left'  Ha: Correlation is less than zero
%
%               The default is 'both'.
%
%	'varNames' 	String vector or cell vector of character vectors, of
%               length numVars, to be used as variable names in the plots.
%               Names are truncated to the first five characters. The
%               default for matrix X is {'var1','var2',...}. The default
%               for dataset array X is X.Properties.VarNames.
%
%   'testR'     String or character vector indicating whether or not to
%               test for significant correlations and highlight them in
%               red. Values are 'off' and 'on'. The default is 'off'.
%
%   'alpha'     Scalar level for tests of correlation significance. Values
%               must be between 0 and 1. The default value is 0.05.
%
% Output Arguments:
%
%	R - numVars-by-numVars correlation matrix of X displayed in the plots.
%
%	PValue - numVars-by-numVars matrix of p-values corresponding to
%       elements of R, used to test the hypothesis of no correlation
%       against the alternative of a nonzero correlation.
%
%   H - Array of handles to the plotted graphics objects.
%
% Notes:
%
%   o P-values for Pearson's correlation are computed by transforming the
%     correlation to create a t statistic with numObs-2 degrees of freedom.
%     The transformation is exact when X is normal. P-values for Kendall's
%     and Spearman's rank correlations are computed using either the exact
%     permutation distributions (for small sample sizes), or large-sample
%     approximations. P-values for two-tailed tests are computed by
%     doubling the more significant of the two one-tailed p-values.
%
%   o Using the 'pairwise' option for the 'rows' parameter may return a
%     correlation matrix that is not positive definite. The 'complete'
%     option always returns a positive definite matrix, but in general the
%     estimates are based on fewer observations.
%
%   o Use the GNAME function to identify points in the plots.
%
% Example:
%
%   load Data_Canada
%   corrplot(DataTable)
%   gname(dates)
%
% See also COLLINTEST, CORR, GNAME.

% Copyright 2020 The MathWorks, Inc.

% Preprocess varargin for target axes:

try
    [ax,args] = internal.econ.axesparser(varargin{:});
catch ME
    throw(ME)
end

% This function produces a single plot:
if ~isempty(ax) && ~isscalar(ax)
    error(message('econ:internal:econ:axesparser:InvalidParent'));
end

% Parse inputs and set defaults:
parseObj = inputParser;
parseObj.addRequired('X',@XCheck);
parseObj.addParameter('type','Pearson',@typeCheck);
parseObj.addParameter('rows','pairwise',@rowsCheck);
parseObj.addParameter('tail','both',@tailCheck);
parseObj.addParameter('varNames',{},@varNamesCheck);
parseObj.addParameter('testR','off',@testRCheck);
parseObj.addParameter('alpha',0.05,@alphaCheck);

parseObj.parse(args{:});

X = parseObj.Results.X;

corrType = parseObj.Results.type;
if isstring(corrType)
    corrType = char(corrType);
end

whichRows = parseObj.Results.rows;
if isstring(whichRows)
    whichRows = char(whichRows);
end

tail = parseObj.Results.tail;
if isstring(tail)
    tail = char(tail);
end

varNames = parseObj.Results.varNames;
varNames = cellstr(varNames);

testRFlag = strcmpi(parseObj.Results.testR,'on');

alpha = parseObj.Results.alpha;

% Handle dataset array inputs:
if isa(X,'dataset')
    try
        X = dataset2table(X);
    catch 
        error(message('econ:corrplot:DataNotConvertible'))
    end
end

numVars = size(X,2);

% Create variable names:
if isempty(varNames)
    if isa(X,'table') || isa(X,'timetable')
    	varNames = X.Properties.VariableNames;
    else
        varNames = strcat({'var'},num2str((1:numVars)','%-u'));
    end
else
    if length(varNames) < numVars
        error(message('econ:corrplot:VarNamesTooFew'))
    elseif length(varNames) > numVars
        error(message('econ:corrplot:VarNamesTooMany'))
    end
end

% Truncate variable names to first five characters:
%varNames = cellfun(@(s)[s,'     '],varNames,'UniformOutput',false);
%varNames = cellfun(@(s)s(1:5),varNames,'UniformOutput',false);

% Convert table to double for numeric processing:
if isa(X,'table') || isa(X,'timetable')
    try
        X = table2array(X);
        X = double(X);
    catch
        error(message('econ:corrplot:DataNotConvertible'))
    end
end

% Compute plot information:
[R,PValue] = corr(X,'type',corrType,'rows',whichRows,'tail',tail);

Mu = nanmean(X);
Sigma = nanstd(X);
Z = bsxfun(@minus,X,Mu);
Z = bsxfun(@rdivide,Z,Sigma);
ZLims = [nanmin(Z(:)),nanmax(Z(:))];

% Store NextPlot flag (and restore on cleanup):
ax = newplot(ax);
next = get(ax,'NextPlot');
cleanupObj = onCleanup(@()set(ax,'NextPlot',next));

% Plot matrix:
hS = plot(ax,X(:,1), X(:,2),'o', 'MarkerFaceColor',hex2rgb('619CFF'),'MarkerEdgeColor',hex2rgb('619CFF'));
set(hS,'MarkerSize',4)

hParent = get(ax,'Parent');

% There may be a panel or other container between the parent and
% the figure. The figure is needed for unit conversions and to set
% the CurrentAxes.
hFig = ancestor(ax,'figure');

% The CanvasHost is needed to do unit conversions below. In some
% cases (such as an axes inside a TiledChartLayout), the immediate
% parent is not the CanvasHost.
hCanvasHost = ancestor(ax, 'matlab.ui.internal.mixin.CanvasHostMixin','node');
set(hFig,'CurrentAxes',ax(1,1))
set(ax(1,1),'XLim',Mu(1)+(1.1)*ZLims*Sigma(1),...
            'YLim',Mu(2)+(1.1)*ZLims*Sigma(2))
axis(ax(1,1),'normal')

hls = lsline(ax(1,1));
set(hls,'Color','k','Tag','lsLines');
plotPos = get(ax(1,1),'InnerPosition');

% Convert the InnerPosition from the units used by the axes to
% normalized coordinates, which are required by the annotation
% command.
plotPos = hgconvertunits(hFig,plotPos,get(ax(1,1),'Units'),...
         'normalized',hCanvasHost);

if testRFlag && (PValue(2,1) < alpha)
    corrColor = 'r';
else
    corrColor = 'k';
end

pValString = append("p = ", num2str(PValue(2,1),'%3.3f'));
if PValue(2,1)< 0.001
    pValString = "p < 0.001";
end

annotation(hParent,...
           'textbox',plotPos,...
           'String',append("R = ", num2str(R(2,1),'%3.2f'), ", ", pValString),...
           'FontWeight','Bold',...
           'Color',corrColor,...
           'EdgeColor','none','Tag','corrCoefs')
            
% Return "plot object":
H = hS;

% Modify other axes properties conditional on NextPlot flag:
ax.Tag = 'CorrPlot';

switch next
    case {'replace','replaceall'}
        Xlabels = gobjects(1,1);
        Ylabels = gobjects(1,1);
        Xlabels(1) = xlabel(ax(1,1),varNames{1});
        Ylabels(1) = ylabel(ax(1,1),varNames{2});
        set(get(ax,'Title'),'String','{\bf Correlation Matrix}')

    case {'replacechildren','add'}
        % Do not modify axes properties
end

% Restore current axes to bigAx:
set(hFig,'CurrentAxes',ax)

% Suppress assignment to ans:
nargoutchk(0,3);
if nargout > 0
    varargout = {R,PValue,H};
end

%-------------------------------------------------------------------------
% Check input X
function OK = XCheck(X)

if ischar(X)
    
    error(message('econ:corrplot:DataNonNumeric'))
            
elseif isempty(X)

    error(message('econ:corrplot:DataUnspecified'))

elseif isvector(X)

    error(message('econ:corrplot:DataIsVector'))

else

    OK = true;

end

%-------------------------------------------------------------------------
% Check value of 'type' parameter
function OK = typeCheck(corrType)

if ~isvector(corrType)

    error(message('econ:corrplot:CorrTypeNonVector'))

elseif isnumeric(corrType)

    error(message('econ:corrplot:CorrTypeNumeric'))

elseif ~ismember(lower(corrType),{'pearson','kendall','spearman'})

    error(message('econ:corrplot:CorrTypeInvalid'))

else

    OK = true;

end

%-------------------------------------------------------------------------
% Check value of 'rows' parameter
function OK = rowsCheck(whichRows)

if ~isvector(whichRows)

    error(message('econ:corrplot:RowsParamNonVector'))

elseif isnumeric(whichRows)

    error(message('econ:corrplot:RowsParamNumeric'))

elseif ~ismember(lower(whichRows),{'all','complete','pairwise'})

    error(message('econ:corrplot:RowsParamInvalid'))

else

    OK = true;

end

%-------------------------------------------------------------------------
% Check value of 'tail' parameter
function OK = tailCheck(tail)

if ~isvector(tail)

    error(message('econ:corrplot:TailParamNonVector'))

elseif isnumeric(tail)

    error(message('econ:corrplot:TailParamNumeric'))

elseif ~ismember(lower(tail),{'both','right','left'})

    error(message('econ:corrplot:TailParamInvalid'))

else

    OK = true;

end

%-------------------------------------------------------------------------
% Check value of 'varNames' parameter
function OK = varNamesCheck(varNames)
    
if ~isvector(varNames)

    error(message('econ:corrplot:VarNamesNonVector'))

elseif isnumeric(varNames) || (iscell(varNames) && any(cellfun(@isnumeric,varNames)))

    error(message('econ:corrplot:VarNamesNumeric'))

else

    OK = true;

end

%-------------------------------------------------------------------------
% Check value of 'testR' parameter
function OK = testRCheck(testR)

if ~isvector(testR)

    error(message('econ:corrplot:testRNonVector'))

elseif isnumeric(testR)

    error(message('econ:corrplot:testRNumeric'))

elseif ~ismember(lower(testR),{'off','on'})

    error(message('econ:corrplot:testRInvalid'))

else

    OK = true;

end

%-------------------------------------------------------------------------
% Check value of 'alpha' parameter
function OK = alphaCheck(alpha)
    
if ~isnumeric(alpha)

    error(message('econ:corrplot:AlphaNonNumeric'))

elseif ~isscalar(alpha)

    error(message('econ:corrplot:AlphaNonScalar'))

elseif alpha < 0 || alpha > 1

    error(message('econ:corrplot:AlphaOutOfRange'))

else

    OK = true;

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