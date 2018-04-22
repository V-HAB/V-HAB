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
            
            eval(this.oRoot.oCfgParams.configCode(this));
            
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            %% Gas System
            % Creating a store, volume 1 m^3
            matter.store(this, 'Tank_1', 1);
            
            % Adding a phase to the store 'Tank_1', 1 m^3 air
            oGasPhase = this.toStores.Tank_1.createPhase('air', 1);
            
            % Creating a second store, volume 1 m^3
            matter.store(this, 'Tank_2', 1);
            
            % Adding a phase to the store 'Tank_2', 2 m^3 air
            oAirPhase = this.toStores.Tank_2.createPhase('air', 3);
            
            % Adding extract/merge processors to the phase
            matter.procs.exmes.gas(oGasPhase, 'Port_1');
            matter.procs.exmes.gas(oAirPhase, 'Port_2');
            matter.procs.exmes.gas(oGasPhase, 'Port_3');
            matter.procs.exmes.gas(oAirPhase, 'Port_4');
            
            %% Water System
            % Creating a third store, volume 1 m^3
            matter.store(this, 'Tank_3', 1);
            
            % Adding a phase to the store 'Tank_3', 1 m^3 water
            oLiquidPhase = matter.phases.liquid(this.toStores.Tank_3, ...  Store in which the phase is located
                'Liquid_Phase', ...        Phase name
                struct('H2O', 1), ...      Phase contents
                1, ...                     Phase volume
                333.15, ...                Phase temperature
                101325);                 % Phase pressure
            
            % Creating a fourth store, volume 1 m^3
            matter.store(this, 'Tank_4', 1);
            %keyboard(); 
            % Adding a phase to the store 'Tank_4', 1 kg water
            oWaterPhase = matter.phases.liquid(this.toStores.Tank_4, ...  Store in which the phase is located
                'Water_Phase', ...         Phase name
                struct('H2O', 1), ...      Phase contents
                1, ...                     Phase volume
                333.15, ...                Phase temperature
                101325);                 % Phase pressure
            
            matter.procs.exmes.liquid(oLiquidPhase, 'Port_5');
            matter.procs.exmes.liquid(oWaterPhase,  'Port_6');
            matter.procs.exmes.liquid(oLiquidPhase, 'Port_7');
            matter.procs.exmes.liquid(oWaterPhase,  'Port_8');
            
            %% Heat Exchanger
            % Some configurating variables
            sHX_type = 'counter plate';       % Heat exchanger type
            Geometry = [0.2, 0.3, (0.19/2), 0.25, 1];   % Geometry [value1, value2, value3, value4] 
            % --> see the HX file for information on the inputs for the different HX types
            Conductivity = 15;                          % Conductivity of the Heat exchanger solid material
            
            %defines the heat exchanged object using the previously created properties
            components.HX(this, 'HeatExchanger', Geometry, sHX_type, Conductivity);
            
            %% Adding some pipes
            components.pipe(this, 'Pipe1', 1, 0.01);
            components.pipe(this, 'Pipe2', 1, 0.01);
            components.pipe(this, 'Pipe3', 1, 0.01);
            components.pipe(this, 'Pipe4', 1, 0.01);
            components.pipe(this, 'Pipe5', 1, 0.01);
            components.pipe(this, 'Pipe6', 1, 0.01);
            
            % Creating the flow path between the two gas tanks via the heat
            % exchanger
            % Input parameter format is always: 
            % 'store.exme', {'f2f-processor, 'f2fprocessor'}, 'store.exme'
            matter.branch(this, 'Tank_1.Port_1', {'Pipe1', 'HeatExchanger_2', 'Pipe2'}, 'Tank_2.Port_2');
            matter.branch(this, 'Tank_2.Port_4', {'Pipe5'}, 'Tank_1.Port_3');
            
            % Creating the flow path between the two water tanks via the 
            % heat exchanger
            matter.branch(this, 'Tank_3.Port_5', {'Pipe3', 'HeatExchanger_1', 'Pipe4'}, 'Tank_4.Port_6');
            matter.branch(this, 'Tank_4.Port_8', {'Pipe6'}, 'Tank_3.Port_7');
        end
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            % Creating the solver branches.
            oB1 = solver.matter.manual.branch(this.aoBranches(1));
            oB2 = solver.matter.manual.branch(this.aoBranches(2));
            oB3 = solver.matter.manual.branch(this.aoBranches(3));
            oB4 = solver.matter.manual.branch(this.aoBranches(4));
            
            % Now we set the flow rate in the manual solver branches to a
            % slow 10 grams per second.
            oB1.setFlowRate(0.01);
            oB2.setFlowRate(0.01);
            oB3.setFlowRate(0.01);
            oB4.setFlowRate(0.01);
            
            this.setThermalSolvers();
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

