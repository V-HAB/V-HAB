classdef Example_69 < vsys
    %EXAMPLE Example simulation for a simple flow in V-HAB 2.0
    %   Two tanks filled with gas at different pressures and a pipe in between
    
    properties (SetAccess = protected, GetAccess = public)
        fPipeLength   = 1.5;
        fPipeDiameter = 0.0254/3;
        
        oManual;
    end
    
    methods
        function this = Example_69(oParent, sName)
            this@vsys(oParent, sName, 100);
            
            
            eval(this.oRoot.oCfgParams.configCode(this));
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            
            
%             matter.store(this, 'Vacuum', 10000);
%             this.toStores.Vacuum.createPhase('air', 0.001 * 10000);
%             matter.procs.exmes.gas(this.toStores.Vacuum.aoPhases(1), 'Port_1');
%             %%%
%             %matter.procs.exmes.gas(this.toStores.Vacuum.aoPhases(1), 'Port_2');
%             special.matter.const_press_exme(this.toStores.Vacuum.aoPhases(1), 'Port_2', 0);
            
            
            
            
            matter.store(this, 'Store', 1000);
            this.toStores.Store.createPhase('air', this.toStores.Store.fVolume);
            %%%special.matter.const_press_exme(this.toStores.Store.aoPhases(1), 'Port_Out', 600 + this.toStores.Store.aoPhases(1).fPressure);
            %%%special.matter.const_press_exme(this.toStores.Store.aoPhases(1), 'Port_Rtn', this.toStores.Store.aoPhases(1).fPressure);
            matter.procs.exmes.gas(this.toStores.Store.aoPhases(1), 'Port_Out');
            matter.procs.exmes.gas(this.toStores.Store.aoPhases(1), 'Port_Return');
            
            
            matter.store(this, 'Valve_0', 1e-6);
            cParams = matter.helper.phase.create.air(this, this.toStores.Valve_0.fVolume);
            matter.phases.flow.gas(this.toStores.Valve_0, 'flow', cParams{:});
            matter.procs.exmes.gas(this.toStores.Valve_0.aoPhases(1), 'In'); 
            matter.procs.exmes.gas(this.toStores.Valve_0.aoPhases(1), 'Out');
            
            
            matter.store(this, 'Valve_1', 1e-6);
            cParams = matter.helper.phase.create.air(this, this.toStores.Valve_1.fVolume);
            matter.phases.flow.gas(this.toStores.Valve_1, 'flow', cParams{:});
            matter.procs.exmes.gas(this.toStores.Valve_1.aoPhases(1), 'In'); 
            matter.procs.exmes.gas(this.toStores.Valve_1.aoPhases(1), 'Out');
            
            
            
            matter.store(this, 'Filter', 1e-1);
            cParams = matter.helper.phase.create.air(this, this.toStores.Filter.fVolume);
            matter.phases.flow.gas(this.toStores.Filter, 'flow', cParams{:});
            matter.procs.exmes.gas(this.toStores.Filter.aoPhases(1), 'In');
            matter.procs.exmes.gas(this.toStores.Filter.aoPhases(1), 'Out');
            
            this.toStores.Filter.createPhase('air', 'adsorbed', 0);
            
            
            
            
            %P2P!
            %components.generic.filter(this.toStores.Filter, 'co2_filter', 'flow', 'adsorbed', 'CO2', inf);%0.01);
            %components.generic.filter(this.toStores.Filter, 'co2_filter', 'flow', 'adsorbed', 'CO2', 0.001, 1);%inf);%0.01);
            %components.generic.filter(this.toStores.Filter, 'a_filter', 'flow', 'adsorbed', 'CO2', 0.05);%0.01);
            
            components.generic.filter(this.toStores.Filter, 'a_filter', 'flow', 'adsorbed', 'CO2', 0.25, 2);%0.01);
            %components.generic.filter(this.toStores.Filter, 'a_filter', 'flow', 'adsorbed', 'CO2', 0.025);
            
            
            matter.store(this, 'Valve_2', 1e-6);
            cParams = matter.helper.phase.create.air(this, this.toStores.Valve_2.fVolume);
            matter.phases.flow.gas(this.toStores.Valve_2, 'flow', cParams{:});
            matter.procs.exmes.gas(this.toStores.Valve_2.aoPhases(1), 'In'); 
            matter.procs.exmes.gas(this.toStores.Valve_2.aoPhases(1), 'Out'); 
            
            
            
            %components.fan(this, 'Fan_Valve0_Valve1', 5*40000, 'Left2Right');
            components.fan(this, 'Fan_Valve0_Valve1', 17.5*40000, 'Left2Right');
            %components.fan(this, 'Fan_Valve0_Valve1', 10000, 'Left2Right');
            this.fPipeDiameter = this.fPipeDiameter * 1.5;
            
            components.pipe(this, 'Pipe_Store_Valve0_1',  this.fPipeLength, this.fPipeDiameter);
            components.pipe(this, 'Pipe_Store_Valve0_2',  this.fPipeLength, this.fPipeDiameter);
            components.pipe(this, 'Pipe_Valve1_Filter_1', this.fPipeLength, this.fPipeDiameter);
            components.pipe(this, 'Pipe_Valve1_Filter_2', this.fPipeLength, this.fPipeDiameter);
            components.pipe(this, 'Pipe_Filter_Valve2_1', this.fPipeLength, this.fPipeDiameter);
            components.pipe(this, 'Pipe_Filter_Valve2_2', this.fPipeLength, this.fPipeDiameter);
            components.pipe(this, 'Pipe_Valve2_Store_1',  this.fPipeLength, this.fPipeDiameter);
            components.pipe(this, 'Pipe_Valve2_Store_2',  this.fPipeLength, this.fPipeDiameter);
            
            
            matter.branch(this, 'Store.Port_Out', { 'Pipe_Store_Valve0_1',  'Pipe_Store_Valve0_2'  }, 'Valve_0.In');
            matter.branch(this, 'Valve_0.Out',    { 'Fan_Valve0_Valve1' }, 'Valve_1.In');
            matter.branch(this, 'Valve_1.Out',    { 'Pipe_Valve1_Filter_1', 'Pipe_Valve1_Filter_2' }, 'Filter.In');
            matter.branch(this, 'Filter.Out',     { 'Pipe_Filter_Valve2_1', 'Pipe_Filter_Valve2_2' }, 'Valve_2.In');
            
            matter.branch(this, 'Valve_2.Out',    { 'Pipe_Valve2_Store_1',  'Pipe_Valve2_Store_2'  }, 'Store.Port_Return');
            
        end
        
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            % Set CPE pressures from phase
            %%%
            %%%fPressure = this.toStores.Store.aoPhases(1).fPressure;
            
            %%%this.toStores.Store.aoPhases(1).coProcsEXME{1}.fPortPressure = fPressure + 600;
            %%%this.toStores.Store.aoPhases(1).coProcsEXME{2}.fPortPressure = fPressure;
            %%%
            
            
            %this.toStores.Store.aoPhases(1).rMaxChange  = 0.05;
            %this.toStores.Filter.aoPhases(2).rMaxChange = 0.15;
            %this.toStores.Filter.aoPhases(2).rMaxChange = 0.01;
            
            tTimeStepProperties.rMaxChange = 5;
            this.toStores.Filter.aoPhases(2).setTimeStepProperties(tTimeStepProperties);
            
            %this.toStores.Filter.aoPhases(2).rMaxChange = 0.01;
            % Hack
            %this.toStores.Filter.aoPhases(2).setVolume(10000);
            
            solver.matter_multibranch.iterative.branch(this.aoBranches(1:5), 'complex');
            
            
            %this.oManual = solver.matter.manual.branch(this.aoBranches(5));
            
%             this.oManual.setFlowRate(0.01);
            this.setThermalSolvers();
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
            
%             if this.oTimer.fTime == 540 %&& this.oManual.fFlowRate == 0.01
%                 this.oManual.setFlowRate(0.02);
%                 
%             elseif this.oTimer.fTime == 990 %&& this.oManual.fFlowRate == 0.02
%                 this.oManual.setFlowRate(0.005);
%                 
%             elseif this.oTimer.fTime == 1520 %&& this.oManual.fFlowRate == 0.005
%                 this.oManual.setFlowRate(0.01);
%                 
%             elseif this.oTimer.fTime == 2030 %&& this.oManual.fFlowRate == 0.01
%                 this.oManual.setFlowRate(0);
%                 
%             elseif this.oTimer.fTime >= 2500 && this.oTimer.fTime <= 3500
%                 this.oManual.setFlowRate(rand() * 0.01);
%                 
%             elseif this.oTimer.fTime == 3600
%                 this.oManual.setFlowRate(0);
%                 
%             end
        end
        
     end
    
end

