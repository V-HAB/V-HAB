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
        
        fLastExec = 0;
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
        
        function ManualUpdateFinal(this, ~)
            
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
        end
        function update(this,~)
            
            fTimeStep = this.oTimer.fTime - this.fLastExec;
            if fTimeStep <= 0
                return
            end
            
            afMass          = this.oOut.oPhase.afMass;
            fTemperature    = this.oIn.oPhase.fTemperature;
            % Instead of using the partial pressure of the flow phase, use the
            % total pressure of the the flow phase but the composition of the
            % ingoing flow to calculate the partial pressure of the
            % inflowing matter. Otherwise the partial pressure in the cell
            % will oscillate because it first has to increase before it can
            % absorb something
            % afCurrentMols       = (this.oIn.oPhase.afMass./this.oMT.afMolarMass);
            % afCurrentMolsIn     = (afInFlow ./ this.oMT.afMolarMass);
            
            
            % arFractions         = (((afCurrentMolsIn) * fTimeStep) + afCurrentMols) ./ (sum(afCurrentMolsIn) * fTimeStep + sum(afCurrentMols));

            % workaround because the pressure calculation is not perfect at
            % the moment
            % afPP                = arFractions .* 1e5; %this.oIn.oPhase.fPressure;
            
            % test using only the current partial pressure
            afPP = this.oIn.oPhase.afPP;
            
            [ ~, mfLinearConstant ] = this.oMT.calculateEquilibriumLoading(afMass, afPP, fTemperature);
            
            mfLinearConstant(isnan(mfLinearConstant)) = 0;
            if all(mfLinearConstant == 0)
                return
            end
            
            mfCurrentLoading = afMass;
            % the absorber material is not considered loading ;)
            mfCurrentLoading(this.oMT.abAbsorber) = 0;
            
            mfCurrentFlowMass   = this.oIn.oPhase.afMass;
            mfGasConstant       = this.oMT.Const.fUniversalGas ./ this.oMT.afMolarMass;
            fGasTemperature     = this.oIn.oPhase.fTemperature;
            fGasVolume          = this.oIn.oPhase.fVolume;
            
            %% Derivation of used calculations
            % According to RT_BA 13_15 equation 3.31 the change in
            % loading over time is the (equilibrium loading - actual
            % loading) times a factor: dq/dt = k(q*-q)
            %
            % q here is the current loading which changes over time
            % q* is the equilibrium loading
            % q0 is the current loading at the beginning of this step
            %
            % This differential equation has the solution: 
            % q* - (q* - q0)e^(-kt) This can be used to calculate the               Eq I
            % new loading for the given timestep and current loading
            % assuming the equilibrium loading remains constant
            %
            % Now we want to limit the amount of mass that is absorbed to
            % get a realistic value. Because within one step, assuming the
            % partial pressure is constant, only a certain amount of mass
            % can be absorbed and the partial pressure will never reach
            % completly zero (because before that the equilibrium loading
            % q* will become smaller than the current loading)
            %
            % The mass in the gas phase of the absorbed substance at the
            % time t + delta_t can be written as:
            % m_gas(t + delta_t) = m_gas(t) - [m_abs(t + delta_t) - m_abs(t)]       Eq II
            % Since the mass that is added/removed from the absorber has to
            % be taken from the gas. The loading (q) calculated above can be
            % transformed into m_abs simply by multiplying it with the mass
            % of absorber material
            %
            % The following derivations will be done for CO2 as an example
            % but are also valied for any other gaseous substance beeing
            % absorbed
            %
            % By putting the equation I into equation II (using q* = K * p_CO2) we obtain:
            % m_gas(t + delta_t) = m_gas(t) + [K * p_CO2 - m_abs(t)]*[e^(-k_m * t) - 1];
            %
            % If we now include the fact that the partial pressure of CO2
            % is not constant, but rather that the actually transferred
            % mass will depend on the final mass of CO2 in the gas (as that
            % will decide the final equilibrium loading). By now replacing
            % p_CO2 with the ideal gas law for the final mass of gas we
            % obtain:
            %
            % m_gas(t + delta_t) = {m_gas(t) + m_abs(t) * [1- e^(-k_m * t)]} / ...
            %                      {1 + (K R T_gas / V_gas) * [1- e^(-k_m * t)]};
            %
            % This equation is now used to calculate the new mass of the
            % substance in the gas phase after the time step:
            mfNewFlowMass = (mfCurrentFlowMass + mfCurrentLoading .* (1 - exp(-this.mfMassTransferCoefficient.*fTimeStep)))...
                            ./ (1 + ((mfLinearConstant .* mfGasConstant .* fGasTemperature) / fGasVolume) .* (1 - exp(-this.mfMassTransferCoefficient.*fTimeStep)));
            %
            % Previous calculation
            % mfNewLoading = (mfLinearConstant .* afPP) - (((mfLinearConstant .* afPP) - mfCurrentLoading).*exp(-this.mfMassTransferCoefficient.*fTimeStep));

            % the mass change for the absorber then obviously has to be the
            % difference between the current and the new flow mass
            mfMassChangeAbsorber = mfCurrentFlowMass - mfNewFlowMass;
            
            this.mfFlowRatesProp = mfMassChangeAbsorber ./ fTimeStep;
            
            if any(isnan(this.mfFlowRatesProp))
                keyboard()
            end
            
            this.fAdsorptionHeatFlow = - sum((this.mfFlowRatesProp ./ this.oMT.afMolarMass) .* this.mfAbsorptionEnthalpy);
            this.oStore.oContainer.tThermalNetwork.mfAdsorptionHeatFlow(this.iCell) = this.fAdsorptionHeatFlow;
            this.oStore.oContainer.tMassNetwork.mfAdsorptionFlowRate(this.iCell) = sum(this.mfFlowRatesProp);
            
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
            
            this.fLastExec = this.oTimer.fTime;
        end
    end
end
