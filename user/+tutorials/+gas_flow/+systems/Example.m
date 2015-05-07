classdef Example < vsys
    %EXAMPLE Example simulation for a fan driven gas flow in V-HAB 2.0
    %   Two tanks, filled with gas at different pressures, a fan in between
    %   and two pipes to connect it all
    
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
            this.addStore(matter.store(this.oData.oMT, 'Tank_1', 1));
            
            % Adding a phase to the store 'Tank_1', 1 m^3 air
            oGasPhase = this.toStores.Tank_1.createPhase('air', 1);
            
            % Creating a second store, volume 1 m^3
            this.addStore(matter.store(this.oData.oMT, 'Tank_2', 1));
            
            % Adding a phase to the store 'Tank_2', 2 m^3 air
            oAirPhase = this.toStores.Tank_2.createPhase('air', 1);
            
            % Adding extract/merge processors to the phase
            matter.procs.exmes.gas(oGasPhase, 'Port_1');
            matter.procs.exmes.gas(oAirPhase, 'Port_2');
            
            % Adding a fan to move the gas
            this.addProcF2F(components.fan(this.oData.oMT, 'Fan', 'setSpeed', 40000, 'Right2Left'));
             
            % Adding a pipe to connect the tanks
            this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_1', 1, 0.01));
            this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_2', 1, 0.01));
            
            % Creating the flowpath (=branch) between the components
            % Input parameter format is always: 
            % 'store.exme', {'f2f-processor, 'f2fprocessor'}, 'store.exme'
            oBranch = this.createBranch('Tank_1.Port_1', {'Pipe_1', 'Fan', 'Pipe_2'}, 'Tank_2.Port_2');
            
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

