classdef SWME < vsys
    % SWME Model of the Space Suit Water Membrane Evaporator designed for the xEMU
    %   This model defines the SWME store, which contains a flow phase and
    %   a vapor phase, and the X50Membrane p2p that models the evaporation
    %   through the membrane. It also contains the updateBPVFlow() method
    %   that calculates the mass flow through the back pressure valve (BPV)
    %   into the environment and the updateBPVPosition() method, which acts
    %   as a model of the controller of the BPV stepper motor. 
    
    %% SWME roperties that don't change during a simulation
    properties (SetAccess = protected, GetAccess = public)
        % SWME volume - HoFI volume in [m^3]
        fSWMEVaporVolume = 0.0010212418;
        
        % Number of hollow fibers in the SWME [-]
        iNumberOfFibers = 27900;
        
        % Inner diameter of one individual hollow fiber [m] (220 [µm])
        fFiberInnerDiameter = 220e-6;
        
        % Length of exposed fiber inside the SWME [m] (4.7 [in])
        fFiberExposedLength = 0.11938;
        
        % Maximum number of steps the valve needs to be fully open [-]
        iValveMaximumSteps = 4200;
        
    end
    
    %% Dynamic properties that change during the simulation or are assigned during construction
    properties (SetAccess = protected, GetAccess = public)
        
        % A reference to the environment phase. Used in the calculations
        % for the flow through the back pressure valve (BPV).
        oEnvironment;
        
        % Initial water temperature in [K]
        fInitialTemperature; 
        
        
        % Current step position the valve [-]
        iBPVCurrentSteps = 0;
        
        % Vapor flow rate through the valve in [kg/s]
        fVaporFlowRate = 0;
        
        fValveCurrentArea = 0;
        
        % Desired outlet water temperature of the SWME in [K] 
        % Value is equivalent to 10°C and 50°F. 
        fTemperatureSetPoint = 283.15;
    end
    
    
    methods
        
        function this = SWME(oParent, sName, fInitialTemperature)
            
            % Calling the parent class constructor. Third parameter is the
            % fixed time step at which this vsys's exec() method is being
            % called by the timer. It contains a call to the
            % updateBPVPosition() method, which in reality runs at 5 Hz. 
            this@vsys(oParent, sName, 0.2);
            
            % Setting parameters if they were set by a simulation runner
            eval(this.oRoot.oCfgParams.configCode(this));
            
            % Setting the initial temperature property
            this.fInitialTemperature = fInitialTemperature;
        end
        
        function createMatterStructure(this)
            
            createMatterStructure@vsys(this);
            
            % Creating the SWME Store
            eval([this.oMeta.ContainingPackage.Name, '.SWME.stores.SWMEStore(this, ''SWMEStore'');']);
            
            % Two standard pipes, which connect the SWME to the super
            % system
            components.matter.pipe(this, 'Pipe_1', 0.01, 0.0127);
            components.matter.pipe(this, 'Pipe_2', 0.01, 0.0127);
            
            % Creating the inlet branch with an interface
            matter.branch(this, 'SWMEStore.WaterIn', {'Pipe_1'}, 'Inlet', 'InletBranch');
            
            % Creating the outlet branch with an interface
            matter.branch(this, 'SWMEStore.WaterOut', {'Pipe_2'}, 'Outlet', 'OutletBranch');
            
            % Creating the branch to the environment with an interface
            matter.branch(this, 'SWMEStore.VaporOut', {}, 'Environment', 'EnvironmentBranch');
            
        end
        
        function createThermalStructure(this)
            
            createThermalStructure@vsys(this);
            
            % Creating a heat source to transfer the heat of evaporation
            % out of the water flow and adding it to the flow phase.
            oHeatSource = thermal.heatsource('HeatOfEvaporation');
            this.toStores.SWMEStore.toPhases.FlowPhase.oCapacity.addHeatSource(oHeatSource);
            
            % Telling the p2p processor which heat source to use.
            this.toStores.SWMEStore.toProcsP2P.X50Membrane.setHeatSource(oHeatSource);
            
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
            % matter out of the phase in one time step. It also helps with
            % the overall stability of the simulation and the quality of
            % the simulation results. Without this they become quite noisy.
            this.toStores.SWMEStore.toPhases.VaporPhase.setTimeStepProperties(struct('fMaxStep', 0.5));
            
            % Setting the thermal solvers
            this.setThermalSolvers();
        end
        
        function setInterfaces(this, sInlet, sOutlet, sVapor)
            % Setting the interface flows.
            this.connectIF('Inlet',  sInlet);
            this.connectIF('Outlet', sOutlet);
            this.connectIF('Environment', sVapor);
        end
        
        function setTemperatureSetPoint(this, fTemperatureSetPoint)
            % Externally accessible method to change the temperature
            % setpoint. To be called from supersystem.
            this.fTemperatureSetPoint = fTemperatureSetPoint;
        end
        
        %% Back pressure valve update methods
        function updateBPVFlow(this, fPressureInternal)
            % This method calculates the actual water vapor flow through
            % the valve based on the pressure difference between the inside
            % of the SWME and the external pressure.
            % This method is called by the X50Membrane class and the
            % internal pressure is calculated there using a modification
            % factor that accounts for pressure differences within the SWME
            % housing. To ensure that both classes use the same pressure
            % for their calculations, the X50Membrane class passes the
            % calculated internal pressure to this method as a parameter.
            
            if ~base.oDebug.bOff
                this.out(1,1,'SWME','BPV Flow Update');
            end
            
            if nargin < 2 
                fPressureInternal = this.toStores.SWMEStore.toPhases.VaporPhase.fMassToPressure * this.toStores.SWMEStore.toPhases.VaporPhase.fMass;
            end
            
            % Getting the current density from the phase
            fVaporDensity = this.toStores.SWMEStore.toPhases.VaporPhase.fDensity;
            
            % Calculating the current open area of the valve based on the
            % current position of the stepper motor. The curve fit is
            % derived from test data that may need to be updated. Per this
            % test data, below 756 steps the effective area is zero, so we
            % also catch this here.
            if this.iBPVCurrentSteps < 756
                this.fValveCurrentArea = 0;
            else
                iSteps = this.iBPVCurrentSteps;
                this.fValveCurrentArea = ...
                    3.7983e-24 * iSteps^6 + ...
                    -5.0117e-20 * iSteps^5 + ...
                    2.4377e-16 * iSteps^4 + ...
                    -5.5101e-13 * iSteps^3 + ...
                    6.6882e-10 * iSteps^2 + ...
                    -3.9027e-07 * iSteps   + ...
                    8.477e-05;
            end
            % If the valve is open, calculates the vapor flux
            if (this.iBPVCurrentSteps ~=0)
                
                fC1 = sqrt((8 * fPressureInternal) / (pi * fVaporDensity));
                
                fKappa = this.oMT.calculateAdiabaticIndex(this.toStores.SWMEStore.toPhases.VaporPhase);
                
                fCriticalPressure = fPressureInternal * ((2 / (1 + fKappa))^(fKappa / (fKappa - 1)));
                
                if this.oEnvironment.fPressure > fCriticalPressure
                    
                    % If the internal pressure is lower than the external
                    % pressure, fPsi becomes imaginary. Theoretically
                    % impossible, since the internal pressure should never
                    % be lower than the external pressure. But with big
                    % time steps or unstable simulations (high external
                    % pressure) could happen. In this case the frequency
                    % how often the .exec() method is called in the
                    % SWME class (components.matter.SWME) is called
                    % should be decreased to make the simulation more
                    % stable.
                    rPressure = this.oEnvironment.fPressure / fPressureInternal;
                    
                    fPsi = sqrt( (fKappa / (fKappa - 1))  *  ((rPressure^(2 / fKappa)) - (rPressure^((1 + fKappa) / fKappa))));
                    
                else
                    fPsi = sqrt(0.5 * fKappa * ((2 / (1 + fKappa))^((fKappa + 1) / (fKappa - 1))));
                end
                
                this.fVaporFlowRate = (0.86 * this.fValveCurrentArea * 4 * fPressureInternal * fPsi)  /  (fC1 * sqrt(pi));
                
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
        
        function updateBPVPosition(this)
            % This method calculates the new valve position based on the
            % temperature difference between the outlet of the SWME and the
            % temperature set point and then determines the required action
            % by the stepper motor (open or close) and the magnitude of
            % such action (how many steps). If the temperature is within an
            % acceptable range, nothing (should) happen.
            
            % Getting the current outlet temperature
            fCurrentOutletWaterTemperature = this.toStores.SWMEStore.toPhases.FlowPhase.fTemperature;
            
            % If this is the very first time step, there is no flow through
            % the processor yet, so the above query will return a
            % temperature of zero. In this case, we'll just skip this
            % execution.
            if fCurrentOutletWaterTemperature == 0
                return;
            end
            
            % Calculating the temperature difference between inlet and
            % outlet in Kelvin.
            fDeltaTemperature = fCurrentOutletWaterTemperature - this.fTemperatureSetPoint;
            
            % Only do stuff here if there is a 0.28 K (0.5°F) temperature
            % difference between the current outlet and the setpoint.
            if abs(fDeltaTemperature) <= 0.28
                return;
            end
            
            % From CON-450 code documentation
            % d_steps = K_gain * C_steps * (TS439 - set_temp_F) 
            % Wo d_steps die Veränderung der Schritte ist, K_gain ein
            % Gewichtungsfaktor ist der normalerweise 1 ist, aber zwischen
            % 0.1 und 10 variiert werden kann, C_steps ist 58.8, ist eine
            % Konstante die laut der Softwaredokumentation "derived from
            % sensible energy balance equation" ist, wobei ich keine Ahnung
            % habe, was die sein soll und letztlich sind TS439 die
            % gemessene Temperatur und set_temp_F die eingestellte
            % Temperatur in fucking Fahrenheit.
            
            % For V-HAB, we do this: Gain is one and the third factor is
            % the conversion from Kelvin to Fahrenheit
            fDeltaSteps = 58.8 * fDeltaTemperature / 1.8;
 
            this.iBPVCurrentSteps = this.iBPVCurrentSteps + fDeltaSteps;
                
            % Last conditional statement to avoid impossible motor steps
            % positions. if it falls below zero, sets it back to zero and
            % if rises above the maximum amount of steps sets it to the
            % maximum.
            if (this.iBPVCurrentSteps < 0)
                this.iBPVCurrentSteps = 0;
            elseif (this.iBPVCurrentSteps > this.iValveMaximumSteps)
                this.iBPVCurrentSteps = this.iValveMaximumSteps;
            end
            
            if ~base.oDebug.bOff
                this.out(1,1,'SWME BPV Position','BPV Position Update');
                this.out(1,2,'SWME BPV Position','Delta Steps: %f',{fDeltaSteps});
                this.out(1,2,'SWME BPV Position','Current Position: %f',{this.iBPVCurrentSteps});
            end
            
            this.updateBPVFlow();
        end
        
        function setEnvironmentReference(this, oPhase)
            this.oEnvironment = oPhase;
        end
        
    end
    
    
    methods (Access= protected)
        function exec(this, ~)
            exec@vsys(this);
            
            % Running the BPV controller
            this.updateBPVPosition();
        end
    end
end


