classdef Example < vsys
    %EXAMPLE Example simulation for a fan driven looped gas flow in V-HAB 2.2
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
            this@vsys(oParent, sName, 100);
        end
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            % Creating a store, volume 1 m^3
            matter.store(this, 'Tank_1', 1);
            
            % Adding a phase to the store 'Tank_1', 1 m^3 air
            oGasPhase = this.toStores.Tank_1.createPhase('air', 1);
            
            % Adding extract/merge processors to the phase
            matter.procs.exmes.gas(oGasPhase, 'Port_1');
            matter.procs.exmes.gas(oGasPhase, 'Port_2');
            
            % Adding a fan to move the gas
            components.matter.fan(this, 'Fan', 55000);
             
            % Adding a pipe to connect the tanks
            components.matter.pipe(this, 'Pipe_1', 1, 0.02);
            components.matter.pipe(this, 'Pipe_2', 1, 0.02);
            
            % Creating the flowpath (=branch) between the components
            % Input parameter format is always: 
            % 'store.exme', {'f2f-processor, 'f2fprocessor'}, 'store.exme'
            matter.branch(this, 'Tank_1.Port_1', {'Pipe_1', 'Fan', 'Pipe_2'}, 'Tank_1.Port_2');
            
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            % Now that the system is sealed, we can add the branch to a
            % specific solver. In this case we will use the linear
            % solver. 
            solver.matter.interval.branch(this.toBranches.Tank_1__Port_1___Tank_1__Port_2);
            
            this.toProcsF2F.Fan.switchOn();
            
            this.setThermalSolvers();
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            % exec(ute) function for this system
            % Here it only calls its parent's exec function
            exec@vsys(this);
            
            % To change the flow speed of the fan just change the
            % fSpeedSetpoint property. This is a value in RPM.
            
            % Since toProcsF2F is a read only property the speed setpoint
            % cannot be set by accessing the fan directly from the this
            % object. This means that the following call would produce an
            % error:
            % this.toProcsF2F.Fan.fSpeedSetpoint = 75000;
            %
            % Instead we just take the fan object from the toProcsF2F and
            % save it to the oFan variable. Now setting the fSpeedSetpoint
            % property for oFan will produce the required results.
            oFan = this.toProcsF2F.Fan;
            if this.oTimer.fTime > 600 && this.oTimer.fTime < 1200
                oFan.fSpeedSetpoint = 40000;
            elseif this.oTimer.fTime > 1200 && this.oTimer.fTime < 1800
                oFan.fSpeedSetpoint = 75000;
            else
                oFan.fSpeedSetpoint = 55000;
            end
        end
        
     end
    
end

