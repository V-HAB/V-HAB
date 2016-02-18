classdef BPV < matter.procs.f2f
    % BPV Backpressure valve that controls the water vapor flow to the environment
    %
    % The BPV is a F2F processor that controls the vapor pressure inside
    % the SWME and consequently the evaporation rate of the cooling water
    % and the heat rejection
    %
    % NOTE: This model is NOT suitable for general use. It is specially
    %       tailored to calculate WATER VAPOR flow, not any other
    %       substances.
    
    properties (SetAccess = protected, GetAccess = public)
        
        % Fixed values that define the behavior of the valve
        fValveMaximumArea       = 0.00129;          % [m^2]      maximum throat area of the valve
        iValveMaximumSteps      = 4170;             % [-]        maximum amount of steps the valve needs to be fully open
        fControllerTimeConstant = 0.001;            % [s]        time the controller waits for the temperature to settle before trying to adjust the valve again
        fKappa                  = 1.333;            % [-]        Isentropic exponent of water 
        
        % Variable values, some of which have default values
        iValveCurrentSteps    = 1000;               % [-]        current step position the valve is in
        fTimeOfLastAdjustment = -0.001;             % [s]        simulation time where the last valve adjustment ocurred. Default value is negative time constant to get an update at time = 0s.
        fVaporFlowRate;                             % [kg/s]     vapor flow rate through the valve
        fTemperatureSetPoint;                       % [K]        desired outlet water temperature of the SWME

        % A reference to the exme the BPV branch is connected to so we can
        % always get the up to date environmental pressure. 
        oReferenceExme;
    end
    
    methods
        function this= BPV(oContainer, sName, oReferenceExme)
            
            this@matter.procs.f2f(oContainer, sName);
            
            this.oReferenceExme = oReferenceExme;
            
            % BPV class only supports the manual solver
            this.supportSolver('manual', true, @this.update);
            
            
        end
        
        function setTemperatureSetPoint(this, fTemperatureSetPoint)
            this.fTemperatureSetPoint = fTemperatureSetPoint;
        end
        
        function update(this)
            
            %% Calculating the valve position in steps
            
            % Determines the required action by the stepper motor (open or
            % close) and the magnitude of such action (how many steps). If
            % the temperature is within an acceptable range, nothing
            % (should) happen.
            
            % Getting the current outlet temperature
            fCurrentOutletWaterTemperature = this.oContainer.toProcsF2F.TemperatureProcessor.aoFlows(2).fTemperature;
            
            % If this is the very first time step, there is no flow through
            % the processor yet, so the above query will return a
            % temperature of zero. In this case, we'll just skip this
            % execution.
            if fCurrentOutletWaterTemperature == 0
                return;
            end
            
            % Only go through if the controller gave the system enough time
            % to settle itself
            if (this.oBranch.oContainer.oTimer.fTime >= (this.fTimeOfLastAdjustment + this.fControllerTimeConstant))
                
                tParameters = struct();
                tParameters.sSubstance = 'H2O';
                tParameters.sProperty = 'Heat Capacity';
                tParameters.sFirstDepName = 'Temperature';
                tParameters.fFirstDepValue = this.fTemperatureSetPoint;
                tParameters.sPhaseType = 'liquid';
                
                % Now we can call the findProperty() method.
                fLiquidSpecificHeatCapacitySetPoint = this.oMT.findProperty(tParameters);
                
                tParameters.fFirstDepValue = fCurrentOutletWaterTemperature;
                
                fLiquidSpecificHeatCapacityOutlet = this.oMT.findProperty(tParameters);
                
                % The heat rejection error is used as the parameter
                % that defines how much the valve should open or close.
                fHeatRejectionError = abs (this.oBranch.oContainer.toBranches.OutletBranch.fFlowRate  *  ...
                    (fLiquidSpecificHeatCapacitySetPoint * this.fTemperatureSetPoint - ...
                    fLiquidSpecificHeatCapacityOutlet  *  fCurrentOutletWaterTemperature));
                
                % If outlet temperature rises above the temperature limit,
                % calculate the heat rejection error and open the valve.
                if ( (fCurrentOutletWaterTemperature - 273.15) > 1.007 * (this.fTemperatureSetPoint - 273.15))

                    % Two different proportional constants for two
                    % different sections of the Heat Rejection vs. Valve
                    % Position curve (Makinen, Anchonodo et al. 2013, "RVP
                    % SWME; A Next-Generation Evaporative Cooling
                    % System[...]"
                    if (this.iValveCurrentSteps <= 600)
                        
                        iRequiredValveSteps = round (fHeatRejectionError);
                        
                    else
                        
                        iRequiredValveSteps = 24 * round (fHeatRejectionError);
                        
                    end
                    
                    
                    % Overriding the previously implemented controller,
                    % since it makes the simulation too unstable, but i am
                    % still leaving the code there, maybe for future work?
                    if (iRequiredValveSteps > 1)
                        
                        iRequiredValveSteps= 1;
                        
                    end
                    
                    % Setting the new current position of the valve and
                    % setting the time of last adjustment to current
                    % simulation time
                    this.iValveCurrentSteps    = this.iValveCurrentSteps + iRequiredValveSteps;
                    
                    this.fTimeOfLastAdjustment = this.oBranch.oContainer.oTimer.fTime;
                    
                    
                    % Same as above, but this time if the temperature falls
                    % below the limit, the response of the motor is to
                    % close the valve
                elseif ( (fCurrentOutletWaterTemperature - 273.15) < 0.993 * (this.fTemperatureSetPoint - 273.15) )
                    
                    if (this.iValveCurrentSteps <= 600)
                        
                        iRequiredValveSteps = round (fHeatRejectionError);
                        
                    else
                        
                        iRequiredValveSteps = 24 * round (fHeatRejectionError);
                    end
                    
                    
                    % Overriding the previously implemented controller,
                    % since it makes the simulation too unstable, but i am
                    % still leaving the code there, maybe for future work?
                    if (iRequiredValveSteps > 1)
                        
                        iRequiredValveSteps= 1;
                        
                    end
                    
                    
                    % Since the controller above makes the simulation
                    % unstable, a step by step controller was used instead.
                    % I'm leaving the code for an eventual future work.
                    this.iValveCurrentSteps    = this.iValveCurrentSteps - iRequiredValveSteps;
                    
                    this.fTimeOfLastAdjustment = this.oBranch.oContainer.oTimer.fTime;
                    
                end
                
            end
            
            % Last conditional statement to avoid impossible motor steps
            % positions. if it falls below zero, sets it back to zero and
            % if rises above the maximum amount of steps sets it to the
            % maximum.
            if (this.iValveCurrentSteps < 0)
                
                this.iValveCurrentSteps = 0;
                
            elseif (this.iValveCurrentSteps > this.iValveMaximumSteps)
                
                this.iValveCurrentSteps = this.iValveMaximumSteps;
                
            end
            
            %% Calculating the water vapor flux through the valve
            
            % Getting the pressure and density of the vapor on the inside
            % of the SWME
            fPressureInternal  = this.oContainer.toStores.SWMEStore.toPhases.VaporSWME.fMassToPressure * this.oContainer.toStores.SWMEStore.toPhases.VaporSWME.fMass;
            
            fVaporDensity      = this.oContainer.toStores.SWMEStore.toPhases.VaporSWME.fDensity;
            
            % Calculating the current open area of the valve based on the
            % current position of the stepper motor
            %TODO Check if this linear correlation between the area and the
            %actual geometry of the valve is valid.
            fValveCurrentArea = (this.iValveCurrentSteps / this.iValveMaximumSteps) * this.fValveMaximumArea;
            
            %if the valve is open, calculates the vapor flux
            if (this.iValveCurrentSteps ~=0)
                
                fC1               = sqrt((8 * fPressureInternal) / (pi * fVaporDensity));
                
                fCriticalPressure = fPressureInternal * ((2 / (1 + this.fKappa))^(this.fKappa / (this.fKappa - 1)));
                
                [ fEnvironmentalPressure, ~ ] = this.oReferenceExme.getPortProperties();
                
                if fEnvironmentalPressure > fCriticalPressure
                    
                    % If the internal pressure is lower than the external
                    % pressure, fPsi becomes imaginary. Theoretically
                    % impossible, since the internal pressure should never
                    % be lower than the external pressure. But with big
                    % time steps or unstable simulations (high external
                    % pressure) could happen. In this case the frequency
                    % how often the .exec() method is called in the
                    % SWMELoop class (roth.swme.system.SWMELoop) is called
                    % should be decreased to make the simulation more
                    % stable.
                    rPressure = fEnvironmentalPressure / fPressureInternal;
                    
                    fPsi      = sqrt( (this.fKappa / (this.fKappa - 1))  *  ((rPressure^(2 / this.fKappa)) - (rPressure^((1 + this.fKappa) / this.fKappa))));
                    
                else
                    
                    fPsi = sqrt(0.5 * this.fKappa * ((2 / (1 + this.fKappa))^((this.fKappa + 1) / (this.fKappa - 1))));
                    
                end
                
                this.fVaporFlowRate = (0.86 * fValveCurrentArea * 4 * fPressureInternal * fPsi)  /  (fC1 * sqrt(pi));
                
            else
                % If the valve is closed, vapor flux is zero.
                this.fVaporFlowRate = 0;
                
            end
            
        end
        
        
        
    end
    
end