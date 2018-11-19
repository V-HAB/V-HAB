classdef ColdPlateRef < vsys
    %Example simulation for liquid flow problems V-HAB 2.0
    %This example contains a continous flow between two tanks driven by a
    %pump.Additionally a heater increasing the temperature of the fluid in
    %the first branch is implemented.
    
    properties
        aoLiquidBranch;
    end
    
    methods
        function this = ColdPlateRef(oParent, sName)
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
            this@vsys(oParent, sName, 60);
            
            % Creating a store
            this.addStore(matter.store(this, 'Tank_1', 0.01));
            
            % Creating a second store
            this.addStore(matter.store(this, 'Tank_2', 0.01));
            
%             this.addStore(matter.store(this.oData.oMT, 'Tank_3', 10));

            oWaterPhase1 = this.toStores.Tank_1.createPhase('water', 0.005, 293, 5*10^5);
            oAirPhase1   = this.toStores.Tank_1.createPhase('air', 0.005, 293, 5*10^5);
            
            % Adding a phase to the store 'Tank_2'
            oWaterPhase2 = this.toStores.Tank_2.createPhase('water', 0.005, 293, 1*10^5);
            oAirPhase2   = this.toStores.Tank_2.createPhase('air', 0.005, 293, 1*10^5);
            
            % Adding extract/merge processors to the phases
            matter.procs.exmes.liquid(oWaterPhase1, 'Port_1' );
            matter.procs.exmes.liquid(oWaterPhase2, 'Port_2');
            
            % Adding a heater
            %heater(oMT, sName, fTemp, fHydrDiam, fHydrLength, fRoughness)
            this.addProcF2F(tutorials.compressible_liquid_solver.components.heater('Heater', 292.85, 0.01, 0, 0));
            
            % Adding pipes to connect the components
            this.addProcF2F(components.matter.pipe('Pipe_1', 1, 0.01, 0.2*10^-3));
            this.addProcF2F(components.matter.pipe('Pipe_2', 1, 0.01, 0.2*10^-3));
                      
            this.createBranch('Tank_1.Port_1', {'Pipe_1', 'Heater', 'Pipe_2',}, 'Tank_2.Port_2');
                        
            % Seal - means no more additions of stores etc can be done to
            % this system.
            this.seal();
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
        end
        
     end
    
end

