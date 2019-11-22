classdef water_reaction_manual < matter.manips.substance.stationary
    %     process in the mebrane of the fuel cell
    %     depending on the amount of current H2 reacts with O2 to H2O
    %     after that the same amount of H2,H2Ogas goes into the cell
    
    properties (SetAccess = protected, GetAccess = public)
        
        fmnold=0;    % massenstrom wegen euler und so
        fLastExec=0;
        fin_H2=0;
        fTimeStep;
        FlowRateH2=0;
    end
    
    
    
    methods
        function this = water_reaction_manual(sName, oPhase)
            this@matter.manips.substance.stationary(sName, oPhase);
            
        end
        
        
        
        function update(this)
            
            
            %farady constant As/mol
            fFaraday=96485.3365;
            
            %get the current
            fI=this.oPhase.oStore.oContainer.fI;
            
            %calculate the resulting massflow [mol/sec]
            this.fin_H2=23*fI/2/fFaraday;
            
            %Initialize the array we pass back to the phase
            afPartialFlows = zeros(1, this.oPhase.oMT.iSubstances);
            
            % Abbreviating some of the variables to make code more legible
            afMolMass  = this.oPhase.oMT.afMolarMass;
            tiN2I      = this.oPhase.oMT.tiN2I;
            
            %calculate the other parts of the chemical reaktion [mol/sec]
            iN_H2O=this.fin_H2;
            iN_O2=iN_H2O/2;
            
            %convert molar flowrate to mass flowrate [mol/sec]->[kg/sec]
            fMassH2O=iN_H2O*afMolMass(tiN2I.H2O);
            fMassH2=this.fin_H2*afMolMass(tiN2I.H2);
            fMassO2=iN_O2*afMolMass(tiN2I.O2);
            
            %set the flowrates of the manip
            afPartialFlows(tiN2I.H2O) = fMassH2O;
            afPartialFlows(tiN2I.H2)   =-fMassH2;
            afPartialFlows(tiN2I.O2)  = -fMassO2;
            
            this.FlowRateH2=fMassH2;
            % Now we can call the parent update method and pass on the
            % afPartials variable. The last parameter indicates that the
            % values in afPartials are absolute masses, so within the
            % update method they are converted to flow rates.
            update@matter.manips.substance.stationary(this, afPartialFlows);
            
            %update Inner energy function, calutlate voltage function
            %and calculate current funktion
            this.oPhase.oStore.oContainer.calculate_inner_energy_change();
            %
            this.oPhase.oStore.oContainer.calculate_voltage();
            %
            this.oPhase.oStore.oContainer.calculate_current();
            
            this.oPhase.oStore.oContainer.deltaP()
            
        end
    end
    
end

