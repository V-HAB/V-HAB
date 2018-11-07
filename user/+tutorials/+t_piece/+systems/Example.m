classdef Example < vsys
    %EXAMPLE Example simulation for a simple flow in V-HAB 2.0
    %   Two tanks filled with gas at different pressures and a pipe in between
    
    properties (SetAccess = protected, GetAccess = public)
        fPipeLength   = 0.5;
        fPipeDiameter = 0.005;
        
        % Pressure difference in bar
        fPressureDifference = 1;
        
        % Empty by default - pipes used
        fTpieceLen;
        
        fStoreVols = 100;
        
        coSolvers = {};
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
            this@vsys(oParent, sName, 30);
            
            % Make the system configurable
%             disp(this);
%             disp('------------');
%             disp(this.oRoot.oCfgParams.configCode(this));
%             disp('------------');
%             disp(this.oRoot.oCfgParams.get(this));
%             disp('------------');
            eval(this.oRoot.oCfgParams.configCode(this));
            
            %disp(this);
            
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            % Create stores with one phase and one exme each!
            matter.store(this, 'Tank_1', this.fStoreVols);
            this.toStores.Tank_1.createPhase('air', 'air', (this.fPressureDifference + 1) * this.fStoreVols);
            matter.procs.exmes.gas(this.toStores.Tank_1.toPhases.air, 'Port');
            %special.matter.const_press_exme(this.toStores.Tank_1.toPhases.air, 'Port', (this.fPressureDifference + 1) * 101325);
            
            matter.store(this, 'Tank_2', this.fStoreVols);
            this.toStores.Tank_2.createPhase('air', 'air', this.fStoreVols);
            matter.procs.exmes.gas(this.toStores.Tank_2.toPhases.air, 'Port');
            %special.matter.const_press_exme(this.toStores.Tank_2.toPhases.air, 'Port', 101325);
            
            matter.store(this, 'Tank_3', this.fStoreVols);
            this.toStores.Tank_3.createPhase('air', 'air', this.fStoreVols);
            matter.procs.exmes.gas(this.toStores.Tank_3.toPhases.air, 'Port');
            %special.matter.const_press_exme(this.toStores.Tank_3.toPhases.air, 'Port', 101325);
            
            
            % Create T-Piece with three ports!
            if isempty(this.fTpieceLen)
                fGeometry = this.fPipeDiameter;
            else
                fGeometry = this.fTpieceLen;
            end
            fVolume = geometry.volumes.cube(fGeometry).fVolume;
            
            matter.store(this, 'T_Piece', fVolume);
            %this.toStores.T_Piece.createPhase('air', 'air', fVolume * (this.fPressureDifference / 2 + 1));
            this.toStores.T_Piece.createPhase('air', 'air', fVolume, [], [], 1.0411e5);
            
            % Use helper directly
%             %cParams       = matter.helper.phase.create.air(this, fVolume * (this.fPressureDifference / 2 + 1));
%             cParams = matter.helper.phase.create.air(this, fVolume * 1e0);
%             oPhase  = matter.phases.gas_virtual(this.toStores.T_Piece, 'air', cParams{:});
%             %disp(cParams{1});
%             
%             oPhase.setInitialVirtualPressure(1e5);
%             %matter.phases.gas_virtual(this.toStores.T_Piece, 'air', struct('N2', 0.8, 'O2', 0.2), fVolume, 288.15);
            
            
            
            matter.procs.exmes.gas(this.toStores.T_Piece.toPhases.air, 'Port_1');
            matter.procs.exmes.gas(this.toStores.T_Piece.toPhases.air, 'Port_2');
            matter.procs.exmes.gas(this.toStores.T_Piece.toPhases.air, 'Port_3');
            
            
             % Create three pipes
            components.pipe(this, 'Pipe_1_tp', this.fPipeLength, this.fPipeDiameter);
            components.pipe(this, 'Pipe_tp_2', this.fPipeLength, this.fPipeDiameter);
            components.pipe(this, 'Pipe_tp_3', this.fPipeLength, this.fPipeDiameter);
            
            
            % Three branches            
            matter.branch(this, 'Tank_1.Port', { 'Pipe_1_tp' }, 'T_Piece.Port_1');
            
            matter.branch(this, 'T_Piece.Port_2', { 'Pipe_tp_2' }, 'Tank_2.Port');
            matter.branch(this, 'T_Piece.Port_3', { 'Pipe_tp_3' }, 'Tank_3.Port');
            
            
            
        end
        
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            this.coSolvers{1} = solver.matter.interval.branch(this.aoBranches(1));
            this.coSolvers{2} = solver.matter.interval.branch(this.aoBranches(2));
            this.coSolvers{3} = solver.matter.interval.branch(this.aoBranches(3));
            
%             this.coSolvers{1}.iDampFR = 15;
%             this.coSolvers{2}.iDampFR = 15;
%             this.coSolvers{3}.iDampFR = 15;
            
            
%             this.coSolvers{1} = solver.matter.linear.branch(this.aoBranches(1));
%             this.coSolvers{2} = solver.matter.linear.branch(this.aoBranches(2));
%             this.coSolvers{3} = solver.matter.linear.branch(this.aoBranches(3));

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

