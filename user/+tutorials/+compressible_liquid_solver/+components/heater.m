classdef heater < matter.procs.f2f
    %Heater: static heater model
    % the value fTemp is the temperature up to which the heater is capable
    % to heat the fluid
    
    properties
        fDeltaPressure = 0;      % Pressure difference created by the heater in Pa
        
        iDir = 0;            % Direction of flow
        
        fTempMax = 0;
        
        fRoughness = 0;
        
       
    end
    
    properties (SetAccess = protected, GetAccess = public)
        fHydrDiam = 0.5;        % Hydraulic diameter
        fHydrLength = 1;        % Hydraulic Length
        fDeltaTemp = 0;         % temperature difference created by the heater in K
        bActive = true;         % Must be true so the update function is called from the branch solver
    end
    
    methods
        function this = heater(oMT, sName, fTemp, fHydrDiam, fHydrLength, fRoughness)
            this@matter.procs.f2f(oMT, sName);
                        
            this.fTempMax = fTemp;
            if nargin == 4
                this.fHydrDiam = fHydrDiam;
            elseif nargin == 5
                this.fHydrLength = fHydrLength;
                this.fHydrDiam = fHydrDiam;
            elseif nargin == 6
                this.fHydrLength = fHydrLength;
                this.fHydrDiam = fHydrDiam;
                this.fRoughness = fRoughness;
            end

        end
        
        function update(this)
            
            bZeroFlows = 0;
            for k = 1:length(this.aoFlows)
                if this.aoFlows(1,k).fFlowRate == 0
                   bZeroFlows = 1; 
                end
            end
            if bZeroFlows == 1
                this.fDeltaTemp = 0;
            else
                [InFlow, OutFlow]=this.getFlows();
                %this.fDeltaPressure;
                this.fDeltaTemp = this.fTempMax-InFlow.fTemp;
                
                %fix matter values required to use the correlations for
                %density and pressure. 

                %TO DO make dependant on matter table
                %values for water
                %density at one fixed datapoint
                fFixDensity = 998.21;        %g/dm³
                %temperature for the fixed datapoint
                fFixTemperature = 293.15;           %K
                %Molar Mass of the compound
                fMolMassH2O = 18.01528;       %g/mol
                %critical temperature
                fCriticalTemperature = 647.096;         %K
                %critical pressure
                fCriticalPressure = 220.64*10^5;      %N/m² = Pa

                %boiling point normal pressure
                fBoilingPressure = 1.01325*10^5;      %N/m² = Pa
                %normal boiling point temperature
                fBoilingTemperature = 373.124;      %K

                fDensity = solver.matter.fdm_liquid.functions.LiquidDensity(InFlow.fTemp,...
                                    InFlow.fPressure, fFixDensity, fFixTemperature, fMolMassH2O, fCriticalTemperature,...
                                    fCriticalPressure, fBoilingPressure, fBoilingTemperature);

                fFlowSpeed = InFlow.fFlowRate/(fDensity*pi*0.25*this.fHydrDiam^2);

                this.fDeltaPressure = pressure_loss_pipe (this.fHydrDiam, this.fHydrLength,...
                                fFlowSpeed, 1200.4*10^-6, fDensity, this.fRoughness, 0);
            end
            
            
        end
        
    end
    
end

