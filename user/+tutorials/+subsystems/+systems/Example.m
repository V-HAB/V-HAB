classdef Example < vsys
    %EXAMPLE Example simulation for a system with subsystems in V-HAB 2.0
    %   TODO Insert proper description here
    
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
            this@vsys(oParent, sName, -1);
            
            % Creating a store, volume 1 m^3
            this.addStore(matter.store(this.oData.oMT, 'Tank_1', 1));
            
            % Adding a phase to the store 'Tank_1', 1 m^3 air
            oGasPhase = this.toStores.Tank_1.createPhase('air', 2);
            
            % Creating a second store, volume 1 m^3
            this.addStore(matter.store(this.oData.oMT, 'Tank_2', 1));
            
            % Adding a phase to the store 'Tank_2', 2 m^3 air
            oAirPhase = this.toStores.Tank_2.createPhase('air', 1);
            
            % Adding extract/merge processors to the phase
            matter.procs.exmes.gas(oGasPhase, 'Port_1');
            matter.procs.exmes.gas(oAirPhase, 'Port_2');
            
            %% Adding the subsystem
            oSubSys = tutorials.subsystems.subsystems.ExampleSubsystem(this, 'SubSystem');
            
                        
            %% Adding some pipes
            this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe1', 1, 0.1));
            this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe2', 1, 0.1));
            
            % Creating the flowpath (=branch) into a subsystem
            % Input parameter format is always: 
            % 'System level port name', {'f2f-processor, 'f2fprocessor'}, 'store.exme'
            this.createBranch('SubsystemInput', {'Pipe1'}, 'Tank_1.Port_1');
            
            % Creating the flowpath (=branch) out of a subsystem
            % Input parameter format is always: 
            % 'System level port name', {'f2f-processor, 'f2fprocessor'}, 'store.exme'
            this.createBranch('SubsystemOutput', {'Pipe2'}, 'Tank_2.Port_2');
            
            % Now we need to connect the subsystem with the top level system (this one). This is
            % done by a method provided by the subsystem.
            oSubSys.setIfFlows('SubsystemInput', 'SubsystemOutput');
            
            % Seal - means no more additions of stores etc can be done to
            % this system.
            this.seal();
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

