function hCombinedFigure = combineFigures(chFigures, tOptionalInputs)
% This function can be used to combine seperate matlab figures into one
% figure with subplots. It requires the respective figure handles as input
% which can be obtained by openening both figures and using the command 
% figHandles = get(groot, 'Children'); This function then requires them as
% cell input e.g. like this {figHandles(1), figHandles(2), figHandles(3)}
%
% chFigures:        cell array containing the figure handles
% tOptionalInputs:  Struct containing the following optional Inputs
%   sName:          Name of the new combined figure (otherwise the name of
%                   the first figure is used)
%   sPositioning:   Can be 'column' or 'row' and decides whether the
%                   subplots from the figures shall be arranged in columns
%                   or in rows
%   miSubPlots:    	Alternative to sPositioning where the number of rows
%                   (first entry) and number of columns (second entry)
%                   for the subplots can be defined
%   bOnlyOneLegend: If this is set to true, only the legends from the first
%                   figure are created, which is usefull if all figures use
%                   the same legends
%   bAddEmptySpace: if this is set to true one empty subplot row or column
%                   is created which can be used to e.g. place the legend

% If not name is specified we use the ´name of the first figure
sName = chFigures{1}.Name;
if nargin > 1
    if isfield(tOptionalInputs, 'sName')
        sName = tOptionalInputs.sName;
    end
else
    tOptionalInputs = struct();
end
        
hCombinedFigure = figure('Name', sName);

iFigures = length(chFigures);

chChildren = cell(iFigures,1);
for iFigure = 1:iFigures
    chChildren{iFigure} = get(chFigures{iFigure},'children');
end

% Check number of subplots in the figures. The user can specify whether
% each figures subplots shall be in row or column format, but all subplots
% for the figures will be in either one row or one column
chSubplots = cell(iFigures,1);
chLegends  = cell(iFigures,1);
miSubplots = zeros(iFigures,1);
for iFigure = 1:iFigures
    iLegend = 0;
    iSubplot = 0;
    for iChild = 1:length(chChildren{iFigure})
        hChild = chChildren{iFigure}(iChild);
        if strcmp(hChild.Type, 'legend')
            iLegend = iLegend + 1;
            chChildLegends{iLegend} = hChild; 
        elseif strcmp(hChild.Type, 'axes')
            iSubplot = iSubplot + 1;
            chChildSubplots{iSubplot} = hChild; 
            miSubplots(iFigure) = miSubplots(iFigure) + 1;
        end
    end
    chLegends{iFigure} = chChildLegends;
    chSubplots{iFigure} = chChildSubplots;
end

% Check whether the combined figure subplots shall be put into column or
% row format
sPositioning = 'column';
if nargin > 1
    if isfield(tOptionalInputs, 'sPositioning')
        sPositioning = tOptionalInputs.sPositioning;
    end
end


if nargin > 1 && isfield(tOptionalInputs, 'bAddEmptySpace') && tOptionalInputs.bAddEmptySpace
    iFiguresForSubplots = iFigures+1;
else
    iFiguresForSubplots = iFigures;
end

iTotalNewSubplots = iFiguresForSubplots * max(miSubplots);
iNewSubplotsPerFigure = iTotalNewSubplots / iFigures;
            
if isfield(tOptionalInputs, 'miSubPlots')
    for iFigure = 1:iFigures
        for iSubplot = 1:miSubplots(iFigures)
            chNewSubplots(iFigure, iSubplot) = subplot(tOptionalInputs.miSubPlots(1), tOptionalInputs.miSubPlots(2), (iNewSubplotsPerFigure * (iFigure-1)) + iSubplot);
        end
    end
elseif strcmp(sPositioning,  'column')
    for iFigure = 1:iFigures
        for iSubplot = 1:miSubplots(iFigures)
            chNewSubplots(iFigure, iSubplot) = subplot(iFiguresForSubplots, max(miSubplots), (iNewSubplotsPerFigure * (iFigure-1)) + iSubplot);
        end
    end
else
    for iFigure = 1:iFigures
        for iSubplot = 1:miSubplots(iFigures)
            chNewSubplots(iFigure, iSubplot) = subplot(max(miSubplots), iFiguresForSubplots, (iNewSubplotsPerFigure * (iSubplot-1)) + iFigure);
        end
    end
end
for iFigure = 1:iFigures
    chCurrentFigureSubplots = chSubplots{iFigure};
%     chCurrentFigureLegends = chLegends{iFigure};
    for iSubplot = 1:miSubplots(iFigure)
        copyobj(allchild(chCurrentFigureSubplots{iSubplot}),chNewSubplots(iFigure, iSubplot));
        sXLabel =  chCurrentFigureSubplots{iSubplot}.XLabel.String;
        sYLabel =  chCurrentFigureSubplots{iSubplot}.YLabel.String;
        sTitle  = chCurrentFigureSubplots{iSubplot}.Title.String;
        chNewSubplots(iFigure, iSubplot).XLabel.String = sXLabel;
        chNewSubplots(iFigure, iSubplot).YLabel.String = sYLabel;
        if ~isempty(sTitle)
            chNewSubplots(iFigure, iSubplot).Title.String = sTitle;
        end
        chNewSubplots(iFigure, iSubplot).YGrid = 'on';
        chNewSubplots(iFigure, iSubplot).XGrid = 'on';
        chNewSubplots(iFigure, iSubplot).YMinorGrid = 'on';
        chNewSubplots(iFigure, iSubplot).XMinorGrid = 'on';
        
        if nargin > 1 && isfield(tOptionalInputs, 'mrRescalePlots')
            % Horizontal Rescaling
            chNewSubplots(iFigure, iSubplot).Position(3) = chNewSubplots(iFigure, iSubplot).Position(3) .* tOptionalInputs.mrRescalePlots(1);
            
            % Vertical Rescaling, this is a bit more complicated because we
            % want the free space below the plots
            rOriginalPlotSizeVertical =  chNewSubplots(iFigure, iSubplot).Position(4);
            chNewSubplots(iFigure, iSubplot).Position(4) = chNewSubplots(iFigure, iSubplot).Position(4) .* tOptionalInputs.mrRescalePlots(2);
            rSizeDifferenceVertical = chNewSubplots(iFigure, iSubplot).Position(4) - rOriginalPlotSizeVertical;
            chNewSubplots(iFigure, iSubplot).Position(2) = chNewSubplots(iFigure, iSubplot).Position(2) - rSizeDifferenceVertical;
        end
        if nargin > 1 && isfield(tOptionalInputs, 'mrLineColors')
            % This is necessary because otherwise it is confusing for the
            % user as the first line in the legend is actually the last
            % line in the children!
            miChildLine = length(chNewSubplots(iFigure, iSubplot).Children):-1:1;
            for iLine = 1:length(chNewSubplots(iFigure, iSubplot).Children)
                chNewSubplots(iFigure, iSubplot).Children(miChildLine(iLine)).Color = tOptionalInputs.mrLineColors(iLine,:);
            end
        end
        
        if nargin > 1 && isfield(tOptionalInputs, 'bOnlyOneLegend') && tOptionalInputs.bOnlyOneLegend 
            if iFigure == 1
                chNewLegends(iFigure, iSubplot)    =   legend(chNewSubplots(iFigure, iSubplot));
            end
        else
            chNewLegends(iFigure, iSubplot)    =   legend(chNewSubplots(iFigure, iSubplot));
        end
    end
end

end

