classdef Example < vsys
    %EXAMPLE Example simulation for a simple flow in V-HAB 2.0
    %   Two tanks filled with gas at different pressures and a pipe in between
    
    properties (SetAccess = protected, GetAccess = public)
        fPipeLength   = 0.5;
        fPipeDiameter = 0.01; %% for 3/5 mm overflow of warnings
        
        oManual;
    end
    
    methods
        function this = Example(oParent, sName)
            this@vsys(oParent, sName, 100);
            
            
            eval(this.oRoot.oCfgParams.configCode(this));
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            
            
            matter.store(this, 'Vacuum', 1);
            this.toStores.Vacuum.createPhase('air',  1);
            matter.procs.exmes.gas(this.toStores.Vacuum.aoPhases(1), 'Port_1');
            %%%
            %matter.procs.exmes.gas(this.toStores.Vacuum.aoPhases(1), 'Port_2');
            
            %%special.matter.const_press_exme(this.toStores.Vacuum.aoPhases(1), 'Port_2', 0);
            matter.procs.exmes.gas(this.toStores.Vacuum.aoPhases(1), 'Port_2');
            
            
            
            
            matter.store(this, 'Store', 1);
            this.toStores.Store.createPhase('air', this.toStores.Store.fVolume);
            %%%special.matter.const_press_exme(this.toStores.Store.aoPhases(1), 'Port_Out', 600 + this.toStores.Store.aoPhases(1).fPressure);
            %%%special.matter.const_press_exme(this.toStores.Store.aoPhases(1), 'Port_Rtn', this.toStores.Store.aoPhases(1).fPressure);
            
            %%matter.procs.exmes.gas(this.toStores.Store.aoPhases(1), 'Port_Out');
            matter.procs.exmes.gas(this.toStores.Store.aoPhases(1), 'Port_Out');
            
            
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
            matter.procs.exmes.gas(this.toStores.Filter.aoPhases(1), 'Filtered');
            
            %this.toStores.Filter.createPhase('air', 'adsorbed', 0);
            
            
            
            
            %P2P!
            %components.matter.generic.filter(this.toStores.Filter, 'co2_filter', 'flow', 'adsorbed', 'CO2', inf);%0.01);
            %components.matter.generic.filter(this.toStores.Filter, 'co2_filter', 'flow', 'adsorbed', 'CO2', 0.001, 1);%inf);%0.01);
            %components.matter.generic.filter(this.toStores.Filter, 'a_filter', 'flow', 'adsorbed', 'CO2', 0.05);%0.01);
            
            %%components.matter.generic.filter(this.toStores.Filter, 'a_filter', 'flow', 'adsorbed', 'CO2', 0.01, 2);%0.01);
            %components.matter.generic.filter(this.toStores.Filter, 'a_filter', 'flow', 'adsorbed', 'CO2', 0.025);
            
            
            matter.store(this, 'Valve_2', 1e-6);
            cParams = matter.helper.phase.create.air(this, this.toStores.Valve_2.fVolume);
            matter.phases.flow.gas(this.toStores.Valve_2, 'flow', cParams{:});
            matter.procs.exmes.gas(this.toStores.Valve_2.aoPhases(1), 'In'); 
            matter.procs.exmes.gas(this.toStores.Valve_2.aoPhases(1), 'Out'); 
            
            fRoughness = 0;% 0.002;
            
            components.matter.pipe(this, 'Pipe_Store_Valve1_1',  this.fPipeLength, this.fPipeDiameter, fRoughness);
            components.matter.pipe(this, 'Pipe_Store_Valve1_2',  this.fPipeLength, this.fPipeDiameter, fRoughness);
            components.matter.pipe(this, 'Pipe_Valve1_Filter_1', this.fPipeLength, this.fPipeDiameter, fRoughness);
            components.matter.pipe(this, 'Pipe_Valve1_Filter_2', this.fPipeLength, this.fPipeDiameter, fRoughness);
            components.matter.pipe(this, 'Pipe_Filter_Valve2_1', this.fPipeLength, this.fPipeDiameter, fRoughness);
            components.matter.pipe(this, 'Pipe_Filter_Valve2_2', this.fPipeLength, this.fPipeDiameter, fRoughness);
            components.matter.pipe(this, 'Pipe_Valve2_Store_1',  this.fPipeLength, this.fPipeDiameter, fRoughness);
            components.matter.pipe(this, 'Pipe_Valve2_Store_2',  this.fPipeLength, this.fPipeDiameter, fRoughness);
            
            
            matter.branch(this, 'Store.Port_Out', { 'Pipe_Store_Valve1_1',  'Pipe_Store_Valve1_2'  }, 'Valve_1.In');
            matter.branch(this, 'Valve_1.Out',    { 'Pipe_Valve1_Filter_1', 'Pipe_Valve1_Filter_2' }, 'Filter.In');
            matter.branch(this, 'Filter.Out',     { 'Pipe_Filter_Valve2_1', 'Pipe_Filter_Valve2_2' }, 'Valve_2.In');
            
            %%%
            %%%matter.branch(this, 'Valve_2.Out',    { 'Pipe_Valve2_Store_1',  'Pipe_Valve2_Store_2'  }, 'Store.Port_Rtn');
            matter.branch(this, 'Valve_2.Out',    { 'Pipe_Valve2_Store_1',  'Pipe_Valve2_Store_2'  }, 'Vacuum.Port_2');
            
            
            matter.branch(this, 'Filter.Filtered', {}, 'Vacuum.Port_1');
            %TODO something like
            %matter.branch(this, 'Filter.Filtered', {}, oVacuum.createNewPortAndGetName());
        end
        
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            % Set CPE pressures from phase
            %%%
            %%%fPressure = this.toStores.Store.aoPhases(1).fPressure;
            
            %%%this.toStores.Store.aoPhases(1).coProcsEXME{1}.fPortPressure = fPressure + 600;
            %%%this.toStores.Store.aoPhases(1).coProcsEXME{2}.fPortPressure = fPressure;
            %%%
            
            tProps.rMaxChange = 0.01;
            this.toStores.Store.aoPhases(1).setTimeStepProperties(tProps);
            this.toStores.Vacuum.aoPhases(1).setTimeStepProperties(tProps);
            %this.toStores.Filter.aoPhases(2).rMaxChange = 0.15;
            %this.toStores.Filter.aoPhases(2).rMaxChange = 0.01;
            
            
            %this.toStores.Filter.aoPhases(2).rMaxChange = 5;
            %this.toStores.Filter.aoPhases(2).rMaxChange = 0.01;
            % Hack
            %this.toStores.Filter.aoPhases(2).setVolume(10000);
            
            solver.matter_multibranch.iterative.branch(this.aoBranches(1:4));
            
            
            this.oManual = solver.matter.manual.branch(this.aoBranches(5));
            
            this.oManual.setFlowRate(0.01);
            
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

