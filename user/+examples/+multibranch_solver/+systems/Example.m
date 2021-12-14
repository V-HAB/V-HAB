classdef Example < vsys
    %EXAMPLE Example simulation for a fan driven looped gas flow in V-HAB 2
    %   It includes 5 tanks which are connected in a loop. Two tanks
    %   represent a parallel flow path, for which either one of the two or
    %   both can be open. This behavior is controlled by valves. Two tanks
    %   contain flow phases, as the current implementation of the matter
    %   multibranch solver requires fans
  	%   to be placed in between two flow phases!
    
    properties
    end
    
    methods
        function this = Example(oParent, sName)
            this@vsys(oParent, sName, 100);
        end
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            matter.store(this, 'Tank_1', 1);
            oGasPhase1 = this.toStores.Tank_1.createPhase('air', 1);
            
            % In the implementation of the matter multibranch solver fans
            % currently must be placed in between two flow phases!
            matter.store(this, 'Tank_2', 1);
            oGasPhase2 = this.toStores.Tank_2.createPhase('air', 'flow', 1);
            
            matter.store(this, 'Tank_3', 1);
            oGasPhase3 = this.toStores.Tank_3.createPhase('air', 'flow', 1);
            
            matter.store(this, 'Tank_4', 1);
            oGasPhase4 = this.toStores.Tank_4.createPhase('air', 1);
            
            matter.store(this, 'Tank_5', 1);
            oGasPhase5 = this.toStores.Tank_5.createPhase('air', 1);
            
            oFan = components.matter.fan(this, 'Fan', 57500);
            oFan.fPowerFactor = 0;
            
            fRoughness = 2e-3;
            components.matter.pipe(this, 'Pipe_1', 1, 0.02, fRoughness);
            components.matter.pipe(this, 'Pipe_2', 1, 0.02, fRoughness);
            components.matter.pipe(this, 'Pipe_3', 1, 0.02, fRoughness);
            components.matter.pipe(this, 'Pipe_4', 1, 0.02, fRoughness);
            components.matter.pipe(this, 'Pipe_5', 1, 0.02, fRoughness);
            
            % Now we add two valves to control which part of the parallel
            % flow path shall be open:
            components.matter.valve(this, 'Valve_1', true);
            components.matter.valve(this, 'Valve_2', false);
            % We also add two check valves to prevent an unintentional back
            % flow in the parallel flow path
            components.matter.checkvalve(this, 'CheckValve_1');
            components.matter.checkvalve(this, 'CheckValve_2');
            
            matter.branch(this, oGasPhase1, {'Pipe_1'}, oGasPhase2);
            matter.branch(this, oGasPhase2, {'Fan'}, 	oGasPhase3);
            
            % Tank 4 and Tank 5 are used as the parallel flow path. They
            % are both connected to Tank 1 and Tank 3!
            matter.branch(this, oGasPhase3, {'Pipe_2', 'Valve_1'},      oGasPhase4);
            matter.branch(this, oGasPhase4, {'Pipe_3', 'CheckValve_1'},	oGasPhase1);
            matter.branch(this, oGasPhase3, {'Pipe_4', 'Valve_2'},      oGasPhase5);
            matter.branch(this, oGasPhase5, {'Pipe_5', 'CheckValve_2'},	oGasPhase1);
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            solver.matter_multibranch.iterative.branch(this.aoBranches);
            
            this.setThermalSolvers();
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            % exec(ute) function for this system
            % Here it only calls its parent's exec function
            exec@vsys(this);
            
            % The flowpath through valve 1 is initially open, after 600
            % seconds we open the flowpath through valve 2 and close valve
            % 1 and after another 600 seconds we open both valves:
            if this.oTimer.fTime > 1200 && ~this.toProcsF2F.Valve_1.bOpen
                this.toProcsF2F.Valve_1.setOpen(true);
                this.toProcsF2F.Valve_2.setOpen(true);
            elseif this.oTimer.fTime > 600 && ~this.toProcsF2F.Valve_2.bOpen
                this.toProcsF2F.Valve_1.setOpen(false);
                this.toProcsF2F.Valve_2.setOpen(true);
            end
            
        end
     end
end