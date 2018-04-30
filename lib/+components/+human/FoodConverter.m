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
            
            %% Calculates the mass error for this manipulator
            this.setTimeStep(this.fTimeStep, true);
            
            txResults = this.oMT.calculateNutritionalContent(this.oIn.oPhase);
            
            keyboard();
            
            
            %% sets the flowrate values
            update@matter.manips.substance.flow(this, afFlowRates);
            
            this.fLastExec = this.oTimer.fTime;
        end
    end
end