classdef staticManip < matter.manips.substance.stationary
    %GROWTHMEDIUMCHANGES manipulator that changes the growth medium phase
    %content that results from chemical reactions and photosynthesis.
    %the reactions are calculated in separate objects for better
    %clarity and the resulting flow rates passed back to this manipulator.
    %in the manipulator the flow rates are then added and combined.
    
    properties (SetAccess = protected, GetAccess = public)
        
        
        fM_EDTA2minus_ini;          %moles initial of EDTA2- added to solution
        fM_H2PO4_ini;               %moles initial of Dihydrogen Phosphate added to solution
        fM_HPO4_ini;                %moles  Hydrogen Phosphate added to solution
        fM_KOH_ini;                 %moles Potassium hydroxide added to solution
        
        fC_EDTA2minus_ini           %[mol/L] initial concentration of EDTA2-^
        fC_H2PO4_ini                %[mol/L] initial concentration of Dihydrogen Phosphate
        fC_HPO4_ini                 %[mol/L] initial concentration of Hydrogen Phosphate
        fC_KOH_ini                  %[mol/L] initial concentration of Potassium Hydroxide
        
        mfCurrentConcentrationAll;
        fCurrentTotalEDTA               = 0;
        fCurrentTotalInorganicCarbon    = 0;
        fCurrentTotalPhosphate          = 0;
        fCurrentTotalMass               = 0;
        
        fCurrentCalculatedHplus         = 0;
        fCurrentCalculatedPH            = 0;
        fCurrentCalculatedOH            = 0;
        
        miTranslator;
        abSolve;
        
        fCurrentVolume                  = 0;
        
        %% acid constants
        fK_EDTA;                %[-] acid constant of EDTA to EDTA- and H+
        fK_EDTAminus;           %[-] acid constant of EDTA- to EDTA2- and H+
        fK_EDTA2minus;          %[-] acid constant of EDTA2- to EDTA3- and H+
        fK_EDTA3minus;          %[-] acid constant of EDTA3- to EDTA4- and H+
        
        fK_CO2;                 %[-] acid constant of CO2 + H2O to HCO3 and H+
        fK_HCO3;                %[-] acid constant of HCO3 to CO3 and H+
        
        fK_H3PO4;               %[-] acid constant of H3PO4 to H2PO4 and H+
        fK_H2PO4;               %[-] acid constant of H2PO4 to HPO4 and H+
        fK_HPO4;                %[-] acid constant of HPO4 to PO4 and H+
        
        fK_w;                    %[-] acid constant of H2O to OH- and H+
    end
    
    
    methods
        function this = staticManip(sName, oPhase)
            this@matter.manips.substance.stationary(sName, oPhase);
            
        end
    end
    
    methods (Access = protected)
        function update(this)
            
            
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
        end
    end
end