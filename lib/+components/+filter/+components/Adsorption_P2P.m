classdef Adsorption_P2P < matter.procs.p2ps.flow & event.source
    
    
    
    properties
        mfMassTransferCoefficient;
        
        sCell;
        iCell;
        
        fAdsorptionHeatFlow = 0;
        
        afMassOld;
        afPPOld;
        fTemperatureOld;
        
        mfAbsorptionEnthalpy;
    end
    
   
    
    methods
        
        %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%% Constructor %%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        function [this] = Adsorption_P2P(oStore, sName, sPhaseIn, sPhaseOut, mfMassTransferCoefficient)
            this@matter.procs.p2ps.flow(oStore, sName, sPhaseIn, sPhaseOut);
            
            this.mfMassTransferCoefficient = mfMassTransferCoefficient;
            
            this.sCell = this.sName(~isletter(this.sName));
            this.iCell = str2double(this.sCell(2:end));
            
            this.afMassOld   = zeros(1,this.oMT.iSubstances);
            this.afPPOld     = zeros(1,this.oMT.iSubstances);
            this.fTemperatureOld = 0;
            
            
            afMass = this.oOut.oPhase.afMass;
            csAbsorbers = this.oMT.csSubstances(((afMass ~= 0) .* this.oMT.abAbsorber) ~= 0);

            fAbsorberMass = sum(afMass(this.oMT.abAbsorber));
            mfAbsorptionEnthalpyHelper = zeros(1,this.oMT.iSubstances);
            for iAbsorber = 1:length(csAbsorbers)
                rAbsorberMassRatio = afMass(this.oMT.tiN2I.(csAbsorbers{iAbsorber}))/fAbsorberMass;
                mfAbsorptionEnthalpyHelper = mfAbsorptionEnthalpyHelper + rAbsorberMassRatio * this.oMT.ttxMatter.(csAbsorbers{iAbsorber}).tAbsorberParameters.mfAbsorptionEnthalpy;
            end
            this.mfAbsorptionEnthalpy = mfAbsorptionEnthalpyHelper;
        end
            
        
        function update(~)
            %Nope nothing happens here, it is manually controlled by the
            %CDRA solver...
        end
        function setFlowRateToZero(this, ~)
            % OK this is a workaround because within CDRA the flowrate
            % logic for desorption is not able to handle it if the
            % absorbers are still absorbing during the intended desorption
            % time ;)
            arPartials	= zeros(1,this.oMT.iSubstances);
            fFlowRate 	= 0;
            this.oStore.toProcsP2P.(['DesorptionProcessor',this.sCell]).setMatterProperties(fFlowRate, arPartials);
            this.setMatterProperties(fFlowRate, arPartials);
        end
        function ManualUpdate(this, fTimeStep, afInFlow)
            
            afMass          = this.oOut.oPhase.afMass;
            fTemperature    = this.oOut.oPhase.fTemperature;
            afPP            = this.oIn.oPhase.afPP;
            
            % TO DO: make percentage before recalculation adaptive
            if (max(abs(this.afMassOld - afMass) - (1e-2 * this.afMassOld)) > 0) ||...
                (max(abs(this.afPPOld - afPP)    - (1e-2 * this.afPPOld))   > 0) ||...
                abs(this.fTemperatureOld - fTemperature) > (1e-2 * this.fTemperatureOld)
                
                mfQ_eq = this.oMT.calculateEquilibriumLoading(this);

                mfQ = afMass;
                % the absorber material is not considered loading ;)
                mfQ(this.oMT.abAbsorber) = 0;

                % According to RT_BA 13_15 (TO DO: get original source)
                % equation 3.31 the change in loading over time is the
                % (equilibrium loading - actual loading) times a factor:
                % mfFlowRates = this.mfMassTransferCoefficient .* (mfQ_eq - mfQ);
                % which is a differential equation dq/dt = k(q*-q) which
                % has the solution: q* - (q* - q0)e^(-kt)
                % This can be used to calculate the new loading for the
                % given timestep and current loading assuming the
                % equilibrium loading remains constant
                mfQ_New = mfQ_eq - ((mfQ_eq - mfQ).*exp(-this.mfMassTransferCoefficient.*fTimeStep));
                mfFlowRates = (mfQ_New - mfQ)/fTimeStep;
                
                mfFlowRatesAdsorption = zeros(1,this.oMT.iSubstances);
                mfFlowRatesDesorption = zeros(1,this.oMT.iSubstances);
                mfFlowRatesAdsorption(mfFlowRates > 0) = mfFlowRates(mfFlowRates > 0);
                mfFlowRatesDesorption(mfFlowRates < 0) = mfFlowRates(mfFlowRates < 0);
                
                fDesorptionFlowRate                             = -sum(mfFlowRatesDesorption);
                arPartialsDesorption                            = zeros(1,this.oMT.iSubstances);
                arPartialsDesorption(mfFlowRatesDesorption~=0)  = abs(mfFlowRatesDesorption(mfFlowRatesDesorption~=0)./fDesorptionFlowRate);

                % Positive values in mfFlowRates mean something is beeing
                % absorbed and the Absorption Enthalpy is stored with a
                % negative value if heat is generated. Therefore the overall
                % result has to be mutliplied with -1

                this.oStore.toProcsP2P.(['DesorptionProcessor',this.sCell]).setMatterProperties(fDesorptionFlowRate, arPartialsDesorption);
                
                this.afMassOld          = afMass;
                this.afPPOld            = afPP;
                this.fTemperatureOld    = fTemperature;
            else
                mfFlowRatesAdsorption = (fTimeStep * this.fFlowRate) .* this.arPartialMass;
                mfFlowRatesDesorption = (fTimeStep * this.oStore.toProcsP2P.(['DesorptionProcessor',this.sCell]).fFlowRate) .* this.oStore.toProcsP2P.(['DesorptionProcessor',this.sCell]).arPartialMass;
            end
            
            afAvailableMass = afInFlow.*fTimeStep + this.oIn.oPhase.afMass;
            
            fP2P_MassChange = fTimeStep .* mfFlowRatesAdsorption;
            
            fP2P_MassChange(fP2P_MassChange > afAvailableMass) = afAvailableMass(fP2P_MassChange > afAvailableMass) ./ fTimeStep;
            
            afPartialFlowRates = fP2P_MassChange./fTimeStep;
            
            fFlowRate = sum(afPartialFlowRates);
            if fFlowRate ~= 0
                arPartials = afPartialFlowRates ./ fFlowRate;
            else
                arPartials = zeros(1,this.oMT.iSubstances);
            end
            
            this.setMatterProperties(fFlowRate, arPartials);
            
            mfFlowRates = afPartialFlowRates - mfFlowRatesDesorption;
            
            this.fAdsorptionHeatFlow = - sum(mfFlowRates.*this.oMT.afMolarMass.*this.mfAbsorptionEnthalpy);
            this.oStore.oContainer.tThermalNetwork.mfAdsorptionHeatFlow(this.iCell) = this.fAdsorptionHeatFlow;
            this.oStore.oContainer.tMassNetwork.mfAdsorptionFlowRate(this.iCell) = sum(mfFlowRates);
        end
    end
end
