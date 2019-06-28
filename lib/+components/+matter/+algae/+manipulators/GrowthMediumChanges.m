classdef GrowthMediumChanges < matter.manips.substance.stationary
    %GROWTHMEDIUMCHANGES manipulator that changes the growth medium phase
    %content that results from chemical reactions and photosynthesis.
    %the reactions are calculated in separate objects for better
    %clarity and the resulting flow rates passed back to this manipulator.
    %in the manipulator the flow rates are then added and combined.
    
    properties (SetAccess = protected, GetAccess = public)
        fLastExecTimeStep;                      %[s]
        fTimeStep = 0;                          %[s]
        afMass;                                 %[kg] array of fields containing the masses of each component that is currently present in the growth medium
        afPartialFlowRatesFromPhotosynthesis;   %[kg/s]
        afPartialFlowRatesFromFunctions;        %[kg/s]
        
        oPhotosynthesisModule %photosynthesis module that calculates the photosynthetic growth of Chlorella vulgaris based on stoichiometric relations
        oChemicalReactions %objects that calculates the chemical reactions and resulting molalities in the growth medium. sets flow rates for manipulator
        
        %factors for tracing of nutrient limitation, all this should go
        %into photosynthesis module.
        
        
    end
    
    
    methods
        function this = GrowthMediumChanges(sName, oPhase)
            this@matter.manips.substance.stationary(sName, oPhase);
            this.fLastExec = 0;
            this.oChemicalReactions = components.matter.algae.CalculationModules.GrowthMediumModule.BBMReactions(this);
            try
                this.oPhotosynthesisModule = this.oPhase.oStore.oContainer.oPhotosynthesisModule;
            catch
                
            end
        end
    end
    
    methods (Access = protected)
        function update(this)
            this.fTimeStep = this.oPhase.fTimeStep; %%[s]prediction to future time step. if calculated last time step is used (fTime-fLastExec), then errors and tiny time steps result.
            this.fLastExecTimeStep = this.oTimer.fTime - this.fLastExec; %%[s]passed since last execution
            %set all to 0 to delete old values
            afPartialFlowRates = zeros(1, this.oMT.iSubstances); %kg/s
            
            
            
            
            %% Photosynthesis
            %the function that is called here calculates the mass increase
            %of chlorella and o2 and how m mass of other reactants is used to
            %allow this growth
            if ~isempty(this.oPhotosynthesisModule)
                this.afPartialFlowRatesFromPhotosynthesis = this.oPhotosynthesisModule.update(this); %[kg/s]
            else
                this.afPartialFlowRatesFromPhotosynthesis = zeros(1, this.oPhase.oMT.iSubstances);
            end
            
            %% BBM Components Chemistry / oH calculation
            afPartialFlowRatesFromReactions = this.oChemicalReactions.update(this.fTimeStep); %[kg/s]
            
            %% add flow rates from different functions
            this.afPartialFlowRatesFromFunctions =  afPartialFlowRatesFromReactions + this.afPartialFlowRatesFromPhotosynthesis; %[kg/s]
            
            %% set flow rates to pass back
            
            % check if time step is larger than 0 (exclude first time
            % step) in order to ensure one is not dividing by zero.
            % actually this is already being done in the functions where
            % the calculations take place
            if this.fTimeStep > 0
                
                afPartialFlowRates = this.afPartialFlowRatesFromFunctions; %[kg/s]
                
            else
                afPartialFlowRates = zeros(1, this.oMT.iSubstances); %[kg/s]
            end
            
            update@matter.manips.substance.stationary(this, afPartialFlowRates);
            this.fLastExec = this.oTimer.fTime; %[s]
        end
    end
    
end

