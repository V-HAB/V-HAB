classdef Example_4 < vsys
    %EXAMPLE Example simulation for a simple flow in V-HAB 2.0
    %   Two tanks filled with gas at different pressures and a pipe in between
    
    properties (SetAccess = protected, GetAccess = public)
        fPipeLength   = 0.5;
        fPipeDiameter = 0.0254/3; 
    end
    
    methods
        function this = Example_4(oParent, sName)
            this@vsys(oParent, sName, 100);
            
            
            eval(this.oRoot.oCfgParams.configCode(this));
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            
            matter.store(this, 'Store', 100);
            this.toStores.Store.createPhase('N2Atmosphere', this.toStores.Store.fVolume);
            special.matter.const_press_exme(this.toStores.Store.aoPhases(1), 'Port_Out', 600 + this.toStores.Store.aoPhases(1).fPressure);
            special.matter.const_press_exme(this.toStores.Store.aoPhases(1), 'Port_Rtn', this.toStores.Store.aoPhases(1).fPressure);
            
            
            
            iValves = 4;
            
            for iT = 1:iValves
                sN = sprintf('Valve_%i', iT);
                
                matter.store(this, sN, 1e-6);
                cParams = matter.helper.phase.create.N2Atmosphere(this, this.toStores.(sN).fVolume);
                matter.phases.gas_flow_node(this.toStores.(sN), 'flow', cParams{:});
                matter.procs.exmes.gas(this.toStores.(sN).aoPhases(1), 'Port_1');
                matter.procs.exmes.gas(this.toStores.(sN).aoPhases(1), 'Port_2');
                matter.procs.exmes.gas(this.toStores.(sN).aoPhases(1), 'Port_3');
            
            end
            
            for iP = 1:(iValves + 3)
                components.pipe(this, sprintf('Pipe_%i', iP),  this.fPipeLength, this.fPipeDiameter);
            end
            
            % Resistors
            components.pipe(this, 'R_1',  0.1, 0.001);
            components.pipe(this, 'R_2',  0.1, 0.001);
            components.pipe(this, 'R_3',  0.1, 0.001);
            components.pipe(this, 'R_4',  0.1, 0.001);
            components.pipe(this, 'R_5',  0.1, 0.001);
            
            
            matter.branch(this, 'Store.Port_Out', { 'Pipe_1' }, 'Valve_1.Port_1');
            
            %matter.branch(this, 'Valve_1.Port_2', { 'Pipe_2', 'R_2' }, 'Valve_2.Port_1');
            matter.branch(this, 'Valve_1.Port_2', { 'Pipe_2' }, 'Valve_2.Port_1');
            
            matter.branch(this, 'Valve_1.Port_3', { 'Pipe_3' }, 'Valve_3.Port_1');
            
            matter.branch(this, 'Valve_2.Port_2', { 'Pipe_4', 'R_4', 'R_5' }, 'Valve_3.Port_2');
            %matter.branch(this, 'Valve_2.Port_2', { 'Pipe_4' }, 'Valve_3.Port_2');
            
            %matter.branch(this, 'Valve_2.Port_3', { 'Pipe_5', 'R_1', 'R_3' }, 'Valve_4.Port_1');
            matter.branch(this, 'Valve_2.Port_3', { 'Pipe_5', 'R_1' }, 'Valve_4.Port_1');
            %matter.branch(this, 'Valve_2.Port_3', { 'Pipe_5' }, 'Valve_4.Port_1');
            
            matter.branch(this, 'Valve_3.Port_3', { 'Pipe_6' }, 'Valve_4.Port_2');
            matter.branch(this, 'Valve_4.Port_3', { 'Pipe_7' }, 'Store.Port_Rtn');
        end
        
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            % Set CPE pressures from phase
            fPressure = this.toStores.Store.aoPhases(1).fPressure;
            
            this.toStores.Store.aoPhases(1).coProcsEXME{1}.fPortPressure = fPressure + 600;
            this.toStores.Store.aoPhases(1).coProcsEXME{2}.fPortPressure = fPressure;
            
            
            solver.matter_multibranch.laminar_incompressible.branch(this.aoBranches, 'complex');
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
        end
        
     end
    
end

