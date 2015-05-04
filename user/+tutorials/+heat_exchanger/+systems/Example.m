classdef Example < vsys
    %EXAMPLE Example simulation for a system with a heat exchanger in V-HAB 2.0
    %   This system has four stores with one phase each. There are two gas
    %   phases and two liquid phases. The gas phases and the liquid phases
    %   are connected to each other with two branches. A heat exchanger
    %   provides two f2f processors, one of each is integrated into each of
    %   the two branches. The flow through the gas branch is driven by the
    %   pressure difference between the two tanks. The flow through the
    %   liquid branch is set by using a manual solver branch. 
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
            
            %% Gas System
            % Creating a store, volume 1 m^3
            this.addStore(matter.store(this.oData.oMT, 'Tank_1', 1000));
            
            % Adding a phase to the store 'Tank_1', 1 m^3 air
            oGasPhase = this.toStores.Tank_1.createPhase('air', 2000);
            
            % Creating a second store, volume 1 m^3
            this.addStore(matter.store(this.oData.oMT, 'Tank_2', 1000));
            
            % Adding a phase to the store 'Tank_2', 2 m^3 air
            oAirPhase = this.toStores.Tank_2.createPhase('air', 1000);
            
            % Adding extract/merge processors to the phase
            matter.procs.exmes.gas(oGasPhase, 'Port_1');
            matter.procs.exmes.gas(oAirPhase, 'Port_2');
            
            %% Water System
            % Creating a third store, volume 1 m^3
            this.addStore(matter.store(this.oData.oMT, 'Tank_3', 1));
            
            % Adding a phase to the store 'Tank_3', 1 m^3 water
            oLiquidPhase = matter.phases.liquid(this.toStores.Tank_3, ...  Store in which the phase is located
                'Liquid_Phase', ...        Phase name
                struct('H2O', 1000), ...   Phase contents
                1, ...                     Phase volume
                303.15, ...                Phase temperature
                101325);                 % Phase pressure
            
            % Creating a fourth store, volume 1 m^3
            this.addStore(matter.store(this.oData.oMT, 'Tank_4', 1));
            %keyboard(); 
            % Adding a phase to the store 'Tank_4', 1 kg water
            oWaterPhase = matter.phases.liquid(this.toStores.Tank_4, ...  Store in which the phase is located
                'Water_Phase', ...         Phase name
                struct('H2O', 1), ...      Phase contents
                1, ...                     Phase volume
                303.15, ...                Phase temperature
                101325);                 % Phase pressure
            
            matter.procs.exmes.liquid(oLiquidPhase, 'Port_3');
            matter.procs.exmes.liquid(oWaterPhase,  'Port_4');
            
            %% Heat Exchanger
            % Some configurating variables
            sHX_type = 'counter plate';       % Heat exchanger type
            Geometry = [0.2, 0.3, (0.19/2), 0.25, 1];   % Geometry [value1, value2, value3, value4]
            Conductivity = 15;                          % Conductivity of...?
            
            oHX = components.HX(this, 'HeatExchanger', Geometry, sHX_type, Conductivity);
            
            % Adding the processors from the heat exchanger to the system.
            % Their 'sName' properties will be [oHX.sName, '_1'] and ...'_2'
            % So in this case 'HeatExchanger_1' and 'HeatExchanger_2'.
            this.addProcF2F(oHX.oF2F_1);
            this.addProcF2F(oHX.oF2F_2);
            
            
            %% Adding some pipes
            this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe1', 1, 0.01));
            this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe2', 1, 0.01));
            this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe3', 1, 0.01));
            this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe4', 1, 0.01));
            
            % Creating the flow path between the two gas tanks via the heat
            % exchanger
            % Input parameter format is always: 
            % 'store.exme', {'f2f-processor, 'f2fprocessor'}, 'store.exme'
            this.createBranch('Tank_1.Port_1', {'Pipe1', 'HeatExchanger_2', 'Pipe2'}, 'Tank_2.Port_2');
            
            % Creating the flow path between the two water tanks via the 
            % heat exchanger
            this.createBranch('Tank_3.Port_3', {'Pipe3', 'HeatExchanger_1', 'Pipe4'}, 'Tank_4.Port_4');
            
            % Seal - means no more additions of stores etc can be done to
            % this system.
            this.seal();
            
            % Creating the solver branches. For the gas flow we use the
            % iterative solver and, for simplicity, the manual solver for
            % the water flow. That saves us the trouble to implement a
            % pump.
            oB1 = solver.matter.iterative.branch(this.aoBranches(1));
            oB2 = solver.matter.manual.branch(this.aoBranches(2));
            
            % Now we set the flow rate in the manual solver branch to a
            % slow 10 grams per second.
            oB2.setFlowRate(0.01);
            
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

