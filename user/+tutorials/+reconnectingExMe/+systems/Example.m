classdef Example < vsys
    %EXAMPLE This example is based on the subsystem example. The only
    %difference here is, that during the simulation the way the branches
    %are connected will be changed at tick 100 in the simulation. For more
    %information on how to change this, view the exec function of this file
    properties
        
    end
    
    methods
        function this = Example(oParent, sName)
            this@vsys(oParent, sName, -1);
            
            % Adding the subsystem
            tutorials.reconnectingExMe.subsystems.MiddleSystem(this, 'MiddleSystem');
            
            
            eval(this.oRoot.oCfgParams.configCode(this));
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            % Creating a store, volume 1 m^3
            matter.store(this, 'Tank_1', 1);
            
            % Adding a phase to the store 'Tank_1', 2 m^3 air
            oGasPhase = this.toStores.Tank_1.createPhase('air', 1, 293, 0.5, 2e5);
            
            % Creating a second store, volume 1 m^3
            matter.store(this, 'Tank_2', 1);
            
            % Adding a phase to the store 'Tank_2', 1 m^3 air
            oAirPhase = this.toStores.Tank_2.createPhase('air', 1);
            
            % Adding extract/merge processors to the phase
            matter.procs.exmes.gas(oGasPhase, 'Port_1');
            matter.procs.exmes.gas(oAirPhase, 'Port_2');
            
            
                        
            %% Adding some pipes
            components.matter.pipe(this, 'Pipe1', 1, 0.005);
            components.matter.pipe(this, 'Pipe2', 1, 0.005);
            
            % Creating the flowpath (=branch) into a subsystem
            % Input parameter format is always: 
            % 'Interface port name', {'f2f-processor, 'f2fprocessor'}, 'store.exme'
            matter.branch(this, 'MiddleSystemInput', {'Pipe1'}, 'Tank_1.Port_1');
            
            % Creating the flowpath (=branch) out of a subsystem
            % Input parameter format is always: 
            % 'Interface port name', {'f2f-processor, 'f2fprocessor'}, 'store.exme'
            matter.branch(this, 'MiddleSystemOutput', {'Pipe2'}, 'Tank_2.Port_2');
            
            
            
            
            %%% NOTE!!! setIfFlows has to be done in createMatterStructure!
            
            % Now we need to connect the subsystem with the top level system (this one). This is
            % done by a method provided by the subsystem.
            this.toChildren.MiddleSystem.setIfFlows('MiddleSystemOutput', 'MiddleSystemInput');
        end
        
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            this.setThermalSolvers();
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
            
            % To reconnect a exme to a different phase each exme has the
            % function "reconnectExMe" which requires a phase as an input.
            % By calling this function on the exme, the exme will be moved
            % to the phase which is defined as input and therefore the
            % branch will now connect two different phases. In this example
            % the filter in and outlet branch are changed to switch the
            % flow direction within the filter, just to showcase what
            % happens. This can be done for any exme during the simulation,
            % the only limitation beeing that changing the phase to which
            % the exme is connect is not allowed to change the system to
            % which the branch belong. For example, the interface branches
            % are always part of the subsystem, not the parent system.
            % Therefore, it is not allowed to change the exme which is
            % located in the subsystem, to a phase in the parent system or
            % a different subsystem, this will result in an error since it
            % can lead to inconsistent system states.
            if this.oTimer.iTick == 100
                this.toChildren.MiddleSystem.toChildren.SubSystem.toBranches.Filter_Inlet.coExmes{2}.reconnectExMe(this.toStores.Tank_2.toPhases.Tank_2_Phase_1);
                this.toChildren.MiddleSystem.toChildren.SubSystem.toBranches.Filter_Outlet.coExmes{2}.reconnectExMe(this.toStores.Tank_1.toPhases.Tank_1_Phase_1);
            end
        end
        
     end
    
end

