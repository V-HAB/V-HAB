classdef Example < vsys
    %EXAMPLE Simple system showing ExMe reconfiguration
    % This example uses three stores with different temperature and
    % pressure conditions to show how to reconnect exmes during a
    % simulation. The way the branches are connected will be changed at
    % tick 1000 in the simulation. For more information on how to change
    % this, view the exec function of this file.

    properties
    end
    
    methods
        function this = Example(oParent, sName)
            this@vsys(oParent, sName, -1);
            
            eval(this.oRoot.oCfgParams.configCode(this));
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            matter.store(this, 'Store1', 10, false);
            oAir1 = this.toStores.Store1.createPhase('gas', 'Air', 10, struct('N2', 1e5, 'O2',    0, 'CO2',    0), 293, 0);
            
            matter.store(this, 'Store2', 10);
            oAir2 = this.toStores.Store2.createPhase('gas', 'Air', 10, struct('N2',   0, 'O2', 10e5, 'CO2',    0), 303, 0);
            
            matter.store(this, 'Store3', 10);
                    this.toStores.Store3.createPhase('gas', 'Air', 10, struct('N2',   0, 'O2',    0, 'CO2', 10e5), 283, 0.5);
            
            components.matter.pipe(this, 'Pipe', 1, 0.005);
            
            matter.branch(this, oAir2, {'Pipe'}, oAir1, 'AirExchange');
            
        end
        
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            solver.matter.interval.branch(this.aoBranches(1));
            
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
            if this.oTimer.iTick == 1000
                this.toBranches.AirExchange.coExmes{1}.reconnectExMe(this.toStores.Store3.toPhases.Air);
            end
        end
     end
end