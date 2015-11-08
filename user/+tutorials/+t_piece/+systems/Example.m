classdef Example < vsys
    %EXAMPLE Example simulation for a simple flow in V-HAB 2.0
    %   Two tanks filled with gas at different pressures and a pipe in between
    
    properties (SetAccess = protected, GetAccess = public)
        fPipeLength   = 0.5;
        fPipeDiameter = 0.005;
        
        % Pressure difference in bar
        fPressureDifference = 1;
        
        fTpieceLen = 0.01;
        
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
            
            
            
            % Create stores with one phase and one exme each!
            matter.store(this, 'Tank_1', 100);
            this.toStores.Tank_1.createPhase('air', 'air', (this.fPressureDifference + 1) * 100);
            %matter.procs.exmes.gas(this.toStores.Tank_1.toPhases.air, 'Port');
            special.matter.const_press_exme(this.toStores.Tank_1.toPhases.air, 'Port', (this.fPressureDifference + 1) * 101325);
            
            matter.store(this, 'Tank_2', 100);
            this.toStores.Tank_2.createPhase('air', 'air', 100);
            %matter.procs.exmes.gas(this.toStores.Tank_2.toPhases.air, 'Port');
            special.matter.const_press_exme(this.toStores.Tank_2.toPhases.air, 'Port', 101325);
            
            matter.store(this, 'Tank_3', 100);
            this.toStores.Tank_3.createPhase('air', 'air', 100);
            %matter.procs.exmes.gas(this.toStores.Tank_3.toPhases.air, 'Port');
            special.matter.const_press_exme(this.toStores.Tank_3.toPhases.air, 'Port', 101325);
            
            
            % Create T-Piece with three ports!
            %fVolume = geom.volumes.cube(this.fPipeDiameter).fVolume;
            %fVolume = 0.001;
            fVolume = geom.volumes.cube(this.fTpieceLen).fVolume;
            
            matter.store(this, 'T_Piece', fVolume);
            %this.toStores.T_Piece.createPhase('air', 'air', fVolume * (this.fPressureDifference / 2 + 1));
            this.toStores.T_Piece.createPhase('air', 'air', fVolume, [], [], 1.0411e5);
            
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
            
            
            % Seal - means no more additions of stores etc can be done to
            % this system.
            this.seal();
            
            
            this.coSolvers{1} = solver.matter.iterative.branch(this.aoBranches(1));
            this.coSolvers{2} = solver.matter.iterative.branch(this.aoBranches(2));
            this.coSolvers{3} = solver.matter.iterative.branch(this.aoBranches(3));
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

