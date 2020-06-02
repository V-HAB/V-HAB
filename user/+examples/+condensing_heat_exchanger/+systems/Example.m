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
            matter.store(this, 'Tank_1', 1.1);
            
            % uses the custom air helper to generate an air phase with a
            % defined co2 level and relative humidity
            fCO2Percent = 0.4;
            cAirHelper = matter.helper.phase.create.air_custom(this.toStores.Tank_1, 1, struct('CO2', fCO2Percent),  313, 0.5, 1e5);
               
            % Adding a phase to the store 'Tank_1', 1 m^3 air
            oAirPhase_1 = matter.phases.gas(this.toStores.Tank_1, 'Air_1', cAirHelper{1}, cAirHelper{2}, cAirHelper{3});

            %this.Air_1.setMatterProperties(
            
            % Creating a second store, volume 1 m^3
            matter.store(this, 'Tank_2', 1.1);
            
            % Adding a phase to the store 'Tank_2', 2 m^3 air
            oAirPhase_2 = matter.phases.gas(this.toStores.Tank_2, 'Air_2', cAirHelper{1}, cAirHelper{2}, cAirHelper{3});
            
            
            %% Water System
            % Creating a third store, volume 1 m^3
            matter.store(this, 'Tank_3', 2);
            
            % Adding a phase to the store 'Tank_3', 1 m^3 water
            oCoolantPhase1 = matter.phases.liquid(this.toStores.Tank_3, ...  Store in which the phase is located
                'Coolant_Phase1', ...        Phase name
                struct('H2O', 1000), ...         Phase contents
                275.15,...                  % Phase temperature
                1e5);                       % Phase pressure
            
            % Creating a fourth store, volume 1 m^3
            matter.store(this, 'Tank_4', 2);
            %keyboard(); 
            % Adding a phase to the store 'Tank_4', 1 kg water
            oCoolantPhase2 = matter.phases.liquid(this.toStores.Tank_4, ...  Store in which the phase is located
                'Coolant_Phase2', ...         Phase name
                struct('H2O', 1000), ...          Phase contents
                275.15,...                    % Phase temperature
                1e5);                       % Phase pressure
            
% %             matter.store(this, 'Humidity', 1);
%             oHumidityPhase = matter.phases.liquid(this.toStores.Tank_1, 'HumidityPhase', struct('H2O',1), 0.1, 295, 101325);
%             matter.procs.exmes.liquid(oHumidityPhase, 'Humidity_Out');
            
            aoPhases_Temp(1) = oAirPhase_1;
            aoPhases_Temp(2) = oAirPhase_2;
            aoPhases_Temp(3) = oCoolantPhase1;
            aoPhases_Temp(4) = oCoolantPhase2;
%             aoPhases_Temp(5) = oHumidityPhase;
            this.aoPhases = aoPhases_Temp;
            %% Heat Exchanger
            
            matter.store(this, 'CHX', 1);
            oCHX_Air = this.toStores.CHX.createPhase('gas', 'flow', 'CHX_Gas', 0.9, struct('N2', 8e4, 'O2', 2e4, 'CO2', 500), 293.15, 0.5);
            
            oCondensatePhase = matter.phases.liquid(this.toStores.CHX, ...  Store in which the phase is located
                'Condensate_Phase', ...         Phase name
                struct('H2O', 1), ...      Phase contents
                295, ...                Phase temperature
                101325);                 % Phase pressure
            
            
            matter.procs.exmes.gas(oCHX_Air, 'Condensate_Out');
            matter.procs.exmes.liquid(oCondensatePhase, 'Condensate_In');
            % Some configurating variables
            sHX_type = 'plate_fin';       % Heat exchanger type
            
            % broadness of the heat exchange area in m
            tGeometry.fBroadness        = 0.1;  
            % Height of the channel for fluid 1 in m
            tGeometry.fHeight_1         = 0.003;
            % Height of the channel for fluid 2 in m
            tGeometry.fHeight_2         = 0.003;
            % length of the heat exchanger in m
            tGeometry.fLength           = 0.1;
            % thickness of the plate in m
            tGeometry.fThickness        = 0.004;
            % number of layers stacked
            tGeometry.iLayers           = 33;
            % number of baffles (evenly distributed)
            tGeometry.iBaffles          = 3;
            % broadness of a fin of the first canal (air)
            tGeometry.fFinBroadness_1	= 1/18;
            % broadness of a fin of the second canal (coolant)
            tGeometry.fFinBroadness_2	= 1/18; 
            %  Thickness of the Fins (for now both fins have the same thickness
            tGeometry.fFinThickness     = 0.001;
            
            % TODO: add calculation for different fin broadness, currently
            % value 1 and 2 must be equal
            
            % Conductivity of the Heat exchanger solid material
            Conductivity = 15;                          
            
            % Number of incremental heat exchangers used in the calculation
            % of the CHX
            iIncrements = 2;
            
            % Defines when the CHX should be recalculated: 
            fTempChangeToRecalc = 0.05;        % If any inlet temperature changes by more than 1 K
            fPercentChangeToRecalc = 0.05;  % If any inlet flowrate or composition changes by more than 0.25%
            
            % defines the heat exchanged object using the previously created properties
            % (oParent, sName, mHX, sHX_type, iIncrements, fHX_TC, fTempChangeToRecalc, fPercentChangeToRecalc)
            oCHX = components.matter.CHX(this, 'CondensingHeatExchanger', tGeometry, sHX_type, iIncrements, Conductivity, fTempChangeToRecalc, fPercentChangeToRecalc);
            
            % adds the P2P proc for the CHX that takes care of the actual
            % phase change
            oCHX.oP2P = components.matter.HX.CHX_p2p(this.toStores.CHX, 'CondensingHX', 'CHX_Gas.Condensate_Out', 'Condensate_Phase.Condensate_In', oCHX);

            % Humidity Source
%             components.P2Ps.ManualP2P(this, this.toStores.Tank_1, 'Humidity_Source' , 'HumidityPhase.Humidity_Out', 'Air_1.Humidity_In');
            
            %% Adding some pipes
            components.matter.pipe(this, 'Pipe1', 1, 0.01, 0.0002);
            components.matter.pipe(this, 'Pipe2', 1, 0.01, 0.0002);
            components.matter.pipe(this, 'Pipe3', 1, 0.01, 0.0002);
            components.matter.pipe(this, 'Pipe4', 1, 0.01, 0.0002);
            components.matter.pipe(this, 'Pipe5', 1, 0.01, 0.0002);
            components.matter.pipe(this, 'Pipe6', 1, 0.01, 0.0002);
            
            % Creating the flow path between the two gas tanks via the heat
            % exchanger
            % Input parameter format is always: 
            % 'store.exme', {'f2f-processor, 'f2fprocessor'}, 'store.exme'
            matter.branch(this, oAirPhase_1,    {'Pipe1',   'CondensingHeatExchanger_1'},               oCHX_Air,       'CHX_Air_In');
            matter.branch(this, oCHX_Air,       {'Pipe2'},                                              oAirPhase_1,  	'CHX_Air_Out');
            
            % Creating the flow path between the two water tanks via the 
            % heat exchanger
            matter.branch(this, oCoolantPhase1,    {'Pipe3', 'CondensingHeatExchanger_2', 'Pipe4'},     oCoolantPhase2,    'CHX_Water_In');
            matter.branch(this, oCoolantPhase2,    {'Pipe6'},                                           oCoolantPhase1,    'CHX_Water_Out');
            

%             matter.branch(this, 'Tank_1.Humidity_Out', {'Humidity_Source'}, 'Tank_1.Humidity_In');
            
        end
        
        function createThermalStructure(this)
            createThermalStructure@vsys(this);
            
            oCapacityTank_1 = this.toStores.Tank_1.toPhases.Air_1.oCapacity;
            oHeatSource = thermal.heatsource('AirHeater', 100);
            oCapacityTank_1.addHeatSource(oHeatSource);
            
            
            oCapacityTank_4 = this.toStores.Tank_4.toPhases.Coolant_Phase2.oCapacity;
            oHeatSource = components.thermal.heatsources.ConstantTemperature('Coolant_Constant_Temperature');
            oCapacityTank_4.addHeatSource(oHeatSource);
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            % Creating the solver branches.
            solver.matter.manual.branch(this.toBranches.CHX_Air_In);
            solver.matter.residual.branch(this.toBranches.CHX_Air_Out);
            
            solver.matter.manual.branch(this.toBranches.CHX_Water_In);
            solver.matter.manual.branch(this.toBranches.CHX_Water_Out);
            

            % Volumetric Flowrate Atmosphere (maximum) 14150 L/min
            % [Wieland1998] --> vol. Flowrate 0.2358 m^3/s
            % Coolant Flowrate CHX ISS 558kg/h [Wieland1998] = 0.1150 kg/s
            
            fAirVolumetricFlowRate = 0.2358;
            fCoolanttFlowRate = 0.1150;
            this.toBranches.CHX_Air_In.oHandler.setVolumetricFlowRate(fAirVolumetricFlowRate);
            
            this.toBranches.CHX_Water_In.oHandler.setFlowRate(fCoolanttFlowRate);
            this.toBranches.CHX_Water_Out.oHandler.setFlowRate(fCoolanttFlowRate);
            
%             %Flowrate for Humidity Source
%             afHumidityP2PFlowRates = zeros(1,this.oMT.iSubstances);
%             afHumidityP2PFlowRates(this.oMT.tiN2I.H2O) = 0.1;
%             this.toStores.Tank_1.toProcsP2P.Humidity_Source.setFlowRate(afHumidityP2PFlowRates);
% %             ob5.setFlowRate(afHumidityP2PFlowRates);
             
            iCrewMember = 3;
            this.toStores.Tank_1.toPhases.Air_1.oCapacity.toHeatSources.AirHeater.setHeatFlow(83.1250*iCrewMember);
            
            csStoreNames = fieldnames(this.toStores);
            for iStore = 1:length(csStoreNames)
                for iPhase = 1:length(this.toStores.(csStoreNames{iStore}).aoPhases)
                    oPhase = this.toStores.(csStoreNames{iStore}).aoPhases(iPhase);
                    
                    arMaxChange = zeros(1,this.oMT.iSubstances);
                    arMaxChange(this.oMT.tiN2I.H2O) = 0.001;
                    tTimeStepProperties.arMaxChange = arMaxChange;
                    
                    oPhase.setTimeStepProperties(tTimeStepProperties);
                    
                    tThermalTimeStepProperties.rMaxChange = 1e-3;
                    oPhase.oCapacity.setTimeStepProperties(tThermalTimeStepProperties);
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
            
%             if this.oTimer.fTime > 10
%                 for iBranch = 1:length(this.aoBranches)
%                     
%                     this.aoBranches(iBranch).oHandler.setFlowRate(0.001);
%                     
%                 end
%             else
%                 for iBranch = 1:length(this.aoBranches)
%                     
%                     this.aoBranches(iBranch).oHandler.setFlowRate(1);
%                     
%                 end
%             end
        end
    end
end
