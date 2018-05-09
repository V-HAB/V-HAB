classdef FoodConverter < matter.manips.substance.flow
    
    % A phase manipulator to convert the food entering the human into the
    % different basic components like proteins, fat, carbohydrates and
    % water
    
    properties (SetAccess = protected, GetAccess = public)
        
        fTotalError = 0;
        fLastUpdate = 0;
        
        fTimeStep = 1;
    end
    
    methods
        function this = FoodConverter(sName, oPhase, fTimeStep)
            this@matter.manips.substance.flow(sName, oPhase);
            
            this.fTimeStep = fTimeStep;
            
        end
        
        function update(this, ~)
            
        end
    end
end