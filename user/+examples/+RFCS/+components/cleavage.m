classdef cleavage < matter.manips.substance.stationary
    %process in the absorber phase of the membrane where h2o reacts to h2
    %and o2
    
    
    properties (SetAccess = protected, GetAccess = public)
        
        
        fin_H2=0;
        fTimeStep;
        fMassH2=0;
        fMassH2O=0;
        fMassO2=0;
    end
    
    
    
    methods
        function this = cleavage(sName, oPhase)
            this@matter.manips.substance.stationary(sName, oPhase);
            
        end
    end
    methods (Access = protected)
        function update(this)
            
            
            %calculate the timestep
            this.fTimeStep = this.oTimer.fTime - this.fLastExec;
            if this.fTimeStep <= 0
                return
            end
            
            %farady constant As/mol
            fFaraday=96485.3365;
            %calculate the overall current
            fI=this.oPhase.oStore.oContainer.fI*this.oPhase.oStore.oContainer.Number_cells;
            
            %calculate the resulting molar flow
            this.fin_H2=fI/2/fFaraday;
            
            % Initialize the array we pass back to the phase once we're
            % done
            afPartialFlows = zeros(1, this.oPhase.oMT.iSubstances);
            
            % Abbreviating some of the variables to make code more legible
            afMolMass  = this.oPhase.oMT.afMolarMass;
            tiN2I      = this.oPhase.oMT.tiN2I;
            
            %calculate the other parts of the chemical reaktion
            iN_H2O=this.fin_H2;
            iN_O2=iN_H2O/2;
            
            %convert molar flowrate to mass flowrate
            this.fMassH2O=iN_H2O*afMolMass(tiN2I.H2O);
            this.fMassH2=this.fin_H2*afMolMass(tiN2I.H2);
            this.fMassO2=iN_O2*afMolMass(tiN2I.O2);
            
            %set the flowrates of the manip
            afPartialFlows(tiN2I.H2O) = -this.fMassH2O;
            afPartialFlows(tiN2I.H2)   =this.fMassH2;
            afPartialFlows(tiN2I.O2)  = this.fMassO2;
            
            % update method they are converted to flow rates.
            update@matter.manips.substance.stationary(this, afPartialFlows);
            
            %update Inner energy function, calutlate voltage function
            
            this.oPhase.oStore.oContainer.calculate_inner_energy_change();
            
            this.oPhase.oStore.oContainer.calculate_voltage();
            
            this.fLastExec = this.oTimer.fTime;
            
        end
    end
end

