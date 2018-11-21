classdef Example < vsys
    %EXAMPLE Example simulation for a simple flow in V-HAB 2.0
    %   Two tanks filled with gas at different pressures and a pipe in between
    
    properties (SetAccess = protected, GetAccess = public)
        % manual or linear or iterative
        sSolvers = 'manual';
        
        % none, flow, filter. For filter - 2nd branch / manual -> residual!
        sMode = 'flow';
        
        % Main stores - volumes
        fStoreVolumes = 1000;
        
        
        fLastUpdate = -1;
    end
    
    methods
        function this = Example(oParent, sName)
            % Call parent constructor. Third parameter defined how often
            % the .exec() method of this subsystem is called. This can be
            % used to change the system state, e.g. close valves or switch
            % on/off components.
            % Values can be: 0-inf for interval in [s] (zero means with
            % lowest time step set for the timer). -1 means with every TICK
            % of the timer, which is determined by the smallest time step
            % of any of the systems. Providing a logical false (def) means
            % the .exec method is called when the oParent.exec() is
            % executed (see this .exec() method - always call exec@vsys as
            % well!).
            this@vsys(oParent, sName, 5000);
            
            eval(this.oRoot.oCfgParams.configCode(this));
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            if strcmp(this.sMode, 'flow') || strcmp(this.sMode, 'filter')
                matter.store(this, 'Tank_1', this.fStoreVolumes);
                this.toStores.Tank_1.createPhase('air', this.toStores.Tank_1.fVolume, [], [], 2e5);
                matter.procs.exmes.gas(this.toStores.Tank_1.aoPhases(1), 'Port');


                matter.store(this, 'Tank_2', this.fStoreVolumes);
                this.toStores.Tank_2.createPhase('air', 0);
                matter.procs.exmes.gas(this.toStores.Tank_2.aoPhases(1), 'Port');


                
                matter.store(this, 'Tank_Mid', this.fStoreVolumes);
                this.toStores.Tank_Mid.createPhase('air', 'flow_phase', this.toStores.Tank_Mid.fVolume);
                matter.procs.exmes.gas(this.toStores.Tank_Mid.aoPhases(1), 'Port_Left');
                matter.procs.exmes.gas(this.toStores.Tank_Mid.aoPhases(1), 'Port_Right');
                
                
                this.toStores.Tank_Mid.createPhase('air', 'filtered', 0);
                tests.performance_test.comps.DummyAdsorber(this.toStores.Tank_Mid, 'dummyDing', 'flow_phase', 'filtered', 'O2', inf);
            end
            
            
            if strcmp(this.sMode, 'flow')
                components.matter.pipe(this, 'Pipe_1', 2.5, 0.005);
                components.matter.pipe(this, 'Pipe_2', 2.5, 0.005);

                matter.branch(this, 'Tank_1.Port', {'Pipe_1'}, 'Tank_Mid.Port_Left');
                matter.branch(this, 'Tank_Mid.Port_Right', {'Pipe_2'}, 'Tank_2.Port');
            end
        end
        
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            
            if strcmp(this.sSolvers, 'manual')
                %oManual = solver.matter.manual.branch(this.aoBranches(1));
                %oManual.setFlowRate(0.002);
                
                %oManual = solver.matter.manual.branch(this.aoBranches(2));
                %oManual.setFlowRate(0.002);
                
                solver.matter.manual.branch(this.aoBranches(1));
                %solver.matter.manual.branch(this.aoBranches(2));
                solver.matter.residual.branch(this.aoBranches(2));
            end
            
            this.setThermalSolvers();
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            % exec(ute) function for this system
            % Here it only calls its parent's exec function
            exec@vsys(this);
            
            
            if this.oTimer.fTime > this.fLastUpdate
                fFlowRate = this.aoBranches(1).oHandler.fFlowRate + 0.002;
                
                if fFlowRate > 0.01 || fFlowRate == 0
                    fFlowRate = 0.002;
                end
                
                this.aoBranches(1).oHandler.setFlowRate(fFlowRate);
                %this.aoBranches(2).oHandler.setFlowRate(fFlowRate);
            end
        end
        
     end
    
end

