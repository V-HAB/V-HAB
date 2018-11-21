function [  ] = overlayFigures( csFigures )
% This is a function that can be used to overlay multiple figures (e.g.
% from a case study) into one figure, provided they have some common time
% frame and the same layout of subplots. Some common time frame means that
% the function will determine the time frame the different plots share and
% only plot the time frame that is available in all plots. E.g. if one plot
% is from 0h to 21h and another from 20h to 40h then the plot will only be
% for the time frame from 20h to 21h.
%
% The input has to be a string to the save path for each figure (you can
% find this string easily if you drag and drop the figure into the matlab
% command window, which will execute a command containing the required
% string!)
%
% Note the first figure specified will keep the line styles as is, the
% other figures that are added will be dash dotted for the second figure,
% dashed for the third and dotted for the fourth figure. Overlaying more than
% four figures is not recommended, but all further figures will use dotted
% lines as well. The colors of the lines will remain as specified in the
% individual figures!

iTotalFigures   = length(csFigures);
coFigures       = cell(iTotalFigures,1);
coAxes          = cell(iTotalFigures,1);
coDataObjects	= cell(iTotalFigures,1);

for iFigure = 1:iTotalFigures
    % first step, store the figures in the cells to make them easily
    % accesible
    coFigures{iFigure} = openfig(csFigures{iFigure}, 'invisible');
    
    % and then we can store the axes of each figure in a cell
    try
        % case with subplots
        coAxes{iFigure} = get(coFigures{iFigure},'children');
        
        aoAxes = coAxes{iFigure};
        A = aoAxes(1).YLim;
    catch
        % case without subplots
        coAxes{iFigure} = gca;
    end
    % and the data objects, which also contain the actual data points of
    % interest for us
    coDataObjects{iFigure} = get(coAxes{iFigure}, 'Children');
    
end

% Now we can go ahead and create a new figure which would be the overlay of
% all the figures provided as inputs
%
% The first step when making one common figure out of the different figures
% is to decide the correct limits for the axis. For the x axis, where
% usually time is plotted, the narrowest frame available from all figures
% will be used. For the y axis on the other hand, the broadest range will
% be used
fOverallLowerLimit_X = 0;
fOverallUpperLimit_X = inf;

aoAxes = coAxes{1};
mfYLimits = aoAxes(1).YLim;
fOverallLowerLimit_Y = mfYLimits(1);
fOverallUpperLimit_Y = mfYLimits(2);

for iFigure = 1:iTotalFigures
    
    aoAxes = coAxes{iFigure};
    for iAxes = 1:length(aoAxes)
        mfXLimits = aoAxes(iAxes).XLim;
        mfYLimits = aoAxes(iAxes).YLim;

        if mfXLimits(1) > fOverallLowerLimit_X
            fOverallLowerLimit_X = mfXLimits(1);
        end

        if mfXLimits(2) < fOverallUpperLimit_X
            fOverallUpperLimit_X = mfXLimits(2);
        end

        if mfYLimits(1) < fOverallLowerLimit_Y
            fOverallLowerLimit_Y = mfYLimits(1);
        end

        if mfYLimits(2) > fOverallUpperLimit_Y
            fOverallUpperLimit_Y = mfYLimits(2);
        end
    end
end

% The first figure is skipped because all plots are put together in the
% first figure!
set(0, 'currentfigure', coFigures{1});
aoAxesFigure1 = coAxes{1};

for iFigure = 2:iTotalFigures
    % gets the data object array for the current figure
    aoData = coDataObjects{iFigure};
    
    for iAxes = 1:length(aoAxes)
        
        % now sets the corresponding axis in the first figure as current
        % (thus ensuring that the data from the other figures is plotted
        % into the same subplot)
        set(coFigures{1}, 'currentaxes', aoAxesFigure1(iAxes));
        
        hold on
        % plots the data
        if iFigure == 2
            sLineSpec = '-.';
        elseif iFigure == 3
            sLineSpec = '--';
        elseif iFigure >= 4
            sLineSpec = ':';
        end
        try
            % case with subplots
            for iData = 1:length(aoData{iAxes})
                aoCurrentData = aoData{iAxes};
                plot(aoCurrentData(iData).XData, aoCurrentData(iData).YData, sLineSpec, 'Color', aoCurrentData(iData).Color);
            end
        catch
            % case without subplots
            for iData = 1:length(aoData)
                plot(aoData(iData).XData, aoData(iData).YData, sLineSpec, 'Color', aoData(iData).Color);
            end
        end
        % set the overall x and y limits
        xlim([fOverallLowerLimit_X, fOverallUpperLimit_X]);
        ylim([fOverallLowerLimit_Y, fOverallUpperLimit_Y]);
        
    end
end

% Now activates the visibility of the first figure again, which now
% includes all the data
coFigures{1}.Visible = 'on';
end

