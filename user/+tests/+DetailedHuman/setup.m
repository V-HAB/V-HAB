classdef setup < simulation.infrastructure
    
    properties
    end
    
    methods
        function this = setup(ptConfigParams, tSolverParams, ttMonitorConfig, fSimTime) % Constructor function
            
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
            if nargin < 4 || isempty(fSimTime)
                this.fSimTime = 3600 * 24;
            else 
                this.fSimTime = fSimTime;
            end
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
            
            %% Parent System Logging
            csFecesComponents = {'H2O', 'DietaryFiber', 'C6H12O6', 'C51H98O6', 'C3H7NO2', 'Naplus'};
            for iComponent = 1:length(csFecesComponents)
                oLog.addValue('Example.toStores.FecesStorage.toPhases.Feces',   ['this.afMass(this.oMT.tiN2I.Feces) .* this.arCompoundMass(this.oMT.tiN2I.Feces, this.oMT.tiN2I.', csFecesComponents{iComponent}, ')'],         'kg',   ['Feces ', csFecesComponents{iComponent},' Content']);
            end
            
            csUrineComponents = {'H2O', 'Naplus', 'CH4N2O'};
            for iComponent = 1:length(csUrineComponents)
                oLog.addValue('Example.toStores.UrineStorage.toPhases.Urine',   ['this.afMass(this.oMT.tiN2I.Urine) .* this.arCompoundMass(this.oMT.tiN2I.Urine, this.oMT.tiN2I.', csUrineComponents{iComponent}, ')'],         'kg',   ['Urine ', csUrineComponents{iComponent},' Content']);
            end
            
            oLog.addValue('Example:c:Human_1.toBranches.Potable_Water_In',          'fFlowRate',       'kg/s', 'Ingested Water Flow Rate');
            oLog.addValue('Example:c:Human_1.toBranches.RespirationWaterOutput',    'fFlowRate',       'kg/s', 'Respiration Water Flow Rate');
            oLog.addValue('Example:c:Human_1.toBranches.PerspirationWaterOutput',   'fFlowRate',       'kg/s', 'Perspiration Water Flow Rate');
            oLog.addValue('Example:c:Human_1.toBranches.Urine_Out',                 'fFlowRate',       'kg/s', 'Urine Flow Rate');
            oLog.addValue('Example:c:Human_1.toBranches.Food_In',                   'fFlowRate',       'kg/s', 'Food Flow Rate');
            
            
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
            
            oLog.addValue('Example:c:Human_1.toBranches.O2_from_Brain',     'fFlowRate',      'kg/s',     'Metabolic O2 from Brain');
            oLog.addValue('Example:c:Human_1.toBranches.O2_from_Tissue',    'fFlowRate',      'kg/s',     'Metabolic O2 from Tissue');
            oLog.addValue('Example:c:Human_1.toBranches.CO2_to_Brain',      'fFlowRate',      'kg/s',     'Metabolic CO2 to Brain');
            oLog.addValue('Example:c:Human_1.toBranches.CO2_to_Tissue',     'fFlowRate',      'kg/s',     'Metabolic CO2 to Tissue');
            
            oLog.addValue('Example:c:Human_1:c:Respiration.toStores.Lung.toProcsP2P.Alveola_to_Air',    'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)',      'kg/s', 	'Exhaled CO2');
            oLog.addValue('Example:c:Human_1:c:Respiration.toStores.Lung.toProcsP2P.Air_to_Alveola',    'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.O2)',       'kg/s',     'Inhaled O2');
            oLog.addValue('Example:c:Human_1:c:Respiration.toStores.Brain.toProcsP2P.Blood_to_Brain',   'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.O2)',       'kg/s',     'Brain absorbed O2');
            oLog.addValue('Example:c:Human_1:c:Respiration.toStores.Brain.toProcsP2P.Brain_to_Blood',   'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)',      'kg/s',     'Brain desorbed CO2');
            oLog.addValue('Example:c:Human_1:c:Respiration.toStores.Tissue.toProcsP2P.Blood_to_Tissue', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.O2)',       'kg/s',     'Tissue absorbed O2');
            oLog.addValue('Example:c:Human_1:c:Respiration.toStores.Tissue.toProcsP2P.Tissue_to_Blood', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)',      'kg/s',     'Tissue desorbed CO2');
            
            oLog.addValue('Example:c:Human_1.toBranches.Air_In.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)',                  'kg/s',    'CO2 Inlet Flowrate');
            oLog.addValue('Example:c:Human_1.toBranches.Air_Out.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)',                 'kg/s',    'CO2 Outlet Flowrate');
            oLog.addValue('Example:c:Human_1.toBranches.Air_In.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.O2)',                   'kg/s',    'O2 Inlet Flowrate');
            oLog.addValue('Example:c:Human_1.toBranches.Air_Out.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.O2)',                  'kg/s',    'O2 Outlet Flowrate');
            
            oLog.addVirtualValue('"CO2 Outlet Flowrate"    + "CO2 Inlet Flowrate"',   'kg/s', 'Effective CO2 Flow');
            oLog.addVirtualValue( '"O2 Outlet Flowrate"    +  "O2 Inlet Flowrate"',   'kg/s', 'Effective O2 Flow');
            
            %% Metabolic Logging
            
            oLog.addValue('Example:c:Human_1:c:Metabolic', 'fVO2',                              'L/min',    'VO2');
            oLog.addValue('Example:c:Human_1:c:Metabolic', 'fVO2_rest',                         'L/min',    'VO2 Rest');
            oLog.addValue('Example:c:Human_1:c:Metabolic', 'fVO2_max',                          'L/min',    'VO2 Max');
            oLog.addValue('Example:c:Human_1:c:Metabolic', 'rActivityLevel',                    '-',        'Activity Level');
            oLog.addValue('Example:c:Human_1:c:Metabolic', 'fTotalMetabolicRate',               'W',        'Current Metabolic Rate');
            oLog.addValue('Example:c:Human_1:c:Metabolic', 'fMetabolicHeatFlow',                'W',        'Current Metabolic Heatflow');
            oLog.addValue('Example:c:Human_1:c:Metabolic', 'rRespiratoryCoefficient',           '-',        'Respiratory Coefficient');
            oLog.addValue('Example:c:Human_1:c:Metabolic', 'fRestingDailyEnergyExpenditure',  	'-',        'Resting Daily Energy Demand');
            oLog.addValue('Example:c:Human_1:c:Metabolic', 'fAdditionalFoodEnergyDemand',       '-',        'Additional Energy Demand from Exercise');
            
            oLog.addValue('Example:c:Human_1:c:Metabolic.toStores.Metabolism.toPhases.Liver',            'this.afMass(this.oMT.tiN2I.C6H12O6)',  	 'kg', 'Glucose in Liver');
            oLog.addValue('Example:c:Human_1:c:Metabolic.toStores.Metabolism.toPhases.AdiposeTissue',    'this.afMass(this.oMT.tiN2I.C51H98O6)',  	 'kg', 'Fat Mass Adipose Tissue');
            oLog.addValue('Example:c:Human_1:c:Metabolic.toStores.Metabolism.toPhases.AdiposeTissue',    'this.afMass(this.oMT.tiN2I.H2O)',          'kg', 'Water in Adipose Tissue');
            oLog.addValue('Example:c:Human_1:c:Metabolic.toStores.Metabolism.toPhases.MuscleTissue',     'this.afMass(this.oMT.tiN2I.C6H12O6)',  	 'kg', 'Glucose in Muscle');
            oLog.addValue('Example:c:Human_1:c:Metabolic.toStores.Metabolism.toPhases.MuscleTissue',     'this.afMass(this.oMT.tiN2I.Human_Tissue)', 'kg', 'Muscle Mass');
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
            
            % Since it is confusing to blood the flowrates that basically
            % handle negative flows as two values, we create virtual values
            % for the overall flows
            oLog.addVirtualValue('"H2O Massflow through Endothelium" - "H2O MassREflow through Endothelium"',       'kg/s', 'Endothelium H2O Massflow');
            oLog.addVirtualValue('"Na+ Massflow through Endothelium" - "Na+ MassREflow through Endothelium"',       'kg/s', 'Endothelium Na+ Massflow');
            oLog.addVirtualValue('"K+ Massflow through Endothelium"  - "K+ MassREflow through Endothelium"',        'kg/s', 'Endothelium K+ Massflow');
            
            oLog.addVirtualValue('"H2O Massflow through CellMembranes" - "H2O MassREflow through CellMembranes"',   'kg/s', 'CellMembranes H2O Massflow');
            oLog.addVirtualValue('"Na+ Massflow through CellMembranes" - "Na+ MassREflow through CellMembranes"',   'kg/s', 'CellMembranes Na+ Massflow');
            oLog.addVirtualValue('"K+ Massflow through CellMembranes"  - "K+ MassREflow through CellMembranes"',    'kg/s', 'CellMembranes K+ Massflow');
            
            oLog.addVirtualValue('"H2O Massflow to Kidney" - "H2O readsorption from Kidney"',   'kg/s', 'Kidney H2O Massflow');
            oLog.addVirtualValue('"Na+ Massflow to Kidney" - "Na+ readsorption from Kidney"',   'kg/s', 'Kidney Na+ Massflow');
            oLog.addVirtualValue('"K+ Massflow to Kidney"  - "K+ readsorption from Kidney"',    'kg/s', 'Kidney K+ Massflow');
            
            %% Digestion
            % Stomach
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Stomach',                          'fMass',                                            'kg',   'Total Mass in Stomach');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Stomach',                          'this.afMass(this.oMT.tiN2I.C3H7NO2)',              'kg',   'Protein Mass in Stomach');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Stomach',                          'this.afMass(this.oMT.tiN2I.C51H98O6)',            	'kg',   'Fat Mass in Stomach');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Stomach',                          'this.afMass(this.oMT.tiN2I.C6H12O6)',              'kg',   'Glucose Mass in Stomach');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Stomach',                          'this.afMass(this.oMT.tiN2I.H2O)',                  'kg',   'H2O Mass in Stomach');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Stomach',                          'this.afMass(this.oMT.tiN2I.DietaryFiber)',     	'kg',   'Fiber Mass in Stomach');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Stomach',                          'this.afMass(this.oMT.tiN2I.Naplus)',            	'kg',   'Sodium Mass in Stomach');
            
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Stomach.toManips.substance',       'this.afPartialFlows(this.oMT.tiN2I.C3H7NO2)',   	'kg/s', 'Stomach Protein Flow Rate');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Stomach.toManips.substance',       'this.afPartialFlows(this.oMT.tiN2I.C51H98O6)',    	'kg/s', 'Stomach Fat Flow Rate');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Stomach.toManips.substance',       'this.afPartialFlows(this.oMT.tiN2I.C6H12O6)',    	'kg/s', 'Stomach Glucose Flow Rate');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Stomach.toManips.substance',       'this.afPartialFlows(this.oMT.tiN2I.H2O)',          'kg/s', 'Stomach H2O Flow Rate');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Stomach.toManips.substance',       'this.afPartialFlows(this.oMT.tiN2I.DietaryFiber)', 'kg/s', 'Stomach Fiber Flow Rate');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Stomach.toManips.substance',       'this.afPartialFlows(this.oMT.tiN2I.Naplus)',      	'kg/s', 'Stomach Sodium Flow Rate');
            
            % Duodenum
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Duodenum',                         'this.afMass(this.oMT.tiN2I.C3H7NO2)',              'kg',   'Protein Mass in Duodenum');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Duodenum',                         'this.afMass(this.oMT.tiN2I.C51H98O6)',            	'kg',   'Fat Mass in Duodenum');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Duodenum',                         'this.afMass(this.oMT.tiN2I.C6H12O6)',              'kg',   'Glucose Mass in Duodenum');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Duodenum',                         'this.afMass(this.oMT.tiN2I.H2O)',                  'kg',   'H2O Mass in Duodenum');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Duodenum',                         'this.afMass(this.oMT.tiN2I.DietaryFiber)',     	'kg',   'Fiber Mass in Duodenum');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Duodenum',                         'this.afMass(this.oMT.tiN2I.Naplus)',             	'kg',   'Sodium Mass in Duodenum');
            
            % Jejunum
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Jejunum',                          'this.afMass(this.oMT.tiN2I.C3H7NO2)',              'kg',   'Protein Mass in Jejunum');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Jejunum',                          'this.afMass(this.oMT.tiN2I.C51H98O6)',             'kg',   'Fat Mass in Jejunum');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Jejunum',                          'this.afMass(this.oMT.tiN2I.C6H12O6)',              'kg',   'Glucose Mass in Jejunum');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Jejunum',                          'this.afMass(this.oMT.tiN2I.H2O)',                  'kg',   'H2O Mass in Jejunum');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Jejunum',                          'this.afMass(this.oMT.tiN2I.DietaryFiber)',     	'kg',   'Fiber Mass in Jejunum');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Jejunum',                          'this.afMass(this.oMT.tiN2I.Naplus)',             	'kg',   'Sodium Mass in Jejunum');
            
            % Ileum
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Ileum',                            'this.afMass(this.oMT.tiN2I.C3H7NO2)',              'kg',   'Protein Mass in Ileum');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Ileum',                            'this.afMass(this.oMT.tiN2I.C51H98O6)',             'kg',   'Fat Mass in Ileum');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Ileum',                            'this.afMass(this.oMT.tiN2I.C6H12O6)',              'kg',   'Glucose Mass in Ileum');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Ileum',                            'this.afMass(this.oMT.tiN2I.H2O)',                  'kg',   'H2O Mass in Ileum');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Ileum',                            'this.afMass(this.oMT.tiN2I.DietaryFiber)',     	'kg',   'Fiber Mass in Ileum');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Ileum',                            'this.afMass(this.oMT.tiN2I.Naplus)',           	'kg',   'Sodium Mass in Ileum');
            
            % LargeIntestine
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.LargeIntestine',                   'this.afMass(this.oMT.tiN2I.C3H7NO2)',              'kg',   'Protein Mass in LargeIntestine');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.LargeIntestine',                	'this.afMass(this.oMT.tiN2I.C51H98O6)',             'kg',   'Fat Mass in LargeIntestine');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.LargeIntestine',               	'this.afMass(this.oMT.tiN2I.C6H12O6)',              'kg',   'Glucose Mass in LargeIntestine');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.LargeIntestine',                	'this.afMass(this.oMT.tiN2I.H2O)',                  'kg',   'H2O Mass in LargeIntestine');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.LargeIntestine',                   'this.afMass(this.oMT.tiN2I.DietaryFiber)',     	'kg',   'Fiber Mass in LargeIntestine');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.LargeIntestine',                 	'this.afMass(this.oMT.tiN2I.Naplus)',              	'kg',   'Sodium Mass in LargeIntestine');
            
            % Rectum
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Rectum',                           'fMass',                                            'kg',   'Total Mass in Rectum');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Rectum',                           'this.afMass(this.oMT.tiN2I.Feces)',                'kg',   'Feces Mass in Rectum');
            
            % Branches to Metabolic Layer
            oLog.addValue('Example:c:Human_1.toBranches.DuodenumToMetabolism.aoFlows(1)',                               'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C3H7NO2)',    	'kg/s',     'Digested Protein from Duodenum');
            oLog.addValue('Example:c:Human_1.toBranches.DuodenumToMetabolism.aoFlows(1)',                               'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C51H98O6)',   	'kg/s',     'Digested Fat from Duodenum');
            oLog.addValue('Example:c:Human_1.toBranches.DuodenumToMetabolism.aoFlows(1)',                               'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C6H12O6)',    	'kg/s',     'Digested Glucose from Duodenum');
            
            oLog.addValue('Example:c:Human_1.toBranches.JejunumToMetabolism.aoFlows(1)',                                'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C3H7NO2)',    	'kg/s',     'Digested Protein from Jejunum');
            oLog.addValue('Example:c:Human_1.toBranches.JejunumToMetabolism.aoFlows(1)',                                'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C51H98O6)',   	'kg/s',     'Digested Fat from Jejunum');
            oLog.addValue('Example:c:Human_1.toBranches.JejunumToMetabolism.aoFlows(1)',                                'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C6H12O6)',    	'kg/s',     'Digested Glucose from Jejunum');
            
            oLog.addValue('Example:c:Human_1.toBranches.IleumToMetabolism.aoFlows(1)',                                  'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C3H7NO2)',    	'kg/s',     'Digested Protein from Ileum');
            oLog.addValue('Example:c:Human_1.toBranches.IleumToMetabolism.aoFlows(1)',                                  'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C51H98O6)',   	'kg/s',     'Digested Fat from Ileum');
            oLog.addValue('Example:c:Human_1.toBranches.IleumToMetabolism.aoFlows(1)',                                  'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C6H12O6)',    	'kg/s',     'Digested Glucose from Ileum');
            
            % Readsorption Branches
            oLog.addValue('Example:c:Human_1.toBranches.ReadsorptionFromDuodenum.aoFlows(1)',                           'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',          'kg/s',     'H2O Readsorption Duodenum');
            oLog.addValue('Example:c:Human_1.toBranches.ReadsorptionFromDuodenum.aoFlows(1)',                           'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Naplus)',      	'kg/s',     'Sodium Readsorption Duodenum');
            
            oLog.addValue('Example:c:Human_1.toBranches.ReadsorptionFromJejunum.aoFlows(1)',                            'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',          'kg/s',     'H2O Readsorption Jejunum');
            oLog.addValue('Example:c:Human_1.toBranches.ReadsorptionFromJejunum.aoFlows(1)',                            'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Naplus)',    	'kg/s',     'Sodium Readsorption Jejunum');
            
            oLog.addValue('Example:c:Human_1.toBranches.ReadsorptionFromIleum.aoFlows(1)',                              'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',          'kg/s',     'H2O Readsorption Ileum');
            oLog.addValue('Example:c:Human_1.toBranches.ReadsorptionFromIleum.aoFlows(1)',                              'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Naplus)',      	'kg/s',     'Sodium Readsorption Ileum');
            
            oLog.addValue('Example:c:Human_1.toBranches.ReadsorptionFromLargeIntestine.aoFlows(1)',                     'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',          'kg/s',     'H2O Readsorption LargeIntestine');
            oLog.addValue('Example:c:Human_1.toBranches.ReadsorptionFromLargeIntestine.aoFlows(1)',                 	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Naplus)',      	'kg/s',     'Sodium Readsorption LargeIntestine');
            
            % Secretion Branches
            oLog.addValue('Example:c:Human_1.toBranches.SecretionToStomach.aoFlows(1)',                                 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',          'kg/s',     'H2O Secretion Stomach');
            oLog.addValue('Example:c:Human_1.toBranches.SecretionToStomach.aoFlows(1)',                                 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Naplus)',      	'kg/s',     'Sodium Secretion Stomach');
            
            oLog.addValue('Example:c:Human_1.toBranches.SecretionToDuodenum.aoFlows(1)',                                'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',          'kg/s',     'H2O Secretion Duodenum');
            oLog.addValue('Example:c:Human_1.toBranches.SecretionToDuodenum.aoFlows(1)',                                'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Naplus)',     	'kg/s',     'Sodium Secretion Duodenum');
            
            oLog.addValue('Example:c:Human_1.toBranches.SecretionToJejunum.aoFlows(1)',                                 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',          'kg/s',     'H2O Secretion Jejunum');
            oLog.addValue('Example:c:Human_1.toBranches.SecretionToJejunum.aoFlows(1)',                                 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Naplus)',     	'kg/s',     'Sodium Secretion Jejunum');
            
            oLog.addValue('Example:c:Human_1.toBranches.SecretionToIleum.aoFlows(1)',                                   'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',          'kg/s',     'H2O Secretion Ileum');
            oLog.addValue('Example:c:Human_1.toBranches.SecretionToIleum.aoFlows(1)',                                   'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Naplus)',     	'kg/s',     'Sodium Secretion Ileum');
            
            oLog.addValue('Example:c:Human_1.toBranches.SecretionToLargeIntestine.aoFlows(1)',                          'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',          'kg/s',     'H2O Secretion LargeIntestine');
            oLog.addValue('Example:c:Human_1.toBranches.SecretionToLargeIntestine.aoFlows(1)',                        	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Naplus)',     	'kg/s',     'Sodium Secretion LargeIntestine');
            
            % Transport P2Ps
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.Stomach_to_Duodenum',            'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C3H7NO2)',    	'kg/s',     'Protein from Stomach');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.Stomach_to_Duodenum',            'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C51H98O6)',    	'kg/s',     'Fat from Stomach');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.Stomach_to_Duodenum',            'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C6H12O6)',    	'kg/s',     'Glucose from Stomach');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.Stomach_to_Duodenum',            'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',          'kg/s',     'H2O from Stomach');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.Stomach_to_Duodenum',            'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.DietaryFiber)',	'kg/s',     'Fiber from Stomach');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.Stomach_to_Duodenum',            'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Naplus)',      	'kg/s',     'Sodium from Stomach');
            
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.Duodenum_to_Jejunum',            'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C3H7NO2)',    	'kg/s',     'Protein from Duodenum');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.Duodenum_to_Jejunum',            'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C51H98O6)',    	'kg/s',     'Fat from Duodenum');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.Duodenum_to_Jejunum',            'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C6H12O6)',    	'kg/s',     'Glucose from Duodenum');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.Duodenum_to_Jejunum',            'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',          'kg/s',     'H2O from Duodenum');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.Duodenum_to_Jejunum',            'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.DietaryFiber)',	'kg/s',     'Fiber from Duodenum');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.Duodenum_to_Jejunum',            'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Naplus)',      	'kg/s',     'Sodium from Duodenum');
            
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.Jejunum_to_Ileum',               'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C3H7NO2)',    	'kg/s',     'Protein from Jejunum');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.Jejunum_to_Ileum',               'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C51H98O6)',    	'kg/s',     'Fat from Jejunum');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.Jejunum_to_Ileum',               'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C6H12O6)',    	'kg/s',     'Glucose from Jejunum');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.Jejunum_to_Ileum',               'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',          'kg/s',     'H2O from Jejunum');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.Jejunum_to_Ileum',               'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.DietaryFiber)',	'kg/s',     'Fiber from Jejunum');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.Jejunum_to_Ileum',               'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Naplus)',      	'kg/s',     'Sodium from Jejunum');
            
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.Ileum_to_LargeIntestine',       	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C3H7NO2)',    	'kg/s',     'Protein from Ileum');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.Ileum_to_LargeIntestine',     	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C51H98O6)',    	'kg/s',     'Fat from Ileum');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.Ileum_to_LargeIntestine',       	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C6H12O6)',    	'kg/s',     'Glucose from Ileum');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.Ileum_to_LargeIntestine',    	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',          'kg/s',     'H2O from Ileum');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.Ileum_to_LargeIntestine',     	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.DietaryFiber)',	'kg/s',     'Fiber from Ileum');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.Ileum_to_LargeIntestine',     	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Naplus)',      	'kg/s',     'Sodium from Ileum');
            
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.LargeIntestine_to_Rectum',    	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C3H7NO2)',    	'kg/s',     'Protein from LargeIntestine');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.LargeIntestine_to_Rectum',    	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C51H98O6)',    	'kg/s',     'Fat from LargeIntestine');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.LargeIntestine_to_Rectum',    	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C6H12O6)',    	'kg/s',     'Glucose from LargeIntestine');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.LargeIntestine_to_Rectum',   	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',          'kg/s',     'H2O from LargeIntestine');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.LargeIntestine_to_Rectum',    	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.DietaryFiber)',	'kg/s',     'Fiber from LargeIntestine');
            oLog.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.LargeIntestine_to_Rectum',     	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Naplus)',      	'kg/s',     'Sodium from LargeIntestine');
            
        end
        
        function plot(this, varargin) % Plotting the results
            
            %% Define Plots
            
            close all
            oPlotter = plot@simulation.infrastructure(this);
            
            
            tPlotOptions.sTimeUnit  = 'hours';
            
            %% General Plots
            
            coPlot = cell(2,2);
            csFecesComponents = {'H2O', 'DietaryFiber', 'C6H12O6', 'C51H98O6', 'C3H7NO2', 'Naplus'};
            csFecesMass = cell(1, length(csFecesComponents));
            for iComponent = 1:length(csFecesComponents)
                csFecesMass{iComponent} = ['"Feces ', csFecesComponents{iComponent},' Content"'];
            end
            
            csUrineComponents = {'H2O', 'Naplus', 'CH4N2O'};
            csUrineMass = cell(1, length(csUrineComponents));
            for iComponent = 1:length(csUrineComponents)
                csUrineMass{iComponent} = ['"Urine ', csUrineComponents{iComponent},' Content"'];
            end
            
            coPlot{1,1} = oPlotter.definePlot(csFecesMass, 'Feces Composition', tPlotOptions);
            coPlot{2,1} = oPlotter.definePlot(csUrineMass, 'Urine Composition', tPlotOptions);
           
            coPlot{1,2} = oPlotter.definePlot({'"Ingested Water Flow Rate"', '"Respiration Water Flow Rate"', '"Perspiration Water Flow Rate"', '"Urine Flow Rate"'}, 'Human Water Flows', tPlotOptions);
            
            oPlotter.defineFigure(coPlot,  'General Plots');
            
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
            coPlot{2,1} = oPlotter.definePlot({'"Fat Mass Adipose Tissue"', '"Water in Adipose Tissue"', '"Muscle Mass"'}, 'Masses in Metabolic Layer', tPlotOptions);
            coPlot{2,2} = oPlotter.definePlot({'"Protein Mass in Metabolism"', '"Fat Mass in Metabolism"', '"Glucose Mass in Metabolism"', '"Water Mass in Metabolism"'}, 'Masses in Metabolism Phase', tPlotOptions);
            
            coPlot{2,3} = oPlotter.definePlot({'"Metabolism Protein Flow Rate"', '"Metabolism Fat Flow Rate"', '"Metabolism Glucose Flow Rate"', '"Metabolism O2 Flow Rate"',...
                '"Metabolism CO2 Flow Rate"', '"Metabolism H2O Flow Rate"', '"Metabolism Urea Flow Rate"', '"Metabolism Muscle Flow Rate"'}, 'Manipulator Flowrates in Metabolism', tPlotOptions);
            
            coPlot{3,1} = oPlotter.definePlot({'"Glucose in Liver"', '"Glucose in Muscle"', }, 'Glucose Masses in Metabolic Layer', tPlotOptions);
            
            coPlot{3,2} = oPlotter.definePlot({'"Resting Daily Energy Demand"', '"Additional Energy Demand from Exercise"', }, 'Metabolic Energy Demands', tPlotOptions);
            
            coPlot{3,3} = oPlotter.definePlot({'"Glucose to Liver Flow Rate"', '"Glucose to Muscle Flow Rate"', '"Muscle from Metabolism Flow Rate"', '"Fat to Adipose Tissue Flow Rate"', '"H2O to Adipose Tissue Flow Rate"'}, 'P2P Flowrates in Metabolism', tPlotOptions);
            
            oPlotter.defineFigure(coPlot,  'Metabolic');
            
            %% Water Balance
            coPlot = cell(3,3);
            
            coPlot{1,1} = oPlotter.definePlot({'"ADH in Blood Plasma"', '"Renin in Blood Plasma"', '"Angiotensin II in Blood Plasma"', '"Aldosteron in Blood Plasma"'}, 'Hormone Concentrations in Blood Plasma',   tPlotOptions);
            coPlot{1,2} = oPlotter.definePlot({'"Thirst Level"'}, 'Thirst', tPlotOptions);
            coPlot{1,3} = oPlotter.definePlot({'"Urine Mass in Bladder"',       '"H2O Mass in Bladder"',	'"Na+ Mass in Bladder"',                    '"K+ Mass in Bladder"'},              	'Bladder Masses',   tPlotOptions);
            coPlot{2,1} = oPlotter.definePlot({'"H2O Mass in Blood Plasma"',    '"H2O Mass in Kidney"',    	'"H2O Mass in InterstitialFluid"',          '"H2O Mass in IntracellularFluid"'}, 	'Water Masses',     tPlotOptions);
            coPlot{2,2} = oPlotter.definePlot({'"Na+ Mass in Blood Plasma"', 	'"Na+ Mass in Kidney"',     '"Na+ Mass in InterstitialFluid"',          '"Na+ Mass in IntracellularFluid"'},  	'Na+ Masses',       tPlotOptions);
            coPlot{2,3} = oPlotter.definePlot({'"K+ Mass in Blood Plasma"',     '"K+ Mass in Kidney"',      '"K+ Mass in InterstitialFluid"',           '"K+ Mass in IntracellularFluid"'},     'K+ Masses',        tPlotOptions);
            
            coPlot{3,1} = oPlotter.definePlot({'"Endothelium H2O Massflow"',        '"Endothelium Na+ Massflow"',       '"Endothelium K+ Massflow"'},                                           'Endothelium Flows', tPlotOptions);
            
            coPlot{3,2} = oPlotter.definePlot({'"CellMembranes H2O Massflow"',      '"CellMembranes Na+ Massflow"',   	'"CellMembranes K+ Massflow"'},                                       	'Cell Membrane Flows', tPlotOptions);
            
            coPlot{3,3} = oPlotter.definePlot({'"Kidney H2O Massflow"',         	'"Kidney Na+ Massflow"',         	'"Kidney K+ Massflow"',...
                '"H2O Massflow to Bladder"',      	'"Na+ Massflow to Bladder"',      	'"K+ Massflow to Bladder"'},                                           	'Kidney Flows', tPlotOptions);
            
            oPlotter.defineFigure(coPlot,  'Water Balance');
            
            %% Digestion
            csPhases = {'Stomach', 'Duodenum', 'Jejunum', 'Ileum', 'LargeIntestine'};
            csMasses = {'Protein', 'Fat', 'Glucose', 'H2O', 'Sodium', 'Fiber'};
            
            tfMass = struct();
            
            iPhases = length(csPhases);
            iMasses = length(csMasses);
            
            for iMass = 1:iMasses
                tfMass.(csMasses{iMass}) = cell(1, iPhases);
                for iPhase = 1:iPhases
                    tfMass.(csMasses{iMass}){iPhase} = ['"', csMasses{iMass}, ' Mass in ', csPhases{iPhase}, '"'];
                end
            end
            
            % For the transport flows inside the digestion layer, consider
            % all phases and masses again:
            tfTransportFlows = struct();
            for iMass = 1:iMasses
                tfTransportFlows.(csMasses{iMass}) = cell(1, iPhases + 1);
                for iPhase = 1:iPhases
                    tfTransportFlows.(csMasses{iMass}){iPhase} = ['"', csMasses{iMass}, ' from ', csPhases{iPhase}, '"'];
                end
                tfTransportFlows.(csMasses{iMass}){iPhases + 1} = ['"Stomach ', csMasses{iMass}, ' Flow Rate"'];
            end
            
            % For the flows to metabolism, all phases except stomach and
            % large intestine, and for masses only the major nutrients
            % (water and sodium are handled in the readsorption part)
            csMasses = {'Protein', 'Fat', 'Glucose'};
            iMasses = length(csMasses);
            
            tfMetabolismFlows = struct();
            for iMass = 1:(iMasses)
                tfMetabolismFlows.(csMasses{iMass}) = cell(1, iPhases - 2);
                for iPhase = 2:(iPhases - 1)
                    tfMetabolismFlows.(csMasses{iMass}){iPhase - 1} = ['"Digested ', csMasses{iMass}, ' from ', csPhases{iPhase}, '"'];
                end
            end
            
            % For secretion and readsorption only water and sodium
            csMasses = {'H2O', 'Sodium'};
            iMasses = length(csMasses);
            % Readsorption Branches, without stomach
            tfReadsorptionFlows = struct();
            for iMass = 1:(iMasses)
                tfReadsorptionFlows.(csMasses{iMass}) = cell(1, iPhases - 1);
                for iPhase = 2:(iPhases)
                    tfReadsorptionFlows.(csMasses{iMass}){iPhase - 1} = ['"', csMasses{iMass}, ' Readsorption ', csPhases{iPhase}, '"'];
                end
            end
            
            tfSecretionFlows = struct();
            for iMass = 1:(iMasses)
                tfSecretionFlows.(csMasses{iMass}) = cell(1, iPhases);
                for iPhase = 1:(iPhases)
                    tfSecretionFlows.(csMasses{iMass}){iPhase} = ['"', csMasses{iMass}, ' Secretion ', csPhases{iPhase}, '"'];
                end
            end
            
            % Define the figures, for digestion we use more than one figure
            coPlot = cell(3,2);
            csMasses = fieldnames(tfMass);
            iMasses = length(csMasses);
            for iMass = 1:iMasses
                coPlot{iMass} = oPlotter.definePlot(tfMass.(csMasses{iMass}), [csMasses{iMass}, ' Masses'],   tPlotOptions);
            end
            oPlotter.defineFigure(coPlot,  'Digestion Masses');
            
            coPlot = cell(3,1);
            csFlows = fieldnames(tfMetabolismFlows);
            iFlows = length(csFlows);
            for iFlow = 1:iFlows
                coPlot{iFlow} = oPlotter.definePlot(tfMetabolismFlows.(csFlows{iFlow}), [csFlows{iFlow}, ' Flows to Metabolism'],   tPlotOptions);
            end
            oPlotter.defineFigure(coPlot,  'Digestion Flows to Metabolism');
            
            coPlot = cell(3,2);
            csFlows = fieldnames(tfTransportFlows);
            iFlows = length(csFlows);
            for iFlow = 1:iFlows
                coPlot{iFlow} = oPlotter.definePlot(tfTransportFlows.(csFlows{iFlow}), [csFlows{iFlow}, ' Transport and Stomach Manip Flows'],   tPlotOptions);
            end
            oPlotter.defineFigure(coPlot,  'Digestion Internal Flows');
            
            coPlot = cell(3,2);
            coPlot{1,1} = oPlotter.definePlot(tfReadsorptionFlows.H2O,      'H2O Readsorption Flows',       tPlotOptions);
            coPlot{1,2} = oPlotter.definePlot(tfReadsorptionFlows.Sodium,   'Sodium Readsorption Flows',    tPlotOptions);
            coPlot{2,1} = oPlotter.definePlot(tfSecretionFlows.H2O,         'H2O Secretion Flows',          tPlotOptions);
            coPlot{2,2} = oPlotter.definePlot(tfSecretionFlows.Sodium,      'Sodium Secretion Flows',       tPlotOptions);
            coPlot{3,1} = oPlotter.definePlot({'"Total Mass in Stomach"', '"Total Mass in Rectum"', '"Feces Mass in Rectum"'},      'Masses in Stomach and Rectum',       tPlotOptions);
                
            oPlotter.defineFigure(coPlot,  'Digestion Readsorption and Secretion Flows');
            
            oPlotter.plot();
            
            oLogger = this.toMonitors.oLogger;
            
            iLogs = length(oLogger.afTime);
            
            afTimeSteps = (oLogger.afTime(2:end) - oLogger.afTime(1:end-1));

            for iLog = 1:oLogger.iNumberOfLogItems
                if strcmp(oLogger.tLogValues(iLog).sLabel, 'Ingested Water Flow Rate')
                    iDrinkingWaterFlow = iLog;
                end
                
                if strcmp(oLogger.tLogValues(iLog).sLabel, 'Respiration Water Flow Rate')
                    iRespirationWaterFlow = iLog;
                end
                
                if strcmp(oLogger.tLogValues(iLog).sLabel, 'Perspiration Water Flow Rate')
                    iPerspirationWaterFlow = iLog;
                end
                
                if strcmp(oLogger.tLogValues(iLog).sLabel, 'Metabolism H2O Flow Rate')
                    iMetabolicWater = iLog;
                end
                
                if strcmp(oLogger.tLogValues(iLog).sLabel, 'Stomach H2O Flow Rate')
                    iWaterinFood = iLog;
                end
                
                if strcmp(oLogger.tLogValues(iLog).sLabel, 'H2O from LargeIntestine')
                    iFecesH2O = iLog;
                end
                
                if strcmp(oLogger.tLogValues(iLog).sLabel, 'H2O Massflow to Bladder')
                    iUrineH2O = iLog;
                end
                
                if strcmp(oLogger.tLogValues(iLog).sLabel, 'Food Flow Rate')
                    iFood = iLog;
                end
                
                if strcmp(oLogger.tLogValues(iLog).sLabel, 'Protein from LargeIntestine')
                    iProteinFeces = iLog;
                end
                
                if strcmp(oLogger.tLogValues(iLog).sLabel, 'Fat from LargeIntestine')
                    iFatFeces = iLog;
                end
                
                if strcmp(oLogger.tLogValues(iLog).sLabel, 'Glucose from LargeIntestine')
                    iGlucoseFeces = iLog;
                end
                
                if strcmp(oLogger.tLogValues(iLog).sLabel, 'Fiber from LargeIntestine')
                    iFiberFeces = iLog;
                end
                
                if strcmp(oLogger.tLogValues(iLog).sLabel, 'Sodium from LargeIntestine')
                    iSodiumFeces = iLog;
                end
                
                if strcmp(oLogger.tLogValues(iLog).sLabel, 'Na+ Massflow to Bladder')
                    iSodiumUrine = iLog;
                end
                
                if strcmp(oLogger.tLogValues(iLog).sLabel, 'K+ Massflow to Bladder')
                    iPotassiumUrine = iLog;
                end
                
                if strcmp(oLogger.tLogValues(iLog).sLabel, 'Metabolism Urea Flow Rate')
                    iUreaUrine = iLog;
                end
            end
            
            afConsumedDrinkingWater     = zeros(iLogs,1);
            afProducedRespirationWater  = zeros(iLogs,1);
            afProducedPerspirationWater = zeros(iLogs,1);
            afProducedMetabolicWater    = zeros(iLogs,1);
            afIngestedWaterInFood       = zeros(iLogs,1);
            afFecesWater                = zeros(iLogs,1);
            afUrineWater                = zeros(iLogs,1);
            afFood                      = zeros(iLogs,1);
            afFecesProtein            	= zeros(iLogs,1);
            afFecesFat                	= zeros(iLogs,1);
            afFecesGlucose            	= zeros(iLogs,1);
            afFecesFiber            	= zeros(iLogs,1);
            afFecesSodium             	= zeros(iLogs,1);
            afUrineSodium             	= zeros(iLogs,1);
            afUrinePotassium          	= zeros(iLogs,1);
            afUrineUrea                 = zeros(iLogs,1);
            
            for iLog = 2:iLogs
                afConsumedDrinkingWater(iLog)       = afConsumedDrinkingWater(iLog-1)       + afTimeSteps(iLog-1)' .* oLogger.mfLog(iLog,iDrinkingWaterFlow);
                afProducedRespirationWater(iLog) 	= afProducedRespirationWater(iLog-1)    + afTimeSteps(iLog-1)' .* oLogger.mfLog(iLog,iRespirationWaterFlow);
                afProducedPerspirationWater(iLog) 	= afProducedPerspirationWater(iLog-1)   + afTimeSteps(iLog-1)' .* oLogger.mfLog(iLog,iPerspirationWaterFlow);
                afProducedMetabolicWater(iLog)      = afProducedMetabolicWater(iLog-1)      + afTimeSteps(iLog-1)' .* oLogger.mfLog(iLog,iMetabolicWater);
                afIngestedWaterInFood(iLog)         = afIngestedWaterInFood(iLog-1)         + afTimeSteps(iLog-1)' .* oLogger.mfLog(iLog,iWaterinFood);
                afFecesWater(iLog)                  = afFecesWater(iLog-1)                  + afTimeSteps(iLog-1)' .* oLogger.mfLog(iLog,iFecesH2O);
                afUrineWater(iLog)                  = afUrineWater(iLog-1)                  + afTimeSteps(iLog-1)' .* oLogger.mfLog(iLog,iUrineH2O);
                afFood(iLog)                        = afFood(iLog-1)                        + afTimeSteps(iLog-1)' .* oLogger.mfLog(iLog,iFood);
                afFecesProtein(iLog)             	= afFecesProtein(iLog-1)              	+ afTimeSteps(iLog-1)' .* oLogger.mfLog(iLog,iProteinFeces);
                afFecesFat(iLog)                    = afFecesFat(iLog-1)                    + afTimeSteps(iLog-1)' .* oLogger.mfLog(iLog,iFatFeces);
                afFecesGlucose(iLog)             	= afFecesGlucose(iLog-1)              	+ afTimeSteps(iLog-1)' .* oLogger.mfLog(iLog,iGlucoseFeces);
                afFecesFiber(iLog)                  = afFecesFiber(iLog-1)              	+ afTimeSteps(iLog-1)' .* oLogger.mfLog(iLog,iFiberFeces);
                afFecesSodium(iLog)                 = afFecesSodium(iLog-1)              	+ afTimeSteps(iLog-1)' .* oLogger.mfLog(iLog,iSodiumFeces);
                afUrineSodium(iLog)                 = afUrineSodium(iLog-1)              	+ afTimeSteps(iLog-1)' .* oLogger.mfLog(iLog,iSodiumUrine);
                afUrinePotassium(iLog)          	= afUrinePotassium(iLog-1)              + afTimeSteps(iLog-1)' .* oLogger.mfLog(iLog,iPotassiumUrine);
                afUrineUrea(iLog)                   = afUrineUrea(iLog-1)                   + afTimeSteps(iLog-1)' .* oLogger.mfLog(iLog,iUreaUrine);
            end
            
            % We calculated the individual masses to be able to check
            % those, but for now we just compare the total feces solid
            % production
            afFecesSolids = afFecesProtein + afFecesFat + afFecesGlucose + afFecesFiber + afFecesSodium;
            afUrineSolids = afUrineSodium + afUrinePotassium + afUrineUrea;
            
            for iVirtualLog = 1:length(oLogger.tVirtualValues)
                if strcmp(oLogger.tVirtualValues(iVirtualLog).sLabel, 'Effective CO2 Flow')
                    
                    mfEffectiveCO2Flow = oLogger.tVirtualValues(iVirtualLog).calculationHandle(oLogger.mfLog);
                    
                elseif strcmp(oLogger.tVirtualValues(iVirtualLog).sLabel, 'Effective O2 Flow')
                    
                    mfEffectiveO2Flow = oLogger.tVirtualValues(iVirtualLog).calculationHandle(oLogger.mfLog);
                    
                end
                
            end
            
            afGeneratedCO2Mass  = zeros(iLogs,1);
            afConsumedO2Mass    = zeros(iLogs,1);
            for iLog = 2:iLogs
                afGeneratedCO2Mass(iLog)  = sum(afTimeSteps(1:iLog-1)' .* mfEffectiveCO2Flow(2:iLog));
                afConsumedO2Mass(iLog)    = sum(afTimeSteps(1:iLog-1)' .* mfEffectiveO2Flow(2:iLog));
            end
            
            figure()
            plot(oLogger.afTime./3600, -1 .* afConsumedDrinkingWater,   	'-')
            hold on
            grid on
            plot(oLogger.afTime./3600, -1 .* afProducedRespirationWater,   	'-')
            plot(oLogger.afTime./3600, -1 .* afProducedPerspirationWater,  	'-')
            plot(oLogger.afTime./3600,       afProducedMetabolicWater,     	'--')
            plot(oLogger.afTime./3600, -1 .* afFecesWater,                  '--')
            plot(oLogger.afTime./3600, -1 .* afFecesSolids,                 '--')
            plot(oLogger.afTime./3600, -1 .* afUrineWater,                  ':')
            plot(oLogger.afTime./3600, -1 .* afUrineSolids,                 ':')
            plot(oLogger.afTime./3600, -1 .* afGeneratedCO2Mass,            ':')
            plot(oLogger.afTime./3600,       afIngestedWaterInFood,     	'-.')
            plot(oLogger.afTime./3600,       afFood,                        '-.')
            plot(oLogger.afTime./3600,       afConsumedO2Mass,              '-.')
           
            legend( 'Drinking Water', 'Respiration Water', 'Perspiration Water', 'Metabolic Water', 'Feces Water', 'Feces Solids', ...
                    'Urine Water', 'Urine Solids', 'Generated CO2', 'Ingested Water from Food', 'Consumed Food', 'Consumed O2');
            xlabel('Time in [h]')
            ylabel('Mass in [kg]')
            hold off
            
            % Average Daily consumptions and productions
            fAverageO2              = abs(afConsumedO2Mass(end)                                                 / (oLogger.afTime(end) / (24*3600)));
            fAverageCO2             = abs(afGeneratedCO2Mass(end)                                               / (oLogger.afTime(end) / (24*3600)));
            fAverageHumidity        = abs((afProducedRespirationWater(end) + afProducedPerspirationWater(end))  / (oLogger.afTime(end) / (24*3600)));
            fAveragePotableWater    = abs(afConsumedDrinkingWater(end)                                          / (oLogger.afTime(end) / (24*3600)));
            fAverageMetabolicWater 	= abs(afProducedMetabolicWater(end)                                         / (oLogger.afTime(end) / (24*3600)));
            fAverageFoodWater       = abs(afIngestedWaterInFood(end)                                            / (oLogger.afTime(end) / (24*3600)));
            fAverageFood            = abs(afFood(end)                                                           / (oLogger.afTime(end) / (24*3600)));
            fAverageUrine           = abs((afUrineWater(end))                                                   / (oLogger.afTime(end) / (24*3600)));
            fAverageUrineSolids    	= abs((afUrineSolids(end))                                                  / (oLogger.afTime(end) / (24*3600)));
            fAverageFeces           = abs((afFecesWater(end))                                                   / (oLogger.afTime(end) / (24*3600)));
            fAverageFecesSolid    	= abs((afFecesSolids(end))                                                  / (oLogger.afTime(end) / (24*3600)));
            
            fDifferenceO2               = (1 - (fAverageO2              / 0.816))   * 100;
            fDifferenceCO2              = (1 - (fAverageCO2             / 1.04))    * 100;
            fDifferenceHumidity         = (1 - (fAverageHumidity        / 1.9))     * 100; 
            fDifferencePotableWater     = (1 - (fAveragePotableWater    / 2.5))     * 100; 
            fDifferenceMetabolicWater	= (1 - (fAverageMetabolicWater  / 0.345))   * 100; 
            fDifferenceFoodWater        = (1 - (fAverageFoodWater       / 0.7))     * 100; 
            fDifferenceFood             = (1 - (fAverageFood            / 1.5))     * 100; 
            fDifferenceUrine            = (1 - (fAverageUrine           / 1.6))     * 100; 
            fDifferenceUrineSolids    	= (1 - (fAverageUrineSolids     / 0.059))   * 100; 
            fDifferenceFeces            = (1 - (fAverageFeces           / 0.1))     * 100; 
            fDifferenceFecesSolid    	= (1 - (fAverageFecesSolid      / 0.032))   * 100; 
            
            disp(['Average daily O2 consumption:                ', num2str(fAverageO2), ' kg    BVAD value is 0.816 kg'])
            disp(['Average daily Water consumption:             ', num2str(fAveragePotableWater), ' kg  BVAD value is 2.5 kg'])
            disp(['Average daily Food Water consumption:        ', num2str(fAverageFoodWater), ' kg  BVAD value is 0.7 kg'])
            disp(['Average daily Food consumption:              ', num2str(fAverageFood), ' kg  BVAD value is 1.5 kg'])
            disp(['Average daily Metabolic Water production:    ', num2str(fAverageMetabolicWater), ' kg  BVAD value is 0.345 kg'])
            disp(['Average daily CO2 production:                ', num2str(fAverageCO2), ' kg   BVAD value is 1.04 kg'])
            disp(['Average daily Humidity production:           ', num2str(fAverageHumidity), ' kg  BVAD value is 1.9 kg'])
            disp(['Average daily Urine Water production:        ', num2str(fAverageUrine), ' kg     BVAD value is 1.6 kg'])
            disp(['Average daily Urine Solid production:        ', num2str(fAverageUrineSolids), ' kg     BVAD value is 0.059 kg'])
            disp(['Average daily Feces Water production:        ', num2str(fAverageFeces), ' kg     BVAD value is 0.1 kg'])
            disp(['Average daily Feces Solid production:        ', num2str(fAverageFecesSolid), ' kg     BVAD value is 0.032 kg'])
            disp('')
            disp(['Difference daily O2 consumption:                ', num2str(fDifferenceO2), ' %'])
            disp(['Difference daily Water consumption:             ', num2str(fDifferencePotableWater), ' %'])
            disp(['Difference daily Food Water consumption:        ', num2str(fDifferenceFoodWater), ' %'])
            disp(['Difference daily Food consumption:              ', num2str(fDifferenceFood), ' %'])
            disp(['Difference daily Metabolic Water production:    ', num2str(fDifferenceMetabolicWater), ' %'])
            disp(['Difference daily CO2 production:                ', num2str(fDifferenceCO2), ' %'])
            disp(['Difference daily Humidity production:           ', num2str(fDifferenceHumidity), ' %'])
            disp(['Difference daily Urine Water production:        ', num2str(fDifferenceUrine), ' %'])
            disp(['Difference daily Urine Solid production:        ', num2str(fDifferenceUrineSolids), ' %'])
            disp(['Difference daily Feces Water production:        ', num2str(fDifferenceFeces), ' %'])
            disp(['Difference daily Feces Solid production:        ', num2str(fDifferenceFecesSolid), ' %'])
            disp('')
            disp('All BVAD values refer to Table 3.26 in the NASA Baseline Values and Assumptions Document (BVAD) 2018')
            
            
        end
    end
end