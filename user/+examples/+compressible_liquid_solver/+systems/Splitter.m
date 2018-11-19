classdef Splitter < vsys
    %EXAMPLE Example simulation for V-HAB 2.0
    %   This class creates blubb
    
    properties
        aoLiquidBranch;
    end
    
    methods
        function this = Splitter(oParent, sName)
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
            
            % Creating stores
            this.addStore(matter.store(this, 'Tank_1', 0.1));
            this.addStore(matter.store(this, 'Tank_2', 0.05));
            this.addStore(matter.store(this, 'Tank_3', 0.02));
            this.addStore(matter.store(this, 'Tank_4', 0.01));
            this.addStore(matter.store(this, 'Splitter', 2.6*10^-3));
            
            %adding phases
            oWaterPhase1 = this.toStores.Tank_1.createPhase('water', 0.075, 313, 10*10^5);
            oAirPhase1   = this.toStores.Tank_1.createPhase('air', 0.025, 298, 0, 10*10^5);
            
            oWaterPhase2 = this.toStores.Tank_2.createPhase('water', 0.01, 293, 5*10^5);
            oAirPhase2   = this.toStores.Tank_2.createPhase('air', 0.04, 293, 0, 5*10^5);
            
            oWaterPhase3 = this.toStores.Tank_3.createPhase('water', 0.02, 293, 5*10^5);
            
            oWaterPhase4 = this.toStores.Tank_4.createPhase('water', 0.01, 293, 5*10^5);
            
            oWaterPhase5 = this.toStores.Splitter.createPhase('water', 2.6*10^-3, 293, 5*10^5);
            
            % Adding extract/merge processors to the phases
            matter.procs.exmes.liquid(oWaterPhase1, 'Port_1' );
            matter.procs.exmes.liquid(oWaterPhase2, 'Port_2' );
            matter.procs.exmes.liquid(oWaterPhase3, 'Port_3' );
            matter.procs.exmes.liquid(oWaterPhase4, 'Port_4' );
            
            %adding ports to the water phase in the splitter
            matter.procs.exmes.liquid(oWaterPhase5, 'Splitter_Port_1');
            matter.procs.exmes.liquid(oWaterPhase5, 'Splitter_Port_2');
            matter.procs.exmes.liquid(oWaterPhase5, 'Splitter_Port_3');
            matter.procs.exmes.liquid(oWaterPhase5, 'Splitter_Port_4');

            % Adding pipes to connect the components
            this.addProcF2F(components.pipe('Pipe_1', 1.0, 0.1, 0.02));
            this.addProcF2F(components.pipe('Pipe_2', 1.0, 0.1, 0.02));
            this.addProcF2F(components.pipe('Pipe_3', 1.0, 0.1, 0.02));
            this.addProcF2F(components.pipe('Pipe_4', 1.0, 0.1, 0.02));
            
            
            this.createBranch('Tank_1.Port_1', {'Pipe_1'}, 'Splitter.Splitter_Port_1');
            this.createBranch('Splitter.Splitter_Port_2', {'Pipe_2'}, 'Tank_2.Port_2');
            this.createBranch('Splitter.Splitter_Port_3', {'Pipe_3'}, 'Tank_3.Port_3');
            this.createBranch('Splitter.Splitter_Port_4', {'Pipe_4'}, 'Tank_4.Port_4');

            
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

