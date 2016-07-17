classdef SWME < vsys
    % SWME Model of the Space Suit Water Membrane Evaporator designed for
    % the AEMU
    % 
    % Add a nice description here
    %% Overall SWME Properties
    properties (SetAccess = protected, GetAccess = public)
        % The external pressure in [Pa] is set to zero for a simulation of
        % an EVA in space, but can be changed to the atmospheric pressure
        % of Mars for a Mars EVA simulation.
        fEnvironmentalPressure = 0;
        
        % Total internal volume of the SWME in [m^3]   
        fSWMEVolume            = 9.620939e-4;
        
        % SWME volume - HoFI volume in [m^3]
        fSWMEVaporVolume       = 8.7395e-4;
        
        % Initial water temperature in [K]
        fInitialTemperature; 
        
    end
    
    %% Properties relevant to the back pressure valve
    properties (SetAccess = protected, GetAccess = public)
        
        % Fixed values that define the behavior of the valve
        fValveMaximumArea          = 0.00129;          % [m^2]      maximum throat area of the valve
        iValveMaximumSteps         = 4170;             % [-]        maximum amount of steps the valve needs to be fully open
        fBPVControllerTimeConstant = 0.001;            % [s]        time the controller waits for the temperature to settle before trying to adjust the valve again
        fKappa                     = 1.333;            % [-]        Isentropic exponent of water 
        
        % Variable values with their defaults
        iBPVCurrentSteps           = 0;                % [-]        current step position the valve is in
        fTimeOfLastBPVAdjustment   = -0.001;           % [s]        simulation time where the last valve adjustment ocurred. Default value is negative time constant to get an update at time = 0s.
        fVaporFlowRate             = 0;                % [kg/s]     vapor flow rate through the valve
        fTemperatureSetPoint       = 283.15;           % [K]        desired outlet water temperature of the SWME
    end
    
    
    methods
        
        function this = SWME(oParent, sName, fInitialTemperature)
            
            % Calling the parent class constructor
            this@vsys(oParent, sName);
            
            % Setting parameters if they were set by a simulation runner
            eval(this.oRoot.oCfgParams.configCode(this));
            
            % Setting the initial temperature property
            this.fInitialTemperature = fInitialTemperature;
            
        end
        
        function createMatterStructure(this)
            
            createMatterStructure@vsys(this);
            
            % Creating an empty tank where the vapor flows to, simulating
            % the environment (can be vacuum or planetary atmosphere)
            matter.store(this, 'EnvironmentTank', 10);
            
            % Adding an empty phase to the environment tank, representing
            % an empty tank
            oEnvironment = matter.phases.gas(...
                this.toStores.EnvironmentTank, ...        % Store in which the phase is located
                'EnvironmentPhase', ...                   % Phase name
                struct('H2O', 0), ...                     % Phase contents
                0.001, ...                                % Phase volume
                293);                                     % Phase temperature
            
            % Special exme with a constant pressure, set on the initial
            % parameters
            oExme = special.matter.const_press_exme(oEnvironment, 'ToEnvironment', this.fEnvironmentalPressure);
            
            % Creating the SWME Store
            components.SWME.stores.SWMEStore(this, 'SWMEStore', this.fSWMEVolume, this.fSWMEVaporVolume, this.fInitialTemperature);
            
            % Two standard pipes, which connect the SWME to the super
            % system
            components.pipe(this, 'Pipe_1', 0.01, 0.0127);
            components.pipe(this, 'Pipe_2', 0.01, 0.0127);
            
            % We need to change the outlet temperature via a f2f processor,
            % which we create here.
            oProc = components.SWME.procs.TemperatureProcessor(this, 'TemperatureProcessor');
            
            % We also have to tell the P2P Processor in the SWME, that this
            % is the processor it is linked to.
            this.toStores.SWMEStore.setTemperatureProcessor(oProc);
            
            % Creating the inlet branch with an interface
            matter.branch(this, 'SWMEStore.WaterIn', {'Pipe_1'}, 'Inlet', 'InletBranch');
            
            % Creating the outlet branch with an interface
            matter.branch(this, 'SWMEStore.WaterOut', {'TemperatureProcessor', 'Pipe_2'}, 'Outlet', 'OutletBranch');
            
            % Creating the branch to the environment with an interface
            matter.branch(this, 'SWMEStore.VaporOut', {}, 'EnvironmentTank.ToEnvironment', 'EnvironmentBranch');
            
        end
        
        function createSolverStructure(this)
            
            createSolverStructure@vsys(this);
            
            % Creating references to branches in order to set flow rate manually later
            solver.matter.manual.branch(this.toBranches.InletBranch);
            solver.matter.manual.branch(this.toBranches.OutletBranch);
            solver.matter.manual.branch(this.toBranches.EnvironmentBranch);
            
            % Binding the setFlowRate() method of the outlet solver branch
            % to the inlet branches' 'outdated' event.
            this.toBranches.InletBranch.bind('outdated', @(~) this.toBranches.OutletBranch.oHandler.setFlowRate(-1 * this.toBranches.InletBranch.fFlowRate - this.toStores.SWMEStore.toProcsP2P.X50Membrane.fWaterVaporFlowRate));
            
            % We need to make sure, that this phase is updated frequently,
            % otherwise it is possible, that the connected branch that
            % transfers the water vapor to the environment sucks all of the
            % matter out of the phase in one time step. 
            this.toStores.SWMEStore.toPhases.VaporPhase.fMaxStep = 0.5;
        end
        
        function setInterfaces(this, sInlet, sOutlet)
            % Setting the interface flows.
            this.connectIF('Inlet',  sInlet);
            this.connectIF('Outlet', sOutlet);
        end
        
        function setTemperatureSetPoint(this, fTemperatureSetPoint)
            % Externally accessible method to change the temperature
            % setpoint. To be called from supersystem.
            this.fTemperatureSetPoint = fTemperatureSetPoint;
        end
        
        %% Back pressure valve update method
        function updateBPV(this, fPressureInternal)
            % This method consists of two parts: The first calculates the
            % new valve position based on the temperature difference
            % between the outlet of the SWME and the temperature set point,
            % the second calculates the actual water vapor flow through the
            % valve based on the pressure difference between the inside of
            % the SWME and the external pressure. 
            % This method is called by the X50Membrane class and the
            % internal pressure is calculated there using a modification
            % factor that accounts for pressure differences within the SWME
            % housing. To ensure that both classes use the same pressure
            % for their calculations, the X50Membrane class passes the
            % calculated internal pressure to this method as a parameter.
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Calculating the valve position in steps %%%%%%%%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
             
            % Determines the required action by the stepper motor (open or
            % close) and the magnitude of such action (how many steps). If
            % the temperature is within an acceptable range, nothing
            % (should) happen.
            
            % Getting the current outlet temperature
            fCurrentOutletWaterTemperature = this.toProcsF2F.TemperatureProcessor.aoFlows(2).fTemperature;
            
            % If this is the very first time step, there is no flow through
            % the processor yet, so the above query will return a
            % temperature of zero. In this case, we'll just skip this
            % execution.
            if fCurrentOutletWaterTemperature == 0
                return;
            end
            
            % Only go through if the controller gave the system enough time
            % to settle itself
            if (this.oTimer.fTime >= (this.fTimeOfLastBPVAdjustment + this.fBPVControllerTimeConstant))
                
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
                fHeatRejectionError = abs (this.toBranches.OutletBranch.fFlowRate  *  ...
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
                    if (this.iBPVCurrentSteps <= 600)
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
                    this.iBPVCurrentSteps    = this.iBPVCurrentSteps + iRequiredValveSteps;
                    
                    % Same as above, but this time if the temperature falls
                    % below the limit, the response of the motor is to
                    % close the valve
                elseif ( (fCurrentOutletWaterTemperature - 273.15) < 0.993 * (this.fTemperatureSetPoint - 273.15) )
                    
                    if (this.iBPVCurrentSteps <= 600)
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
                    this.iBPVCurrentSteps    = this.iBPVCurrentSteps - iRequiredValveSteps;
                    
                end
                
                this.fTimeOfLastBPVAdjustment = this.oTimer.fTime;
                
            end
            
            % Last conditional statement to avoid impossible motor steps
            % positions. if it falls below zero, sets it back to zero and
            % if rises above the maximum amount of steps sets it to the
            % maximum.
            if (this.iBPVCurrentSteps < 0)
                this.iBPVCurrentSteps = 0;
            elseif (this.iBPVCurrentSteps > this.iValveMaximumSteps)
                this.iBPVCurrentSteps = this.iValveMaximumSteps;
            end
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Calculating the water vapor flux through the valve %%%%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

            % Getting the current density from the phase
            fVaporDensity = this.toStores.SWMEStore.toPhases.VaporPhase.fDensity;
            
            % Calculating the current open area of the valve based on the
            % current position of the stepper motor
            %TODO Check if this linear correlation between the area and the
            %actual geometry of the valve is valid.
            fValveCurrentArea = (this.iBPVCurrentSteps / this.iValveMaximumSteps) * this.fValveMaximumArea;
            
            %if the valve is open, calculates the vapor flux
            if (this.iBPVCurrentSteps ~=0)
                
                fC1 = sqrt((8 * fPressureInternal) / (pi * fVaporDensity));
                
                fCriticalPressure = fPressureInternal * ((2 / (1 + this.fKappa))^(this.fKappa / (this.fKappa - 1)));
                
                if this.fEnvironmentalPressure > fCriticalPressure
                    
                    % If the internal pressure is lower than the external
                    % pressure, fPsi becomes imaginary. Theoretically
                    % impossible, since the internal pressure should never
                    % be lower than the external pressure. But with big
                    % time steps or unstable simulations (high external
                    % pressure) could happen. In this case the frequency
                    % how often the .exec() method is called in the
                    % SWME class (components.SWME) is called
                    % should be decreased to make the simulation more
                    % stable.
                    rPressure = this.fEnvironmentalPressure / fPressureInternal;
                    
                    fPsi = sqrt( (this.fKappa / (this.fKappa - 1))  *  ((rPressure^(2 / this.fKappa)) - (rPressure^((1 + this.fKappa) / this.fKappa))));
                    
                else
                    fPsi = sqrt(0.5 * this.fKappa * ((2 / (1 + this.fKappa))^((this.fKappa + 1) / (this.fKappa - 1))));
                end
                
                this.fVaporFlowRate = (0.86 * fValveCurrentArea * 4 * fPressureInternal * fPsi)  /  (fC1 * sqrt(pi));
                
            else
                % If the valve is closed, vapor flux is zero.
                this.fVaporFlowRate = 0;
            end
            
            % We have to round the calculated flow rate to the global
            % precision because otherwise extremely small oscilations may
            % cause instabilities. 
            this.fVaporFlowRate = tools.round.prec(this.fVaporFlowRate, this.oTimer.iPrecision);
            
            % Now we can set the new flow rate on the branch connecting the
            % SWME housing with the environment.
            this.toBranches.EnvironmentBranch.oHandler.setFlowRate(this.fVaporFlowRate);
            
            this.toBranches.InletBranch.setOutdated();
            
        end
    end
    
    
    methods (Access= protected)
        function exec(this, ~)
            exec@vsys(this);
        end
    end
end


