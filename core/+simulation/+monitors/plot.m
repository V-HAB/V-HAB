classdef plot < handle
    %PLOT Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (SetAccess = protected, GetAccess = public)
        sTitle;
        aiIndexes;
        
    end
    
    properties (SetAccess = public, GetAccess = public)
        tPlotOptions;
    end
    
    methods
        function this = plot(sTitle, aiIndexes, tPlotOptions)
            this.sTitle = sTitle;
            this.aiIndexes = aiIndexes;
            if nargin > 2
                this.tPlotOptions = tPlotOptions;
            else
                this.tPlotOptions = struct();
            end
            
        end
        
        
    end
end

