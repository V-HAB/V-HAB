classdef WPA < vsys
    %% Model of the Water Processing Assembly (WPA) as it is used on the ISS
    % in reality the WPA also has a product water tank of 150 lb capacity,
    % but that is not included in this model, as it would be difficult to
    % handle the outlet flowrates for that case. If you want to implement a
    % full WPA include that Tank on the system into which the WPA is built.
    %
    % Most of the model is based on the dissertation 
    % "DEVELOPMENT OF ION EXCHANGE MODELS FOR WATER TREATMENT AND
    % APPLICATION TO THE INTERNATIONAL SPACE STATION WATER PROCESSOR",
    % David Robert Hokanson, 2004
    % With some values regarding operation of the WPA and nominal
    % conditions from other papers.
    %
    % The Volatile Reactor Assembly (VRA) is modelled based on 
    % "Two-Phase Oxidizing Flow in Volatile Removal Assembly Reactor Under
    % Microgravity Conditions", Boyun Guo, Donald W. Holder and 
    % John T. Tester, 2005
    properties (SetAccess = protected, GetAccess = public)
        % The rated flowrate of the WPA is 13 lb/hr according to
        % "Performance Qualification Test of the ISS Water Processor
        % Assembly (WPA) Expendables", Layne Carter et.al, 2005
        fFlowRate           = 5.8967 / 3600;         %flowrate out of the waste water tank
        
        fCheckFillStateIntervall = 60;
        
        abContaminants;                            % Ionic contaminant array
        bCurrentlyProcessingWater = false;         % Boolean variable to decide whether water is currently beeing processed
    end
    methods
        function this = WPA(oParent, sName)
            this@vsys(oParent, sName, 60);
            eval(this.oRoot.oCfgParams.configCode(this));
            %connecting subystems
            
            % Must be at least 2, defines how many cells are used to
            % discretice the inddividual resin parts of the multifiltration
            % beds:
            miCells =  [5, 5, 3, 5, 3, 3, 2];
            % increase of speed by decreasing max capacity of MFBeds (used
            % to speed up the simulation for faster verification)
            fSpeed            = 1;                    
       
            components.matter.WPA.subsystems.MultifiltrationBED(this, 'MultiBED1',  miCells, fSpeed);
            components.matter.WPA.subsystems.MultifiltrationBED(this, 'MultiBED2',  miCells, fSpeed);
            components.matter.WPA.subsystems.MultifiltrationBED(this, 'IonBed',     miCells, fSpeed, true);
        end
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            %% stores
            
            matter.store(this, 'WasteWater', 68/998);    % Waster water tank 150lb water tank= 0,068m^3
            matter.store(this, 'LiquidSeperator_1',  2e-6);
            
            % reactor part
            fReactorPorosity = 0.447; 
            matter.store(this, 'LiquidSeperator_2',  2e-6);
            
            matter.store(this, 'Delay_Tank', 100);
            
            matter.store(this, 'Check_Tank',    1e-6);
            
            %reactor length=112cm and radius=1.74cm
            fReactorVolume = 0.001065 * fReactorPorosity; %reactor length=112cm and radius=1.74cm
            matter.store(this, 'Rack_Air',      fReactorVolume + 1e-6);
            
            %WW_Tank & WT_Tank
            oWasteWater         = this.toStores.WasteWater.createPhase(       	'mixture',          'Water', 'liquid',        0.62*this.toStores.WasteWater.fVolume,   struct('H2O', 1),                    293, 1e5);
            oLiquidSeperator1   = this.toStores.LiquidSeperator_1.createPhase(	'mixture', 'flow',	'Water', 'liquid',        1e-6,                                    struct('H2O', 1),                    293, 1e5);
            oCheckTank          = this.toStores.Check_Tank.createPhase(      	'mixture', 'flow',	'Water', 'liquid',        this.toStores.Check_Tank.fVolume,        struct('H2O', 1),                    293, 1e5);
            oReactor            = this.toStores.Rack_Air.createPhase(           'mixture', 'flow', 	'Water', 'liquid',        fReactorVolume,                          struct('H2O', 0.9995, 'O2', 5e-4),	402.594,  4.481e5);%265 Fahrenheit, 65psia =4,481bar
            oLiquidSeperator2   = this.toStores.LiquidSeperator_2.createPhase(	'mixture', 'flow',	'Water', 'liquid',        1e-6,                                    struct('H2O', 1),                    293, 1e5);
            
            oRackAir             = this.toStores.Rack_Air.createPhase(           'gas', 'flow',   'Air',   1e-6, struct('N2', 8e4, 'O2', 2e4, 'CO2', 500),          293,          0.5);
            oLiquidSeperator1Air = this.toStores.LiquidSeperator_1.createPhase(  'gas', 'flow',   'Air',   1e-6, struct('N2', 8e4, 'O2', 2e4, 'CO2', 500),          293,          0.5);
            oLiquidSeperator2Air = this.toStores.LiquidSeperator_2.createPhase(  'gas', 'flow',   'Air',   1e-6, struct('N2', 8e4, 'O2', 2e4, 'CO2', 500),          293,          0.5);
            
            %% components
            components.matter.WPA.components.Reactor_Manip('Oxidator', oReactor);
            
            components.matter.WPA.components.MLS(this.toStores.LiquidSeperator_1, 'LiquidSeperator_1_P2P', oLiquidSeperator1, oLiquidSeperator1Air);
            components.matter.WPA.components.MLS(this.toStores.LiquidSeperator_2, 'LiquidSeperator_2_P2P', oLiquidSeperator2, oLiquidSeperator2Air);
            
            components.matter.P2Ps.ManualP2P(    this.toStores.Rack_Air,          'ReactorOxygen_P2P',     oRackAir, oReactor);
            
            
            %% Valves
            oReflowValve = components.matter.valve(this, 'ReflowValve', 0);
            this.abContaminants = this.toChildren.MultiBED1.abContaminants;
            components.matter.WPA.components.MicrobialCheckValve(this, 'MicrobialCheckValve', 1, oReflowValve, this.abContaminants);
            
            %% Branches
            % Interface Branches of the WPA to Parent System
            matter.branch(this, oWasteWater,            {},                         'Inlet',    'Inlet');
            matter.branch(this, oCheckTank,             {'MicrobialCheckValve'},    'Outlet',   'Outlet');
            
            matter.branch(this, oRackAir,               {},                         'AirInlet',   'AirInlet');
            matter.branch(this, oRackAir,               {},                         'AirOutlet',  'AirOutlet');
            
            % Interface Branches to the Subsystem Beds
            % (Note that these are created here directly, instead of using
            % the setIfFlow function, because that allows us to create them
            % without defining interface tanks in between!)
            matter.branch(this, oWasteWater,            {}, oLiquidSeperator1,          'WasteWater_to_MLS1');
            
            oInletPhaseMLS1 = this.toChildren.MultiBED1.toChildren.Resin_1.toStores.Resin.toPhases.Water_1;
            matter.branch(this, oLiquidSeperator1,   	{}, oInletPhaseMLS1,            'MLS1_to_MFBed1');
            
            oOutletPhaseMFBed1 = this.toChildren.MultiBED1.toStores.OrganicRemoval.toPhases.Water;
            oInletPhaseMFBed2 = this.toChildren.MultiBED2.toChildren.Resin_1.toStores.Resin.toPhases.Water_1;
            matter.branch(this, oOutletPhaseMFBed1,     {}, oInletPhaseMFBed2,          'MFBed1_to_MFBed2');
            
            oOutletPhaseMFBed2 = this.toChildren.MultiBED2.toStores.OrganicRemoval.toPhases.Water;
            matter.branch(this, oOutletPhaseMFBed2,     {}, oReactor,                   'MFBed2_to_Reactor');
            
            matter.branch(this, oReactor,               {}, oLiquidSeperator2,          'Reactor_to_MLS2');
            
            oInletPhaseIonBed = this.toChildren.IonBed.toChildren.Resin_1.toStores.Resin.toPhases.Water_1;
            matter.branch(this, oLiquidSeperator2,   	{}, oInletPhaseIonBed,          'MLS2_to_IonBed');
            
            sLastPhaseName = ['Water_', num2str(this.toChildren.IonBed.toChildren.Resin_7.iCells)];
            oOutletPhaseIonBed = this.toChildren.IonBed.toChildren.Resin_7.toStores.Resin.toPhases.(sLastPhaseName);
            matter.branch(this, oOutletPhaseIonBed,   	{}, oCheckTank,                 'IonBed_to_Check');
            
            matter.branch(this, oCheckTank,          	{'ReflowValve'}, oWasteWater,  	'Check_to_WasteWater');
            
            matter.branch(this, oLiquidSeperator1Air, 	{}, oRackAir,                   'MLS1_to_Air');
            matter.branch(this, oLiquidSeperator2Air,  	{}, oRackAir,                   'MLS2_to_Air');
            
        end
        
        function createThermalStructure(this)
            % First we always need to call the createThermalStructure()
            % method of the parent class.
            createThermalStructure@vsys(this);
            
            oHeatSource = components.thermal.heatsources.ConstantTemperature('ReactorConstantTemperature');
            this.toStores.Rack_Air.toPhases.Water.oCapacity.addHeatSource(oHeatSource);
            
            oHeatSource = components.thermal.heatsources.ConstantTemperature('MLS2ConstantTemperature');
            this.toStores.LiquidSeperator_2.toPhases.Water.oCapacity.addHeatSource(oHeatSource);
            
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            solver.matter.manual.branch(this.toBranches.WasteWater_to_MLS1);
            
            solver.matter.manual.branch(this.toBranches.AirInlet);
            this.toBranches.AirInlet.oHandler.setFlowRate(-0.1);
            
            solver.matter.residual.branch(this.toBranches.AirOutlet);
            
            csFields = fieldnames(this.toBranches);
            csFields(strcmp(csFields, 'WasteWater_to_MLS1'))= [];
            csFields(strcmp(csFields, 'AirInlet'))          = [];
            csFields(strcmp(csFields, 'AirOutlet'))         = [];

            for iBranch = 1:length(csFields)
                aoMultiSolverBranches(iBranch,1) = this.toBranches.(csFields{iBranch});%#ok
            end
            
            aoMultiSolverBranches = [aoMultiSolverBranches; this.toChildren.MultiBED1.aoBranches];
            
            for iResin = 1:7
                aoMultiSolverBranches = [aoMultiSolverBranches; this.toChildren.MultiBED1.toChildren.(['Resin_', num2str(iResin)]).aoBranches];%#ok
            end
            
            aoMultiSolverBranches = [aoMultiSolverBranches; this.toChildren.MultiBED2.aoBranches];
            for iResin = 1:7
                aoMultiSolverBranches = [aoMultiSolverBranches; this.toChildren.MultiBED2.toChildren.(['Resin_', num2str(iResin)]).aoBranches];%#ok
            end
            
            aoMultiSolverBranches = [aoMultiSolverBranches; this.toChildren.IonBed.aoBranches];
            for iResin = 1:7
                aoMultiSolverBranches = [aoMultiSolverBranches; this.toChildren.IonBed.toChildren.(['Resin_', num2str(iResin)]).aoBranches];%#ok
            end
            
            tSolverProperties.fMaxError = 1e-6;
            tSolverProperties.iMaxIterations = 1000;
            tSolverProperties.fMinimumTimeStep = 1;
            tSolverProperties.iIterationsBetweenP2PUpdate = 200;
            tSolverProperties.bSolveOnlyFlowRates = true;
            
            oSolver = solver.matter_multibranch.iterative.branch(aoMultiSolverBranches, 'complex');
            oSolver.setSolverProperties(tSolverProperties);
            
            for iBed = 1:this.iChildren
                oBed = this.toChildren.(this.csChildren{iBed});
                for iResin = 1:oBed.iChildren
                    oResin = oBed.toChildren.(oBed.csChildren{iResin});
                    for iCell = 1:oResin.iCells
                        oResin.toStores.Resin.toPhases.(['Resin_', num2str(iCell)]).bind('update_post', @oSolver.registerUpdate);
                    end
                end
            end
            % We only have one non flow phase, the waste water phase. For
            % that we do not really care how fast things in it change,
            % therefore we set the Max Change to inf.
            tTimeStepProperties.rMaxChange = inf;
            tTimeStepProperties.fMaxStep = this.fTimeStep;

            this.toStores.WasteWater.toPhases.Water.setTimeStepProperties(tTimeStepProperties);
            
            this.setThermalSolvers();
        end
        
        function setIfFlows(this, varargin)
            % This function connects the system and subsystem level branches with
            % each other. It uses the connectIF function provided by the
            % matter.container class
            this.connectIF('Inlet' ,     	varargin{1});
            this.connectIF('Outlet' ,     	varargin{2});
            this.connectIF('AirInlet',    	varargin{3}); 
            this.connectIF('AirOutlet',    	varargin{4});
        end
        
    end
    
    methods (Access = protected)
        function exec(this, ~)
            
            exec@vsys(this);
            %% Internal Space Station Water Balance Operation (Paper)
            bActiveMassTransfer = this.toBranches.WasteWater_to_MLS1.oHandler.bMassTransferActive;
            if (this.toStores.WasteWater.toPhases.Water.fMass > 0.65 * 68) && ~bActiveMassTransfer
                % flowrate set to inlet processing flowrate
                fMassToTransfer = 0.61 * this.toStores.WasteWater.toPhases.Water.fMass;
                fTimeForTransfer = fMassToTransfer / this.fFlowRate;
                
            	this.toBranches.WasteWater_to_MLS1.oHandler.setMassTransfer(fMassToTransfer, fTimeForTransfer)
                
                % Since the only next point at which we want to execute the
                % WPA is when the transfer is finished, we set the time
                % step accordingly
                this.setTimeStep(fTimeForTransfer)
            
            end
            
            this.bCurrentlyProcessingWater = this.toBranches.WasteWater_to_MLS1.oHandler.bMassTransferActive;
            
            if this.bCurrentlyProcessingWater
                % According to "Two-Phase Oxidizing Flow in Volatile Removal
                % Assembly Reactor Under Microgravity Conditions", Boyun Guo,
                % Donald W. Holder and John T. Tester, 2005, 
                % The oxygen injection rate of the VRA reactor on the ISS is
                % 0.001 g/s
                afFlowRates = zeros(1, this.oMT.iSubstances);
                afFlowRates(this.oMT.tiN2I.O2) = 0.001e-3;
                this.toStores.Rack_Air.toProcsP2P.ReactorOxygen_P2P.setFlowRate(afFlowRates);
            else
                afFlowRates = zeros(1, this.oMT.iSubstances);
                this.toStores.Rack_Air.toProcsP2P.ReactorOxygen_P2P.setFlowRate(afFlowRates);
                
                % While the WPA is off, we check the fill state of the tank
                % at the specified intervall
                this.setTimeStep(this.fCheckFillStateIntervall)
            end
        end
    end
end