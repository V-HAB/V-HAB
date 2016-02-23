classdef X50Membrane < matter.procs.p2ps.flow
    % X50MEMBRANE is a P2P processor that calculates the water vapor flux from inside the hollow fibers, 
    % through the membrane wall, to the vapor store outside the hollow
    % fibers
    %
    %
    % X50Membrane(oStore, sName, sPhaseAndPortIn, sPhaseAndPortOut)
    
    properties (SetAccess = protected, GetAccess = public)
        % The water vapor flow rate through the membrane in [kg/s]
        fWaterVaporFlowRate;
        
        % Heat rejection of the membrane calculated using the
        % simplification of neglecting the advective heat transfer through
        % the evaporated water mass. In [W].
        fHeatRejectionSimple;
        
    end
    
    properties (SetAccess = protected, GetAccess = protected)
        
        % A reference to the flow to flow processor that will do the actual
        % changing of the temperature of the SWME outlet flow. It is set
        % via the setTemperatureProcessor() method.
        oTemperatureProcessor;
        
        % This array contains the relative parts of the substances that are
        % evaporated across the membrane.
        arExtractPartials;
        
        fPressureDropCoefficient = 1.021;       % [-]    Correction factor for the vapor pressure directly outside of the membrane
        fMembraneArea            = 1.5;         % [m^2]  Total surface area of the membrane
        fMembraneTortuosity      = 2.325;       % [-]    Tortuosity factor of the membrane
        fMembraneThickness       = 40e-6;       % [m]    Thickness of the membrane wall
        fMembraneOpenPoreArea    = 0.6;         % [m^2]  Open pore area of the surface of the membrane
        fMembranePorosity        = 0.4;         % [-]    Porosity of the membrane
        fPoreDiameter            = 0.04e-6;     % [m]    Diameter of a membrane pore
        fReferencePressure       = 800;         % [Pa]   Average pressure for the range of application of the membrane
        
    end
    
    methods
        function this = X50Membrane(oStore, sName, sPhaseIn, sPhaseOut)
            
           this@matter.procs.p2ps.flow(oStore, sName, sPhaseIn, sPhaseOut);
           
           % Since this membrane model is only created for water evaporation,
           % we can make the extration partials a static value. If the model
           % is ever expanded to evaporate substances other than water, then
           % this array has to be dynamically determined based on the input
           % flows.
           this.arExtractPartials = zeros(1, this.oMT.iSubstances);
           this.arExtractPartials(this.oMT.tiN2I.('H2O')) = 1;
        end
        
        function update (this)
           
            % Getting the current water temperatures
            fWaterTemperatureInlet  = this.oIn.oPhase.toProcsEXME.WaterIn.oFlow.fTemperature;
            fWaterTemperatureOutlet = this.oTemperatureProcessor.aoFlows(2).fTemperature;
            
            % Calculating the mean temperature inside a hollow fiber in [K]
            fMeanTemperature = 0.5 * (fWaterTemperatureInlet + fWaterTemperatureOutlet);
            
            % Calculating the vapor pressure inside the SWME in [Pa]
            fVaporPressure = this.fPressureDropCoefficient * this.oOut.oPhase.fMassToPressure * this.oOut.oPhase.fMass;
            
            tGasParameters = struct();
            tGasParameters.sSubstance = 'H2O';
            tGasParameters.sProperty = 'Heat Capacity';
            tGasParameters.sFirstDepName = 'Temperature';
            tGasParameters.fFirstDepValue = fMeanTemperature;
            tGasParameters.sSecondDepName = 'Pressure';
            tGasParameters.fSecondDepValue = fVaporPressure;
            tGasParameters.sPhaseType = 'gas';
            
            % Calculating the specific heat capacity of vapor in [J/kgK]
            fVaporSpecificHeatCapacity = this.oMT.findProperty(tGasParameters);
            
            % First we need to create a struct with all the necessary
            % parameters.
            tLiquidParameters = struct();
            tLiquidParameters.sSubstance = 'H2O';
            tLiquidParameters.sProperty = 'Heat Capacity';
            tLiquidParameters.sFirstDepName = 'Temperature';
            tLiquidParameters.fFirstDepValue = fMeanTemperature;
            tLiquidParameters.sPhaseType = 'liquid';
            
            % Now we can call the findProperty() method.
            fLiquidSpecificHeatCapacity = this.oMT.findProperty(tLiquidParameters);
            
            % Calculating the mean saturation pressure inside the hollow
            % fibers in [Pa]
            fSaturationVaporPressure = this.oMT.calculateWaterSaturationVaporPressure(fMeanTemperature);
            
            % Calculating the mean molecular free path and the Knudsen
            % number in [m]
            fMeanMolecularFreePath = (this.oMT.Const.fBoltzmann * fMeanTemperature) /...
                                     (sqrt(2) * pi * fSaturationVaporPressure * this.oMT.ttxMatter.H2O.fAverageMolecularDiameter^2);
            
            fKnudsenNumber = fMeanMolecularFreePath / this.fPoreDiameter;
            
            % Calculating the average pressure between the saturation
            % vapor pressure and the actual vapor pressure in [Pa]
            fPressureAverage = 0.5 * (fSaturationVaporPressure + fVaporPressure);
            
            % Determining the type of diffuson through the membrane wall
            if (fKnudsenNumber >= 10) 
                % Knudsen diffusion
                
                fMembraneCoefficient = ( (1.064 * (this.fPoreDiameter / 2) * (this.fMembranePorosity)) ...
                                       / (this.fMembraneTortuosity * this.fMembraneThickness)) * ...
                                         sqrt(this.oMT.ttxMatter.H2O.fMolarMass / (this.oMT.Const.fUniversalGas * fMeanTemperature));
                              
            elseif 0.01 < fKnudsenNumber && fKnudsenNumber < 10 
                % Transition diffusion
                
                % Mean free path in [m]
                fMeanFreePathAtUnitPressure = (this.oMT.Const.fBoltzmann * fMeanTemperature) /...
                                          (sqrt(2) * pi * this.fReferencePressure * this.oMT.ttxMatter.H2O.fAverageMolecularDiameter^2);
            
                fMolecularSpeed = sqrt( (8 * this.oMT.Const.fUniversalGas * fMeanTemperature) / (pi * this.oMT.ttxMatter.H2O.fMolarMass));
                
                % Calculating the parameters for the membrane coefficient
                % equation
                fA = (this.fPoreDiameter * this.fMembranePorosity) / (3 * this.oMT.Const.fUniversalGas * fMeanTemperature * this.fMembraneTortuosity);
                fB = (pi * this.fMembranePorosity * (this.fPoreDiameter / 2)^2) / (32 * this.oMT.Const.fUniversalGas * fMeanTemperature * this.fMembraneTortuosity);
                fa = this.oMT.ttxMatter.H2O.fMolarMass * ( (fMolecularSpeed * (fA + (fB * this.fReferencePressure) / fMeanFreePathAtUnitPressure)) / this.fMembraneThickness);
                fb = ( (fB * this.fReferencePressure) / fMeanFreePathAtUnitPressure ) / ( fA + ((fB * this.fReferencePressure) / fMeanFreePathAtUnitPressure) );
                
                fMembraneCoefficient = fa * this.fMembraneThickness * (1 + fb * ( (fPressureAverage / this.fReferencePressure) - 1 ) );
            
            else   
                % fKnudsenNumber <= 0.01 viscous or Poiseuille flow
                
                % Changing the property parameter and calling
                % findProperty() for the dynamic viscosity of the gas in
                % the SWME.
                tGasParameters.sProperty = 'Dynamic Viscosity';
                fGasDynamicViscosity     = this.oMT.findProperty(tGasParameters);
                
                fMembraneCoefficient     = (0.125 * fPressureAverage * this.oMT.ttxMatter.H2O.fMolarMass * this.fMembranePorosity * (this.fPoreDiameter / 2)^2) /  ...
                                          (this.fMembraneThickness * this.fMembraneTortuosity * fGasDynamicViscosity * this.oMT.Const.fUniversalGas * fMeanTemperature);
            end
            
            % Calculating the water vapour mass flow through the membrane
            % and the resulting liquid water outlet mass flux in [kg/s]
            this.fWaterVaporFlowRate = fMembraneCoefficient * (fSaturationVaporPressure - fVaporPressure) * this.fMembraneArea;
            
            % Getting the input flow rate into the SWME. Need to use the
            % absolute value because the SWME is a subsystem, so the inflow
            % is mathematically negative due to the positive flow direction
            % always being out of the subsystem.
            fSWMEInputFlowRate = abs(this.oIn.oPhase.toProcsEXME.WaterIn.oFlow.fFlowRate);
            
            if fSWMEInputFlowRate == 0
                fWaterFlowRateOutlet = 0;
            else
                %TODO Why is the water vapor flow rate an absolute value? can
                %the flux be negative? Why would it be?
                fWaterFlowRateOutlet = fSWMEInputFlowRate - abs(this.fWaterVaporFlowRate);
                
            end
            
            % Setting mass flow through the membrane wall
            this.setMatterProperties(this.fWaterVaporFlowRate, this.arExtractPartials);
            
            % Calculating evaporation enthalpy and resulting heat rejection
            % through the membrane
            fEvaporationEnthalpy = this.calculateEvaporationEnthalpy(fMeanTemperature);
            
            fHeatRejection = this.fWaterVaporFlowRate * fEvaporationEnthalpy;
            
            % Calculating the new water outlet temperature based on the
            % escaped vapor and heat rejection. If the input flow rate is
            % zero, then the outlet temperature is set equal to the inlet
            % temperature. 
            if fSWMEInputFlowRate == 0
                fWaterTemperatureOutlet = this.oIn.oPhase.toProcsEXME.WaterIn.fTemperature;
            else
                fWaterTemperatureOutlet = (fWaterTemperatureInlet * fLiquidSpecificHeatCapacity * fSWMEInputFlowRate ...
                    - this.fWaterVaporFlowRate * fMeanTemperature * fVaporSpecificHeatCapacity - fHeatRejection) /  ...
                    (fLiquidSpecificHeatCapacity * fWaterFlowRateOutlet);
            end
            
            % Since all data sources use the simplified version of the
            % previous equation to determine the heat rejection based on
            % the outlet temperature, neglecting the energy carried away by
            % the vapor, the same will be done here so the results can be
            % compared to published results.
            this.fHeatRejectionSimple = fSWMEInputFlowRate * fLiquidSpecificHeatCapacity * (fWaterTemperatureInlet - fWaterTemperatureOutlet);
            
            % We have to calculate the heat flow for the temperature
            % processor downstream of the SWME that will do the actual
            % changing of the temperature. For that, we will use the same
            % equation as above, but using the outlet flow rate instead. 
            fOutletFlowRate = fSWMEInputFlowRate - this.fWaterVaporFlowRate;
            fProcessorHeatRejection = fOutletFlowRate * fLiquidSpecificHeatCapacity * (fWaterTemperatureInlet - fWaterTemperatureOutlet);
            
            % Now we're setting the heat flow on the processor, multiplying
            % the calculated heat rejection with -1 because it is a
            % negative heat flow, out of the matter.
            this.oTemperatureProcessor.setHeatFlow( -1 * fProcessorHeatRejection );
            
            % Now that we're done here, we can call the update method for
            % the back pressure valve in our parent system. This will
            % calculate the new valve position and the according flow rate
            % out of the SWME. We want to use the same internal pressure as
            % we used for the calculation here, so we pass it along.
            this.oStore.oContainer.updateBPV(fVaporPressure);

        end
        
        function setTemperatureProcessor(this, oProcessor)
            % The temperature changing processor is created outside of this
            % p2p processor, so we need a method to set the property.
            this.oTemperatureProcessor = oProcessor;
        end
            
    end
    
end

