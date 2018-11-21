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
            
            % Adding a phase to the store 'Tank_2', 1 m^3 air, 2 bar
            % pressure
            oAirPhase = this.toStores.Tank_2.createPhase('air', 1, 293, 0.5, 3e5);
            
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
                333.15, ...                Phase temperature
                101325);                 % Phase pressure
            
            % Creating a fourth store, volume 1 m^3
            matter.store(this, 'Tank_4', 1);
            %keyboard(); 
            % Adding a phase to the store 'Tank_4', 1 kg water
            oWaterPhase = matter.phases.liquid(this.toStores.Tank_4, ...  Store in which the phase is located
                'Water_Phase', ...         Phase name
                struct('H2O', 1), ...      Phase contents
                333.15, ...                Phase temperature
                101325);                 % Phase pressure
            
            matter.procs.exmes.liquid(oLiquidPhase, 'Port_5');
            matter.procs.exmes.liquid(oWaterPhase,  'Port_6');
            matter.procs.exmes.liquid(oLiquidPhase, 'Port_7');
            matter.procs.exmes.liquid(oWaterPhase,  'Port_8');
            
            %% Examples for the different types of heat exchangers:
            % Note old notations using the mHX can be translated to this by
            % simply filling the mHX values into the respective struct
            % values (the order should be from 1 to end here)
            
%             sHX_type = 'CounterAnnularPassage';       % Heat exchanger type
%             tHX_Parameters.fInnerDiameter   = 1.1e-2;
%             tHX_Parameters.fOuterDiameter   = 2e-2;
%             tHX_Parameters.fInternalRadius  = 1e-2;
%             tHX_Parameters.fLength          = 1;
            
%             sHX_type = 'CounterPipeBundle';       % Heat exchanger type
%             tHX_Parameters.fInnerDiameter           = 5e-3;
%             tHX_Parameters.fOuterDiameter           = 1e-2;
%             tHX_Parameters.fShellDiameter           = 0.5;
%             tHX_Parameters.fLength                  = 1;
%             tHX_Parameters.iNumberOfPipes           = 20;
%             tHX_Parameters.fPerpendicularSpacing    = 1e-2;
%             tHX_Parameters.fParallelSpacing         = 1e-2;

%             sHX_type = 'CounterPlate';       % Heat exchanger type
%             sHX_type = 'ParallelPlate';
%             sHX_type = 'Cross';
%             tHX_Parameters.fBroadness  = 0.2;
%             tHX_Parameters.fHeight_1   = 1e-2;
%             tHX_Parameters.fHeight_2   = 1e-2;
%             tHX_Parameters.fLength     = 1;
%             tHX_Parameters.fThickness  = 1e-3;
% 
%             % For a plate cross flow use the same configuration as for the
%             % other plate HX and add the field:
%             tHX_Parameters.iNumberOfRows = 0;
            
            
            sHX_type = 'Cross';
            tHX_Parameters.iNumberOfRows            = 10;
            tHX_Parameters.iNumberOfPipes           = 100;
            tHX_Parameters.fInnerDiameter           = 5e-3;
            tHX_Parameters.fOuterDiameter           = 1e-2;
            tHX_Parameters.fLength                  = 10;
            tHX_Parameters.fPerpendicularSpacing  	= 2e-2; 
            tHX_Parameters.fParallelSpacing         = 2e-2;
            tHX_Parameters.iConfiguration           = 2;
            tHX_Parameters.fPipeRowOffset           = 1e-2;
        
        
   
            
            % --> see the HX file for information on the inputs for the different HX types
            Conductivity = 15;                          % Conductivity of the Heat exchanger solid material
            
            %% Heat Exchanger
            %defines the heat exchanged object using the previously created properties
            components.matter.HX(this, 'HeatExchanger', tHX_Parameters, sHX_type, Conductivity);
            
            %% Adding some pipes
            components.matter.pipe(this, 'Pipe1', 1, 0.01);
            components.matter.pipe(this, 'Pipe2', 1, 0.01);
            components.matter.pipe(this, 'Pipe3', 1, 0.01);
            components.matter.pipe(this, 'Pipe4', 1, 0.01);
            components.matter.pipe(this, 'Pipe5', 1, 0.01);
            components.matter.pipe(this, 'Pipe6', 1, 0.01);
            
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

