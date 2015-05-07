classdef Example < vsys
    %EXAMPLE Example simulation for a fan driven looped gas flow in V-HAB 2.0
    %   One tank, filled with gas, a fan, and two pipes
    
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
            this@vsys(oParent, sName);
            
            % Creating a store, volume 1 m^3
            this.addStore(matter.store(this.oData.oMT, 'Tank_1', 1));
            
            % Adding a phase to the store 'Tank_1', 1 m^3 air
            oGasPhase = this.toStores.Tank_1.createPhase('air', 1);
            
            % Adding extract/merge processors to the phase
            matter.procs.exmes.gas(oGasPhase, 'Port_1');
            matter.procs.exmes.gas(oGasPhase, 'Port_2');
            
            % Adding a fan to move the gas
            this.addProcF2F(components.fan(this.oData.oMT, 'Fan', 'setSpeed', 55000, 'Left2Right'));
             
            % Adding a pipe to connect the tanks
            this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_1', 1, 0.1));
            this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_2', 1, 0.1));
            
            % Creating the flowpath (=branch) between the components
            % Input parameter format is always: 
            % 'store.exme', {'f2f-processor, 'f2fprocessor'}, 'store.exme'
            oBranch = this.createBranch('Tank_1.Port_1', {'Pipe_1', 'Fan', 'Pipe_2'}, 'Tank_1.Port_2');
            
            % Seal - means no more additions of stores etc can be done to
            % this system.
            this.seal();
            
            % Now that the system is sealed, we can add the branch to a
            % specific solver. In this case we will use the linear
            % solver. 
            solver.matter.linear.branch(oBranch);
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            % exec(ute) function for this system
            % Here it only calls its parent's exec function
            exec@vsys(this);
            
            %disp(['Tank Pressure: ',num2str(this.toStores.Tank_1.aoPhases(1).fPressure)])
        end
        
     end
    
end

