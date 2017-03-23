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
        
        mfFlowRatesProp;
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
            
            this.mfFlowRatesProp = zeros(1,this.oMT.iSubstances);
            
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
            
        end
        
        function ManualUpdateFinal(this, ~)
            
            mfFlowRatesAdsorption = zeros(1,this.oMT.iSubstances);
            mfFlowRatesDesorption = zeros(1,this.oMT.iSubstances);
            mfFlowRatesAdsorption(this.mfFlowRatesProp > 0) = this.mfFlowRatesProp(this.mfFlowRatesProp > 0);
            mfFlowRatesDesorption(this.mfFlowRatesProp < 0) = this.mfFlowRatesProp(this.mfFlowRatesProp < 0);
            
            fDesorptionFlowRate                             = -sum(mfFlowRatesDesorption);
            arPartialsDesorption                            = zeros(1,this.oMT.iSubstances);
            arPartialsDesorption(mfFlowRatesDesorption~=0)  = abs(mfFlowRatesDesorption(mfFlowRatesDesorption~=0)./fDesorptionFlowRate);

            fAdsorptionFlowRate                             = sum(mfFlowRatesAdsorption);
            arPartialsAdsorption                            = zeros(1,this.oMT.iSubstances);
            arPartialsAdsorption(mfFlowRatesAdsorption~=0)  = abs(mfFlowRatesAdsorption(mfFlowRatesAdsorption~=0)./fAdsorptionFlowRate);
            
            this.oStore.toProcsP2P.(['DesorptionProcessor',this.sCell]).setMatterProperties(fDesorptionFlowRate, arPartialsDesorption);
            
            this.setMatterProperties(fAdsorptionFlowRate, arPartialsAdsorption);
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
            fTemperature    = this.oIn.oPhase.fTemperature;
            % Instead of using the partial pressure of the flow phase, use the
            % total pressure of the the flow phase but the composition of the
            % ingoing flow to calculate the partial pressure of the
            % inflowing matter. Otherwise the partial pressure in the cell
            % will oscillate because it first has to increase before it can
            % absorb something
            afCurrentMols       = (this.oIn.oPhase.afMass./this.oMT.afMolarMass);
            afCurrentMolsIn     = (afInFlow ./ this.oMT.afMolarMass);
            
            arFractions         = (((afCurrentMolsIn) * fTimeStep) + afCurrentMols) ./ (sum(afCurrentMolsIn) * fTimeStep + sum(afCurrentMols));

            % workaround because the pressure calculation is not perfect at
            % the moment
            afPP                = arFractions .* 1e5; %this.oIn.oPhase.fPressure;
            
            % very small (less than one milli pascal) partial pressures are rounded to zero 
            afPP = tools.round.prec(afPP,   3);
            
            [ ~, mfLinearConstant ] = this.oMT.calculateEquilibriumLoading(afMass, afPP, fTemperature);
            
            mfLinearConstant(isnan(mfLinearConstant)) = 0;
            if all(mfLinearConstant == 0)
                return
            end
            
            mfCurrentLoading = afMass;
            % the absorber material is not considered loading ;)
            mfCurrentLoading(this.oMT.abAbsorber) = 0;
            
            mfCurrentFlowMass = this.oIn.oPhase.afMass + afInFlow .*fTimeStep;
            
            % Maximum number of internal steps, should not be used often
            iInternalSteps = 200;
            
            % Set so the logic will require 200 steps maximum!
            fMinInternalStep = fTimeStep / iInternalSteps;
            
            mfFlowRates         = zeros(iInternalSteps, this.oMT.iSubstances);
            mfTimeStepInternal  = zeros(iInternalSteps, this.oMT.iSubstances);
%             fTimeStepInternal = fTimeStep / iInternalSteps;
            
