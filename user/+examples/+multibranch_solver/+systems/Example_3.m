classdef Example_3 < vsys
    %EXAMPLE Example simulation for a simple flow in V-HAB 2.0
    %   Two tanks filled with gas at different pressures and a pipe in between
    
    properties (SetAccess = protected, GetAccess = public)
        fPipeLength   = 1.5;
        fPipeDiameter = 0.05;
        
    end
    
    methods
        function this = Example_3(oParent, sName)
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
            
            % Creating a store, volume 1 m^3
            matter.store(this, 'Tank_1', 1);
            
            oGasPhase = this.toStores.Tank_1.createPhase(  'gas',   'CabinAir', this.toStores.Tank_1.fVolume, struct('N2', 16e4, 'O2', 4e4, 'CO2', 1000), 293, 0.5);
            matter.procs.exmes.gas(oGasPhase, 'Port_1');
            matter.procs.exmes.gas(oGasPhase, 'Port_2');
            
            % Creating a second store, volume 1 m^3
            matter.store(this, 'Tank_2', 1);
            oGasPhase = this.toStores.Tank_2.createPhase(  'gas',   'CabinAir', this.toStores.Tank_1.fVolume, struct('N2', 8e4, 'O2', 2e4, 'CO2', 500), 293, 0.5);
            matter.procs.exmes.gas(oGasPhase, 'Port_1');
            matter.procs.exmes.gas(oGasPhase, 'Port_2');
            
            matter.store(this, 'Flow_1', 1e-5);
            oGasPhase         = this.toStores.Flow_1.createPhase(  'gas', 'flow', 'FlowPhase',   this.toStores.Flow_1.fVolume, struct('N2', 8e4, 'O2', 2e4, 'CO2', 500), 293, 0.5);
            matter.procs.exmes.gas(oGasPhase, 'Port_1');
            matter.procs.exmes.gas(oGasPhase, 'Port_2');
            
            matter.store(this, 'Flow_2', 1e-5);
            oGasPhase         = this.toStores.Flow_2.createPhase(  'gas', 'flow', 'FlowPhase',   this.toStores.Flow_1.fVolume, struct('N2', 8e4, 'O2', 2e4, 'CO2', 500), 293, 0.5);
            matter.procs.exmes.gas(oGasPhase, 'Port_1');
            matter.procs.exmes.gas(oGasPhase, 'Port_2');
            
            matter.store(this, 'Flow_3', 1e-5);
            oGasPhase         = this.toStores.Flow_3.createPhase(  'gas', 'flow', 'FlowPhase',   this.toStores.Flow_1.fVolume, struct('N2', 8e4, 'O2', 2e4, 'CO2', 500), 293, 0.5);
            matter.procs.exmes.gas(oGasPhase, 'Port_1');
            matter.procs.exmes.gas(oGasPhase, 'Port_2');
            
            % Adding a pipe to connect the tanks, 1.5 m long, 5 mm in
            % diameter.
            components.matter.pipe(this, 'Pipe1', this.fPipeLength, this.fPipeDiameter, 2e-3);
            components.matter.pipe(this, 'Pipe2', this.fPipeLength, this.fPipeDiameter, 2e-3);
            components.matter.pipe(this, 'Pipe3', this.fPipeLength, this.fPipeDiameter, 2e-3);
            components.matter.pipe(this, 'Pipe4', this.fPipeLength, this.fPipeDiameter, 2e-3);
            
            components.matter.fan_simple(this, 'Fan1', 0.5*10^5);
            
            % Creating the flowpath (=branch) between the components
            % Input parameter format is always: 
            % 'store.exme', {'f2f-processor, 'f2fprocessor'}, 'store.exme'
            matter.branch(this, 'Tank_1.Port_1', {'Pipe1'}, 'Flow_1.Port_1', 'Branch1');
            matter.branch(this, 'Flow_1.Port_2', {'Pipe2'}, 'Tank_2.Port_1', 'Branch2');
            
            matter.branch(this, 'Tank_2.Port_2', {'Pipe3'}, 'Flow_2.Port_1', 'Branch3');
            matter.branch(this, 'Flow_2.Port_2', {'Fan1'}, 'Flow_3.Port_1', 'Branch4');
            
            matter.branch(this, 'Flow_3.Port_2', {'Pipe4'}, 'Tank_1.Port_2', 'Branch5');
            
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            % Now that the system is sealed, we can add the branch to a
            % specific solver. In this case we will use the iterative
            % solver. 
            solver.matter_multibranch.iterative.branch(this.aoBranches(:), 'complex');
            
            %oIt1.iDampFR = 5;
            tTimeStepProperties.rMaxChange = 0.001;
            this.toStores.Tank_1.toPhases.CabinAir.setTimeStepProperties(tTimeStepProperties);
            this.toStores.Tank_2.toPhases.CabinAir.setTimeStepProperties(tTimeStepProperties);
            
            this.setThermalSolvers();
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            % exec(ute) function for this system
            % Here it only calls its parent's exec function
            exec@vsys(this);
            
            if ~base.oDebug.bOff, this.out(2, 1, 'exec', 'Exec vsys %s', { this.sName }); end;
        end
        
     end
    
end

