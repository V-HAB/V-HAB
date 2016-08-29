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
        %Object for the System solver since the incompressible liquid
        %solver does not calculate each branch individually but instead
        %calculates all branches at once with regard to dependencies
        %between the branches
        oSystemSolver;
        
        aoPhases;
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
            
            % uses the custom air helper to generate an air phase with a
            % defined co2 level and relative humidity
            fCO2Percent = 0.4;
            cAirHelper = matter.helper.phase.create.air_custom(this.toStores.Tank_1, 1, struct('CO2', fCO2Percent),  313, 0.5, 1e5);
               
            % Adding a phase to the store 'Tank_1', 1 m^3 air
            oAirPhase_1 = matter.phases.gas(this.toStores.Tank_1, 'Air_1', cAirHelper{1}, cAirHelper{2}, cAirHelper{3});
            
            % Creating a second store, volume 1 m^3
            matter.store(this, 'Tank_2', 1.1);
            
            % Adding a phase to the store 'Tank_2', 2 m^3 air
            oAirPhase_2 = matter.phases.gas(this.toStores.Tank_2, 'Air_2', cAirHelper{1}, cAirHelper{2}, cAirHelper{3});
            
            oCondensatePhase = matter.phases.liquid(this.toStores.Tank_2, ...  Store in which the phase is located
                'Condensate_Phase', ...         Phase name
                struct('H2O', 1), ...      Phase contents
                0.1, ...                     Phase volume
                295, ...                Phase temperature
                101325);                 % Phase pressure
            
            % Adding extract/merge processors to the phase
            matter.procs.exmes.gas(oAirPhase_1, 'Port_1');
            matter.procs.exmes.gas(oAirPhase_2, 'Port_2');
            matter.procs.exmes.gas(oAirPhase_1, 'Port_3');
            matter.procs.exmes.gas(oAirPhase_2, 'Port_4');
            
            matter.procs.exmes.gas(oAirPhase_2, 'Condensate_Out');
            matter.procs.exmes.liquid(oCondensatePhase, 'Condensate_In');
            %% Water System
            % Creating a third store, volume 1 m^3
            matter.store(this, 'Tank_3', 1);
            
            % Adding a phase to the store 'Tank_3', 1 m^3 water
            oCoolantPhase1 = matter.phases.gas(this.toStores.Tank_3, ...  Store in which the phase is located
                'Coolant_Phase1', ...        Phase name
                struct('N2', 1.2), ...         Phase contents
                1, ...                       Phase volume
                275.15);                   % Phase temperature
            
            % Creating a fourth store, volume 1 m^3
            matter.store(this, 'Tank_4', 1);
            %keyboard(); 
            % Adding a phase to the store 'Tank_4', 1 kg water
            oCoolantPhase2 = matter.phases.gas(this.toStores.Tank_4, ...  Store in which the phase is located
                'Coolant_Phase2', ...         Phase name
                struct('N2', 1.2), ...          Phase contents
                1, ...                        Phase volume
                275.15);                    % Phase temperature
            
            matter.procs.exmes.gas(oCoolantPhase1, 'Port_5');
            matter.procs.exmes.gas(oCoolantPhase2,  'Port_6');
            matter.procs.exmes.gas(oCoolantPhase1, 'Port_7');
            matter.procs.exmes.gas(oCoolantPhase2,  'Port_8');
            
            aoPhases_Temp(1) = oAirPhase_1;
            aoPhases_Temp(2) = oAirPhase_2;
            aoPhases_Temp(3) = oCoolantPhase1;
            aoPhases_Temp(4) = oCoolantPhase2;
            this.aoPhases = aoPhases_Temp;
            %% Heat Exchanger
            % Some configurating variables
            sHX_type = 'cross';       % Heat exchanger type
            
            %Geometry = [fN_Rows, fN_Pipes, fD_i, fD_o, fLength, fs_1, fs_2, fconfig
            Geometry = [3, 12, 0.05, 0.055, 0.5, 0.15, 0.15, 0];
            % --> see the HX file for information on the inputs for the different HX types
            
            Conductivity = 15;                          % Conductivity of the Heat exchanger solid material
            
            % Number of incremental heat exchangers used in the calculation
            % of the CHX
            iIncrements = 10;
            
            % Defines when the CHX should be recalculated: 
            fTempChangeToRecalc = 0.1;        % If any inlet temperature changes by more than 1 K
            fPercentChangeToRecalc = 0.25;  % If any inlet flowrate or composition changes by more than 0.25%
            
            % defines the heat exchanged object using the previously created properties
            % (oParent, sName, mHX, sHX_type, iIncrements, fHX_TC, fTempChangeToRecalc, fPercentChangeToRecalc)
            oCHX = components.CHX(this, 'CondensingHeatExchanger', Geometry, sHX_type, iIncrements, Conductivity, fTempChangeToRecalc, fPercentChangeToRecalc);
            
            % adds the P2P proc for the CHX that takes care of the actual
            % phase change
            oCHX.oP2P = components.HX.CHX_p2p(this.toStores.Tank_2, 'CondensingHX', 'Air_2.Condensate_Out', 'Condensate_Phase.Condensate_In', oCHX);

            % adds heaters to provide some temperature difference between
            % the two fluid loops
            components.heater(this, 'Air_Heater');
            components.heater(this, 'Water_Heater');
            
            %% Adding some pipes
            components.pipe(this, 'Pipe1', 1, 0.01, 0.0002);
            components.pipe(this, 'Pipe2', 1, 0.01, 0.0002);
            components.pipe(this, 'Pipe3', 1, 0.01, 0.0002);
            components.pipe(this, 'Pipe4', 1, 0.01, 0.0002);
            components.pipe(this, 'Pipe5', 1, 0.01, 0.0002);
            components.pipe(this, 'Pipe6', 1, 0.01, 0.0002);
            
            % Creating the flow path between the two gas tanks via the heat
            % exchanger
            % Input parameter format is always: 
            % 'store.exme', {'f2f-processor, 'f2fprocessor'}, 'store.exme'
            matter.branch(this, 'Tank_1.Port_1', {'Pipe1', 'CondensingHeatExchanger_2', 'Pipe2'}, 'Tank_2.Port_2');
            matter.branch(this, 'Tank_2.Port_4', {'Pipe5', 'Air_Heater'}, 'Tank_1.Port_3');
            
            % Creating the flow path between the two water tanks via the 
            % heat exchanger
            matter.branch(this, 'Tank_3.Port_5', {'Pipe3', 'CondensingHeatExchanger_1', 'Pipe4'}, 'Tank_4.Port_6');
            matter.branch(this, 'Tank_4.Port_8', {'Pipe6', 'Water_Heater'}, 'Tank_3.Port_7');
            
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
            
            this.toProcsF2F.Air_Heater.fPower = 10;
            this.toProcsF2F.Water_Heater.fPower = -10;
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

