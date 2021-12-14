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
            this@vsys(oParent, sName, 60);
            
            eval(this.oRoot.oCfgParams.configCode(this));
            
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            matter.store(this, 'Cabin', 10);
            oCabin              = this.toStores.Cabin.createPhase(      'gas',              'Air',          this.toStores.Cabin.fVolume,        struct('N2', 8e4, 'O2', 2e4, 'CO2', 500),	293,	0.5);
            
            matter.store(this, 'Coolant', 2);
            oCoolant            = this.toStores.Coolant.createPhase(	'liquid',           'Water',        this.toStores.Coolant.fVolume,      struct('H2O', 1),                           275.15, 1e5);
            
            %% Heat Exchanger
            
            matter.store(this, 'CHX', 1);
            oCHX_Air            = this.toStores.CHX.createPhase(        'gas',      'flow', 'CHX_Gas',      0.9 * this.toStores.CHX.fVolume,    struct('N2', 8e4, 'O2', 2e4, 'CO2', 500),   293.15, 0.5);
            
            oCondensatePhase    = this.toStores.CHX.createPhase(        'liquid',           'Condensate',   0.1 * this.toStores.CHX.fVolume,    struct('H2O', 1),                           275.15, 1e5);
            
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
            iIncrements = 3;
            
            % Defines when the CHX should be recalculated: 
            fTempChangeToRecalc = 0.05;        % If any inlet temperature changes by more than 1 K
            fPercentChangeToRecalc = 0.05;  % If any inlet flowrate or composition changes by more than 0.25%
            
            % defines the heat exchanged object using the previously created properties
            % (oParent, sName, mHX, sHX_type, iIncrements, fHX_TC, fTempChangeToRecalc, fPercentChangeToRecalc)
            oCHX = components.matter.CHX(this, 'CondensingHeatExchanger', tGeometry, sHX_type, iIncrements, Conductivity, fTempChangeToRecalc, fPercentChangeToRecalc);
            
            % adds the P2P proc for the CHX that takes care of the actual
            % phase change
            oCHX.oP2P = components.matter.HX.CHX_p2p(this.toStores.CHX, 'CondensingHX', oCHX_Air, oCondensatePhase, oCHX);
            
            % Creating the flow path between the two gas tanks via the heat
            % exchanger
            % Input parameter format is always: 
            % 'store.exme', {'f2f-processor, 'f2fprocessor'}, 'store.exme'
            matter.branch(this, oCabin,     {'CondensingHeatExchanger_1'},   	oCHX_Air,	'CHX_Air_In');
            matter.branch(this, oCHX_Air,	{},                              	oCabin,  	'CHX_Air_Out');
            
            % Creating the flow path between the two water tanks via the 
            % heat exchanger
            matter.branch(this, oCoolant,  	{'CondensingHeatExchanger_2'},  	oCoolant,    'CHX_Water_Loop');
            

        end
        
        function createThermalStructure(this)
            createThermalStructure@vsys(this);
            
            oCapacityCabin = this.toStores.Cabin.toPhases.Air.oCapacity;
            iCrewMember = 3;
            oHeatSource = thermal.heatsource('AirHeater', 83.1250*iCrewMember);
            oCapacityCabin.addHeatSource(oHeatSource);
            
            
            oCapacityCoolant = this.toStores.Coolant.toPhases.Water.oCapacity;
            oHeatSource = components.thermal.heatsources.ConstantTemperature('Coolant_Constant_Temperature');
            oCapacityCoolant.addHeatSource(oHeatSource);
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            % Creating the solver branches.
            solver.matter.manual.branch(this.toBranches.CHX_Air_In);
            solver.matter.residual.branch(this.toBranches.CHX_Air_Out);
            
            solver.matter.manual.branch(this.toBranches.CHX_Water_Loop);
            
            % Volumetric Flowrate Atmosphere (maximum) 14150 L/min
            % [Wieland1998] --> vol. Flowrate 0.2358 m^3/s
            % Coolant Flowrate CHX ISS 558kg/h [Wieland1998] = 0.1150 kg/s
            fAirVolumetricFlowRate = 0.2358;
            fCoolanttFlowRate = 0.1150;
            this.toBranches.CHX_Air_In.oHandler.setVolumetricFlowRate(fAirVolumetricFlowRate);
            
            this.toBranches.CHX_Water_Loop.oHandler.setFlowRate(fCoolanttFlowRate);
            
            
            csStoreNames = fieldnames(this.toStores);
            for iStore = 1:length(csStoreNames)
                for iPhase = 1:length(this.toStores.(csStoreNames{iStore}).aoPhases)
                    oPhase = this.toStores.(csStoreNames{iStore}).aoPhases(iPhase);
                    
                    arMaxChange = zeros(1,this.oMT.iSubstances);
                    arMaxChange(this.oMT.tiN2I.H2O) = 1e-2;
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
            
            % this.toStores.Cabin.toPhases.Air.oCapacity.toHeatSources.AirHeater.setHeatFlow(83.1250*iCrewMember);
        end
    end
end
