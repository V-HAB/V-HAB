classdef figure < handle 
    %FIGURE Summary of this class goes here
    %   Detailed explanation goes here
    
     properties (SetAccess = protected, GetAccess = public)
        sName;
        coPlots;
        
    end
    
    properties (SetAccess = public, GetAccess = public)
        tFigureOptions;
    end
    
    methods
        function this = figure(sName, coPlots, tFigureOptions)
            this.sName = sName;
            this.coPlots = coPlots;
            if nargin > 2
                this.tFigureOptions = tFigureOptions;
            else
                this.tFigureOptions = struct();
            end
        end
        
        
    end
end

