classdef Example < vsys
%   EXAMPLE Example system to demonstrate the use of the SWME component
%   
%   This system contains two tanks and a subsystem in between. The
%   subsystem represents the Spacesuit Water Membrane Evaporator (SWME)
%   component, which is used for spacesuit cooling. The user can set the
%   water flow rate and inlet temperature for the SWME here, all other 

    properties
        % Inlet water flow in [kg/s]
        fFlowRate = 91/3600;
        
        % Initial inlet water temperature in [K]
        fInitialTemperature = 288.15;
    end
    
    methods
        function this = Example(oParent, sName)
            this@vsys(oParent, sName, 0.1);
            
            % Setting parameters if they were set by a simulation runner
            eval(this.oRoot.oCfgParams.configCode(this));
            
            % Creating the SWME
            components.matter.SWME(this, 'SWME', this.fInitialTemperature);
            
        end
        
        function createMatterStructure(this)
            
            createMatterStructure@vsys(this);
            
            % Creating the inlet water feed tank
            matter.store(this, 'InletTank', 10);
            
            % Adding a liquid water phase to the inlet tank
            oWaterInlet = matter.phases.liquid(...
                this.toStores.InletTank, ...       % Store in which the phase is located
                'WaterInlet', ...                  % Phase name
                struct('H2O', 2000), ...           % Phase contents
                this.fInitialTemperature, ...      % Phase temperature
                28300);                            % Phase pressure
            
            % Creating the outlet water feed tank
            matter.store(this, 'OutletTank', 10);
            
            % Adding an empty phase to the outlet tank, representing an
            % empty tank
            oWaterOutlet = matter.phases.liquid(...
                this.toStores.OutletTank, ...      % Store in which the phase is located
                'WaterOutlet', ...                 % Phase name
                struct('H2O', 0), ...              % Phase contents
                this.fInitialTemperature, ...      % Phase temperature
                28300);                            % Phase pressure
            
             % Creating an empty tank where the vapor flows to, simulating
            % the environment (can be vacuum or planetary atmosphere)
            matter.store(this, 'EnvironmentTank', 10);
            
            % Adding an empty phase to the environment tank, representing
            % an empty tank
            oEnvironment = matter.phases.boundary.gas(...
                this.toStores.EnvironmentTank, ...        % Store in which the phase is located
                'EnvironmentPhase', ...                   % Phase name
                struct('H2O', 0), ...                     % Phase contents
                10, ...                                   % Phase volume
                293,...                                   % Phase temperature
                0);                                       % Phase pressure
            
            % Two standard pipes, which connect the SWME to the super
            % system
            components.matter.pipe(this, 'Pipe_Inlet', 0.01, 0.0127);
            components.matter.pipe(this, 'Pipe_Outlet', 0.01, 0.0127);
            
            % Creating the flowpath between the components.
            matter.branch(this, 'SWME_Inlet', {'Pipe_Inlet'}, oWaterInlet, 'InletBranch');
            matter.branch(this, 'SWME_Outlet', {'Pipe_Outlet'}, oWaterOutlet, 'OutletBranch');
            matter.branch(this, 'SWME_Vapor', {}, oEnvironment, 'VaporBranch');
            
            this.toChildren.SWME.setInterfaces('SWME_Inlet','SWME_Outlet', 'SWME_Vapor');
            
            this.toChildren.SWME.setEnvironmentReference(oEnvironment);
            
        end
        
        function createThermalStructure(this)
            % This function creates all simulation objects in the thermal
            % domain. 
            
            % First we always need to call the createThermalStructure()
            % method of the parent class.
            createThermalStructure@vsys(this);
            
            % We need to do nothing else here for this simple model. All
            % thermal domain objects related to advective (mass-based) heat
            % transfer will automatically be created by the
            % setThermalSolvers() method. 
            % Here one would create simulation objects for radiative and
            % conductive heat transfer.
            
        end
        
        function createSolverStructure(this)
            
            createSolverStructure@vsys(this);
            
            % Manually setting the inlet flow rate.
            this.toChildren.SWME.toBranches.InletBranch.oHandler.setFlowRate(-1 * this.fFlowRate);
            
            % Since we want V-HAB to calculate the temperature changes in
            % this system we call the setThermalSolvers() method of the
            % thermal.container class. 
            this.setThermalSolvers();
        end
        
    end
    
    
    
    methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
        end
    end
end

