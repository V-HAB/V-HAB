classdef X50Membrane < matter.procs.p2ps.stationary
    %X50MEMBRANE A model of the water evaporation through a membrane
    % This is a P2P processor that calculates the water vapor flow from
    % inside the hollow fibers, through the membrane wall, to the vapor
    % store outside the hollow fibers. It takes into account the
    % temperatures and heat capacities of the water and water vapor. The
    % model does NOT discetize the length of the hollow fibers into smaller
    % sections and calculates an average temperature across. 
    %
    % The input parameters are equal to the parent class. 
    
    %% Static Properties
    % These are configuration parameters of the hollow fiber membrane of
    % the SWME. 
    properties (SetAccess = protected, GetAccess = public)
        % Correction factor for the vapor pressure directly outside of the membrane [-]
        fPressureDropCoefficient = 1.021;
        
        % Tortuosity factor of the membrane [-]
        fMembraneTortuosity = 2.74;
        
        % Thickness of the membrane wall [m] (40 [µm])
        fMembraneThickness = 40e-6;
        
        % Porosity of the membrane [-]
        fMembranePorosity = 0.4;
        
        % Diameter of a membrane pore [m] (0.04 [µm])
        fPoreDiameter = 0.04e-6;
        
        % Average pressure for the range of application of the membrane [Pa]
        fReferencePressure = 800;
        
        % A thermal heat source object that models the engergy loss through
        % evaporation from the flow phase.
        oHeatSource;
    end
    
    %% Dynamic Properties
    % These are re-calculated during the simulation.
    properties (SetAccess = protected, GetAccess = public)
        % The water vapor flow rate through the membrane in [kg/s]
        fWaterVaporFlowRate = 0;
        
        % Heat rejection via evaporation in [W].
        fHeatRejection = 0;
        
        % Heat rejection of the membrane calculated using the
        % simplification of neglecting the advective heat transfer through
        % the evaporated water mass. In [W].
        fHeatRejectionSimple = 0;
        
        % Mean temperature across the SWME
        fMeanTemperature;
        
        % This array contains the relative parts of the substances that are
        % evaporated across the membrane.
        arExtractPartials;
        
        % Current water inlet temperature
        fSWMEInletTemperature = 0;
        
        % Current water outlet temperature
        fSWMEOutletTemperature = 0;
        
        
    end
    
    %% Derived Properties
    % These are calculated in the constructor based on the static
    % properties defined above and do not change during the simulation.
    properties (SetAccess = protected, GetAccess = public)
        
        % A reference to the flow to flow processor that will do the actual
        % changing of the temperature of the SWME outlet flow. It is set
        % via the setTemperatureProcessor() method.
        oTemperatureProcessor;
        
        % Some factors that contain constant terms to speed up the
        % simulation. Are set in constructor.
        fMeanMolecularFreePathCalculationFactor;
        fMembraneCoefficientCalculationFactor;
        
        % Total area of exposed hollow fiber membrane
        fMembraneArea;
        
    end
    
    methods
        function this = X50Membrane(oStore, sName, sPhaseIn, sPhaseOut, fMembraneArea)
            
           this@matter.procs.p2ps.stationary(oStore, sName, sPhaseIn, sPhaseOut);
           
           % Since this membrane model is only created for water
           % evaporation, we can make the extration partials a static
           % value. If the model is ever expanded to evaporate substances
           % other than water, then this array has to be dynamically
           % determined based on the input flows.
           this.arExtractPartials = zeros(1, this.oMT.iSubstances);
           this.arExtractPartials(this.oMT.tiN2I.('H2O')) = 1;
           
           % Calculating the two constant parameters used in update()
           this.fMeanMolecularFreePathCalculationFactor = ...
               this.oMT.Const.fBoltzmann / (sqrt(2) * pi * this.oMT.ttxMatter.H2O.fAverageMolecularDiameter^2);
           
           this.fMembraneCoefficientCalculationFactor = ( (1.064 * (this.fPoreDiameter / 2) * (this.fMembranePorosity)) ...
                                       / (this.fMembraneTortuosity * this.fMembraneThickness)) * ...
                                         sqrt(this.oMT.ttxMatter.H2O.fMolarMass / this.oMT.Const.fUniversalGas);
                                     
           this.fMembraneArea = fMembraneArea;
        end
        
        function setTemperatureProcessor(this, oProcessor)
            % The temperature changing processor is created outside of this
            % p2p processor, so we need a method to set the property.
            this.oTemperatureProcessor = oProcessor;
        end
        
        function setHeatSource(this, oHeatSource)
            this.oHeatSource = oHeatSource;
        end
            
    end
    
    methods (Access = protected)
        
        function update(this)
            
            if ~base.oDebug.bOff
                this.out(1,1,'X50Membrane','X50Membrane Update');
            end
            
            % Getting the current water temperatures
            fWaterTemperatureInlet  = this.oIn.oPhase.toProcsEXME.WaterIn.oFlow.fTemperature;
            fWaterTemperatureOutlet = this.oIn.oPhase.fTemperature;
            
            this.fSWMEInletTemperature = fWaterTemperatureInlet;
            this.fSWMEOutletTemperature = fWaterTemperatureOutlet;
            
            
            % Calculating the mean temperature inside a hollow fiber in [K]
            this.fMeanTemperature = 0.5 * (fWaterTemperatureInlet + fWaterTemperatureOutlet);
            
            % Calculating the vapor pressure inside the SWME in [Pa]
            fVaporPressure = this.fPressureDropCoefficient * this.oOut.oPhase.fPressure;

            % First we need to create a struct with all the necessary
            % parameters.
            tLiquidParameters = struct();
            tLiquidParameters.sSubstance       = 'H2O';
            tLiquidParameters.sProperty        = 'Heat Capacity';
            tLiquidParameters.sFirstDepName    = 'Temperature';
            tLiquidParameters.fFirstDepValue   = this.fMeanTemperature;
            tLiquidParameters.sPhaseType       = 'liquid';
            tLiquidParameters.bUseIsobaricData = true;
            
            % Now we can call the findProperty() method.
            fLiquidSpecificHeatCapacity = this.oMT.findProperty(tLiquidParameters);
            
            % Calculating the mean saturation pressure inside the hollow
            % fibers in [Pa]
            fSaturationVaporPressure = this.oMT.calculateVaporPressure(this.fMeanTemperature, 'H2O');
            
            % Calculating the current membrane coefficient.
            fMembraneCoefficient = this.fMembraneCoefficientCalculationFactor / sqrt(this.fMeanTemperature);
            
            % Calculating the water vapour mass flow through the membrane
            % and the resulting liquid water outlet mass flux in [kg/s].
            % Evaporation only takes place if the vapor pressure outside of
            % the membrane is lower than the saturation vapor pressure. 
            if fVaporPressure < fSaturationVaporPressure
                this.fWaterVaporFlowRate = fMembraneCoefficient * (fSaturationVaporPressure - fVaporPressure) * this.fMembraneArea;
            else
                this.fWaterVaporFlowRate = 0;
            end
            
            % We have to round the calculated flow rate to the global
            % precision because otherwise extremely small oscilations may
            % cause instabilities. 
            this.fWaterVaporFlowRate = tools.round.prec(this.fWaterVaporFlowRate, this.oTimer.iPrecision);
            
            % Getting the input flow rate into the SWME. Need to use the
            % absolute value because the SWME is a subsystem, so the inflow
            % is mathematically negative due to the positive flow direction
            % always being out of the subsystem.
            fSWMEInputFlowRate = abs(this.oIn.oPhase.toProcsEXME.WaterIn.oFlow.fFlowRate);
            
            % Setting mass flow through the membrane wall
            this.setMatterProperties(this.fWaterVaporFlowRate, this.arExtractPartials);
            
            % Calculating evaporation enthalpy and resulting heat rejection
            % through the membrane
            fEvaporationEnthalpy = this.calculateEvaporationEnthalpy(this.fMeanTemperature);
            
            % Calculating the actual heat rejection from the SWME
            this.fHeatRejection = this.fWaterVaporFlowRate * fEvaporationEnthalpy;
            
            % Setting the calculated heat flow on our heat source. 
            this.oHeatSource.setHeatFlow(-this.fHeatRejection);
            
            % Since all data sources use the simplified version of the
            % previous equation to determine the heat rejection based on
            % the outlet temperature, neglecting the energy carried away by
            % the vapor, the same will be done here so the results can be
            % compared to published results.
            this.fHeatRejectionSimple = fSWMEInputFlowRate * fLiquidSpecificHeatCapacity * (fWaterTemperatureInlet - fWaterTemperatureOutlet);
            
            % Now that we're done here, we can call the update method for
            % the back pressure valve in our parent system. This will
            % calculate the new valve position and the according flow rate
            % out of the SWME. We want to use the same internal pressure as
            % we used for the calculation here, so we pass it along.
            this.oStore.oContainer.updateBPVFlow(fVaporPressure);
            
            
            % We need to update this property with the current time so the
            % solver knows when to update us. 
            this.fLastUpdate = this.oStore.oTimer.fTime;

        end
        
    end
    
end

