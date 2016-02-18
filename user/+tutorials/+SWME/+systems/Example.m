classdef Example < vsys
%EXAMPLE Add a proper description here

    properties
        % Initial inlet water flow in [kg/s]
        fInitialFlowRate = 91/3600;
        
        % Initial inlet water temperature in [K]
        fInitialTemperature = 289.15;
    end
    
    methods
        function this = Example(oParent, sName)
            this@vsys(oParent, sName);
            
            % Instatiating the SWME
            components.SWME(this, 'SWME', this.fInitialTemperature);
            
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
                2, ...                             % Phase volume
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
                0.001, ...                         % Phase volume
                this.fInitialTemperature, ...      % Phase temperature
                28300);                            % Phase pressure
            
            % Adding extract/merge processors to the phase
            matter.procs.exmes.liquid(oWaterInlet, 'FeedInlet');
            matter.procs.exmes.liquid(oWaterOutlet, 'FeedOutlet');
            
            % Two standard pipes, which connect the SWME to the super
            % system
            components.pipe(this, 'Pipe_1', 0.01, 0.0127);
            components.pipe(this, 'Pipe_2', 0.01, 0.0127);
            
            % Flow from the inlet feed tank,  flowing through pipe 1,
            % entering the SWME
            matter.branch(this, 'SWME_In', {'Pipe_1'}, 'InletTank.FeedInlet');
            
            % Flow exiting the SWME, flowing through pipe 2, entering the
            % outlet water tank
            matter.branch(this, 'SWME_Out', {'Pipe_2'}, 'OutletTank.FeedOutlet');
            
            this.toChildren.SWME.setInterfaces('SWME_In', 'SWME_Out');
            
        end
        
        function createSolverStructure(this)
            
            createSolverStructure@vsys(this);
            
            % Manually setting the inlet flow rate.
            this.toChildren.SWME.toBranches.InletBranch.oHandler.setFlowRate(-1 * this.fInitialFlowRate);
            
        end
        
    end
    
    
    
    methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
        end
        
        
    end
end

