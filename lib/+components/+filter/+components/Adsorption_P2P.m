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
            % Instead of using the partial pressure of the flow phase, use the
            % total pressure of the the flow phase but the composition of the
            % ingoing flow to calculate the partial pressure of the
            % inflowing matter. Otherwise the partial pressure in the cell
            % will oscillate because it first has to increase before it can
            % absorb something
            afCurrentInFlows = zeros(1,this.oMT.iSubstances);
            for iExme = 1:this.oIn.oPhase.iProcsEXME
                if ~this.oIn.oPhase.coProcsEXME{iExme}.bFlowIsAProcP2P
                    fFlowRate = (this.oIn.oPhase.coProcsEXME{iExme}.iSign * this.oIn.oPhase.coProcsEXME{iExme}.oFlow.fFlowRate);
                    if fFlowRate > 0
                        afCurrentInFlows = afCurrentInFlows + (fFlowRate .* this.oIn.oPhase.coProcsEXME{iExme}.oFlow.arPartialMass);
                    end
                end
            end
            afCurrentMolsIn     = (afCurrentInFlows ./ this.oMT.afMolarMass);
            arFractions         = afCurrentMolsIn ./ sum(afCurrentMolsIn);
            afPP                = arFractions .* this.oIn.oPhase.fPressure;
            afPP(isnan(afPP))   = this.oIn.oPhase.afPP(isnan(afPP));
            
            % TO DO: make percentage before recalculation adaptive
            if (max(abs(this.afMassOld - afMass) - (1e-2 * this.afMassOld)) > 0) ||...
                (max(abs(this.afPPOld - afPP)    - (1e-2 * this.afPPOld))   > 0) ||...
                abs(this.fTemperatureOld - fTemperature) > (1e-2 * this.fTemperatureOld)
                
                % Iteration in case of desorption because that would
                % increase the available partial pressure within the phase
                iCounter = 0;
                while iCounter < 2
                    mfEquilibriumLoading = this.oMT.calculateEquilibriumLoading(afMass, afPP, fTemperature);

                    mfCurrentLoading = afMass;
                    % the absorber material is not considered loading ;)
                    mfCurrentLoading(this.oMT.abAbsorber) = 0;

                    % According to RT_BA 13_15 equation 3.31 the change in
                    % loading over time is the (equilibrium loading - actual
                    % loading) times a factor: dq/dt = k(q*-q)
                    %
                    % q here is the current loading which changes over time
                    % q* is the equilibrium loading
                    % q0 is the current loading at the beginning of this step
                    %
                    % This differential equation has the solution: 
                    % q* - (q* - q0)e^(-kt) This can be used to calculate the
                    % new loading for the given timestep and current loading
                    % assuming the equilibrium loading remains constant
                    mfNewLoading = mfEquilibriumLoading - ((mfEquilibriumLoading - mfCurrentLoading).*exp(-this.mfMassTransferCoefficient.*fTimeStep));
                    mfFlowRates = (mfNewLoading - mfCurrentLoading)/fTimeStep;

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
                    
                    if fDesorptionFlowRate == 0
                        break
                    else
                        afCurrentInFlowsNew     = afCurrentInFlows - mfFlowRatesDesorption;
                        afCurrentMolsIn         = (afCurrentInFlowsNew ./ this.oMT.afMolarMass);
                        arFractions             = afCurrentMolsIn ./ sum(afCurrentMolsIn);
                        afPP                    = arFractions .* this.oIn.oPhase.fPressure;
                        afPP(isnan(afPP))       = this.oIn.oPhase.afPP(isnan(afPP));
                        iCounter = iCounter + 1;
                    end
                end
                
                this.afMassOld          = afMass;
                this.afPPOld            = afPP;
                this.fTemperatureOld    = fTemperature;
            else
                mfFlowRatesAdsorption =  this.fFlowRate .* this.arPartialMass;
                mfFlowRatesDesorption = -this.oStore.toProcsP2P.(['DesorptionProcessor',this.sCell]).fFlowRate .* this.oStore.toProcsP2P.(['DesorptionProcessor',this.sCell]).arPartialMass;
            end
            
            afAvailableMass = afInFlow.*fTimeStep + this.oIn.oPhase.afMass;
            afAvailableMass(afAvailableMass < 0) = 0;
            
            fP2P_MassChange = fTimeStep .* mfFlowRatesAdsorption;
            
            fP2P_MassChange(fP2P_MassChange > afAvailableMass) = afAvailableMass(fP2P_MassChange > afAvailableMass);
            
            afPartialFlowRates = fP2P_MassChange./fTimeStep;
            
            fFlowRate = sum(afPartialFlowRates);
            if fFlowRate ~= 0
                arPartials = afPartialFlowRates ./ fFlowRate;
            else
                arPartials = zeros(1,this.oMT.iSubstances);
            end
            
            this.setMatterProperties(fFlowRate, arPartials);
            
            mfFlowRates = afPartialFlowRates + mfFlowRatesDesorption;
            
            this.fAdsorptionHeatFlow = - sum(mfFlowRates.*this.oMT.afMolarMass.*this.mfAbsorptionEnthalpy);
            this.oStore.oContainer.tThermalNetwork.mfAdsorptionHeatFlow(this.iCell) = this.fAdsorptionHeatFlow;
            this.oStore.oContainer.tMassNetwork.mfAdsorptionFlowRate(this.iCell) = sum(mfFlowRates);
        end
    end
end
