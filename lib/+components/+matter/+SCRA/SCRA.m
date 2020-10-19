classdef SCRA < vsys
    %% Sabatier Carbon Dioxide Reduction Assembly (SCRA)
    %
    % The SCRA uses H2 generated by OGA and CO2 from the CDRA to create
    % water and methane. The methane is then vented over board but the
    % water can be used by the electrolyzer again to generate more oxygen.
    %
    % The H2 and CO2 phase to which it is connected should be a flow phase,
    % to which you provide the flowrate that should enter SCRA with a
    % manual solver branch each.
    
    properties (SetAccess = protected, GetAccess = public)
        
        fCoolantTemperature;
        
        fCurrentPowerConsumption = 0; % W
    end
    
    methods
        function this = SCRA (oParent, sName, fFixedTS, fCoolantTemperature)
            this@vsys(oParent, sName, fFixedTS);
            
            this.fCoolantTemperature = fCoolantTemperature;
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            % according to "Integrated Test and Evaluation of a 4-Bed Molecular
            % Sieve (4BMS) Carbon Dioxide Removal System (CDRA), Mechanical
            % Compressor Engineering Development Unit (EDU), and Sabatier
            % Engineering Development Unit (EDU)", Knox et. al., 2005 ICES
            % 2005-01-2864 the SCRA is mentioned to have a 0.73 ft^3
            % accumulator tank
            fVolumeCRA_Accumulator = 0.02067;
            matter.store(this, 'CRA_Accumulator', fVolumeCRA_Accumulator);
            % pressure ranges for the accumulator are also provided in the
            % paper, here initialized to 6 bar
            oAccumulatorCO2	= this.toStores.CRA_Accumulator.createPhase( 'gas',   'CO2', fVolumeCRA_Accumulator, struct('CO2', 7e5), 293, 0);
            
            matter.store(this, 'CRA_H2_In', 1e-6);
            oH2	= this.toStores.CRA_H2_In.createPhase( 'gas', 'flow', 'H2', 1e-6, struct('H2', 1e5), 293, 0);
            
            % We uses as initial assumptions for the partial pressure,
            % however as flow phases are used in the model, this is not a
            % very important assumption
            fPartialPressureCO2 = 0.01 * 101325;
            fPartialPressureH2  = 0.01 * 101325;
            fPartialPressureCH4 = 0.49 * 101325;
            fPartialPressureH2O = 0.49 * 101325;
            
            fVolumeCRA_Sabatier = 0.1;
            matter.store(this, 'CRA_Sabatier', fVolumeCRA_Sabatier);
            % The reactor temperature for SCRA can also be found in
            % "Integrated Test and Evaluation of a 4-Bed Molecular Sieve
            % (4BMS) Carbon Dioxide Removal System (CDRA), Mechanical
            % Compressor Engineering Development Unit (EDU), and Sabatier
            % Engineering Development Unit (EDU)", Knox et. al., 2005 ICES
            % 2005-01-2864.
            % While the heaters are mentioned to keep the reactor at 300°F
            % (422 K), the reactor hot zone temperature in the figures is
            % shown to be around 1000°F (811 K)
            oCRA_SabatierPhase	= this.toStores.CRA_Sabatier.createPhase( 'gas', 'flow', 'CRA_Sabatierphase', fVolumeCRA_Sabatier, struct('CO2', fPartialPressureCO2, 'H2', fPartialPressureH2, 'CH4', fPartialPressureCH4, 'H2O', fPartialPressureH2O), 811, 0);
            
            % substance manipulator that changes educts to products based on
            % the chemical reaction and the current masses in the reactor.
            % Also calculates the generated heat flow from this reaction
            % according to "Integrated Test and Evaluation of a 4-Bed Molecular
            % Sieve (4BMS) Carbon Dioxide Removal System (CDRA), Mechanical
            % Compressor Engineering Development Unit (EDU), and Sabatier
            % Engineering Development Unit (EDU)", Knox et. al., 2005 ICES
            % 2005-01-2864 Table 5 the conversion efficiency is between 87%
            % and 93% with most test points resulting in 88% efficiency.
            % Therefore, this value is used here
            components.matter.SCRA.CRA_Sabatier_manip_proc('CRA_Sabatier_proc', oCRA_SabatierPhase, 0.88);
            
            %The actual CHX that is used is unknown and therefore this
            %simply uses a heat exchanger with somewhat realistic values.
            %If data on the actual CHX is found this should be corrected.
            % Creating the CHX
            % Some configurating variables
            sHX_type = 'plate_fin';       % Heat exchanger type
            % broadness of the heat exchange area in m
            tGeometry.fBroadness        = 0.05;  
            % Height of the channel for fluid 1 in m
            tGeometry.fHeight_1         = 0.002;
            % Height of the channel for fluid 2 in m
            tGeometry.fHeight_2         = 0.002;
            % length of the heat exchanger in m
            tGeometry.fLength           = 0.05;
            % thickness of the plate in m
            tGeometry.fThickness        = 0.0002;
            % number of layers stacked
            tGeometry.iLayers           = 15;
            % number of baffles (evenly distributed)
            tGeometry.iBaffles          = 3;
            % broadness of a fin of the first canal (air)
            tGeometry.fFinBroadness_1	= tGeometry.fBroadness/180;
            % broadness of a fin of the second canal (coolant)
            tGeometry.fFinBroadness_2	= tGeometry.fBroadness/180; 
            %  Thickness of the Fins (for now both fins have the same thickness
            tGeometry.fFinThickness     = 0.0002;
            % Conductivity of the Heat exchanger solid material (W/m K)
            Conductivity = 205;
            % Number of incremental heat exchangers used in the calculation
            % of the CHX
            miIncrements = [6,3];
            % Defines when the CHX should be recalculated: 
            fTempChangeToRecalc = 4;       % If any inlet temperature changes by more than 1 K
            fPercentChangeToRecalc = 0.1;  % If any inlet flowrate or composition changes by more than 5%
            
            % defines the heat exchanged object using the previously created properties
            % (oParent, sName, mHX, sHX_type, iIncrements, fHX_TC, fTempChangeToRecalc, fPercentChangeToRecalc)
            oCRA_CHX = components.matter.CHX(this, 'CRA_SabatierCHX', tGeometry, sHX_type, miIncrements, Conductivity, fTempChangeToRecalc, fPercentChangeToRecalc);
            
            tProperties.fSearchStepTemperatureDifference    = 5;
            tProperties.iMaximumNumberOfSearchSteps         = 25;
            tProperties.rMaxError                           = 0.2;
            oCRA_CHX.setNumericProperties(tProperties);
            %CRA Water Recovery
            %Recovers the water from the sabatier production gas
            %Implemented with three filters to prevent any water loss
            
            fVolumeCRA_WaterRec = 0.02;
            matter.store(this, 'CRA_WaterRec', fVolumeCRA_WaterRec);
            oCRA_WaterRecLiquidPhase = this.toStores.CRA_WaterRec.createPhase(	'liquid', 'RecoveredWater', 0.5 * fVolumeCRA_WaterRec, struct('H2O', 1), 293, 1e5);
            
            fVolumeGasWaterRec = fVolumeCRA_WaterRec - oCRA_WaterRecLiquidPhase.fVolume;
            oCRA_WaterRecGasPhase	= this.toStores.CRA_WaterRec.createPhase( 'gas', 'flow', 'WRecgas', fVolumeGasWaterRec, struct('CO2', fPartialPressureCO2, 'H2', fPartialPressureH2, 'CH4', fPartialPressureCH4, 'H2O', fPartialPressureH2O), 280, 0);
            
            % adds the P2P proc for the CHX that takes care of the actual
            % phase change
            oCRA_CHX.oP2P = components.matter.HX.CHX_p2p(this.toStores.CRA_WaterRec, 'CondensingHX', oCRA_WaterRecGasPhase, oCRA_WaterRecLiquidPhase, oCRA_CHX);
            
            %this is only necessary because V-HAB does not allow two
            %interfaces to other systems in the same branch
            fCHX_Volume = 0.02;
            matter.store(this, 'CRA_CHXStore', fCHX_Volume);
            oCRA_CHXPhase = this.toStores.CRA_CHXStore.createPhase(	'liquid', 'CHXWater', 0.5 * fCHX_Volume, struct('H2O', 1), this.fCoolantTemperature, 1e5);
            
            % Define the standard values used for pipes
            fPipelength         = 1;
            fPipeDiameter       = 0.1;
            fFrictionFactor     = 2e-4;
            components.matter.pipe(this, 'Pipe_001', fPipelength, fPipeDiameter, fFrictionFactor);
            components.matter.pipe(this, 'Pipe_002', fPipelength, fPipeDiameter, fFrictionFactor);
            components.matter.pipe(this, 'Pipe_003', fPipelength, fPipeDiameter, fFrictionFactor);
            components.matter.pipe(this, 'Pipe_004', fPipelength, fPipeDiameter, fFrictionFactor);
            components.matter.pipe(this, 'Pipe_005', fPipelength, fPipeDiameter, fFrictionFactor);
            components.matter.pipe(this, 'Pipe_006', fPipelength, fPipeDiameter, fFrictionFactor);
            components.matter.pipe(this, 'Pipe_007', fPipelength, fPipeDiameter, fFrictionFactor);
            components.matter.pipe(this, 'Pipe_008', fPipelength, fPipeDiameter, fFrictionFactor);
            components.matter.pipe(this, 'Pipe_009', fPipelength, fPipeDiameter, fFrictionFactor);
            components.matter.pipe(this, 'Pipe_010', fPipelength, fPipeDiameter, fFrictionFactor);
            components.matter.pipe(this, 'Pipe_011', fPipelength, fPipeDiameter, fFrictionFactor);
            
            components.matter.SCRA.CRA_Vacuum_Outlet(this, 'VacuumOutlet');
            components.matter.SimplePressureRegulator(this, 'CRA_H2_Regulator', 1.5e5);
            
            components.matter.valve(this, 'SabatierValve', 0);
            components.matter.valve(this, 'VentValveH2', 0);
            % In this case we use a normal valve, like a check valve
            components.matter.valve(this, 'Checkvalve', 0);
            components.matter.checkvalve(this, 'VacuumCheckvalve');
            
            components.matter.SCRA.CRA_Sabatier_Heater(this, 'CRA_SabatierHeater');
            
            %Finally the flowpaths between all components
            matter.branch(this, oH2,                        {'Pipe_001', 'CRA_H2_Regulator'},                 	'SCRA_H2_In',           'CRA_H2_In');
            matter.branch(this, oAccumulatorCO2,            {'Pipe_002'},                                       'SCRA_CO2_In',          'CRA_CO2_In');
            matter.branch(this, oAccumulatorCO2,            {'Pipe_003'},                                       oCRA_SabatierPhase, 	'Accumulator_To_CRA');
            
            matter.branch(this, oCRA_SabatierPhase,         {'Pipe_004', 'CRA_SabatierCHX_1', 'Checkvalve'},	oCRA_WaterRecGasPhase,	'CRA_ProductstoWaterRecbranch');
            matter.branch(this, oCRA_WaterRecGasPhase,      {'Pipe_005', 'VacuumOutlet', 'VacuumCheckvalve'},  	'SCRA_DryGas_Out',   	'CRA_DryGastoVent');
            matter.branch(this, oCRA_WaterRecLiquidPhase,	{'Pipe_006'},                                       'SCRA_Condensate_Out',	'CRA_RecWaterOut');
            matter.branch(this, oCRA_CHXPhase,              {'Pipe_007'},                                       'SCRA_CoolantIn',     	'CRA_CoolantLoopIn');
            % As can be seen in the Schematic of the SCRA (Figure 3 in
            % "Integrated Test and Evaluation of a 4-Bed Molecular Sieve
            % (4BMS) Carbon Dioxide Removal System (CDRA), Mechanical
            % Compressor Engineering Development Unit (EDU), and Sabatier
            % Engineering Development Unit (EDU)", Knox et. al.
            % ICES-2005-01-2864. The heat from the sabatier reaction also
            % enter the coolant flow after the CHX:
            matter.branch(this, oCRA_CHXPhase,              {'Pipe_008', 'CRA_SabatierCHX_2', 'CRA_SabatierHeater'},	'SCRA_CoolantOut',    	'CRA_CoolantLoopOut');
            
            matter.branch(this, oH2,                        {'Pipe_009', 'SabatierValve'},                    	oCRA_SabatierPhase, 	'H2_to_Sabatier');
            matter.branch(this, oH2,                        {'Pipe_010', 'VentValveH2'},                    	oCRA_WaterRecGasPhase, 	'H2_to_Vent');
            matter.branch(this, oAccumulatorCO2,            {'Pipe_011'},                                       oCRA_WaterRecGasPhase, 	'CO2_to_Vent');
            
        end
        
        function createThermalStructure(this)
            % First we always need to call the createThermalStructure()
            % method of the parent class.
            createThermalStructure@vsys(this);
            
            oHeatSource = components.thermal.heatsources.ConstantTemperature('Sabatier_Constant_Temperature');
            this.toStores.CRA_Sabatier.toPhases.CRA_Sabatierphase.oCapacity.addHeatSource(oHeatSource);
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            solver.matter.residual.branch(this.toBranches.CRA_RecWaterOut);
            
            solver.matter.manual.branch(this.toBranches.Accumulator_To_CRA);
            solver.matter.manual.branch(this.toBranches.CRA_CoolantLoopIn);
            solver.matter.manual.branch(this.toBranches.CRA_CoolantLoopOut);
            solver.matter.manual.branch(this.toBranches.CO2_to_Vent);
            
            this.toBranches.CRA_CoolantLoopIn.oHandler.setFlowRate(-0.2);
            this.toBranches.CRA_CoolantLoopOut.oHandler.setFlowRate(0.2);
            
            % The CO2 Inlet branch is seperated from the other branches in
            % SCRA via the accumulator. It is also a multisolver branch
            % because e.g. the CDRA supplies the CO2 and then adds only
            % this branch to its solver
            oSolver = solver.matter_multibranch.iterative.branch(this.toBranches.CRA_CO2_In, 'complex');
            
            aoMultiSolverBranches = [this.toBranches.CRA_H2_In,...
                                     this.toBranches.H2_to_Sabatier,...
                                     this.toBranches.H2_to_Vent,...
                                     this.toBranches.CRA_ProductstoWaterRecbranch,...
                                     this.toBranches.CRA_DryGastoVent];
            
            tSolverProperties.fMaxError = 1e-2;
            tSolverProperties.iMaxIterations = 1000;
            tSolverProperties.iIterationsBetweenP2PUpdate = 20;
            tSolverProperties.fMinimumTimeStep = 1;
            oSolver = solver.matter_multibranch.iterative.branch(aoMultiSolverBranches, 'complex');
            oSolver.setSolverProperties(tSolverProperties);
            
            this.setMaxIdealGasLawPressure(10e5);
            
            this.setThermalSolvers();
            
            csStoreNames = fieldnames(this.toStores);
            for iStore = 1:length(csStoreNames)
                if strcmp(csStoreNames{iStore}, 'CRA_Accumulator')
                    tTimeStepProperties  = struct();
                    tTimeStepProperties.rMaxChange = 0.2;
                    tTimeStepProperties.fMaxStep = this.fTimeStep * 5;
                    this.toStores.(csStoreNames{iStore}).toPhases.CO2.setTimeStepProperties(tTimeStepProperties);
                    
                    tTimeStepProperties = struct();
                    tTimeStepProperties.fMaxStep = this.fTimeStep * 5;
                    this.toStores.(csStoreNames{iStore}).toPhases.CO2.oCapacity.setTimeStepProperties(tTimeStepProperties);
                else
                    for iPhase = 1:length(this.toStores.(csStoreNames{iStore}).aoPhases)
                        oPhase = this.toStores.(csStoreNames{iStore}).aoPhases(iPhase);

                        arMaxChange = zeros(1,this.oMT.iSubstances);
                        arMaxChange(this.oMT.tiN2I.Ar) = 0.75;
                        arMaxChange(this.oMT.tiN2I.O2) = 0.75;
                        arMaxChange(this.oMT.tiN2I.N2) = 0.75;
                        arMaxChange(this.oMT.tiN2I.H2) = 1;
                        arMaxChange(this.oMT.tiN2I.H2O) = 0.5;
                        arMaxChange(this.oMT.tiN2I.CO2) = 1;
                        arMaxChange(this.oMT.tiN2I.CH4) = 0.75;
                        tTimeStepProperties.arMaxChange = arMaxChange;
                        tTimeStepProperties.fMaxStep = this.fTimeStep * 5;
                        tTimeStepProperties.rMaxChange = 0.1;

                        oPhase.setTimeStepProperties(tTimeStepProperties);

                        tTimeStepProperties = struct();
                        tTimeStepProperties.fMaxStep = this.fTimeStep * 5;
                        oPhase.oCapacity.setTimeStepProperties(tTimeStepProperties);
                    end
                end
            end
            
        end
        
        
        function setIfFlows(this, SCRA_H2_In, SCRA_CO2_In, SCRA_DryGas_Out, SCRA_Condensate_Out, SCRA_CoolantIn, SCRA_CoolantOut)
            %subsystem connections
            this.connectIF('SCRA_H2_In',            SCRA_H2_In);
            this.connectIF('SCRA_CO2_In',           SCRA_CO2_In);
            this.connectIF('SCRA_DryGas_Out',       SCRA_DryGas_Out);
            this.connectIF('SCRA_Condensate_Out',   SCRA_Condensate_Out);
            this.connectIF('SCRA_CoolantIn',        SCRA_CoolantIn);
            this.connectIF('SCRA_CoolantOut',       SCRA_CoolantOut);
        end
    end
    
    methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
            
            fCO2FlowRate = -((this.toBranches.CRA_H2_In.fFlowRate / this.oMT.afMolarMass(this.oMT.tiN2I.H2)) ./ 3.5) * this.oMT.afMolarMass(this.oMT.tiN2I.CO2);
            % Through setting the valve, H2 is vented without passing
            % through the sabatier reactors in case no CO2 is available
            this.toProcsF2F.VentValveH2.setOpen(   	false);
            this.toProcsF2F.SabatierValve.setOpen(  true);
            this.toProcsF2F.Checkvalve.setOpen(     true);
                
            fAccumulatorPressure = this.toStores.CRA_Accumulator.toPhases.CO2.fPressure;
            if this.toStores.CRA_Accumulator.toPhases.CO2.fPressure > 7.2e5
                if fCO2FlowRate <= this.toBranches.CRA_CO2_In.fFlowRate
                    fCO2FlowRate = 1.1 * this.toBranches.CRA_CO2_In.fFlowRate;
                end
                if this.toStores.CRA_Accumulator.toPhases.CO2.fPressure > 8e5
                    fMassToVent = 0.2 * this.toStores.CRA_Accumulator.toPhases.CO2.fMass;
                    this.toBranches.CO2_to_Vent.oHandler.setMassTransfer(fMassToVent, 60);
                end
            elseif fAccumulatorPressure < 1.2e5
                fCO2FlowRate = 0;
                this.toProcsF2F.VentValveH2.setOpen(  	true);
                this.toProcsF2F.SabatierValve.setOpen(  false);
                this.toProcsF2F.Checkvalve.setOpen(     false);
            elseif fAccumulatorPressure > 1.2e5 && fAccumulatorPressure < 2e5 && this.toBranches.Accumulator_To_CRA.fFlowRate == 0
                % If it was turned off, remain off until we reach 2 bar
                % again
                fCO2FlowRate = 0;
                this.toProcsF2F.VentValveH2.setOpen(   	true);
                this.toProcsF2F.SabatierValve.setOpen(  false);
                this.toProcsF2F.Checkvalve.setOpen(     false);
            end
            this.toBranches.Accumulator_To_CRA.oHandler.setFlowRate(fCO2FlowRate);
            oInFlow = this.toBranches.Accumulator_To_CRA.aoFlows(1);
            
            % The power consumption of a compressor can be calculated using
            % equation 8 from "Modeling and Simulation of Air Compressor
            % Energy Use", Chris Schmidt et. al, 2005
            % https://www.aceee.org/files/proceedings/2005/data/papers/SS05_Panel01_Paper13.pdf
            % assuming we have to increase the pressure from 0.01 bar to 1
            % bar in a two stage compression
            this.fCurrentPowerConsumption = fCO2FlowRate * oInFlow.fSpecificHeatCapacity * 293 * (((1e5 / 1e4)^1.289 - 1) + ((1e4 / 1e3)^1.289 - 1));
           if this.fCurrentPowerConsumption > 1500
               this.fCurrentPowerConsumption = 1500;
           end
        end
    end
end