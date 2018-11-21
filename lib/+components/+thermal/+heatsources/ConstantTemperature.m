classdef ConstantTemperature < thermal.heatsource
    % 
    
    properties (SetAccess = protected, GetAccess = public)
        
    end
    
    methods
        
        function this = ConstantTemperature(sName)
            this@thermal.heatsource(sName, 0);
            this.sName  = sName;
            
        end
        
        function setCapacity(this, oCapacity)
            % overwrite the generic setCapacity function so that we can
            % bind a callback to the capacity temperature update
            if isempty(this.oCapacity)
                this.oCapacity = oCapacity;
            else
                this.throw('setCapacity', 'Heatsource already has a capacity object');
            end
            
            if ~isempty(oCapacity.aoHeatSource)
                error('A Constant temperature heat source must be the only heatsource used for the respective capacity!')
            end
            
            % bin callpack to update this heat source before updating the
            % heatsource heatflows of the capacity. Note do not use a
            % consant temperature heat source together with any other heat
            % source (why would you do that?)
            oCapacity.bind('calculateHeatsource_pre',@(~)this.update());
        end
        
        function update(this,~)
            
            fExmeHeatFlow = 0;
            for iExme = 1:length(this.oCapacity.aoExmes)
                fExmeHeatFlow = fExmeHeatFlow + (this.oCapacity.aoExmes(iExme).iSign * this.oCapacity.aoExmes(iExme).fHeatFlow);
            end
            
            this.fHeatFlow = - fExmeHeatFlow;
        end
    end
    
end

