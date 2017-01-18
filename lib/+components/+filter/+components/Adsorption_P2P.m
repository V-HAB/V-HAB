classdef Adsorption_P2P < matter.procs.p2ps.flow & event.source
    
    
    
    properties
        mfMassTransferCoefficient;
        
        sCell;
        iCell;
        
        fAdsorptionHeatFlow = 0;
        
        afMassOld;
        afPPOld;
        fTemperatureOld;
        
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
        end
        
        function update(this, ~)
            
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
                % (equilibrium loading - actual loading) times a factor
                mfFlowRates = this.mfMassTransferCoefficient .* (mfQ_eq - mfQ);

                mfFlowRatesAdsorption = zeros(1,this.oMT.iSubstances);
                mfFlowRatesDesorption = zeros(1,this.oMT.iSubstances);
                mfFlowRatesAdsorption(mfFlowRates > 0) = mfFlowRates(mfFlowRates > 0);
                mfFlowRatesDesorption(mfFlowRates < 0) = mfFlowRates(mfFlowRates < 0);

                fAdsorptionFlowRate                             = sum(mfFlowRatesAdsorption);
                arPartialsAdsorption                            = zeros(1,this.oMT.iSubstances);
                arPartialsAdsorption(mfFlowRatesAdsorption~=0)  = mfFlowRatesAdsorption(mfFlowRatesAdsorption~=0)./fAdsorptionFlowRate;

                fDesorptionFlowRate                             = -sum(mfFlowRatesDesorption);
                arPartialsDesorption                            = zeros(1,this.oMT.iSubstances);
                arPartialsDesorption(mfFlowRatesDesorption~=0)  = abs(mfFlowRatesDesorption(mfFlowRatesDesorption~=0)./fDesorptionFlowRate);

                csAbsorbers = this.oMT.csSubstances(((afMass ~= 0) .* this.oMT.abAbsorber) ~= 0);

                fAbsorberMass = sum(afMass(this.oMT.abAbsorber));
                mfAbsorptionEnthalpy = zeros(1,this.oMT.iSubstances);
                for iAbsorber = 1:length(csAbsorbers)
                    rAbsorberMassRatio = afMass(this.oMT.tiN2I.(csAbsorbers{iAbsorber}))/fAbsorberMass;
                    mfAbsorptionEnthalpy = mfAbsorptionEnthalpy + rAbsorberMassRatio * this.oMT.ttxMatter.(csAbsorbers{iAbsorber}).tAbsorberParameters.mfAbsorptionEnthalpy;
                end

                % Positive values in mfFlowRates mean something is beeing
                % absorbed and the Absorption Enthalpy is stored with a
                % negative value if heat is generated. Therefore the overall
                % result has to be mutliplied with -1
                this.fAdsorptionHeatFlow = - sum(mfFlowRates.*this.oMT.afMolarMass.*mfAbsorptionEnthalpy);
                this.oStore.oContainer.mfAdsorptionHeatFlow(this.iCell) = this.fAdsorptionHeatFlow;
                this.oStore.oContainer.mfAdsorptionFlowRate(this.iCell) = sum(mfFlowRates);

                this.oStore.toProcsP2P.(['DesorptionProcessor',this.sCell]).setMatterProperties(fDesorptionFlowRate, arPartialsDesorption);

                this.setMatterProperties(fAdsorptionFlowRate, arPartialsAdsorption);
                
                this.afMassOld          = afMass;
                this.afPPOld            = afPP;
                this.fTemperatureOld    = fTemperature;
            end
        end
    end
end
