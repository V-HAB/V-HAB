classdef Adsorption_P2P < matter.procs.p2ps.flow & event.source
    % TO DO: Descriptiom, plus comments for properties
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
        
        mbIgnoreSmallPressures;
        
        iInFlowTick = -100;
        afPartialInFlows;
        
        iAveraging = 10;
        
        iPropEntry = 1;
        
        mfFlows;
        
        bUseBufferPhase = false;
    end
    
    properties (SetAccess = protected, GetAccess = public)
        fLastExec = 0;
        fTimeStep;
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
            this.mfFlows     = zeros(1,this.oMT.iSubstances);
            this.fTemperatureOld = 0;
            
            this.mfFlowRatesProp = zeros(this.iAveraging, this.oMT.iSubstances);
            
            afMass = this.oOut.oPhase.afMass;
            csAbsorbers = this.oMT.csSubstances(((afMass ~= 0) .* this.oMT.abAbsorber) ~= 0);

            fAbsorberMass = sum(afMass(this.oMT.abAbsorber));
            mfAbsorptionEnthalpyHelper = zeros(1,this.oMT.iSubstances);
            for iAbsorber = 1:length(csAbsorbers)
                rAbsorberMassRatio = afMass(this.oMT.tiN2I.(csAbsorbers{iAbsorber}))/fAbsorberMass;
                mfAbsorptionEnthalpyHelper = mfAbsorptionEnthalpyHelper + rAbsorberMassRatio * this.oMT.ttxMatter.(csAbsorbers{iAbsorber}).tAbsorberParameters.mfAbsorptionEnthalpy;
            end
            this.mfAbsorptionEnthalpy = mfAbsorptionEnthalpyHelper;

            this.mbIgnoreSmallPressures = true(1,this.oMT.iSubstances);
        end
        
        function update(~)
            
        end
        
        function calculateFilterRate(this, afInFlowRates, aarInPartials)
            
            afMassAbsorber          = this.oOut.oPhase.afMass;
            fTemperature            = this.oIn.oPhase.fTemperature;
            if ~isempty(this.oIn.oPhase.fVirtualPressure)
                fPressure = this.oIn.oPhase.fVirtualPressure;
            else
                fPressure = this.oIn.oPhase.fPressure;
            end
            if fPressure < 0
                fPressure = 0;
            end
            % Instead of using the partial pressure of the flow phase, use the
            % total pressure of the the flow phase but the composition of the
            % ingoing flow to calculate the partial pressure of the
            % inflowing matter. Otherwise the partial pressure in the cell
            % will oscillate because it first has to increase before it can
            % absorb something
            if this.iInFlowTick ~= this.oTimer.iTick
                this.mfFlowRatesProp = zeros(this.iAveraging, this.oMT.iSubstances);
            end
            
            if this.bUseBufferPhase
                % if there is no in flow, assume the partial pressure from
                % the mass phase of this filter as the correct value for
                % the partial pressures
                afPP = zeros(1, this.oMT.iSubstances);
                
                afMassAbsorber(afMassAbsorber < 1e-5) = 0;
                
                % For this case there are no minimum outflows, there would
                % be minimum partial pressures that can be reach, e.g.
                % maximum time steps
                this.afPartialInFlows = zeros(1,this.oMT.iSubstances);
            else
                if ~(isempty(afInFlowRates) || all(sum(aarInPartials) == 0))
                    this.iInFlowTick = this.oTimer.iTick;
                    this.afPartialInFlows = sum((afInFlowRates .* aarInPartials),1);
                else
                    this.afPartialInFlows = zeros(1,this.oMT.iSubstances);
                end
