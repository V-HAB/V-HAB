classdef Adsorption_P2P < matter.procs.p2ps.flow & event.source
    
    % TO DO: at the moment just empty to create the basic simulation
    % infrastructure for the new filter model
    
    properties
        mfMassTransferCoefficient;
        
        sCell;
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
            
            mfQ = this.oOut.oPhase.afMass;
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
            
            fDesorptionFlowRate                             = sum(mfFlowRatesDesorption);
            arPartialsDesorption                            = zeros(1,this.oMT.iSubstances);
            arPartialsDesorption(mfFlowRatesDesorption~=0)  = mfFlowRatesDesorption(mfFlowRatesDesorption~=0)./fDesorptionFlowRate;
            
            this.oStore.toProcsP2P.(['DesorptionProcessor',this.sCell]).setMatterProperties(fDesorptionFlowRate, arPartialsDesorption);
            
            this.setMatterProperties(fAdsorptionFlowRate, arPartialsAdsorption);
        end
    end
end
