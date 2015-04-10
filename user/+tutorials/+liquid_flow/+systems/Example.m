classdef Example < vsys
    %EXAMPLE Example liquid flow simulation for V-HAB 2.0
    %   This class creates blubb
    
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
            this@vsys(oParent, sName, 1);
            
            % Creating a store
            this.addStore(matter.store(this.oData.oMT, 'Tank_1', 1));
            
            % Creating a second store
            this.addStore(matter.store(this.oData.oMT, 'Tank_2', 1));
            
            % Adding a phase with liquid water to the store
            oLiquidPhase = matter.phases.liquid(this.toStores.Tank_1, ...  Store in which the phase is located
                                                'Liquid_Phase', ...        Phase name
                                                struct('H2O', 1000), ...   Phase contents
                                                1, ...                     Phase volume
                                                293.15);                 % Phase temperature
            
            % Adding an empty phase to the second store, 
            % this represents an empty tank
            
            % PROBLEM If the phase contents are set to zero kg of H2O the
            % solver takes forever to increase the step size. If set to 1
            % kg of H2O, it works...
            oWaterPhase = matter.phases.liquid(this.toStores.Tank_2, ...   Store in which the phase is located
                                                'Water_Phase', ...         Phase name
                                                struct('H2O', 1), ...      Phase contents
                                                0.001, ...                 Phase volume
                                                293.15);                 % Phase temperature
                                            
            
            
            % Adding extract/merge processors to the phases
            matter.procs.exmes.liquid(oLiquidPhase, 'Port_1');
            matter.procs.exmes.liquid(oWaterPhase, 'Port_2');
            
            % Adding a pump
            % Warning! This is a really dumb pump, a better model is in the
            % making in conjuction with a better liquid solver. 
            this.addProcF2F(components.pump(this.oData.oMT, 'Pump', 0.267));
            
            % Adding pipes to connect the components
            this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_1', 1, 0.1));
            this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_2', 1, 0.1));
            
            % Creating the flowpath between the components
            this.createBranch('Tank_1.Port_1', {'Pipe_1', 'Pump', 'Pipe_2'}, 'Tank_2.Port_2');
            
            % Seal - means no more additions of stores etc can be done to
            % this system.
            this.seal();
            
            % Have to set the phase pressures manually... forgot why...
            oLiquidPhase.setPressure(101325);
            oWaterPhase.setPressure(101325);
            
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
        end
        
     end
    
end

