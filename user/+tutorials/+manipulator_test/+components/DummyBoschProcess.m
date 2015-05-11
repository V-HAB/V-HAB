classdef DummyBoschProcess < matter.manips.substance.flow
    %DUMMYBOSCHPROCESS A dummy model of the Bosch Process
    %   This manipulator converts all of the CO2 in the connected phase to
    %   the according amount of pure carbon and oxygen.
    
    properties (SetAccess = protected, GetAccess = public)
        
    end
    
    
    methods
        function this = DummyBoschProcess(sName, oPhase)
            this@matter.manips.substance.flow(sName, oPhase);
        end
        
        function update(this)
%             atCallStack = dbstack;
%             sCallerName = atCallStack(2).name;
%             disp(['Manipulator update() called by ', sCallerName]);
%             keyboard(); 

            % Get the content of the phase
            afMassFlows = this.getTotalFlowRates();
            
            % Initialize the array we pass back to the phase once we're
            % done
            afPartialFlows = zeros(1, this.oPhase.oMT.iSubstances);
            
            % Abbreviating some of the variables to make code more legible
            afMolMass  = this.oPhase.oMT.afMolMass;
            tiN2I      = this.oPhase.oMT.tiN2I;
            
            % Getting the total CO2 mass in the phase
            fMassCO2 = afMassFlows(tiN2I.CO2);
            
            if ~(fMassCO2 < 1e-8)
                
                % Setting the carbon mass to the percentage of carbon in the
                % CO2 of the phase
                fMassC   = fMassCO2 * afMolMass(tiN2I.C)  / afMolMass(tiN2I.CO2);
                % Setting the oxygen mass to the percentage of oxygen in the
                % CO2 of the phase
                fMassO2  = fMassCO2 * afMolMass(tiN2I.O2) / afMolMass(tiN2I.CO2);
                
                % Now we can fill the arPartials array which indicates the mass
                % change in the phase affected by the manipulator. The CO2 mass
                % is negative, the carbon and oxygen masses are positive. This
                % means that effectively all CO2 is converted to oxygen and
                % carbon.
                afPartialFlows(tiN2I.CO2) = -1 * fMassCO2;
                afPartialFlows(tiN2I.C)   = fMassC;
                afPartialFlows(tiN2I.O2)  = fMassO2;
            end
            
            % Now we can call the parent update method and pass on the
            % afPartials variable. The last parameter indicates that the
            % values in afPartials are absolute masses, so within the
            % update method they are converted to flow rates. 
            update@matter.manips.substance.flow(this, afPartialFlows);
        end
    end
    
end

