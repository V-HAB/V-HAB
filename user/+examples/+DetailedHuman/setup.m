classdef setup < simulation.infrastructure
    
    properties
    end
    
    methods
        function this = setup(ptConfigParams, tSolverParams) % Constructor function
            
            ttMonitorConfig = struct();
            ttMonitorConfig.oTimeStepObserver.sClass = 'simulation.monitors.timestepObserver';
            ttMonitorConfig.oTimeStepObserver.cParams = { 0 };
            this@simulation.infrastructure('Example_DetailedHumanModel', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            % Water content of Urine and Feces is based on BVAD, not all
            % possible components of both substances defined here
            trBaseCompositionUrine.H2O      = 0.9644;
            trBaseCompositionUrine.CH4N2O   = 0.0356;
            this.oSimulationContainer.oMT.defineCompoundMass(this, 'Urine', trBaseCompositionUrine)
            
            trBaseCompositionFeces.H2O          = 0.7576;
            trBaseCompositionFeces.DietaryFiber = 0.2424;
            this.oSimulationContainer.oMT.defineCompoundMass(this, 'Feces', trBaseCompositionFeces)
            
            examples.DetailedHuman.systems.Example(this.oSimulationContainer, 'Example');
            
            %% Simulation length
            % Stop when specific time in simulation is reached or after 
            % specific amount of ticks (bUseTime true/false).
            this.fSimTime = 3600 * 24 * 5; % In seconds
            this.iSimTicks = 1500;
            this.bUseTime = true;
        end
        
        
        function configureMonitors(this)
            
            %% Logging
            oLog = this.toMonitors.oLogger;
            
            csStores = fieldnames(this.oSimulationContainer.toChildren.Example.toStores);
            for iStore = 1:length(csStores)
                oLog.addValue(['Example.toStores.', csStores{iStore}, '.aoPhases(1)'],	'fMass',        'kg', [csStores{iStore}, ' Mass']);
                oLog.addValue(['Example.toStores.', csStores{iStore}, '.aoPhases(1)'],	'fPressure',	'Pa', [csStores{iStore}, ' Pressure']);
                oLog.addValue(['Example.toStores.', csStores{iStore}, '.aoPhases(1)'],	'fTemperature',	'K',  [csStores{iStore}, ' Temperature']);
            end
            
            csBranches = fieldnames(this.oSimulationContainer.toChildren.Example.toBranches);
            for iBranch = 1:length(csBranches)
                oLog.addValue(['Example.toBranches.', csBranches{iBranch}],             'fFlowRate',    'kg/s', [csBranches{iBranch}, ' Flowrate']);
            end
            
            %% Respiration Logging
            oLog.addValue('Example:c:Human_1:c:Respiration',    'fVolumetricFlow_BrainBlood',       'm^3/s', 'Volumetric Blood Flow Brain');
            oLog.addValue('Example:c:Human_1:c:Respiration',    'fVolumetricFlow_TissueBlood',      'm^3/s', 'Volumetric Blood Flow Tissue');
            oLog.addValue('Example:c:Human_1:c:Respiration',    'fVolumetricFlow_Air',              'm^3/s', 'Volumetric Air Flow');
            
            oLog.addValue('Example:c:Human_1:c:Respiration',	'this.tfPartialPressure.Brain.O2', 	'Pa',   'Partial Pressure O2 Brain');
            oLog.addValue('Example:c:Human_1:c:Respiration',    'tfPartialPressure.Brain.CO2',      'Pa',   'Partial Pressure CO2 Brain');
            oLog.addValue('Example:c:Human_1:c:Respiration',    'tfPartialPressure.Tissue.O2',  	'Pa',   'Partial Pressure O2 Tissue');
            oLog.addValue('Example:c:Human_1:c:Respiration',    'tfPartialPressure.Tissue.CO2', 	'Pa',   'Partial Pressure CO2 Tissue');
            oLog.addValue('Example:c:Human_1:c:Respiration',    'tfPartialPressure.Arteries.O2',  	'Pa',   'Partial Pressure O2 Arteries');
            oLog.addValue('Example:c:Human_1:c:Respiration',    'tfPartialPressure.Arteries.CO2', 	'Pa',   'Partial Pressure CO2 Arteries');
            
            
            oLog.addValue('Example:c:Human_1:c:Respiration.toStores.Lung.toProcsP2P.Alveola_to_Air',    'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)',      'kg/s', 	'Exhaled CO2');
            oLog.addValue('Example:c:Human_1:c:Respiration.toStores.Lung.toProcsP2P.Air_to_Alveola',    'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.O2)',       'kg/s',     'Inhaled O2');
            oLog.addValue('Example:c:Human_1:c:Respiration.toStores.Brain.toProcsP2P.Blood_to_Brain',   'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.O2)',       'kg/s',     'Brain absorbed O2');
            oLog.addValue('Example:c:Human_1:c:Respiration.toStores.Brain.toProcsP2P.Brain_to_Blood',   'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)',      'kg/s',     'Brain desorbed CO2');
            oLog.addValue('Example:c:Human_1:c:Respiration.toStores.Tissue.toProcsP2P.Blood_to_Tissue', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.O2)',       'kg/s',     'Tissue absorbed O2');
            oLog.addValue('Example:c:Human_1:c:Respiration.toStores.Tissue.toProcsP2P.Tissue_to_Blood', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)',      'kg/s',     'Tissue desorbed CO2');
            
            oLog.addValue('Example:c:Human_1.toBranches.O2_from_Brain',     'fFlowRate',      'kg/s',     'Metabolic O2 from Brain');
            oLog.addValue('Example:c:Human_1.toBranches.O2_from_Tissue',    'fFlowRate',      'kg/s',     'Metabolic O2 from Tissue');
            oLog.addValue('Example:c:Human_1.toBranches.CO2_to_Brain',      'fFlowRate',      'kg/s',     'Metabolic CO2 to Brain');
            oLog.addValue('Example:c:Human_1.toBranches.CO2_to_Tissue',     'fFlowRate',      'kg/s',     'Metabolic CO2 to Tissue');
            
            %% Metabolic Logging
            
            oLog.addValue('Example:c:Human_1:c:Metabolic', 'fVO2',                      'L/min',    'VO2');
            oLog.addValue('Example:c:Human_1:c:Metabolic', 'fVO2_rest',              	'L/min',    'VO2 Rest');
            oLog.addValue('Example:c:Human_1:c:Metabolic', 'fVO2_max',              	'L/min',    'VO2 Max');
            oLog.addValue('Example:c:Human_1:c:Metabolic', 'rActivityLevel',            '-',        'Activity Level');
            oLog.addValue('Example:c:Human_1:c:Metabolic', 'fTotalMetabolicRate',   	'W',        'Current Metabolic Rate');
            oLog.addValue('Example:c:Human_1:c:Metabolic', 'fMetabolicHeatFlow',        'W',        'Current Metabolic Heatflow');
            oLog.addValue('Example:c:Human_1:c:Metabolic', 'rRespiratoryCoefficient',  	'-',        'Respiratory Coefficient');
            
            oLog.addValue('Example:c:Human_1:c:Metabolic.toStores.Metabolism.toPhases.Liver',            'this.afMass(this.oMT.tiN2I.C6H12O6)',  	'kg', 'Glucose in Liver');
            oLog.addValue('Example:c:Human_1:c:Metabolic.toStores.Metabolism.toPhases.AdiposeTissue',    'this.afMass(this.oMT.tiN2I.C51H98O6)',  	'kg', 'Fat Mass Adipose Tissue');
            oLog.addValue('Example:c:Human_1:c:Metabolic.toStores.Metabolism.toPhases.AdiposeTissue',    'this.afMass(this.oMT.tiN2I.H2O)',          'kg', 'Water in Adipose Tissue');
            oLog.addValue('Example:c:Human_1:c:Metabolic.toStores.Metabolism.toPhases.MuscleTissue',     'this.afMass(this.oMT.tiN2I.C6H12O6)',  	'kg', 'Glucose in Muscle');
            oLog.addValue('Example:c:Human_1:c:Metabolic.toStores.Metabolism.toPhases.MuscleTissue',     'this.afMass(this.oMT.tiN2I.Human_Tissue)',	'kg', 'Muscle Mass');
            oLog.addValue('Example:c:Human_1:c:Metabolic.toStores.Metabolism.toPhases.Metabolism',       'this.afMass(this.oMT.tiN2I.C3H7NO2)',      'kg', 'Protein Mass in Metabolism');
            oLog.addValue('Example:c:Human_1:c:Metabolic.toStores.Metabolism.toPhases.Metabolism',       'this.afMass(this.oMT.tiN2I.C51H98O6)',     'kg', 'Fat Mass in Metabolism');
            oLog.addValue('Example:c:Human_1:c:Metabolic.toStores.Metabolism.toPhases.Metabolism',       'this.afMass(this.oMT.tiN2I.C6H12O6)',      'kg', 'Glucose Mass in Metabolism');
            oLog.addValue('Example:c:Human_1:c:Metabolic.toStores.Metabolism.toPhases.Metabolism',       'this.afMass(this.oMT.tiN2I.H2O)',          'kg', 'Water Mass in Metabolism');
           
            oLog.addValue('Example:c:Human_1:c:Metabolic.toStores.Metabolism.toPhases.Metabolism.toManips.substance',       'this.afPartialFlows(this.oMT.tiN2I.C3H7NO2)',        'kg/s', 'Metabolism Protein Flow Rate');
            oLog.addValue('Example:c:Human_1:c:Metabolic.toStores.Metabolism.toPhases.Metabolism.toManips.substance',       'this.afPartialFlows(this.oMT.tiN2I.C51H98O6)',       'kg/s', 'Metabolism Fat Flow Rate');
            oLog.addValue('Example:c:Human_1:c:Metabolic.toStores.Metabolism.toPhases.Metabolism.toManips.substance',       'this.afPartialFlows(this.oMT.tiN2I.C6H12O6)',        'kg/s', 'Metabolism Glucose Flow Rate');
            oLog.addValue('Example:c:Human_1:c:Metabolic.toStores.Metabolism.toPhases.Metabolism.toManips.substance',       'this.afPartialFlows(this.oMT.tiN2I.O2)',             'kg/s', 'Metabolism O2 Flow Rate');
            oLog.addValue('Example:c:Human_1:c:Metabolic.toStores.Metabolism.toPhases.Metabolism.toManips.substance',       'this.afPartialFlows(this.oMT.tiN2I.CO2)',            'kg/s', 'Metabolism CO2 Flow Rate');
            oLog.addValue('Example:c:Human_1:c:Metabolic.toStores.Metabolism.toPhases.Metabolism.toManips.substance',       'this.afPartialFlows(this.oMT.tiN2I.H2O)',            'kg/s', 'Metabolism H2O Flow Rate');
            oLog.addValue('Example:c:Human_1:c:Metabolic.toStores.Metabolism.toPhases.Metabolism.toManips.substance',       'this.afPartialFlows(this.oMT.tiN2I.CH4N2O)',         'kg/s', 'Metabolism Urea Flow Rate');
            oLog.addValue('Example:c:Human_1:c:Metabolic.toStores.Metabolism.toPhases.Metabolism.toManips.substance',       'this.afPartialFlows(this.oMT.tiN2I.Human_Tissue)',   'kg/s', 'Metabolism Muscle Flow Rate');

            oLog.addValue('Example:c:Human_1:c:Metabolic.toStores.Metabolism.toProcsP2P.Metabolism_to_Liver',               'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C6H12O6)',      'kg/s', 'Glucose to Liver Flow Rate');
            oLog.addValue('Example:c:Human_1:c:Metabolic.toStores.Metabolism.toProcsP2P.Metabolism_to_MuscleTissue',      	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C6H12O6)',      'kg/s', 'Glucose to Muscle Flow Rate');
            oLog.addValue('Example:c:Human_1:c:Metabolic.toStores.Metabolism.toProcsP2P.Metabolism_to_MuscleTissue',      	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Human_Tissue)',	'kg/s', 'Muscle from Metabolism Flow Rate');
            oLog.addValue('Example:c:Human_1:c:Metabolic.toStores.Metabolism.toProcsP2P.Metabolism_to_AdiposeTissue',      	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C51H98O6)',     'kg/s', 'Fat to Adipose Tissue Flow Rate');
            oLog.addValue('Example:c:Human_1:c:Metabolic.toStores.Metabolism.toProcsP2P.Metabolism_to_AdiposeTissue',      	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',          'kg/s', 'H2O to Adipose Tissue Flow Rate');
            
            %% Water Balance Logging
            
            oLog.addValue('Example:c:Human_1:c:WaterBalance',      	'fConcentrationOfADHinBloodPlasma',             'munits/L', 'ADH in Blood Plasma');
            oLog.addValue('Example:c:Human_1:c:WaterBalance',      	'fConcentrationOfReninInBloodPlasma',           'ng/L',     'Renin in Blood Plasma');
            oLog.addValue('Example:c:Human_1:c:WaterBalance',      	'fConcentrationOfAngiotensinIIInBloodPlasma',  	'ng/L',     'Angiotensin II in Blood Plasma');
            oLog.addValue('Example:c:Human_1:c:WaterBalance',      	'fConcentrationOfAldosteronInBloodPlasma',    	'ng/L',     'Aldosteron in Blood Plasma');
            
            oLog.addValue('Example:c:Human_1:c:WaterBalance',      	'rRatioOfAvailableSweat',                       '-',        'Available Sweat');
            oLog.addValue('Example:c:Human_1:c:WaterBalance',      	'fThirst',                                      '-',        'Thirst Level');
            
            
            oLog.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toPhases.BloodPlasma',      	'this.afMass(this.oMT.tiN2I.H2O)',      'kg',	'H2O Mass in Blood Plasma');
            oLog.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toPhases.BloodPlasma',      	'this.afMass(this.oMT.tiN2I.Naplus)',  	'kg',	'Na+ Mass in Blood Plasma');
            oLog.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toPhases.BloodPlasma',      	'this.afMass(this.oMT.tiN2I.Kplus)',   	'kg',	'K+ Mass in Blood Plasma');
            
            oLog.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toPhases.InterstitialFluid',	'this.afMass(this.oMT.tiN2I.H2O)',      'kg',	'H2O Mass in InterstitialFluid');
            oLog.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toPhases.InterstitialFluid',	'this.afMass(this.oMT.tiN2I.Naplus)',  	'kg',	'Na+ Mass in InterstitialFluid');
            oLog.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toPhases.InterstitialFluid', 	'this.afMass(this.oMT.tiN2I.Kplus)',   	'kg',	'K+ Mass in InterstitialFluid');
            
            oLog.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toPhases.IntracellularFluid',	'this.afMass(this.oMT.tiN2I.H2O)',      'kg',	'H2O Mass in IntracellularFluid');
            oLog.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toPhases.IntracellularFluid',	'this.afMass(this.oMT.tiN2I.Naplus)',  	'kg',	'Na+ Mass in IntracellularFluid');
            oLog.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toPhases.IntracellularFluid', 'this.afMass(this.oMT.tiN2I.Kplus)',   	'kg',	'K+ Mass in IntracellularFluid');
            
            oLog.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toPhases.Kidney',             'this.afMass(this.oMT.tiN2I.H2O)',      'kg',	'H2O Mass in Kidney');
            oLog.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toPhases.Kidney',             'this.afMass(this.oMT.tiN2I.Naplus)',  	'kg',	'Na+ Mass in Kidney');
            oLog.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toPhases.Kidney',             'this.afMass(this.oMT.tiN2I.Kplus)',   	'kg',	'K+ Mass in Kidney');
            
            oLog.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toPhases.Bladder',            'this.afMass(this.oMT.tiN2I.H2O)',      'kg',	'H2O Mass in Bladder');
            oLog.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toPhases.Bladder',            'this.afMass(this.oMT.tiN2I.Naplus)',  	'kg',	'Na+ Mass in Bladder');
            oLog.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toPhases.Bladder',            'this.afMass(this.oMT.tiN2I.Kplus)',   	'kg',	'K+ Mass in Bladder');
            oLog.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toPhases.Bladder',            'this.afMass(this.oMT.tiN2I.Urine)',   	'kg',	'Urine Mass in Bladder');
            
            % Flux through endothelium is from Interstitial to Blood Plasma
            oLog.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toProcsP2P.FluxThroughEndothelium',       'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',   	'kg/s',	'H2O Massflow through Endothelium');
            oLog.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toProcsP2P.ReFluxThroughEndothelium',    	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',   	'kg/s',	'H2O MassREflow through Endothelium');
            oLog.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toProcsP2P.FluxThroughEndothelium',       'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Naplus)',	'kg/s',	'Na+ Massflow through Endothelium');
            oLog.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toProcsP2P.ReFluxThroughEndothelium',    	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Naplus)',	'kg/s',	'Na+ MassREflow through Endothelium');
            oLog.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toProcsP2P.FluxThroughEndothelium',       'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Kplus)', 	'kg/s',	'K+ Massflow through Endothelium');
            oLog.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toProcsP2P.ReFluxThroughEndothelium',    	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Kplus)', 	'kg/s',	'K+ MassREflow through Endothelium');
            
            % Flux through cell membranes is from interstital to
            % intracellular
            oLog.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toProcsP2P.FluxthroughCellMembranes',    	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',   	'kg/s',	'H2O Massflow through CellMembranes');
            oLog.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toProcsP2P.ReFluxthroughCellMembranes', 	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',   	'kg/s',	'H2O MassREflow through CellMembranes');
            oLog.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toProcsP2P.FluxthroughCellMembranes',   	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Naplus)',	'kg/s',	'Na+ Massflow through CellMembranes');
            oLog.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toProcsP2P.ReFluxthroughCellMembranes',  	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Naplus)',	'kg/s',	'Na+ MassREflow through CellMembranes');
            oLog.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toProcsP2P.FluxthroughCellMembranes',  	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Kplus)', 	'kg/s',	'K+ Massflow through CellMembranes');
            oLog.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toProcsP2P.ReFluxthroughCellMembranes',	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Kplus)', 	'kg/s',	'K+ MassREflow through CellMembranes');
            
            oLog.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toProcsP2P.InFluxKidney',                 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',      'kg/s',	'H2O Massflow to Kidney');
            oLog.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toProcsP2P.InFluxKidney',                 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Naplus)', 	'kg/s',	'Na+ Massflow to Kidney');
            oLog.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toProcsP2P.InFluxKidney',                 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Kplus)', 	'kg/s',	'K+ Massflow to Kidney');
            oLog.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toProcsP2P.ReadsorptionFluxFromKidney', 	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',      'kg/s',	'H2O readsorption from Kidney');
            oLog.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toProcsP2P.ReadsorptionFluxFromKidney',  	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Naplus)', 	'kg/s',	'Na+ readsorption from Kidney');
            oLog.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toProcsP2P.ReadsorptionFluxFromKidney',  	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Kplus)', 	'kg/s',	'K+ readsorption from Kidney');
            oLog.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toProcsP2P.KidneyToBladder',              'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',      'kg/s',	'H2O Massflow to Bladder');
            oLog.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toProcsP2P.KidneyToBladder',              'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Naplus)', 	'kg/s',	'Na+ Massflow to Bladder');
            oLog.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toProcsP2P.KidneyToBladder',              'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Kplus)', 	'kg/s',	'K+ Massflow to Bladder');
            
        end
        
        function plot(this, varargin) % Plotting the results
            
            %% Define Plots
            
            close all
            oPlotter = plot@simulation.infrastructure(this);
            
            
            tPlotOptions.sTimeUnit  = 'hours';
            
            %% Respiration
            coPlot = cell(2,2);
            coPlot{1,1} = oPlotter.definePlot({'"Volumetric Blood Flow Brain"', '"Volumetric Blood Flow Tissue"', '"Volumetric Air Flow"'}, 'Respiration Volumetric Flows', tPlotOptions);
            coPlot{1,2} = oPlotter.definePlot({ '"Partial Pressure O2 Brain"',      '"Partial Pressure CO2 Brain"', ....
                                                '"Partial Pressure O2 Tissue"',     '"Partial Pressure CO2 Tissue"', ....
                                                '"Partial Pressure O2 Arteries"',   '"Partial Pressure CO2 Arteries"'}, 'Respiration Partial Presssures', tPlotOptions);
            coPlot{2,1} = oPlotter.definePlot({'"Exhaled CO2"', '"Inhaled O2"', '"Brain absorbed O2"', '"Brain desorbed CO2"', '"Tissue absorbed O2"', '"Tissue desorbed CO2"'}, 'Respiration P2P Flows', tPlotOptions);
            coPlot{2,2} = oPlotter.definePlot({'"Metabolic CO2 to Brain"', '"Metabolic CO2 to Tissue"', '"Metabolic O2 from Brain"', '"Metabolic O2 from Tissue"'}, 'Metabolic O2 and CO2 Flows', tPlotOptions);
            oPlotter.defineFigure(coPlot,  'Respiration');
            
            %% Metabolic
            coPlot = cell(3,3);
            coPlot{1,1} = oPlotter.definePlot({'"VO2"', '"VO2 Rest"', '"VO2 Max"'}, 'VO2', tPlotOptions);
            coPlot{1,2} = oPlotter.definePlot({ '"Current Metabolic Rate"', '"Current Metabolic Heatflow"'}, 'Metabolic Rate', tPlotOptions);
            coPlot{1,3} = oPlotter.definePlot({'"Activity Level"', '"Respiratory Coefficient"'}, 'Activity Level and Respiratory Coefficient', tPlotOptions);
            coPlot{2,1} = oPlotter.definePlot({'"Glucose in Liver"', '"Fat Mass Adipose Tissue"', '"Water in Adipose Tissue"', '"Glucose in Muscle"', '"Muscle Mass"'}, 'Masses in Metabolic Layer', tPlotOptions);
            coPlot{2,2} = oPlotter.definePlot({'"Protein Mass in Metabolism"', '"Fat Mass in Metabolism"', '"Glucose Mass in Metabolism"', '"Water Mass in Metabolism"'}, 'Masses in Metabolism Phase', tPlotOptions);
            
            coPlot{2,3} = oPlotter.definePlot({'"Metabolism Protein Flow Rate"', '"Metabolism Fat Flow Rate"', '"Metabolism Glucose Flow Rate"', '"Metabolism O2 Flow Rate"',...
                                               '"Metabolism CO2 Flow Rate"', '"Metabolism H2O Flow Rate"', '"Metabolism Urea Flow Rate"', '"Metabolism Muscle Flow Rate"'}, 'Manipulator Flowrates in Metabolism', tPlotOptions);
            coPlot{3,3} = oPlotter.definePlot({'"Glucose to Liver Flow Rate"', '"Glucose to Muscle Flow Rate"', '"Muscle from Metabolism Flow Rate"', '"Fat to Adipose Tissue Flow Rate"', '"H2O to Adipose Tissue Flow Rate"'}, 'P2P Flowrates in Metabolism', tPlotOptions);
             
            oPlotter.defineFigure(coPlot,  'Metabolic');
            
            %% Water Balance
            coPlot = cell(3,3);
            
            coPlot{1,1} = oPlotter.definePlot({'"ADH in Blood Plasma"', '"Renin in Blood Plasma"', '"Angiotensin II in Blood Plasma"', '"Aldosteron in Blood Plasma"'}, 'Hormone Concentrations in Blood Plasma', tPlotOptions);
            coPlot{1,2} = oPlotter.definePlot({'"Thirst Level"'}, 'Thirst', tPlotOptions);
            coPlot{1,3} = oPlotter.definePlot({'"Urine Mass in Bladder"',   '"H2O Mass in Bladder"',        	'"Na+ Mass in Bladder"',                    '"K+ Mass in Bladder"',...
                                                                            '"H2O Mass in Kidney"',             '"Na+ Mass in Kidney"',                     '"K+ Mass in Kidney"'},              	'Bladder and Kidney Masses', tPlotOptions);
            coPlot{2,1} = oPlotter.definePlot({                             '"H2O Mass in Blood Plasma"',     	'"Na+ Mass in Blood Plasma"',               '"K+ Mass in Blood Plasma"'},           'Blood Plasma Masses', tPlotOptions);
            coPlot{2,2} = oPlotter.definePlot({                             '"H2O Mass in InterstitialFluid"', 	'"Na+ Mass in InterstitialFluid"',          '"K+ Mass in InterstitialFluid"'},      'InterstitialFluid Masses', tPlotOptions);
            coPlot{2,3} = oPlotter.definePlot({                             '"H2O Mass in IntracellularFluid"',	'"Na+ Mass in IntracellularFluid"',         '"K+ Mass in IntracellularFluid"'},     'IntracellularFluid Masses', tPlotOptions);
            
            coPlot{3,1} = oPlotter.definePlot({'"H2O Massflow through Endothelium"',        '"Na+ Massflow through Endothelium"',       '"K+ Massflow through Endothelium"',...
                                               '"H2O MassREflow through Endothelium"',      '"Na+ MassREflow through Endothelium"',     '"K+ MassREflow through Endothelium"'},                     'Endothelium Flows', tPlotOptions);
                                            
            coPlot{3,2} = oPlotter.definePlot({'"H2O Massflow through CellMembranes"',      '"Na+ Massflow through CellMembranes"',   	'"K+ Massflow through CellMembranes"',...
                                               '"H2O MassREflow through CellMembranes"',	'"Na+ MassREflow through CellMembranes"', 	'"K+ MassREflow through CellMembranes"'},                   'Cell Membrane Flows', tPlotOptions);
                                            
            coPlot{3,3} = oPlotter.definePlot({'"H2O Massflow to Kidney"',                  '"Na+ Massflow to Kidney"',                 '"K+ Massflow to Kidney"',...
                                               '"H2O readsorption from Kidney"',            '"Na+ readsorption from Kidney"',           '"K+ readsorption from Kidney"',...
                                               '"H2O Massflow to Bladder"',                 '"Na+ Massflow to Bladder"',                '"K+ Massflow to Bladder"'},                                'Kidney Flows', tPlotOptions);
            
                       
            oPlotter.defineFigure(coPlot,  'Water Balance');                    
            
            oPlotter.plot();
            
           

            
        end
    end
end