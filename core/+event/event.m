classdef event < handle
    properties (Access = private)
        iCounter   = 0;
    end
    
    properties (SetAccess = private, GetAccess = public)
        sType;
        oCaller;
    end
    
    properties (Access = public)
        % Payload data for the event
        tData;
        xData;
        
        % Store current token for setInterval calls etc - e.g.
        % oEvent.oCaller.setTimeout(oEvent.sToken, 245)
        sToken = [];
        
        % Id of specific callback
        sId = [];
        
        % Data storage
        tStorage = struct();
        
        % Type callback was assigned to (e.g. instead of 
        % schedule.exercise.bicycle, current type is schedule.exercise)
        sCurrentType = '';
        
        % Current setFilterCb
        modifyFilterCb = [];
        
        % Filter value(s) - array - can be changed through setFilterCb or
        % directly, as preferred
        aiFilters = [];
    end
    
    methods
        function this = event(sType, oCaller, xData)
            this.sType   = sType;
            this.oCaller = oCaller;
            this.xData   = xData;
            
            this.tData = xData;
        end
        
        
        function setFilter(this, varargin)
            if ~isempty(this.modifyFilterCb)
                % Cb writes new filter directly to oEvent.aiFilters
                this.modifyFilterCb(this, varargin{:});
            end
        end
    end
end
