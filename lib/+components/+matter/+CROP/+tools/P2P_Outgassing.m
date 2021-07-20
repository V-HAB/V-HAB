classdef P2P_Outgassing < matter.procs.p2ps.stationary
    % This P2P processor determines the theoretical mass of a gas component in the gas
    % phase above a solution at equilibrium, influenced by the gas concentration inside the
    % solution. In case of a discrepancy between the calculated mass value
    % and the current actual mass concentration in the gas phase, the P2P adjusts
    % the flow rate between solution and gas phase.
    
    properties (SetAccess = protected, GetAccess = public)
        
        fLastExecp2p = 0;
        
        % Define how much gas is to be extracted (it is set to 1 in the constructor function)
        arExtractPartials;
        
        % input substance
        sSubstance;
        
        oTankSolution;
        opH_Manip;
    end
    
    methods
        function this = P2P_Outgassing(oStore, sName, sPhaseIn, sPhaseOut, sSubstance)
            this@matter.procs.p2ps.stationary(oStore, sName, sPhaseIn, sPhaseOut);
           
            this.sSubstance = sSubstance;
            % The extracting percentage of the gas is set to 1 since
            % it is the only substance to be extracted. If another gas needs to be extracted,
            % simply use this P2P again with the corresponding substance. 
            this.arExtractPartials = zeros(1, this.oMT.iSubstances);
            
            this.arExtractPartials(this.oMT.tiN2I.(this.sSubstance)) = 1;
            
            this.oTankSolution = this.oStore.oContainer.toStores.CROP_Tank.toPhases.TankSolution;
            this.opH_Manip = this.oStore.oContainer.toStores.CROP_Tank.toPhases.Aeration.toManips.substance;
        end
    end
        
    methods (Access = protected)
        function update(this)
            % Current temperature of the solution
            fCurrentTemp = this.oIn.oPhase.fTemperature;
            
            %current concentration of OH_minus in the solution
            fCurrentOH = 10^( - ( 14 -  this.opH_Manip.fpH));
            
            % current concentration of NH3 in the solution in mol/L
            fCurrentNH3aq = this.oIn.oPhase.afMass(this.oMT.tiN2I.NH3) / (this.oMT.afMolarMass(this.oMT.tiN2I.NH3) *...
                                this.oIn.oPhase.fVolume);
                            
            % current concentration of NH4 in the solution in mol/L
            fCurrentNH4aq = this.oIn.oPhase.afMass(this.oMT.tiN2I.NH4) / (this.oMT.afMolarMass(this.oMT.tiN2I.NH4) *...
                                this.oIn.oPhase.fVolume);
                            
            % Depending on the gas in question, call the corresponding
            % function to calculate the theoretical gas concentration in the gas 
            % phase above the solution in mol/L. NH3 calculation depends on CO2 calculation. 
            % In this thesis, only NH3 and CO2 are considered. Other gases can be added
            % in the future.
            if strcmp(this.sSubstance, 'NH3')
                [fCO2_gas_concentration, fH_cc_CO2] = components.matter.CROP.tools.CO2_Outgassing(fCurrentTemp, this.oOut.oPhase.afPP(this.oMT.tiN2I.NH3));
                fgas_concentration_mol = components.matter.CROP.tools.NH3_Outgassing(fCurrentTemp, fCurrentOH, ...
                                    fCurrentNH3aq, fCurrentNH4aq, fCO2_gas_concentration, fH_cc_CO2);
            elseif strcmp(this.sSubstance, 'CO2')
                [fgas_concentration_mol, ~] = components.matter.CROP.tools.CO2_Outgassing(fCurrentTemp, this.oOut.oPhase.afPP(this.oMT.tiN2I.CO2));
            end
            
            %convert molar concentration to mass
            fgas_mass = fgas_concentration_mol * this.oMT.afMolarMass(this.oMT.tiN2I.(this.sSubstance)) * this.oIn.oPhase.fVolume;
   
            % If the current gas mass in the gas phase above the solution is larger than fgas_mass,
            % the difference between those two values gets transferred out of the solution into the gas phase. 
            % Otherwise the mass flow rate is assumed to remain zero.
            fPhaseGasMass = this.oOut.oPhase.afMass(this.oMT.tiN2I.(this.sSubstance));
            fCurrentPhaseMassChange = this.oIn.oPhase.afCurrentTotalInOuts(this.oMT.tiN2I.(this.sSubstance)) - this.fFlowRate;
            
            % P2P defined from liquid to gas
            fFlowRate = (fPhaseGasMass - fgas_mass) / (2 * this.oStore.oContainer.fTimeStep);
            
            if fFlowRate > 0
                if fFlowRate < -fCurrentPhaseMassChange
                    fFlowRate = 0;
                else
                    fFlowRate = fFlowRate + fCurrentPhaseMassChange;
                end
            end
            
            % Extract the substance out of the "this.oIn.oPhase" according
            % to the mass flow rate
            this.setMatterProperties(fFlowRate, this.arExtractPartials);
            
            this.fLastExecp2p = this.oTimer.fTime;
            
        end
    end
end
    