%                 afCurrentMolsIn     = (this.afPartialInFlows ./ this.oMT.afMolarMass);
%                 arFractions         = afCurrentMolsIn ./ sum(afCurrentMolsIn);
%                 afPP                = arFractions .*  fPressure;

                afPP                = this.oIn.oPhase.afPP;
                afPP((afPP < 2.5) & this.mbIgnoreSmallPressures) = 0;
            end
            
            [ mfEquilibriumLoading , mfLinearizationConstant ] = this.oMT.calculateEquilibriumLoading(afMassAbsorber, afPP, fTemperature);

            mfCurrentLoading = afMassAbsorber;
            % the absorber material is not considered loading ;)
            mfCurrentLoading(this.oMT.abAbsorber) = 0;


            % dq/dt = k(q*-q)
            % Here the solution to this differential equation is used:
            % q(t + dt) = q* - (q* - q(t)) * exp( - k * dt)
            % Here we assume that a fixed time step of 1 s is used (as it
            % is diffcult to calculate the future correct V-HAB time step
            % for this...
            mfFlowRates = (mfEquilibriumLoading - (mfEquilibriumLoading - mfCurrentLoading) .* exp(- this.mfMassTransferCoefficient) - mfCurrentLoading);
            
            mfFlowRatesAdsorption = zeros(1,this.oMT.iSubstances);
            mfFlowRatesDesorption = zeros(1,this.oMT.iSubstances);
            mfFlowRatesAdsorption(mfFlowRates > 0) = mfFlowRates(mfFlowRates > 0);
            mfFlowRatesDesorption(mfFlowRates < 0) = mfFlowRates(mfFlowRates < 0);
            
            fDesorptionFlowRate                             = -sum(mfFlowRatesDesorption);
            arPartialsDesorption                            = zeros(1,this.oMT.iSubstances);
            arPartialsDesorption(mfFlowRatesDesorption~=0)  = abs(mfFlowRatesDesorption(mfFlowRatesDesorption~=0)./sum(mfFlowRatesDesorption));

            mfFlowRatesDesorption = fDesorptionFlowRate .* arPartialsDesorption;
            
            fAdsorptionFlowRate   	= sum(mfFlowRatesAdsorption);
            arPartialsAdsorption    = zeros(1,this.oMT.iSubstances);
            arPartialsAdsorption(mfFlowRatesAdsorption~=0)  = abs(mfFlowRatesAdsorption(mfFlowRatesAdsorption~=0)./sum(mfFlowRatesAdsorption));
            
            mfFlowRatesAdsorption = fAdsorptionFlowRate .* arPartialsAdsorption;
            
            if ~this.bUseBufferPhase
                % in case we are not currently desorbing we assume that
                % this represents a gas flow node and limit the flows
                % accordingly
                afMinPP = mfCurrentLoading ./ mfLinearizationConstant;
                afMinPP(isnan(afMinPP)) = 0;
                afMinPP(isinf(afMinPP)) = 0;

                afMinMolarFraction = afMinPP ./ fPressure;
                afMinMassFraction = afMinMolarFraction .* this.oMT.afMolarMass;
                
                afMinOutFlows = sum(this.afPartialInFlows) .* afMinMassFraction;
                
                abLimitDesorpFlows = afMinOutFlows < mfFlowRatesDesorption;
                mfFlowRatesDesorption(abLimitDesorpFlows) = afMinOutFlows(abLimitDesorpFlows);

                abLimitMinOutFlows = (afMinOutFlows > this.afPartialInFlows);
                afMinOutFlows(abLimitMinOutFlows) = this.afPartialInFlows(abLimitMinOutFlows);
                
                abLimitFlows = ((this.afPartialInFlows - mfFlowRatesAdsorption) < afMinOutFlows);
                afMaxAbsorberFlows = this.afPartialInFlows - afMinOutFlows;
                mfFlowRatesAdsorption(abLimitFlows) = afMaxAbsorberFlows(abLimitFlows);

                abLimitFlows = (mfFlowRatesAdsorption > this.afPartialInFlows);
                mfFlowRatesAdsorption(abLimitFlows) = this.afPartialInFlows(abLimitFlows);
            end
            
            
            fDesorptionFlowRate                             = sum(mfFlowRatesDesorption);
            arPartialsDesorption                            = zeros(1,this.oMT.iSubstances);
            arPartialsDesorption(mfFlowRatesDesorption~=0)  = abs(mfFlowRatesDesorption(mfFlowRatesDesorption~=0)./sum(mfFlowRatesDesorption));

            arPartialsAdsorption    = zeros(1,this.oMT.iSubstances);
            if this.bUseBufferPhase
                % this was implemented to avoid very small time steps
                % during initialization. The error introduced from this
                % assumption should be very small
                fAdsorptionFlowRate     = 0;
            else
                fAdsorptionFlowRate   	= sum(mfFlowRatesAdsorption);
                arPartialsAdsorption(mfFlowRatesAdsorption~=0)  = abs(mfFlowRatesAdsorption(mfFlowRatesAdsorption~=0)./sum(mfFlowRatesAdsorption));
            end
            
            this.oStore.toProcsP2P.(['DesorptionProcessor',this.sCell]).setMatterProperties(fDesorptionFlowRate, arPartialsDesorption);
            
            % exothermic reaction have a negative enthalpy by definition,
            % therefore we have to multiply the equation with -1 to have a
            % positive heat flow for positive flowrates
            mfFlowRates = mfFlowRatesAdsorption - mfFlowRatesDesorption;
            this.fAdsorptionHeatFlow = - sum((mfFlowRates ./ this.oMT.afMolarMass) .* this.mfAbsorptionEnthalpy);
            % set heatflow to a heat source
            % this.oStore.oContainer.tThermalNetwork.mfAdsorptionHeatFlow(this.iCell) = this.fAdsorptionHeatFlow;
            
            % sets the heat flow to the absorber capacity
            this.oOut.oPhase.oCapacity.toHeatSources.(['AbsorberHeatSource_', num2str(this.iCell)]).setHeatFlow(this.fAdsorptionHeatFlow)
            
            this.setMatterProperties(fAdsorptionFlowRate, arPartialsAdsorption);
            
            this.mfFlows = mfFlowRatesAdsorption - mfFlowRatesDesorption;
            this.mfFlowRatesProp(this.iPropEntry, :) = this.mfFlows;
            this.iPropEntry = this.iPropEntry + 1;
            if this.iPropEntry > this.iAveraging
                this.iPropEntry = 1;
            end
            this.fLastExec = this.oTimer.fTime;
        end
        
        
        
        
        
        function ManualUpdate(this, fTimeStep)
            this.fTimeStep = fTimeStep;
            
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
            % afPP                = arFractions .* 1e5; %fPressure;
            
            afPP = this.oIn.oPhase.afPP;
            
            afPP((afPP < 2.5) & this.mbIgnoreSmallPressures) = 0;

            [ ~, mfLinearConstant ] = this.oMT.calculateEquilibriumLoading(afMass, afPP, fTemperature);
            
            mfLinearConstant(isnan(mfLinearConstant)) = 0;
            
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
            % Additionally the influence of the inflow mass over this time
            % is considered by adding the current total in outs of the flow
            % phase in the calculation (has to be removed from the absorber
            % mass calculation) % + this.oIn.oPhase.afCurrentTotalInOuts * fTimeStep 
            mfNewFlowMass = (mfCurrentFlowMass + mfCurrentLoading .* (1 - exp(-this.mfMassTransferCoefficient.*this.fTimeStep)))...
                            ./ (1 + ((mfLinearConstant .* mfGasConstant .* fGasTemperature) / fGasVolume) .* (1 - exp(-this.mfMassTransferCoefficient.*this.fTimeStep)));
            %
            % If you want to understand what is happening, set a breakpoint
            % here and use the following outcommented code to generate a
            % plotting of the flow mass (of CO2 in this case, change CO2 to
            % the substance that is beeing absorbed in your case)
            % Note, that this calculation will never reach completly zero
            % for the mass of the substance that is beeing absorbed in the
            % flow, because that is not possible! This holds true even for
            % extremly large time steps (try changing fTS to see how
            % different time steps affect the calculation)
%             iSteps = 100;
%             fTS = 0.4;
%             mfFlowMass = zeros(iSteps+1,1);
%             mfAbsorberMass = zeros(iSteps+1,1);
%             mfFlowMass(1) = mfCurrentFlowMass(this.oMT.tiN2I.CO2);
%             mfAbsorberMass(1) = mfCurrentLoading(this.oMT.tiN2I.CO2);
%             for iStep = 1:iSteps
%                 mfFlowMass(iStep+1) = (mfFlowMass(iStep) + this.oIn.oPhase.afCurrentTotalInOuts(this.oMT.tiN2I.CO2) * fTimeStep + mfAbsorberMass(iStep) .* (1 - exp(-this.mfMassTransferCoefficient(this.oMT.tiN2I.CO2).*fTS)))...
%                             ./ (1 + ((mfLinearConstant(this.oMT.tiN2I.CO2) .* mfGasConstant(this.oMT.tiN2I.CO2) .* fGasTemperature) / fGasVolume) .* (1 - exp(-this.mfMassTransferCoefficient(this.oMT.tiN2I.CO2).*fTS)));
%                 mfAbsorberMass(iStep+1) = mfAbsorberMass(iStep) + (mfFlowMass(iStep) + (this.oIn.oPhase.afCurrentTotalInOuts(this.oMT.tiN2I.CO2) * fTimeStep) - mfFlowMass(iStep+1));
%             end
%             close all
%             plot(mfFlowMass)
%             hold on
%             plot(mfAbsorberMass)
%             legend('Flow Mass', 'Absorber Mass')
            

            % the mass change for the absorber then obviously has to be the
            % difference between the current and the new flow mass
            mfMassChangeAbsorber = mfCurrentFlowMass - mfNewFlowMass;
            % (this.oIn.oPhase.toProcsEXME.(['Inflow', this.sCell]).oFlow.fFlowRate .* this.oIn.oFlow.arPartialMass) * fTimeStep
            mfMassChangeAbsorber(mfLinearConstant == 0) = 0;
            
            this.mfFlowRatesProp = mfMassChangeAbsorber ./ this.fTimeStep;
            
            % exothermic reaction have a negative enthalpy by definition,
            % therefore we have to multiply the equation with -1 to have a
            % positive heat flow for positive flowrates
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
            
            try
                % try to set the adsorption heat flow to the thermal
                % solver, note this requires the parent system to have some
                % specific properties
                csCycle = {'One', 'Two'};
                oCapacity = this.oStore.oContainer.poCapacities(this.oStore.oContainer.tThermalNetwork.(['csNodes_Flow_Cycle',csCycle{this.oStore.oContainer.iCycleActive}]){this.iCell,1});
                oCapacity.oHeatSource.setPower(this.fAdsorptionHeatFlow + this.oStore.oContainer.tThermalNetwork.mfHeaterPower(this.iCell));
            catch
               % do nothing, no thermal solver heat source attached 
            end
            this.fLastExec = this.oTimer.fTime;
        end
    end
end
