classdef Example < vsys
    %EXAMPLE Example simulation for a simple flow in V-HAB 2.0
    %   Two tanks filled with gas at different pressures and a pipe in between
    
    properties (SetAccess = protected, GetAccess = public)
        fPipeLength   = 1.5;
        fPipeDiameter = 0.005;
        
        % Pressure difference in bar
        fPressureDifference = 1;
    end
    
    methods
        function this = Example(oParent, sName)
            this@vsys(oParent, sName, 30);
            
            eval(this.oRoot.oCfgParams.configCode(this));
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            % Creating a store, volume 1 m^3
            matter.store(this, 'Tank_1', 10000);
            this.toStores.Tank_1.createPhase('air', this.toStores.Tank_1.fVolume * (this.fPressureDifference + 1));
            matter.procs.exmes.gas(this.toStores.Tank_1.aoPhases(1), 'Port');
            %special.matter.const_press_exme(this.toStores.Tank_1.aoPhases(1), 'Port', 2e5);
            
            matter.store(this, 'Tank_2', 10000);
            %this.toStores.Tank_2.createPhase('air', this.toStores.Tank_2.fVolume * (this.fPressureDifference / 2 + 1));
            this.toStores.Tank_2.createPhase('air', this.toStores.Tank_2.fVolume);
            matter.procs.exmes.gas(this.toStores.Tank_2.aoPhases(1), 'Port');
            %matter.procs.exmes.gas(this.toStores.Tank_2.aoPhases(1), 'Port_Out');
            
            matter.store(this, 'Tank_3', 10000);
            this.toStores.Tank_3.createPhase('air', this.toStores.Tank_3.fVolume);
            matter.procs.exmes.gas(this.toStores.Tank_3.aoPhases(1), 'Port');
            %special.matter.const_press_exme(this.toStores.Tank_3.aoPhases(1), 'Port', 1e5);
            
            
            
            
            
            matter.store(this, 'Junction_1', 0.0001);
% %             this.toStores.Junction_1.createPhase('air', this.toStores.Junction_1.fVolume);
            cParams = matter.helper.phase.create.air(this, this.toStores.Junction_1.fVolume);
            matter.phases.gas_flow_node(this.toStores.Junction_1, 'flow', cParams{:});
            
            matter.procs.exmes.gas(this.toStores.Junction_1.aoPhases(1), 'Port_1');
            matter.procs.exmes.gas(this.toStores.Junction_1.aoPhases(1), 'Port_2');
            matter.procs.exmes.gas(this.toStores.Junction_1.aoPhases(1), 'Port_3');
            
            
            
            
            %components.pipe(this, 'Pipe_12', this.fPipeLength, this.fPipeDiameter);
            %components.pipe(this, 'Pipe_23', this.fPipeLength, this.fPipeDiameter);
            %components.valve_pressure_drop(this, 'Pipe_12', 0.19);
            %components.valve_pressure_drop(this, 'Pipe_23', 0.19);
            
            %components.linear_drop(this, 'Pipe_1T', 1e7);
            %components.linear_drop(this, 'Pipe_2T', 1e7);
            %components.linear_drop(this, 'Pipe_3T', 1e7);
            components.valve_pressure_drop(this, 'Pipe_1T', 0.19);
            components.valve_pressure_drop(this, 'Pipe_2T', 0.19);
            components.valve_pressure_drop(this, 'Pipe_3T', 0.19);
            
            %matter.branch(this, 'Tank_1.Port', {'Pipe_12'}, 'Tank_2.Port_In');
            %matter.branch(this, 'Tank_2.Port_Out', {'Pipe_23'}, 'Tank_3.Port');
            matter.branch(this, 'Tank_1.Port', {'Pipe_1T'}, 'Junction_1.Port_1');
            matter.branch(this, 'Tank_2.Port', {'Pipe_2T'}, 'Junction_1.Port_2');
            matter.branch(this, 'Tank_3.Port', {'Pipe_3T'}, 'Junction_1.Port_3');
        end
        
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
%             this.toStores.Junction_1.aoPhases(1).bSynced = true;
%             
%             solver.matter.iterative.branch(this.aoBranches(1));
%             solver.matter.iterative.branch(this.aoBranches(2));
%             solver.matter.iterative.branch(this.aoBranches(3));
            
            solver.matter.linearized.branch(this.aoBranches(1));
            solver.matter.linearized.branch(this.aoBranches(2));
            solver.matter.linearized.branch(this.aoBranches(3));
            
            solver.matter.linearized.controller(this.aoBranches);
            
            this.setThermalSolvers();
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            % exec(ute) function for this system
            % Here it only calls its parent's exec function
            exec@vsys(this);
        end
        
     end
    
end

