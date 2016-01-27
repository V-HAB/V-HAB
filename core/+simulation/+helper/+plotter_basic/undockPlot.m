function undockPlot(iPlot)


if nargin == 0
    disp('Undocks subplot from last focussed figure. First param has to be the number of the subplot.');
    
    return;
end



oMainFigure = gcf;

if isempty(oMainFigure.UserData) || ~isstruct(oMainFigure.UserData) || ~isfield(oMainFigure.UserData, 'coAxesHandles')
    display('Please select figure with plots first!');
    
    return;
end


oNewFigure  = figure();
oAxes       = oMainFigure.UserData.coAxesHandles{iPlot};

oOldParent    = oAxes.Parent;
afOldPosition = oAxes.Position;


oAxes.Parent   = oNewFigure;
oAxes.Position = [ 0.08 0.1 0.88 0.85 ];


function onClose(varargin)
    oAxes.Parent   = oOldParent;
    oAxes.Position = afOldPosition;
    
    delete(oNewFigure);
end

oNewFigure.CloseRequestFcn = @onClose;


end

