classdef SWME < vsys
    % SWMELOOP is the simulation of the Space Suit Water Membrane Evaporator designed for
    % the AEMU
    %
    % The SWMELoop contains:
    % -an inlet matter store filled with warm water
    
    % -an outlet matter store where the cold water flows to
    
    % -an empty matter store with a constant pressure exme representing the
    %  vacuum of space, where the water vapor flows
    
    % -two pipes connecting both of the matter stores to the SWME
    
    % -the SWME (roth.swme.stores.SWME)
    
    % -the backpressure valve (f2f processor) which controls the vapor flow
    %  from the SWME to space (roth.swme.procs.BPV)
    
    properties
        
        % tParam is a struct containing most of the important parameters
        % needed to adjust the simulation for different scenarios, without
        % having to search each property in its class and changing them
        % individually, e.g. 

        
        tParam = struct(...
            'WaterInletFlux',           91/3600, ...      %[kg/s]  Inlet water flux, defined by user
            'fInitialInletTemperature', 289.15, ...       %[K]     Initial inlet temperature, defined by user
            'fSWMEVolume',              9.620939e-4, ...  %[m^3]   Total internal volume of the SWME
            'fSWMEVaporVolume',         8.7395e-4 ...     %[m^3]   (SWME volume - HoFI volume)
            );
        
        % The external pressure is set to zero for a simulation of an EVA
        % in space, but can be changed to the atmospheric pressure of Mars
        % for a Mars EVA simulation.
        fEnvironmentalPressure = 0;
        
        fTimeSinceLastIncrease = 0;
        
        
    end
    
    methods
        function this = SWME(oParent, sName)
            
            % For normal simulations 0.001 is a good interval for the
            % exec() method being called without compromising the stability
            % of the simulation. Higher intervals could also be used. For
            % simulations where the external pressure is ~=0, in Mars
            % atmosphere simulations for example, the interval needs to be
            % decreased so the simulation stays stable. A good interval for
            % external pressures of 1000Pa is 0.00005.
            this@vsys(oParent, sName);%, 0.001);
            
            this.bExecuteContainer = false;
            
        end
        
        function createMatterStructure(this)
            
            createMatterStructure@vsys(this);
            
            % Creating the inlet water feed tank
            matter.store(this, 'InletTank', 10);
            
            % Adding a liquid water phase to the inlet tank
            oWaterInlet = matter.phases.liquid(this.toStores.InletTank, ...          % Store in which the phase is located
                'WaterInlet', ...                         % Phase name
                struct('H2O', 2000), ...                  % Phase contents
                2, ...                                    % Phase volume
                this.tParam.fInitialInletTemperature, ... % Phase temperature
                28300);                                   % Phase pressure
            
            % Setting the phase to synced
            %CHECK Do we need this?
            oWaterInlet.bSynced  = true;
            
            % Creating the outlet water feed tank
            matter.store(this, 'OutletTank', 10);
            
            % Adding an empty phase to the outlet tank, representing an
            % empty tank
            oWaterOutlet = matter.phases.liquid(this.toStores.OutletTank, ...        % Store in which the phase is located
                'WaterOutlet', ...                        % Phase name
                struct('H2O', 0), ...                     % Phase contents
                0.001, ...                                % Phase volume
                this.tParam.fInitialInletTemperature, ... % Phase temperature
                28300);                                   % Phase pressure
            
            % Setting the phase to synced
            %CHECK Do we need this?
            oWaterOutlet.bSynced = true;
            
            % Creating an empty tank where the vapor flows to, simulating
            % the environment (can be vacuum or planetary atmosphere)
            matter.store(this, 'EnvironmentTank', 10);
            
            % Adding an empty phase to the environment tank, representing
            % an empty tank
            oEnvironment = matter.phases.gas(this.toStores.EnvironmentTank, ...                % Store in which the phase is located
                'VaporEnvironment', ...                   % Phase name
                struct('H2O', 0), ...                     % Phase contents
                0.001, ...                                % Phase volume
                293);                                     % Phase temperature
            
            % Setting the phase to synced
            %CHECK Do we need this?
            oEnvironment.bSynced = true;
            
            % Creating the SWME
            roth.swme.stores.SWMEStore(this, 'SWMEStore', this.tParam);
            
            % Two standard pipes, which connect the feed tanks to the SWME
            components.pipe(this, 'Pipe_1', 0.01, 0.0127);
            components.pipe(this, 'Pipe_2', 0.01, 0.0127);
            
            % Adding extract/merge processors to the phase
            matter.procs.exmes.liquid(oWaterInlet, 'FeedInlet');
            matter.procs.exmes.liquid(oWaterOutlet, 'FeedOutlet');
            
            % Special exme with a constant pressure, set on the initial
            % parameters
            oExme = special.matter.const_press_exme(oEnvironment, 'ToEnvironment', this.fEnvironmentalPressure);
            
            % Creating the BPV, passing the constant pressure exme as the
            % reference for the environmental pressure.
            roth.swme.procs.BPV(this, 'BPV', oExme);
            % Setting the initial temperature set point for the controller
            % contained in the BPV in [K]
            this.toProcsF2F.BPV.setTemperatureSetPoint(283.15);
            
            % We need to change the outlet temperature via a f2f processor,
            % which we create here.
            oProc = roth.swme.procs.TemperatureProcessor(this, 'TemperatureProcessor');
            
            % We also have to tell the P2P Processor in the SWME, that this
            % is the processor it is linked to.
            this.toStores.SWMEStore.setTemperatureProcessor(oProc);
            
            % Flow from the inlet feed tank,  flowing through pipe 1,
            % entering the SWME
            matter.branch(this, 'InletTank.FeedInlet', {'Pipe_1'}, 'SWMEStore.WaterIn', 'InletBranch');
            
            % Flow exiting the SWME, flowing through pipe 2, entering the
            % outlet water tank
            matter.branch(this, 'SWMEStore.WaterOut', {'TemperatureProcessor', 'Pipe_2'}, 'OutletTank.FeedOutlet', 'OutletBranch');
            
            % Flow exiting the SWME through the BPV to the VacuumTank
            % (space)
            matter.branch(this, 'SWMEStore.VaporOut', {'BPV'}, 'EnvironmentTank.ToEnvironment', 'EnvironmentBranch');
            
        end
        
        function createSolverStructure(this)
            
            createSolverStructure@vsys(this);
            
            % Creating references to branches in order to set flow rate manually later
            solver.matter.manual.branch(this.toBranches.InletBranch);
            solver.matter.manual.branch(this.toBranches.OutletBranch);
            solver.matter.manual.branch(this.toBranches.EnvironmentBranch);
            
            % Binding the setFlowRate() methods of the outlet and vacuum
            % solver branches to the inlet branches' 'outdated' event. 
            this.toBranches.InletBranch.bind('outdated', @(~) this.toBranches.EnvironmentBranch.oHandler.setFlowRate(this.toProcsF2F.BPV.fVaporFlowRate));
            this.toBranches.InletBranch.bind('outdated', @(~) this.toBranches.OutletBranch.oHandler.setFlowRate(this.toBranches.InletBranch.fFlowRate - this.toStores.SWMEStore.toProcsP2P.X50Membrane.fWaterVaporFlowRate));
            
            % Manually setting the inlet flow rate.
            this.toBranches.InletBranch.oHandler.setFlowRate(this.tParam.WaterInletFlux);
            
        end
    end
    
    
    methods (Access= protected)
        function exec(this, ~)
            
            exec@vsys(this);
            
            
            %%%%%%%%%%%%%%%%%%%changing inlet temperature%%%%%%%%%%%%%%%%%%
            
            %Sets a new random inlet temperature every x seconds defined in
            %fTimeForNextIncrease. The new temperature is an integer
            %between the values [y z] defined in randi. The 1,1 defines the
            %size of the matrix, in this case just 1x1.
            
            %fTimeForNextIncrease = 5;
            
            %if (this.oTimer.fTime > (fTimeForNextIncrease + this.fTimeSinceLastIncrease))
            
            %    this.toStores.InletTank.aoPhases(1).setTemp(this.tParam.InitialInletTemperature + randi([-2 2],1,1));
            
            %    this.fTimeSinceLastIncrease = this.oTimer.fTime;
            %end
            
            
            
            %Increases the inlet temperature gradually
            %this.toStores.InletTank.aoPhases(1).setTemp(this.tParam.InitialInletTemperature + 0.3*this.oTimer.fTime);
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            
            %%manually setting the flow rates of each branch
            
            %this.toBranches.oVacuumBranch.setFlowRate(this.toProcsF2F.BPV.fVaporFlux);
            
            %this.toBranches.oInletBranch.setFlowRate(this.tParam.WaterInletFlux);
            
            %this.toBranches.oOutletBranch.setFlowRate((this.tParam.WaterInletFlux - this.toStores.SWMEStore.toProcsP2P.X50Membrane.fWaterVaporFlux));
        end
    end
end


