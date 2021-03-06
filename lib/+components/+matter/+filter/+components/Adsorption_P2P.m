classdef Adsorption_P2P < matter.procs.p2ps.flow & event.source
    % This a P2P processor to model the uptake of gaseous substances (e.g.
    % CO2 and H2O) into an absorber bed of zeolite/amine. It uses the toth
    % equation, implemented in the matter table, to calculate the possible
    % equilibrium loading for the substances and then uses the linear
    % driving force (LDF) assumption to calculate the current adsorption or
    % desorption flowrate for the different substances. Since adsorption
    % and desorption can both take place at the same time for different
    % substances the adsorption P2P must be used in conjuction with a
    % desorption P2P. The full calculation for the flowrates takes place in
    % this P2P and the desorption flowrates are simply set from here for
    % the desorption P2P. This allows the modelling of an arbitrary number
    % of adsorbing and desorbing substances with only two P2Ps.
    %
    % The P2P is intended to be used in a discretized adsorber bed with
    % cell numbers for the different adsorption and desorption P2Ps using
    % gas flow nodes and the multi branch solver to dsicretize the adsorber
    % bed (see CDRA for an example)
    
    properties
        % Coefficient for the linear driving force of the substances, often
        % called k in literature
        mfMassTransferCoefficient; % [1/s]
        
        % String containing the current number of the numerical cell in
        % which this P2P is located. Necessary to address the correct
        % desorption processor
        sCell;
        % Integer containing the cell number
        iCell;
        
        % currently generated or consumed heat of adsorption
        fAdsorptionHeatFlow = 0;
        
        % Mass averaged value of the adsorption enthalpy (in case multiple
        % different adsorber substances are used in the same bed).
        % Otherwise it contains the adsorption enthalphy from the matter
        % table for the adsorber directly.
        mfAbsorptionEnthalpy;
        
        % partial inflowrates of all substances into the gas phase attached
        % to the adsorption P2P
        afPartialInFlows;
        
        % Boolean to decide if the P2P is currently desorbing or not, can
        % be set by the parent system for example to use simplified
        % calculations
        bDesorption = false;
        
        % To simplify the logging of the overall flowrates (and since they
        % are calculated anyway) we store both the adsorption and
        % desorption flows in this property
        mfFlowRates

    end
    
    methods
        
        %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%% Constructor %%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        function [this] = Adsorption_P2P(oStore, sName, sPhaseIn, sPhaseOut, mfMassTransferCoefficient)
            this@matter.procs.p2ps.flow(oStore, sName, sPhaseIn, sPhaseOut);
            
            this.mfMassTransferCoefficient = mfMassTransferCoefficient;
            
            % get the cell numbers from the name of the P2P
            this.sCell = this.sName(~isletter(this.sName));
            this.iCell = str2double(this.sCell(2:end));
            
            % get the adsorption enthalpies as mass averaged values in case
            % that multiple types of adsorbers are used
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
            % this must be here since the normal V-HAB logic tries to
            % call the update
        end
        
        function calculateFlowRate(this, afInFlowRates, aarInPartials, ~, ~)
            % This function is called by the multibranch solver, which also
            % calculates the inflowrates and partials (as the p2p flowrates
            % themselves should not be used for that we cannot use the gas
            % flow node values directly otherwise the P2P influences itself)
            
            % get the current absorber mass (just in case it changed, which
            % should normally not be the case). As well as temperature and
            % total pressure
            afMassAbsorber          = this.oOut.oPhase.afMass;
            fTemperature            = this.oIn.oPhase.fTemperature;
            if ~isempty(this.oIn.oPhase.fVirtualPressure)
                fPressure = this.oIn.oPhase.fVirtualPressure;
            else
                fPressure = this.oIn.oPhase.fPressure;
            end
            % should not happen, but just in case
            if fPressure < 0
                fPressure = 0;
            end
            
            if this.bDesorption
                % Since the simulation uses only gas flow nodes, the
                % pressure in the desorption case drops instantly. This is
                % not quite correct and therefore a calculation is
                % implemented here to simulate a slower decline of pressure
                % without the mass time step limitations
                fDesorptionTime = this.oTimer.fTime - this.oStore.oContainer.tTimeProperties.fLastCycleSwitch;
                
                fInitialPressure = 2e5;
                fParameter = 250;
                fDelayTime = 400;
                if fDesorptionTime < fDelayTime
                    fPressure = 2e5;
                    afPP = (this.oStore.oContainer.oAtmosphere.afPP ./ this.oStore.oContainer.oAtmosphere.fPressure) .* fPressure;
                elseif fDesorptionTime < 600+fDelayTime
                    fDesorptionTime = fDesorptionTime - fDelayTime;
                    fPressure = (fInitialPressure * fParameter) .* (1./(fParameter + fDesorptionTime) - ((1/(fParameter+600)) .* fDesorptionTime./600));
                    % if there is no in flow, assume the partial pressure from
                    % the mass phase of this filter as the correct value for
                    % the partial pressures
                    afPP = (this.oStore.oContainer.oAtmosphere.afPP ./ this.oStore.oContainer.oAtmosphere.fPressure) .* fPressure;
                else
                    afPP = zeros(1, this.oMT.iSubstances);
                end
                
                % similar to the small partial pressures, we also ignore
                % very small absorber masses to prevent osciallations
                afMassAbsorber(afMassAbsorber < 1e-5) = 0;
                
                % For this case there are no minimum outflows, there would
                % be minimum partial pressures that can be reach, e.g.
                % maximum time steps
                this.afPartialInFlows = zeros(1,this.oMT.iSubstances);
            else
            % Instead of using the partial pressure of the flow phase, use the
            % total pressure of the the flow phase but the composition of the
            % ingoing flow to calculate the partial pressure of the
            % inflowing matter. Otherwise the partial pressure in the cell
            % will oscillate because it first has to increase before it can
            % absorb something. The calculation is identical to the gas
            % flow node calculation and is based on the fact that partial
            % pressures are also molar fractions and that flowrates are
            % used here instead of masses is not an issue since
            % flowrate divided with flowrate results in the same as mass
            % dividided with mass in this case
                if ~(isempty(afInFlowRates) || all(sum(aarInPartials) == 0))
                    this.afPartialInFlows = sum((afInFlowRates .* aarInPartials),1);
                else
                    this.afPartialInFlows = zeros(1,this.oMT.iSubstances);
                end
                afCurrentMolsIn     = (this.afPartialInFlows ./ this.oMT.afMolarMass);
                arFractions         = afCurrentMolsIn ./ sum(afCurrentMolsIn);
                afPP                = arFractions .*  fPressure; 
            end
            
            % use the matter table to calculate the equilibrium loading and
            % the linearization constants using the toth equation
            [ mfEquilibriumLoading , mfLinearizationConstant ] = this.oMT.calculateEquilibriumLoading(afMassAbsorber, afPP, fTemperature);

            mfCurrentLoading = afMassAbsorber;
            % the absorber material is not considered loading ;)
            mfCurrentLoading(this.oMT.abAbsorber) = 0;

            %% Linear Driving Force (LDF) equation
            % dq/dt = k(q*-q)
            % Here the solution to this differential equation is used:
            % q(t + dt) = q* - (q* - q(t)) * exp( - k * dt)
            % Here we assume that a fixed time step of 1 s is used (as it
            % is diffcult to calculate the future correct V-HAB time step
            % for this...
            this.mfFlowRates = (mfEquilibriumLoading - (mfEquilibriumLoading - mfCurrentLoading) .* exp(- this.mfMassTransferCoefficient) - mfCurrentLoading);
            
            %% Seperate the calculate flowrates into adsorption and desorption flowrates
            mfFlowRatesAdsorption = zeros(1,this.oMT.iSubstances);
            mfFlowRatesDesorption = zeros(1,this.oMT.iSubstances);
            mfFlowRatesAdsorption(this.mfFlowRates > 0) = this.mfFlowRates(this.mfFlowRates > 0);
            mfFlowRatesDesorption(this.mfFlowRates < 0) = this.mfFlowRates(this.mfFlowRates < 0);
            
            fDesorptionFlowRate                             = -sum(mfFlowRatesDesorption);
            arPartialsDesorption                            = zeros(1,this.oMT.iSubstances);
            arPartialsDesorption(mfFlowRatesDesorption~=0)  = abs(mfFlowRatesDesorption(mfFlowRatesDesorption~=0)./sum(mfFlowRatesDesorption));

            mfFlowRatesDesorption = fDesorptionFlowRate .* arPartialsDesorption;
            
            fAdsorptionFlowRate   	= sum(mfFlowRatesAdsorption);
            arPartialsAdsorption    = zeros(1,this.oMT.iSubstances);
            arPartialsAdsorption(mfFlowRatesAdsorption~=0)  = abs(mfFlowRatesAdsorption(mfFlowRatesAdsorption~=0)./sum(mfFlowRatesAdsorption));
            
            mfFlowRatesAdsorption = fAdsorptionFlowRate .* arPartialsAdsorption;
            
            %% Limit the flowrates based on physical principles
            % also here to prevent osciallations
            if ~this.bDesorption
                % in case we are not currently desorbing we assume that
                % this represents a gas flow node and limit the flows
                % accordingly
                %
                % To do so we first calculate the minimum value of partial
                % pressure at which desorption/adsorption would switch
                afMinPPHelper = mfCurrentLoading ./ mfLinearizationConstant;
                afMinPPHelper(isnan(afMinPPHelper)) = 0;
                afMinPPHelper(isinf(afMinPPHelper)) = 0;
                
                % then we only overwrite the partial pressure values for
                % the substances where such a minimum pressure exists
                % (gases that are not adsorbed/desorbed are not changed by
                % the p2p)
                afMinPP = afPP;
                afMinPP(mfLinearizationConstant ~= 0) = afMinPPHelper(mfLinearizationConstant ~= 0);
                
                mfFlowRatesHelper = ones(1,this.oMT.iSubstances);
                iIteration = 1;
                afMinPPFinal = afPP;
                % Since we used an approximation the initial result for the
                % minimal partial pressure is not accurate. Therefore we
                % iterate the calculation until the results are
                % sufficiently accurate
                miSubstances = find(mfLinearizationConstant ~= 0);
                for iSubstance = 1:length(miSubstances)
                    while abs(mfFlowRatesHelper(miSubstances(iSubstance))) > 1e-10 && iIteration < 500
                        
                        afMinPPHelper = afPP;
                        afMinPPHelper(miSubstances(iSubstance)) = afMinPP(miSubstances(iSubstance));
                        
                        [ mfEquilibriumLoadingHelper , mfLinearizationConstantHelper ] = this.oMT.calculateEquilibriumLoading(afMassAbsorber, afMinPPHelper, fTemperature);

                        afMinPPHelper = mfCurrentLoading ./ mfLinearizationConstantHelper;
                        afMinPPHelper(isnan(afMinPPHelper)) = 0;
                        afMinPPHelper(isinf(afMinPPHelper)) = 0;

                        % then we only overwrite the partial pressure values for
                        % the substances where such a minimum pressure exists
                        % (gases that are not adsorbed/desorbed are not changed by
                        % the p2p)
                        afMinPP = afPP;
                        afMinPP(mfLinearizationConstantHelper ~= 0) = afMinPPHelper(mfLinearizationConstantHelper ~= 0);

                        mfFlowRatesHelper = (mfEquilibriumLoadingHelper - (mfEquilibriumLoadingHelper - mfCurrentLoading) .* exp(- this.mfMassTransferCoefficient) - mfCurrentLoading);

                        iIteration = iIteration + 1;
                    end
                    afMinPPFinal(miSubstances(iSubstance)) = afMinPP(miSubstances(iSubstance));
                end
                
                arMinMolarFraction = afMinPPFinal ./ fPressure;
                
                % Basically we assume that one mol of the substance
                % currently exists, since we are not interested in the
                % absolute value but only in the fractions
                arMinMassFraction = arMinMolarFraction .* this.oMT.afMolarMass;
                
                % Then we calculate the mass fraction by dividing the
                % individual masses from the one mole assumption with the
                % sum of all the masses
                arMinMassFraction = arMinMassFraction ./ sum(arMinMassFraction);
                
                % Now the minimum outlet flowrates can be calculated by
                % multiplying the inlet flowrate and the partial mass
                % fractions (assuming that the P2P flowrates are small when
                % compared to the inflowing mass)
                afMinOutFlows = sum(this.afPartialInFlows) .* arMinMassFraction;
                
                % now we limit the desorption flowrates so that at most so
                % much can desorb that the P2P would start adsorbing again
                abLimitDesorpFlows = afMinOutFlows < mfFlowRatesDesorption;
                mfFlowRatesDesorption(abLimitDesorpFlows) = afMinOutFlows(abLimitDesorpFlows);

                % Ironically we have to limit the limiting flows before
                % calculating the adsorption limits, because the min outlet
                % flows for the adsorption case can also not be larger than
                % the partial inflowrate of that substance
                abLimitMinOutFlows = (afMinOutFlows > this.afPartialInFlows);
                afMinOutFlows(abLimitMinOutFlows) = this.afPartialInFlows(abLimitMinOutFlows);
                
                % While the adsorption flowrates are limit so that at most
                % so much is adsorbed that the P2P would start desorbing
                % again
                abLimitFlows = ((this.afPartialInFlows - mfFlowRatesAdsorption) < afMinOutFlows);
                afMaxAbsorberFlows = this.afPartialInFlows - afMinOutFlows;
                mfFlowRatesAdsorption(abLimitFlows) = afMaxAbsorberFlows(abLimitFlows);
            end
            
            %% get the final adsorption and desorption flowrates and partials
            fDesorptionFlowRate                             = sum(mfFlowRatesDesorption);
            arPartialsDesorption                            = zeros(1,this.oMT.iSubstances);
            arPartialsDesorption(mfFlowRatesDesorption~=0)  = abs(mfFlowRatesDesorption(mfFlowRatesDesorption~=0)./sum(mfFlowRatesDesorption));

            arPartialsAdsorption    = zeros(1,this.oMT.iSubstances);
            if this.bDesorption
                % this was implemented to avoid very small time steps
                % during initialization. The error introduced from this
                % assumption should be very small
                fAdsorptionFlowRate     = 0;
                mfFlowRatesAdsorption   = zeros(1,this.oMT.iSubstances);
                if fDesorptionTime < fDelayTime
                    fDesorptionFlowRate     = 0;
                    mfFlowRatesDesorption   = zeros(1,this.oMT.iSubstances);
                end
                    
            else
                fAdsorptionFlowRate   	= sum(mfFlowRatesAdsorption);
                arPartialsAdsorption(mfFlowRatesAdsorption~=0)  = abs(mfFlowRatesAdsorption(mfFlowRatesAdsorption~=0)./sum(mfFlowRatesAdsorption));
            end
            
            %% Set the values for the two P2Ps
            this.oStore.toProcsP2P.(['DesorptionProcessor',this.sCell]).setMatterProperties(fDesorptionFlowRate, arPartialsDesorption);
            this.setMatterProperties(fAdsorptionFlowRate, arPartialsAdsorption);
            
            %% Set the heat flow of the adsorption process
            % For this a heat flow inside the adsorber phase must be
            % present!
            
            % exothermic reaction have a negative enthalpy by definition,
            % therefore we have to multiply the equation with -1 to have a
            % positive heat flow for positive flowrates
            this.mfFlowRates = mfFlowRatesAdsorption - mfFlowRatesDesorption;
            this.fAdsorptionHeatFlow = - sum((this.mfFlowRates ./ this.oMT.afMolarMass) .* this.mfAbsorptionEnthalpy);
            
            % sets the heat flow to the absorber capacity
            this.oOut.oPhase.oCapacity.toHeatSources.(['AbsorberHeatSource', this.sCell]).setHeatFlow(this.fAdsorptionHeatFlow)
        end
    end
end
