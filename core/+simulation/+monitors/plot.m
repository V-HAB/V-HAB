classdef plot < handle
    %PLOT Container for all information relating to a single plot 
    %   This class defines objects that are used to store information
    %   regarding individual plots in a MATLAB figure. Most importantly
    %   they contain the tPlotOptions property, which is publicly
    %   accessible, meaning it can be changed directly by the user,
    %   influencing the appearance of plots even after the simulation has
    %   run. 
    
    properties (SetAccess = protected, GetAccess = public)
        % A string containing the plot title
        sTitle;
        
        % An array of integers containing the indexes of all plotted items
        % in the log array.
        aiIndexes;
        
    end
    
    properties (SetAccess = public, GetAccess = public)
        % tPlotOptions has field names that correspond to the properties of
        % axes objects in MATLAB. The values given here are directly set on
        % the axes object once it is created. To adhere to the V-HAB
        % variable naming convention, the field names can still include the
        % prefixes to signal the data type, for example 'csNames'. The
        % lower case letters at the beginning of the string will then be
        % stripped by the plotter.
        %
        % There are a few additional fields that tPlotOptions can have that
        % do not correspond to the properties of the axes object. One field
        % can contain another struct called tLineOptions. This struct can
        % contain settings for the individual line objects of the plot,
        % like markers, line styles and colors. Again, the field names must
        % have the same names as the properties of the line objects. If
        % there are multiple lines in a plot, the values in the struct must
        % be contained in cells with the values in the same order as the
        % lines. If no information is given here, the MATLAB default values
        % are used.
        %
        % With the sTimeUnit field the user can determine the unit of time
        % for of each plot. The default is seconds, but minutes, hours,
        % days, weeks, months and years are also possible. The sTimeUnit
        % field is a string and can contain exactly these words.
        %
        % If the user chooses to have two y axes, we need to provide an
        % opportunity to customize that as well. For this the
        % tRightYAxesOptions field exists. It can have the same entries as
        % the tPlotOptions struct, so field names that correspond to the
        % properties of axes object.
        %
        % The bLegend field determines if the legend of the axes is visible
        % or not. The default is visible.
        %
        % A plot can only have two y axes, one on the left and one on the
        % right. If the plot values defined by the aiIndexes property
        % contain values in one or two units, then one is displayed on the
        % left axis and the other on the right automatically by the
        % plotter. If aiIndexes contains values in more than two units,
        % it needs to be defined, which values and units are displayed on
        % each axis. This can be done by including a field called
        % csUnitOverride. It is a cell containing two further cells, which
        % in turn include the unit strings for the left and right side
        % (left side in the first cell, right side in the second).
        % Alternatively it can contain only one cell in a cell containing
        % the string 'all left'. This will force all units to be displayed
        % on the left side. 
        tPlotOptions;
    end
    
    methods
        function this = plot(sTitle, aiIndexes, tPlotOptions)
            % Constructor method
            % Setting the object properties according to the input
            % arguments.
            this.sTitle = sTitle;
            this.aiIndexes = aiIndexes;
            
            % Only set the tPlotOptions property if it is passed in. If
            % not, we create an empty struct since it may be used by other
            % methods that assume it is there. 
            if nargin > 2
                this.tPlotOptions = tPlotOptions;
            else
                this.tPlotOptions = struct();
            end
            
        end
        
        
    end
end

