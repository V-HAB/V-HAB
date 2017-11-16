classdef figure < handle 
    %FIGURE Container for all information relating to a single figure 
    %   This class defines objects that are used to store information
    %   regarding individual figure objects in MATLAB. Most importantly
    %   they contain the tFigureOptions property, which is publicly
    %   accessible, meaning it can be changed directly by the user,
    %   influencing the appearance of figures even after the simulation has
    %   run. 
    
     properties (SetAccess = protected, GetAccess = public)
         % A string containing the figure's name
         sName;
         
         % A cell array of objects containing plot objects
         coPlots;
         
    end
    
    properties (SetAccess = public, GetAccess = public)
        % tFigureOptions has field names that correspond to the properties
        % of figure objects in MATLAB. The values given here are directly
        % set on the figure object once it is created. To adhere to the
        % V-HAB variable naming convention, the field names can still
        % include the prefixes to signal the data type, for example
        % 'csNames'. The lower case letters at the beginning of the string
        % will then be stripped by the plotter.
        %
        % There are a few additional fields that tPlotOptions can have that
        % do not correspond to the properties of the axes object. Options
        % include turning on or off the plottools (off by default) by using
        % a field 'bPlotTools'. 
        % There is also an option to include a plot of the simulated time
        % versus the simulation ticks in the figure. This can be triggered
        % by including a field called 'bTimePlot' with a true boolean
        % value.
        tFigureOptions;
    end
    
    methods
        function this = figure(sName, coPlots, tFigureOptions)
            % Constructor method
            % Setting the object properties according to the input
            % arguments.
            this.sName = sName;
            this.coPlots = coPlots;
            
            % Only set the tFigureOptions property if it is passed in. If
            % not, we create an empty struct since it may be used by other
            % methods that assume it is there. 
            if nargin > 2
                this.tFigureOptions = tFigureOptions;
            else
                this.tFigureOptions = struct();
            end
        end
        
        
    end
end

