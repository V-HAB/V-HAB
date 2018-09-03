classdef CDRA_Heater < base
    % special heater that simulates the electrical heaters in the adsorber
    % beds of CDRA and ALSO calculates the heat exchange between the
    % zeolite and the flow
    properties (SetAccess = protected, GetAccess = public)
        
        fHeatFlow = 0;
        
        oStore;
        oFlowPhase;
        oFilteredPhase;
        oMT;
        fEffectiveZeoliteArea;
        
        fLastExec = 0;
        
        sName;
    end
    
    methods
        function this = CDRA_Heater(oStore, sName)
            this.oStore = oStore;
            
            this.oFlowPhase = this.oStore.toPhases.FlowPhase;
            this.oFilteredPhase = this.oStore.toPhases.FilteredPhase;
            this.oMT = this.oStore.oMT;
            
            % gets an estimate for the effective zeolite are for the
            % convective heat exchange
            fMassPerSphere = (this.oFilteredPhase.fMass/this.oFilteredPhase.fVolume)*(4/3)*pi*((0.0021/2)^3);
            fNZeoliteSpheres = this.oFilteredPhase.fMass/fMassPerSphere;
                
            %and with that the area is:
            this.fEffectiveZeoliteArea = 0.75*fNZeoliteSpheres*4*pi*0.0021^2;
            % Faktor of 0.75 to account for the zeolite spheres touching
            % each other
            
            this.sName = sName;
        end
       	function update(this)
            fTimeStep = this.oStore.oTimer.fTime - this.fLastExec;
            if fTimeStep <= 0
                return
            end
            %% Thermal Calculation for the filter
            % CDRA uses heaters to increase the zeolite temperature of the
            % filter but this effect is countered to some degree by the
            % cooling of the mass flowing through the filter. This
            % calculation derives the overall heat flow for this case and
            % sets the energy change to the phase
            
            %% Heat Flow between flow and solid phase
            iNumberOfExmes = length(this.oFlowPhase.coProcsEXME);
            mbInFlows = zeros(iNumberOfExmes,1);
            for iK = 1:iNumberOfExmes
                fFlowRateEXME = this.oFlowPhase.coProcsEXME{iK}.oFlow.fFlowRate * this.oFlowPhase.coProcsEXME{iK}.iSign;
                if (fFlowRateEXME > 0) && ~this.oFlowPhase.coProcsEXME{iK}.bFlowIsAProcP2P
                    mbInFlows(iK) = true;
                end
            end
            iInFlow = find(mbInFlows);
            if length(iInFlow) == 1
                oInFlow = this.oFlowPhase.coProcsEXME{iInFlow}.oFlow;
                
                fDensity = this.oMT.calculateDensity(oInFlow);
                fDynVisc = this.oMT.calculateDynamicViscosity(oInFlow);
                fThermCond = this.oMT.calculateThermalConductivity(oInFlow);

                if fDensity == 0
                    fDensity = 1e-3;
                end
                % gets the free are for the flow (approximativly)
                fFlowArea = this.oStore.tGeometryParameters.fCrossSection * this.oStore.tGeometryParameters.rVoidFraction;

                fFlowSpeed = abs(oInFlow.fFlowRate/(fFlowArea*fDensity));

                %Calculates the heat exchange coeffcient between the flow and
                %the zeolite. Using the function for the convection at a plate
                %may not be entirely correct, but it is definitly better than
                %the previous calculations using natural convection.
                fConvection_alpha = convection_plate (1.0922, fFlowSpeed,...
                             fDynVisc, fDensity, fThermCond, this.oFlowPhase.fTemperature);

                fConvectiveHeatFlow = this.fEffectiveZeoliteArea * fConvection_alpha * (this.oFilteredPhase.fTemperature - this.oFlowPhase.fTemperature );
            elseif isempty(iInFlow)
                fConvectiveHeatFlow = 0;
            else
                error('CDRA should only have one or none in flow from non p2p procs')
            end
            
            %% Overal heat exchange
            %The heat flow from the heaters is saved as property to
            %this proc while the heat flow between the zeolite and the 
            %flow is saved in the filter f2f proc. For the temperature
            %change of the zeolite the overall heat flow can be
            %calculated by subtracting the heatflow going into the flow
            %from the heat heat flow:

            % from the perspective of the adsorber, so positive heat flows
            % increase the temperature of the adsorber, negatives decrease
            % it
            fOverallHeatFlow = this.fHeatFlow - fConvectiveHeatFlow;

            fEnergyChangeFilter     = fOverallHeatFlow*fTimeStep;
            fEnergyChangeFlow       = fConvectiveHeatFlow*fTimeStep;

            %To prevent too large timesteps from setting physical
            %impossible values the overall heat flow has to stay within
            %certain limits
            fTempDiffFilter = fEnergyChangeFilter / this.oFilteredPhase.fTotalHeatCapacity;
            fTempDiffFlow   = fEnergyChangeFlow   / this.oFlowPhase.fTotalHeatCapacity;
            
            fNewFilterTemp = this.oFilteredPhase.fTemperature + fTempDiffFilter;
            fNewFlowTemp   = this.oFlowPhase.fTemperature     + fTempDiffFlow;
            % for high time steps it is possible that the calculations
            % yields unphysical results (the filter increasing the flow
            % temperature above its own temperature for example) and
            % therefore the maximum temperature change for each phase has
            % to be limited.
            if this.oFlowPhase.fTemperature < this.oFilteredPhase.fTemperature
                % in this case the flow can at most increase its
                % temperature to the same temperature as the new filter
                % temperature
                if fNewFlowTemp > fNewFilterTemp
                    fNewFlowTemp = fNewFilterTemp;
                %And the filter solid can only decrease its temperature to at most the new flow temperature    
                elseif fNewFilterTemp < fNewFlowTemp
                    fNewFilterTemp = fNewFlowTemp;
                end
            elseif this.oFlowPhase.fTemperature > this.oFilteredPhase.fTemperature
                % Flow can only decrease its temperatue to at most the new
                % filter temperature
                if fNewFlowTemp < fNewFilterTemp
                    fNewFlowTemp = fNewFilterTemp;
                % Filter can at most increase its temperature to the new 
                % flow temperature  
                elseif fNewFilterTemp > fNewFlowTemp
                    fNewFilterTemp = fNewFlowTemp;
                end
            end
            
            fEnergyChangeFilter = (fNewFilterTemp - this.oFilteredPhase.fTemperature) * this.oFilteredPhase.fTotalHeatCapacity;
            fEnergyChangeFlow = (fNewFlowTemp - this.oFlowPhase.fTemperature) * this.oFlowPhase.fTotalHeatCapacity;
            
            if fConvectiveHeatFlow == 0
                % in this case nothing flows so there can be no convective
                % coupling of the solid and flow temperature, however it is
                % still necessary for both temperatures to rise. Therefore
                % the energy change for the filter is split up into an
                % energy change for flow and for the filter in a way that
                % both have the same temperature in the end
                
                % New temperature for both phases, just use solve this
                % linear system of equations:
                % Q_1 = C_1*(T_end – T_start1)
                % Q_2 = C_2*(T_end – T_start2)
                % Q_tot = Q_1 + Q_2
                % to arrive at the equation
                fNewTemperature = ( (fEnergyChangeFilter / this.oFilteredPhase.fTotalHeatCapacity) + this.oFilteredPhase.fTemperature...
                    +  (this.oFlowPhase.fTotalHeatCapacity / this.oFilteredPhase.fTotalHeatCapacity) * this.oFlowPhase.fTemperature)...
                    / ((this.oFlowPhase.fTotalHeatCapacity / this.oFilteredPhase.fTotalHeatCapacity) + 1);
                
                % And the energy changes for the filter and the flow to
                % reach this new temperature
                fEnergyChangeFilter = (fNewTemperature - this.oFilteredPhase.fTemperature) * this.oFilteredPhase.fTotalHeatCapacity;
                fEnergyChangeFlow = (fNewTemperature - this.oFlowPhase.fTemperature) * this.oFlowPhase.fTotalHeatCapacity;
                
            end
            
            
            this.oFilteredPhase.changeInnerEnergy(fEnergyChangeFilter);
            this.oFlowPhase.changeInnerEnergy(fEnergyChangeFlow);
            % For debugging, if this occured something went wrong
            if (this.oFilteredPhase.fTemperature < 273) || (this.oFilteredPhase.fTemperature > 1000)
                keyboard()
            elseif (this.oFlowPhase.fTemperature < 273) || (this.oFlowPhase.fTemperature > 1000)
                keyboard()
            end
            
            %saves the last time this processor was executed
            this.fLastExec = this.oStore.oTimer.fTime;
            
        end
        
        %Function to set the zeolite heater power that is used during
        %desorption to increase the zeolite temperature
        function setHeaterPower(this, HeaterPower)
            this.fHeatFlow = HeaterPower;
        end
    end
end