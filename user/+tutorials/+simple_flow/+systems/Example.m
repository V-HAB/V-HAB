classdef Example < vsys
    %EXAMPLE Example simulation for a simple flow in V-HAB 2.0
    %   Two tanks filled with gas at different pressures and a pipe in between
    
    properties
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
            
            % Creating a store, volume 1 m^3
            this.addStore(matter.store(this, 'Tank_1', 1));
            
            % Adding a phase to the store 'Tank_1', 1 m^3 air at 20 deg C
            oGasPhase = this.toStores.Tank_1.createPhase('air', 1, 293.15);
            
            % Creating a second store, volume 1 m^3
            this.addStore(matter.store(this, 'Tank_2', 1));
            
            % Adding a phase to the store 'Tank_2', 2 m^3 air at 50 deg C
            oAirPhase = this.toStores.Tank_2.createPhase('air', 2, 323.15);
            
            % Adding extract/merge processors to the phase
            matter.procs.exmes.gas(oGasPhase, 'Port_1');
            matter.procs.exmes.gas(oAirPhase, 'Port_2');
             
            % Adding a pipe to connect the tanks, 1.5 m long, 5 mm in
            % diameter.
            this.addProcF2F(components.pipe('Pipe', 1.5, 0.005));
            
            % Creating the flowpath (=branch) between the components
            % Input parameter format is always: 
            % 'store.exme', {'f2f-processor, 'f2fprocessor'}, 'store.exme'
            oBranch = this.createBranch('Tank_1.Port_1', {'Pipe'}, 'Tank_2.Port_2');
            
            % Seal - means no more additions of stores etc can be done to
            % this system.
            this.seal();
            
            % Now that the system is sealed, we can add the branch to a
            % specific solver. In this case we will use the iterative
            % solver. 
            solver.matter.iterative.branch(oBranch);
       
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

