classdef Adsorption_P2P < matter.procs.p2ps.flow & event.source
    
    
    
    properties
        mfMassTransferCoefficient;
        
        sCell;
        
        fHeatFlow = 0;
    end
    
   
    
    methods
        
        %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%% Constructor %%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        function [this] = Adsorption_P2P(oStore, sName, sPhaseIn, sPhaseOut, mfMassTransferCoefficient)
            this@matter.procs.p2ps.flow(oStore, sName, sPhaseIn, sPhaseOut);
            
            this.mfMassTransferCoefficient = mfMassTransferCoefficient;
            
            this.sCell = this.sName(~isletter(this.sName));
        end
        
        function update(this, ~)
            
            mfQ_eq = this.oMT.calculateEquilibriumLoading(this);
            
            afMass = this.oOut.oPhase.afMass;
            
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
            arPartialsDesorption(mfFlowRatesDesorption~=0)  = -1.*mfFlowRatesDesorption(mfFlowRatesDesorption~=0)./fDesorptionFlowRate;
            
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
            this.fHeatFlow = - sum(mfFlowRates.*this.oMT.afMolarMass.*mfAbsorptionEnthalpy);
            
            this.oStore.toProcsP2P.(['DesorptionProcessor',this.sCell]).setMatterProperties(fDesorptionFlowRate, arPartialsDesorption);
            
            this.setMatterProperties(fAdsorptionFlowRate, arPartialsAdsorption);
        end
    end
end
