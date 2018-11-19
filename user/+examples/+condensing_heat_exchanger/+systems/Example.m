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
            this@vsys(oParent, sName, 1);
            
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
            
            
            % Adding extract/merge processors to the phase
            matter.procs.exmes.gas(oAirPhase_1, 'Port_1');
            matter.procs.exmes.gas(oAirPhase_2, 'Port_2');
            matter.procs.exmes.gas(oAirPhase_1, 'Port_3');
            matter.procs.exmes.gas(oAirPhase_2, 'Port_4');
            
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
            
            matter.store(this, 'CHX', 1);
            oCHX_Air = this.toStores.CHX.createPhase('gas', 'flow', 'CHX_Gas', 0.9, struct('N2', 8e4, 'O2', 2e4, 'CO2', 500), 293.15, 0.5);
            
            oCondensatePhase = matter.phases.liquid(this.toStores.CHX, ...  Store in which the phase is located
                'Condensate_Phase', ...         Phase name
                struct('H2O', 1), ...      Phase contents
                295, ...                Phase temperature
                101325);                 % Phase pressure
            
            
            matter.procs.exmes.gas(oCHX_Air, 'CHX_In');
            matter.procs.exmes.gas(oCHX_Air, 'CHX_Out');
            
            matter.procs.exmes.gas(oCHX_Air, 'Condensate_Out');
            matter.procs.exmes.liquid(oCondensatePhase, 'Condensate_In');
            
            % Some configurating variables
            sHX_type = 'cross';       % Heat exchanger type
            %Geometry = [fN_Rows, fN_Pipes, fD_i, fD_o, fLength, fs_1, fs_2, fconfig
            Geometry = [3, 12, 0.05, 0.055, 0.5, 0.15, 0.15, 0];
            % --> see the HX file for information on the inputs for the different HX types
            
            
%             sHX_type = 'parallel plate'; 
%             % Geometry = [fBroadness, fHeight_1, fHeight_2, fLength, fThickness]
%             Geometry = [1, 0.01, 0.01, 2, 0.001];
            
            
            Conductivity = 15;                          % Conductivity of the Heat exchanger solid material
            
            % Number of incremental heat exchangers used in the calculation
            % of the CHX
            iIncrements = 10;
            
            % Defines when the CHX should be recalculated: 
            fTempChangeToRecalc = 0.1;        % If any inlet temperature changes by more than 1 K
            fPercentChangeToRecalc = 0.05;  % If any inlet flowrate or composition changes by more than 0.25%
            
            % defines the heat exchanged object using the previously created properties
            % (oParent, sName, mHX, sHX_type, iIncrements, fHX_TC, fTempChangeToRecalc, fPercentChangeToRecalc)
            oCHX = components.CHX(this, 'CondensingHeatExchanger', Geometry, sHX_type, iIncrements, Conductivity, fTempChangeToRecalc, fPercentChangeToRecalc);
            
            % adds the P2P proc for the CHX that takes care of the actual
            % phase change
            oCHX.oP2P = components.HX.CHX_p2p(this.toStores.CHX, 'CondensingHX', 'CHX_Gas.Condensate_Out', 'Condensate_Phase.Condensate_In', oCHX);

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
            
            components.fan_simple(this, 'Fan_1', 1e4);
            components.fan_simple(this, 'Fan_2', 1e4);
            
            % Creating the flow path between the two gas tanks via the heat
            % exchanger
            % Input parameter format is always: 
            % 'store.exme', {'f2f-processor, 'f2fprocessor'}, 'store.exme'
            matter.branch(this, 'Tank_1.Port_1', {'Pipe1', 'CondensingHeatExchanger_2'}, 'CHX.CHX_In');
            matter.branch(this, 'Tank_2.Port_4', {'Pipe5', 'Air_Heater'}, 'Tank_1.Port_3');
            
            % Creating the flow path between the two water tanks via the 
            % heat exchanger
            matter.branch(this, 'Tank_3.Port_5', {'Pipe3', 'CondensingHeatExchanger_1', 'Pipe4'}, 'Tank_4.Port_6');
            matter.branch(this, 'Tank_4.Port_8', {'Pipe6', 'Water_Heater'}, 'Tank_3.Port_7');
            
            matter.branch(this, 'CHX.CHX_Out', {'Pipe2'}, 'Tank_2.Port_2');
        end
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            % Creating the solver branches.
            oB1 = solver.matter.manual.branch(this.aoBranches(1));
            OB2 = solver.matter.manual.branch(this.aoBranches(2));
            oB3 = solver.matter.manual.branch(this.aoBranches(3));
            oB4 = solver.matter.manual.branch(this.aoBranches(4));
            solver.matter.residual.branch(this.aoBranches(5));
            
            oB1.setFlowRate(1);
            OB2.setFlowRate(1);
            oB3.setFlowRate(1);
            oB4.setFlowRate(1);
            
            
            this.toProcsF2F.Air_Heater.setPower(10);
            this.toProcsF2F.Water_Heater.setPower(-10);
            
            csStoreNames = fieldnames(this.toStores);
            for iStore = 1:length(csStoreNames)
                for iPhase = 1:length(this.toStores.(csStoreNames{iStore}).aoPhases)
                    oPhase = this.toStores.(csStoreNames{iStore}).aoPhases(iPhase);
                    
                    arMaxChange = zeros(1,this.oMT.iSubstances);
                    arMaxChange(this.oMT.tiN2I.H2O) = 0.001;
                    tTimeStepProperties.arMaxChange = arMaxChange;
                    
                    oPhase.setTimeStepProperties(tTimeStepProperties);
                end
            end
            
            this.setThermalSolvers();
        end
    end
    
    methods (Access = protected)
        
        function exec(this, ~)
            % exec(ute) function for this system
            % Here it only calls its parent's exec function
            exec@vsys(this);
            
            if this.oTimer.fTime > 10
                for iBranch = 1:4
                    
                    this.aoBranches(iBranch).oHandler.setFlowRate(0.001);
                    
                end
            else
                for iBranch = 1:4
                    
                    this.aoBranches(iBranch).oHandler.setFlowRate(1);
                    
                end
            end
        end
    end
end