%             for iInternalStep = 1:iInternalSteps

            fExternalTime = this.oTimer.fTime + fTimeStep;
            fInternalTime = this.oTimer.fTime;
            iInternalStep = 1;
            while fInternalTime < fExternalTime
                
                fTimeStepInternal = abs( log( 1 + (0.2 * mfCurrentLoading ./ ((mfLinearConstant .* afPP) - mfCurrentLoading))) ./ this.mfMassTransferCoefficient );
                fTimeStepInternal(isnan(fTimeStepInternal)) = 0;
                if all(fTimeStepInternal == 0)
                    % In this case nothing will flow and we can simply use
                    % one time step to calculate the P2P
                    fTimeStepInternal = fTimeStep;
                end
                fTimeStepInternal = min(fTimeStepInternal(fTimeStepInternal > 0));
                
                if (fInternalTime + fTimeStepInternal) > fExternalTime
                    fTimeStepInternal = fExternalTime - fInternalTime;
                end
                
                if fTimeStepInternal < fMinInternalStep
                    fTimeStepInternal = fMinInternalStep;
                elseif (fInternalTime + fTimeStepInternal) > fExternalTime
                    fTimeStepInternal = fExternalTime - fInternalTime;
                end
                
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
                mfNewLoading = (mfLinearConstant .* afPP) - (((mfLinearConstant .* afPP) - mfCurrentLoading).*exp(-this.mfMassTransferCoefficient.*fTimeStepInternal));
                mfFlowRates(iInternalStep,:) = (mfNewLoading - mfCurrentLoading)/fTimeStepInternal;
                
                mfMassChange = mfFlowRates(iInternalStep,:) .* fTimeStepInternal;
                mfMassChange(mfCurrentFlowMass < mfMassChange) = mfCurrentFlowMass(mfCurrentFlowMass < mfMassChange);
                
                mfAbsorption = zeros(1,this.oMT.iSubstances);
                mfAbsorption(mfMassChange < 0) = -mfMassChange(mfMassChange < 0);
                mfMassChange(mfCurrentLoading < mfAbsorption) = -mfCurrentLoading(mfCurrentLoading < mfAbsorption);
                
                mfFlowRates(iInternalStep,:) = mfMassChange ./ fTimeStepInternal;
                
                mfCurrentLoading    = mfCurrentLoading + mfMassChange;
                mfCurrentFlowMass   = mfCurrentFlowMass - mfMassChange;
                afCurrentMols       = (mfCurrentFlowMass ./this.oMT.afMolarMass);
                
                afEffectiveMolsIn   = ( - mfFlowRates(iInternalStep,:)) ./ this.oMT.afMolarMass;

                arFractions         = (((afEffectiveMolsIn) * fTimeStepInternal) + afCurrentMols) ./ (sum(afEffectiveMolsIn) * fTimeStepInternal + sum(afCurrentMols));
                
                if any(isnan(arFractions))
                    iInternalStep = iInternalStep + 1;
                    break
                else
                    afPP                = arFractions .* 1e5; %this.oIn.oPhase.fPressure;
                    afPP(afPP < 0)      = 0;
                end
                
                mfTimeStepInternal(iInternalStep, :) = fTimeStepInternal;
                fInternalTime = fInternalTime + fTimeStepInternal;
                iInternalStep = iInternalStep + 1;
            end
            iInternalStep = iInternalStep - 1;
            
            this.mfFlowRatesProp = sum(mfFlowRates(1:iInternalStep,:) .* mfTimeStepInternal(1:iInternalStep,:),1)./fTimeStep;
            
            if any(isnan(this.mfFlowRatesProp))
                keyboard()
            end
            
            afNewMassFlow       = this.oIn.oPhase.afMass - (this.mfFlowRatesProp * fTimeStep) + afInFlow * fTimeStep;
            
            abNegativeFlow = afNewMassFlow < 0;
            this.mfFlowRatesProp(abNegativeFlow) = (this.oIn.oPhase.afMass(abNegativeFlow) / fTimeStep) + afInFlow(abNegativeFlow);
            
            afNewMassAbsorber   = this.oOut.oPhase.afMass + (this.mfFlowRatesProp * fTimeStep);
            
            abNegativeAbsorber = afNewMassAbsorber < 0;
            this.mfFlowRatesProp(abNegativeAbsorber) = (this.oOut.oPhase.afMass(abNegativeAbsorber) / fTimeStep);
            
            this.fAdsorptionHeatFlow = - sum((this.mfFlowRatesProp ./ this.oMT.afMolarMass) .* this.mfAbsorptionEnthalpy);
            this.oStore.oContainer.tThermalNetwork.mfAdsorptionHeatFlow(this.iCell) = 0.5*this.fAdsorptionHeatFlow; % assumes that 50% of the heat is lost to env.
            this.oStore.oContainer.tMassNetwork.mfAdsorptionFlowRate(this.iCell) = sum(this.mfFlowRatesProp);
        end
    end
end
