classdef setup < simulation.infrastructure
    
    properties
    end
    
    methods
        function this = setup(ptConfigParams, tSolverParams) % Constructor function
            
            
            ttMonitorConfig = struct ('oLogger', struct('cParams',{{true,100000}}));
            ttMonitorConfig.oTimeStepObserver.sClass = 'simulation.monitors.timestepObserver';
            ttMonitorConfig.oTimeStepObserver.cParams = { 0 };
            
            this@simulation.infrastructure('Cabin', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            examples.algae.systems.PhotobioreactorTutorial(this.oSimulationContainer, 'Cabin');
            
            %% Simulation length
            % Stop when specific time in simulation is reached or after
            % specific amount of ticks (bUseTime true/false).
            this.fSimTime = 3600 * 24 * 10; % In seconds
            % this.fSimTime = 253000;
            this.iSimTicks = 1500;
            this.bUseTime = true;
        end
        
        
        function configureMonitors(this)
            oLog = this.toMonitors.oLogger;
            
            %% CCAA
            oLog.addValue('Cabin:s:Cabin.toPhases.CabinAir', 'rRelHumidity', '-', 'Relative Humidity Cabin');
            
            oLog.addValue('Cabin:c:CCAA:c:CCAA_CHX', 'fTotalCondensateHeatFlow',      'W',    'CCAA Condensate Heat Flow');
            oLog.addValue('Cabin:c:CCAA:c:CCAA_CHX', 'fTotalHeatFlow',                'W',    'CCAA Total Heat Flow');
            oLog.addValue('Cabin:c:CCAA:s:CHX.toProcsP2P.CondensingHX', 'fFlowRate',  'kg/s', 'CCAA Condensate Flow Rate');
            
            %% Cabin and Human
            csStores = fieldnames(this.oSimulationContainer.toChildren.Cabin.toStores);
            for iStore = 1:length(csStores)
                oLog.addValue(['Cabin.toStores.', csStores{iStore}, '.aoPhases(1)'],	'fPressure',	'Pa', [csStores{iStore}, ' Pressure']);
                oLog.addValue(['Cabin.toStores.', csStores{iStore}, '.aoPhases(1)'],	'fTemperature',	'K',  [csStores{iStore}, ' Temperature']);
            end
            
            csBranches = fieldnames(this.oSimulationContainer.toChildren.Cabin.toBranches);
            for iBranch = 1:length(csBranches)
                oLog.addValue(['Cabin.toBranches.', csBranches{iBranch}],             'fFlowRate',    'kg/s', [csBranches{iBranch}, ' Flowrate']);
            end
            
            csStoresHuman_1 = fieldnames(this.oSimulationContainer.toChildren.Cabin.toChildren.Human_1.toStores);
            
            for iStore = 1:length(csStoresHuman_1)
                csPhases = fieldnames(this.oSimulationContainer.toChildren.Cabin.toChildren.Human_1.toStores.(csStoresHuman_1{iStore}).toPhases);
                for iPhase = 1:length(csPhases)
                    oLog.addValue(['Cabin:c:Human_1.toStores.', csStoresHuman_1{iStore}, '.toPhases.', csPhases{iPhase}],	'fMass',        'kg', [csStoresHuman_1{iStore}, ' ', csPhases{iPhase}, ' Mass']);
                    oLog.addValue(['Cabin:c:Human_1.toStores.', csStoresHuman_1{iStore}, '.toPhases.', csPhases{iPhase}],	'fPressure',	'Pa', [csStoresHuman_1{iStore}, ' ', csPhases{iPhase}, ' Pressure']);
                    oLog.addValue(['Cabin:c:Human_1.toStores.', csStoresHuman_1{iStore}, '.toPhases.', csPhases{iPhase}],	'fTemperature',	'K',  [csStoresHuman_1{iStore}, ' ', csPhases{iPhase}, ' Temperature']);
                end
            end
            
            csBranchesHuman_1 = fieldnames(this.oSimulationContainer.toChildren.Cabin.toChildren.Human_1.toBranches);
            for iBranch = 1:length(csBranchesHuman_1)
                oLog.addValue(['Cabin:c:Human_1.toBranches.', csBranchesHuman_1{iBranch}],             'fFlowRate',    'kg/s', [csBranchesHuman_1{iBranch}, ' Flowrate']);
            end
            
            oLog.addValue('Cabin:c:Human_1', 'fVO2_current',              '-', 'VO2');
            oLog.addValue('Cabin:c:Human_1', 'fCurrentEnergyDemand',      'W', 'Current Energy Demand');
            
            oLog.addValue('Cabin:c:Human_1', 'fOxygenDemand',                 'kg/s', 'Oxygen Consumption');
            oLog.addValue('Cabin:c:Human_1', 'fCO2Production',                'kg/s', 'CO_2 Production');
            oLog.addValue('Cabin:c:Human_1', 'fRespiratoryCoefficient',       '-',    'Respiratory Coefficient');
            
            
            oLog.addValue('Cabin:c:Human_1.toStores.Human.toPhases.HumanPhase', 'this.afMass(this.oMT.tiN2I.O2)',          'kg',    'Internal O_2 Mass');
            oLog.addValue('Cabin:c:Human_1.toStores.Human.toPhases.HumanPhase', 'this.afMass(this.oMT.tiN2I.CO2)',         'kg',    'Internal CO_2 Mass');
            oLog.addValue('Cabin:c:Human_1.toStores.Human.toPhases.HumanPhase', 'this.afMass(this.oMT.tiN2I.H2O)',         'kg',    'Internal H_2O Mass');
            oLog.addValue('Cabin:c:Human_1.toStores.Human.toPhases.HumanPhase', 'this.afMass(this.oMT.tiN2I.C4H5ON)',      'kg',    'Internal Protein Mass');
            oLog.addValue('Cabin:c:Human_1.toStores.Human.toPhases.HumanPhase', 'this.afMass(this.oMT.tiN2I.C16H32O2)',    'kg',    'Internal Fat Mass');
            oLog.addValue('Cabin:c:Human_1.toStores.Human.toPhases.HumanPhase', 'this.afMass(this.oMT.tiN2I.C6H12O6)',     'kg',    'Internal Carbohydrate Mass');
            oLog.addValue('Cabin:c:Human_1.toStores.Human.toPhases.HumanPhase', 'this.afMass(this.oMT.tiN2I.C42H69O13N5)', 'kg',    'Internal Feces Solid Mass');
            oLog.addValue('Cabin:c:Human_1.toStores.Human.toPhases.HumanPhase', 'this.afMass(this.oMT.tiN2I.C2H6O2N2)',    'kg',    'Internal Urine Solid Mass');
            
            oLog.addValue('Cabin:c:Human_1.toStores.Human.toProcsP2P.Food_P2P', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',            'kg/s',    'Food Conversion H2O Flowrate');
            oLog.addValue('Cabin:c:Human_1.toStores.Human.toProcsP2P.Food_P2P', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C16H32O2)',       'kg/s',    'Food Conversion Fat Flowrate');
            oLog.addValue('Cabin:c:Human_1.toStores.Human.toProcsP2P.Food_P2P', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C4H5ON)',         'kg/s',    'Food Conversion Protein Flowrate');
            oLog.addValue('Cabin:c:Human_1.toStores.Human.toProcsP2P.Food_P2P', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C6H12O6)',        'kg/s',    'Food Conversion Carbohydrates Flowrate');
            oLog.addValue('Cabin:c:Human_1.toStores.Human.toProcsP2P.Food_P2P', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C)',              'kg/s',    'Food Conversion Ash Flowrate');
            
            oLog.addValue('Cabin:c:Human_1.toStores.Human.toProcsP2P.Food_P2P', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C)',              'kg/s',    'Food Conversion Ash Flowrate');
            
            %cabin O2 and CO2 partialpressures
            oLog.addValue('Cabin.toStores.Cabin.toPhases.CabinAir', 'afPP(this.oMT.tiN2I.O2)',  'Pa',    'Cabin Partial Pressure of O2');
            oLog.addValue('Cabin.toStores.Cabin.toPhases.CabinAir', 'afPP(this.oMT.tiN2I.CO2)', 'Pa',    'Cabin Partial Pressure of CO2');
            
            %% importnant phase masses.
            oLog.addValue('Cabin.toStores.PotableWaterStorage.toPhases.PotableWater',                       'fMass',    'kg',   'Cabin System Potable Water Storage Store Potable Water Phase');
            oLog.addValue('Cabin.toStores.UrineStorage.toPhases.Urine',                                     'fMass',    'kg',   'Cabin System Urine Storage Store urine Phase');
            oLog.addValue('Cabin.toStores.FoodStore.toPhases.Food',                                         'fMass',    'kg',   'Cabin System Food Storage Store Food Phase');
            oLog.addValue('Cabin.toChildren.Photobioreactor.toStores.MediumMaintenance.toPhases.NO3Supply', 'fMass',    'kg',   'PBR System Medium Maintenance Store NO3 Supply Phase');
            oLog.addValue('Cabin.toChildren.Photobioreactor.toStores.MediumMaintenance.toPhases.WaterSupply','fMass',   'kg',   'PBR System Medium Maintenance Store Water Supply Phase');
            oLog.addValue('Cabin.toChildren.Photobioreactor.toStores.Harvester.toPhases.ChlorellaHarvest',  'fMass',    'kg',   'PBR System Harvester Store Chlorella Harvest Phase');
            


            %% growth values
            oLog.addValue('Cabin.toChildren.Photobioreactor.toChildren.ChlorellaInMedia.oGrowthRateCalculationModule',  'fBiomassConcentration',                            'kg/m^3',   'Biomass Concentration');
            oLog.addValue('Cabin.toChildren.Photobioreactor.toChildren.ChlorellaInMedia.oGrowthRateCalculationModule',  'fTheoreticalCurrentBiomassConcentrationIncrease',  '-',        'Theoretical Biomass Concentration Increase');
            oLog.addValue('Cabin.toChildren.Photobioreactor.toChildren.ChlorellaInMedia.oGrowthRateCalculationModule',  'fTheoreticalCurrentBiomassGrowthRate',             'kg/s',     'Theoretical Biomass Growth Rate');
            oLog.addValue('Cabin.toChildren.Photobioreactor.toChildren.ChlorellaInMedia.oGrowthRateCalculationModule',  'fAchievableCurrentBiomassGrowthRate',              'kg/s',     'Achievable Biomass Growth Rate');
            oLog.addValue('Cabin.toChildren.Photobioreactor.toChildren.ChlorellaInMedia.oPhotosynthesisModule',         'fActualGrowthRate',                                'kg/s',     'Actual Biomass Growth Rate');   
            oLog.addValue('Cabin.toChildren.Photobioreactor.toChildren.ChlorellaInMedia.oGrowthRateCalculationModule',  'fCompareTheoreticalBiomassConcentration',          'kg/m^3',   'Reference Biomass Concentration');
            oLog.addValue('Cabin.toChildren.Photobioreactor.toChildren.ChlorellaInMedia.oGrowthRateCalculationModule',  'fCompareTheoreticalCurrentBiomassConcentrationIncrease','-',   'Reference Biomass Concentration Increase');

            
            
            %factors
            %strangely, only O2 or CO2 growth factor can be logged. can't
            %log both at same time
            % error: unable to perform assignment because the size of the left
            % side is 1-by-xxx and the size of the right side is 1-by-(xxx-1).
            oLog.addValue('Cabin.toChildren.Photobioreactor.toChildren.ChlorellaInMedia.oGrowthRateCalculationModule',  'rO2RelativeGrowth',        '-',    'O2 Concentration Relative Growth');
         %   oLog.addValue('Cabin.toChildren.Photobioreactor.toChildren.ChlorellaInMedia.oGrowthRateCalculationModule', 'rCO2RelativeGrowth',       '-',    'CO2 Concentration Relative Growth');
            oLog.addValue('Cabin.toChildren.Photobioreactor.toChildren.ChlorellaInMedia.oGrowthRateCalculationModule',  'rPhRelativeGrowth',        '-',    'PH Influence Relative Growth');
            oLog.addValue('Cabin.toChildren.Photobioreactor.toChildren.ChlorellaInMedia.oGrowthRateCalculationModule',  'rTemperatureRelativeGrowth','-',   'Temperature Influence Relative Growth');
            oLog.addValue('Cabin.toChildren.Photobioreactor.toChildren.ChlorellaInMedia.oGrowthRateCalculationModule',  'rPARRelativeGrowth',       '-',    'PAR Influence Relative Growth');
            %membrane flow factors
            oLog.addValue('Cabin.toChildren.Photobioreactor.toChildren.ChlorellaInMedia.toStores.GrowthChamber.toProcsP2P.CO2_Water_In_Out',    'fFlowFactor', '-', 'CO2 Membrane Transport Factor');
            oLog.addValue('Cabin.toChildren.Photobioreactor.toChildren.ChlorellaInMedia.toStores.GrowthChamber.toProcsP2P.O2_Water_In_Out',     'fFlowFactor', '-', 'O2 Membrane Transport Factor');
            
            %nutrient availability factors 
            oLog.addValue('Cabin.toChildren.Photobioreactor.toChildren.ChlorellaInMedia.oPhotosynthesisModule', 'fCombinedCO2AvailabilityFactor',       '-', 'CO2 Availability Factor in Medium');
            oLog.addValue('Cabin.toChildren.Photobioreactor.toChildren.ChlorellaInMedia.oPhotosynthesisModule', 'fCombinedNitrogenAvailabilityFactor',  '-', 'Nitrogen Availability Factor in Medium');
            oLog.addValue('Cabin.toChildren.Photobioreactor.toChildren.ChlorellaInMedia.oPhotosynthesisModule', 'fAssimilationCoefficient',             '-', 'Assimilation Coefficient of Algal Culture');
            
            %accumulated masses in and out 
            oLog.addValue('Cabin.toChildren.Photobioreactor.toChildren.ChlorellaInMedia.oPhotosynthesisModule',     'fTotalOxygenEvolution',            'kg',   'Total Oxygen Evolution');
            oLog.addValue('Cabin.toChildren.Photobioreactor.toChildren.ChlorellaInMedia.oPhotosynthesisModule',     'fTotalCarbonDioxideAssimilation',  'kg',   'Total Carbon Dioxide Assimilation');
            oLog.addValue('Cabin.toChildren.Photobioreactor',                                                       'fTotalProcessedUrine',             'kg',   'Total Amount of Processed Urine');
            oLog.addValue('Cabin.toChildren.Photobioreactor',                                                       'fTotalProducedWater',              'kg',   'Total Amount of Produced Water');
            
            %growth phase values
            oLog.addValue('Cabin.toChildren.Photobioreactor.toChildren.ChlorellaInMedia.toStores.GrowthChamber.toPhases.GrowthMedium',      'afMass(this.oMT.tiN2I.H2O)',       'kg',   'Mass of Water');
            oLog.addValue('Cabin.toChildren.Photobioreactor.toChildren.ChlorellaInMedia.toStores.GrowthChamber.toPhases.GrowthMedium',      'afMass(this.oMT.tiN2I.NO3)',       'kg',   'Mass of dissolved NO3');
            oLog.addValue('Cabin.toChildren.Photobioreactor.toChildren.ChlorellaInMedia.toStores.GrowthChamber.toPhases.GrowthMedium',      'afMass(this.oMT.tiN2I.Chlorella)', 'kg',   'Mass of Chlorella');
            oLog.addValue('Cabin.toChildren.Photobioreactor.toChildren.ChlorellaInMedia.toStores.GrowthChamber.toPhases.GrowthMedium',      'fTemperature',                     'K',    'Medium Temperature');  
            oLog.addValue('Cabin.toChildren.Photobioreactor.toChildren.ChlorellaInMedia.oGrowthRateCalculationModule.oPhLimitation',        'fPH',                              '-',    'pH of Growth Medium');
            
            
            %Atmospheric Exchange
            oLog.addValue('Cabin.toChildren.Photobioreactor.toChildren.ChlorellaInMedia.toStores.GrowthChamber.toPhases.GrowthMedium',      'afMass(this.oMT.tiN2I.O2)',        'kg',   'Mass of dissolved O2');
            oLog.addValue('Cabin.toChildren.Photobioreactor.toChildren.ChlorellaInMedia.toStores.GrowthChamber.toPhases.AirInGrowthChamber','afPP(this.oMT.tiN2I.CO2)',         'Pa',   'CO2 Partial Pressure in Growth Chamber');
            oLog.addValue('Cabin.toChildren.Photobioreactor.toChildren.ChlorellaInMedia.toStores.GrowthChamber.toPhases.AirInGrowthChamber','afPP(this.oMT.tiN2I.O2)',          'Pa',   'O2 Partial Pressure in Growth Chamber');
            oLog.addValue('Cabin.toChildren.Photobioreactor.toChildren.ChlorellaInMedia.toStores.GrowthChamber.toPhases.GrowthMedium',      'afMass(this.oMT.tiN2I.CO2)',       'kg',   'Mass of dissolved CO2');
            
            
            %PAR module parameters  
            oLog.addValue('Cabin.toChildren.Photobioreactor.toChildren.ChlorellaInMedia.oPARModule', 'fAttenuationCoefficient',     '-', 'Attenuation Coefficient');

            oLog.addValue('Cabin.toChildren.Photobioreactor.toChildren.ChlorellaInMedia.oPARModule', 'fPositionMinimumPPFD',        '-', 'Position of Minimum PPFD');
            oLog.addValue('Cabin.toChildren.Photobioreactor.toChildren.ChlorellaInMedia.oPARModule', 'fPositionSaturationPPFD',     '-', 'Position of Saturated PPFD');
            oLog.addValue('Cabin.toChildren.Photobioreactor.toChildren.ChlorellaInMedia.oPARModule', 'fPositionInhibitionPPFD',     '-', 'Position of Inhibited PPFD');
            
            oLog.addValue('Cabin.toChildren.Photobioreactor.toChildren.ChlorellaInMedia.oPARModule', 'fAveragePPFDLinearGrowth',    '-', 'Average PPFD in Linear Growth Volume');
            oLog.addValue('Cabin.toChildren.Photobioreactor.toChildren.ChlorellaInMedia.oPARModule', 'fPowerSavingSurfacePPFD',     '-', 'Power Saving Surface PPFD');
             oLog.addValue('Cabin.toChildren.Photobioreactor.toChildren.ChlorellaInMedia.oPARModule', 'rPowerSavingRatio',          '-', 'Power Saving Potential with Dynamic PAR Control');
             
            oLog.addValue('Cabin.toChildren.Photobioreactor.toChildren.ChlorellaInMedia.oPARModule', 'fNoGrowthVolume',             '-', 'No Growth Volume');
            oLog.addValue('Cabin.toChildren.Photobioreactor.toChildren.ChlorellaInMedia.oPARModule', 'fSaturatedGrowthVolume',      '-', 'Saturated Growth Volume');
            oLog.addValue('Cabin.toChildren.Photobioreactor.toChildren.ChlorellaInMedia.oPARModule', 'fLinearGrowthVolume',         '-', 'Linear Growth Volume');
            
            oLog.addValue('Cabin.toChildren.Photobioreactor.toChildren.ChlorellaInMedia.oPARModule', 'fExitPPFD',                   '-', 'PPFD Exiting the PBR');
            oLog.addValue('Cabin.toChildren.Photobioreactor.toChildren.ChlorellaInMedia.oPARModule', 'fTotalAbsorbedPPFD',          '-', 'PPFD Absorbed in the PBR');
            oLog.addValue('Cabin.toChildren.Photobioreactor.toChildren.ChlorellaInMedia.oPARModule', 'fPhotonsForPhotosynthesis',   '-', 'PPFD used for PS');
            oLog.addValue('Cabin.toChildren.Photobioreactor.toChildren.ChlorellaInMedia.oPARModule', 'fPPFDtoHeat',                 '-', 'PPFD transformed to heat');
            oLog.addValue('Cabin.toChildren.Photobioreactor.toChildren.ChlorellaInMedia.oPARModule', 'fHeatPower',                  'W', 'Heat generated from absorbed Photons');
            oLog.addValue('Cabin.toChildren.Photobioreactor.toChildren.ChlorellaInMedia.oPARModule', 'fHeatFlux',                   '-', 'Heat Flux generated from absorbed Photons');
            
            %% algae module
            oLog.addValue('Cabin.toChildren.Photobioreactor.toChildren.ChlorellaInMedia.toStores.GrowthChamber.toPhases.GrowthMedium.toManips.substance.oChemicalReactions', 'fCurrentTotalEDTA',               'kg/m^3', 'Total EDTA Concentration');
            oLog.addValue('Cabin.toChildren.Photobioreactor.toChildren.ChlorellaInMedia.toStores.GrowthChamber.toPhases.GrowthMedium.toManips.substance.oChemicalReactions', 'fCurrentTotalInorganicCarbon',    'kg/m^3', 'Total Carbon Concentration');
            oLog.addValue('Cabin.toChildren.Photobioreactor.toChildren.ChlorellaInMedia.toStores.GrowthChamber.toPhases.GrowthMedium.toManips.substance.oChemicalReactions', 'fCurrentTotalPhosphate',          'kg/m^3', 'Total Phosphate Concentration');
            oLog.addValue('Cabin.toChildren.Photobioreactor.toChildren.ChlorellaInMedia.toStores.GrowthChamber.toPhases.GrowthMedium.toManips.substance.oChemicalReactions', 'fCurrentCalculatedHplus',         'kg/m^3', 'Calculated H+ Concentration');
            oLog.addValue('Cabin.toChildren.Photobioreactor.toChildren.ChlorellaInMedia.toStores.GrowthChamber.toPhases.GrowthMedium.toManips.substance.oChemicalReactions', 'fCurrentCalculatedPH',            '-', 'Calculated PH');
            
        end
        
        function plot(this, varargin) % Plotting the results
            %% Define Plots
            
            close all
            
            oPlotter = plot@simulation.infrastructure(this);
            
            % Tries to load stored data from the hard drive if that option
            % was activated (see ttMonitorConfig). Otherwise it only
            % displays that no data was found
            try
                this.toMonitors.oLogger.readDataFromMat;
            catch
                disp('no data outputted yet')
            end
            
            %% plot options with custom labels for what is not available in V-HAB
            tPlotOptions.sTimeUnit = 'days';
            % Biomass Concentration instead of density
            tPlotOptions1 = struct('sYLabel', 'Concentration [kg/m^3]');
            tPlotOptions1.sTimeUnit = 'days';
            %biomass concentration increase rate
            tPlotOptions2 = struct('sYLabel', 'Concentration Increase Rate [kg/(m^3*s)]');  
            tPlotOptions2.sTimeUnit = 'days';
            % Growth Rate instead of flow rate
            tPlotOptions3 = struct('sYLabel', 'Growth Rate [kg/s]');
            tPlotOptions3.sTimeUnit = 'days';
            %Relative Growth Rate
            tPlotOptions4 = struct('sYLabel', 'Relative Growth Rate [µ/µ_o_p_t]');
            tPlotOptions4.sTimeUnit = 'days';
            %Attenuation Coefficient
            tPlotOptions5 = struct('sYLabel', 'Attenuation Coefficient [1/m]');
            tPlotOptions5.sTimeUnit = 'days';
            %Photosynthetic Photon Flux Density
            tPlotOptions6 = struct('sYLabel', 'PPFD [µmol/m^2*s]');
            tPlotOptions6.sTimeUnit = 'days';
            %Heat Flux
            tPlotOptions7 = struct('sYLabel', 'Heat Flux [W/m^2]');
            tPlotOptions7.sTimeUnit = 'days';
            %Distance
            tPlotOptions8 = struct('sYLabel', 'Distance [m]');
            tPlotOptions8.sTimeUnit = 'days';
            %Volume
            tPlotOptions9 = struct('sYLabel', 'Volume [m^3]');
            tPlotOptions9.sTimeUnit = 'days';
            
  
            %% human in cabin plots
            csStores = fieldnames(this.oSimulationContainer.toChildren.Cabin.toStores);
            csMasses = cell(length(csStores),1);
            csPressures = cell(length(csStores),1);
            csTemperatures = cell(length(csStores),1);
            for iStore = 1:length(csStores)
                csMasses{iStore} = ['"', csStores{iStore}, ' Mass"'];
                csPressures{iStore} = ['"', csStores{iStore}, ' Pressure"'];
                csTemperatures{iStore} = ['"', csStores{iStore}, ' Temperature"'];
            end
            
            csBranches = fieldnames(this.oSimulationContainer.toChildren.Cabin.toBranches);
            csFlowRates = cell(length(csBranches),1);
            for iBranch = 1:length(csBranches)
                csFlowRates{iBranch} = ['"', csBranches{iBranch}, ' Flowrate"'];
            end
            
            
            csStoresHuman_1 = fieldnames(this.oSimulationContainer.toChildren.Cabin.toChildren.Human_1.toStores);
            csMassesHuman_1 = cell(length(csStoresHuman_1),1);
            csPressuresHuman_1 = cell(length(csStoresHuman_1),1);
            csTemperaturesHuman_1 = cell(length(csStoresHuman_1),1);
            iIndex = 1;
            for iStore = 1:length(csStoresHuman_1)
                csPhases = fieldnames(this.oSimulationContainer.toChildren.Cabin.toChildren.Human_1.toStores.(csStoresHuman_1{iStore}).toPhases);
                for iPhase = 1:length(csPhases)
                    csMassesHuman_1{iIndex}         = ['"', csStoresHuman_1{iStore}, ' ', csPhases{iPhase}, ' Mass"'];
                    csPressuresHuman_1{iIndex}      = ['"', csStoresHuman_1{iStore}, ' ', csPhases{iPhase}, ' Pressure"'];
                    csTemperaturesHuman_1{iIndex}   = ['"', csStoresHuman_1{iStore}, ' ', csPhases{iPhase}, ' Temperature"'];
                    iIndex = iIndex + 1;
                end
            end
            
            csBranchesHuman_1 = fieldnames(this.oSimulationContainer.toChildren.Cabin.toChildren.Human_1.toBranches);
            csFlowRatesHuman_1 = cell(length(csBranchesHuman_1),1);
            for iBranch = 1:length(csBranchesHuman_1)
                csFlowRatesHuman_1{iBranch} = ['"', csBranchesHuman_1{iBranch}, ' Flowrate"'];
            end
            
          %  tPlotOptions.sTimeUnit = 'seconds';
            tFigureOptions = struct('bTimePlot', false, 'bPlotTools', false);
            
            coPlots{1,1} = oPlotter.definePlot({csPressures{:}, csPressuresHuman_1{:}},     'Pressures', tPlotOptions);
            coPlots{2,1} = oPlotter.definePlot({csFlowRates{:}, csFlowRatesHuman_1{:}},     'Flow Rates', tPlotOptions);
            coPlots{1,2} = oPlotter.definePlot({csTemperatures{:}, csTemperaturesHuman_1{:}},  'Temperatures', tPlotOptions);
            %            coPlots{2,2} = oPlotter.definePlot({csMasses{:}, csMassesHuman_1{:}},  'Masses', tPlotOptions);
            oPlotter.defineFigure(coPlots,  'Plots', tFigureOptions);
            
            csHumansPhaseMassses = {'"Internal O_2 Mass"', '"Internal CO_2 Mass"', '"Internal H_2O Mass"', '"Internal Protein Mass"',  '"Internal Fat Mass"',...
                '"Internal Carbohydrate Mass"', '"Internal Feces Solid Mass"', '"Internal Urine Solid Mass"'};
            
            coPlots{1,1} = oPlotter.definePlot(csHumansPhaseMassses,     'Internal Human Masses', tPlotOptions);
            coPlots{2,1} = oPlotter.definePlot({'"Current Energy Demand"'},     'Energy Demand', tPlotOptions);
            coPlots{1,2} = oPlotter.definePlot({'"Oxygen Consumption"', '"CO_2 Production"'},  'Oxygen and CO2 flowrates', tPlotOptions);
            coPlots{2,2} = oPlotter.definePlot({'"Respiratory Coefficient"'},  'Respiratory Coefficient', tPlotOptions);
            oPlotter.defineFigure(coPlots,  'Human Model Plots', tFigureOptions);
            
            csFoodConversionFlows = {'"Food Conversion H2O Flowrate"', '"Food Conversion Fat Flowrate"', '"Food Conversion Protein Flowrate"',...
                '"Food Conversion Carbohydrates Flowrate"', '"Food Conversion Ash Flowrate"'};
            
            coPlots = {};
            coPlots{1,1} = oPlotter.definePlot(csFoodConversionFlows,           'Food Flows', tPlotOptions);
            coPlots{2,1} = oPlotter.definePlot({'"Human HumanPhase Mass"'},     'Human Phase Mass', tPlotOptions);
            coPlots{1,2} = oPlotter.definePlot({'"Human Stomach Mass"'},        'Stomach Phase Mass', tPlotOptions);
            
            oPlotter.defineFigure(coPlots,  'Food Plots', tFigureOptions);
            
            
            CabinImportant{1,1}= oPlotter.definePlot({'"Cabin Partial Pressure of O2"'}, 'Cabin Partial Pressure of O2', tPlotOptions);
            CabinImportant{2,1}= oPlotter.definePlot({'"Cabin Partial Pressure of CO2"'}, 'Cabin Partial Pressure of CO2', tPlotOptions);
            
            oPlotter.defineFigure(CabinImportant, 'Cabin Atmosphere');
            %% algae
            
            % cc Plot
            %growth medium values
            gmPlot{1,1}=oPlotter.definePlot({'"Medium Temperature"'}, 'Medium Temperature', tPlotOptions);
            gmPlot{1,2}=oPlotter.definePlot({'"pH of Growth Medium"'}, 'pH of Growth Medium', tPlotOptions);
            gmPlot{2,1}=oPlotter.definePlot({'"Mass of Water"'}, 'Mass of Water', tPlotOptions);
            gmPlot{2,2}=oPlotter.definePlot({'"Mass of dissolved NO3"'}, 'Mass of dissolved NO3', tPlotOptions);
            gmPlot{2,3}=oPlotter.definePlot({'"Mass of Chlorella"'}, 'Mass of Chlorella', tPlotOptions);
            
            % growth
            grPlot{1,1}=oPlotter.definePlot({'"Biomass Concentration"'}, 'Biomass Concentration', tPlotOptions1);
            grPlot{2,1}=oPlotter.definePlot({'"Theoretical Biomass Concentration Increase"'}, 'Theoretical Biomass Concentration Increase', tPlotOptions2);
            grPlot{1,2}=oPlotter.definePlot({'"Theoretical Biomass Growth Rate"'}, 'Theoretical Biomass Growth Rate', tPlotOptions3);
            grPlot{2,2}=oPlotter.definePlot({'"Achievable Biomass Growth Rate"'}, 'Achievable Biomass Growth Rate', tPlotOptions3);
            grPlot{3,2}=oPlotter.definePlot({'"Actual Biomass Growth Rate"'}, 'Actual Biomass Growth Rate', tPlotOptions3);
            
             %time controlled theoretical values
            tgrPlot{1,1}=oPlotter.definePlot({'"Reference Biomass Concentration"'}, 'Reference Biomass Concentration', tPlotOptions1);
            tgrPlot{2,1}=oPlotter.definePlot({'"Reference Biomass Concentration Increase"'}, 'Reference Biomass Concentration Increase', tPlotOptions2);
           
           % Relative Growth rate plots
            gfPlot{1,1} =  oPlotter.definePlot({'"PAR Influence Relative Growth"'}, 'PAR Influence Relative Growth', tPlotOptions4);
            gfPlot{1,2} =  oPlotter.definePlot({'"O2 Concentration Relative Growth"'}, 'O2 Concentration Relative Growth', tPlotOptions4);
           % gfPlot{1,4} =  oPlotter.definePlot({'"CO2 Concentration Growth
           % Factor"'}, 'CO2 Concentration Growth Factor', tPlotOptions);
           % %Error description See where this value is added.
            gfPlot{1,3} =  oPlotter.definePlot({'"PH Influence Relative Growth"'}, 'PH Influence Relative Growth', tPlotOptions4);
            gfPlot{2,1} =  oPlotter.definePlot({'"Temperature Influence Relative Growth"'}, 'Temperature Influence Relative Growth', tPlotOptions4);
            gfPlot{2,2} =  oPlotter.definePlot({'"CO2 Availability Factor in Medium"'}, 'CO2 Availability Factor in Medium', tPlotOptions);
            gfPlot{2,3} =  oPlotter.definePlot({'"Nitrogen Availability Factor in Medium"'}, 'Nitrogen Availability Factor in Medium', tPlotOptions);
            
            
            %Assimilation Coefficient
            acPlot{1,1} =  oPlotter.definePlot({'"Assimilation Coefficient of Algal Culture"'}, 'Assimilation Coefficient of Algal Culture', tPlotOptions);
            
            % Atmospheric exchange
            aePlot{1,1}=oPlotter.definePlot({'"CO2 Partial Pressure in Growth Chamber"'}, 'CO2 Partial Pressure in Growth Chamber', tPlotOptions);
            aePlot{1,2}=oPlotter.definePlot({'"O2 Partial Pressure in Growth Chamber"'}, 'O2 Partial Pressure in Growth Chamber', tPlotOptions);
            aePlot{2,1}=oPlotter.definePlot({'"Mass of dissolved CO2"'}, 'Mass of dissolved CO2', tPlotOptions);
            aePlot{2,2}=oPlotter.definePlot({'"Mass of dissolved O2"'}, 'Mass of dissolved O2', tPlotOptions);
            aePlot{3,1} =  oPlotter.definePlot({'"CO2 Membrane Transport Factor"'}, 'CO2 Membrane Transport Factor', tPlotOptions);
            aePlot{3,2} =  oPlotter.definePlot({'"O2 Membrane Transport Factor"'}, 'O2 Membrane Transport Factor', tPlotOptions);

            
            %in outputs of PBR
            ioPlot{1,1} = oPlotter.definePlot({'"Total Carbon Dioxide Assimilation"'}, 'Total Carbon Dioxide Assimilation', tPlotOptions);
            ioPlot{1,2} = oPlotter.definePlot({'"Total Oxygen Evolution"'}, 'Total Oxygen Evolution', tPlotOptions);
            ioPlot{2,1} = oPlotter.definePlot({'"Total Amount of Processed Urine"'}, 'Total Amount of Processed Urine', tPlotOptions);
            ioPlot{2,2} = oPlotter.definePlot({'"Total Amount of Produced Water"'}, 'Total Amount of Produced Water', tPlotOptions);
            
            
            % PAR module plot    
            pmPlot{1,1} = oPlotter.definePlot({'"Attenuation Coefficient"'}, 'Attenuation Coefficient', tPlotOptions5);
            pmPlot{1,2} = oPlotter.definePlot({'"PPFD Exiting the PBR"','"PPFD Absorbed in the PBR"','"PPFD used for PS"','"PPFD transformed to heat"'}, 'PPFD Values', tPlotOptions6);
            pmPlot{1,3} = oPlotter.definePlot({'"Position of Minimum PPFD"','"Position of Saturated PPFD"','"Position of Inhibited PPFD"'}, 'Total Light Boundary Positions', tPlotOptions8);
            pmPlot{2,1} = oPlotter.definePlot({'"No Growth Volume"','"Saturated Growth Volume"','"Linear Growth Volume"'}, 'Growth Volume Sizes', tPlotOptions9);    
            pmPlot{2,2} = oPlotter.definePlot({'"Average PPFD in Linear Growth Volume"'}, 'Average PPFD in Linear Growth Volume', tPlotOptions6);    
            pmPlot{2,3} = oPlotter.definePlot({'"Heat Flux generated from absorbed Photons"'}, 'Heat Flux generated from absorbed Photon', tPlotOptions7);
            pmPlot{3,1} = oPlotter.definePlot({'"Heat generated from absorbed Photons"'}, 'Heat generated from absorbed Photons', tPlotOptions);
          	pmPlot{3,2} = oPlotter.definePlot({'"Power Saving Surface PPFD"'}, 'Power Saving Surface PPFD', tPlotOptions6);
            pmPlot{3,3} = oPlotter.definePlot({'"Power Saving Potential with Dynamic PAR Control"'}, 'Power Saving Potential with Dynamic PAR Control', tPlotOptions);
            
            % masses of whole system
            pmPlot{1,1}=oPlotter.definePlot({'"Cabin System Potable Water Storage Store Potable Water Phase"'}, 'Cabin System Potable Water Storage Store Potable Water Phase', tPlotOptions);
            pmPlot{1,2}=oPlotter.definePlot({'"Cabin System Urine Storage Store urine Phase"'}, 'Cabin System Urine Storage Store urine Phase', tPlotOptions);
            pmPlot{1,3}=oPlotter.definePlot({'"Cabin System Food Storage Store Food Phase"'}, 'Cabin System Food Storage Store Food Phase', tPlotOptions);
            pmPlot{2,1}=oPlotter.definePlot({'"PBR System Medium Maintenance Store NO3 Supply Phase"'}, 'PBR System Medium Maintenance Store NO3 Supply Phase', tPlotOptions);
            pmPlot{2,2}=oPlotter.definePlot({'"PBR System Medium Maintenance Store Water Supply Phase"'}, 'PBR System Medium Maintenance Store Water Supply Phase', tPlotOptions);             
            pmPlot{2,3}=oPlotter.definePlot({'"PBR System Harvester Store Chlorella Harvest Phase"'}, 'PBR System Harvester Store Chlorella Harvest Phase', tPlotOptions);

 
            % plotter functions
            oPlotter.defineFigure(pmPlot, 'Phase Masses');
            oPlotter.defineFigure(gmPlot, 'Growth Medium Values');
            oPlotter.defineFigure(grPlot, 'Growth Rate Values');
            oPlotter.defineFigure(tgrPlot, 'Time Controlled Reference Growth Rate Values');
            oPlotter.defineFigure(pmPlot, 'PAR Module Parameters');
            oPlotter.defineFigure(gfPlot, 'Growth Influence Values');
            oPlotter.defineFigure(ioPlot, 'Total Produced and Consumed Masses');
            oPlotter.defineFigure(acPlot, 'Algal Assimilation Coefficient');
            oPlotter.defineFigure(aePlot, 'Atmospheric Exchange Values');
            
            
            mPlot = [];
            mPlot{1,1} = oPlotter.definePlot({'"Total EDTA Concentration"', '"Total Carbon Concentration"', '"Total Phosphate Concentration"', '"Calculated H+ Concentration"', '"Calculated PH"'}, 'Growth Medium Concentrations', tPlotOptions);
            oPlotter.defineFigure(mPlot, 'Growht Medium Concentrations');
            
            %% CCAA
            tPlotOptions.sTimeUnit = 'hours';
            tFigureOptions = struct('bTimePlot', true, 'bPlotTools', false);
            
            %            coPlots{1,1} = oPlotter.definePlot({'"Temperature Cabin"'},        'Temperature', tPlotOptions);
            coPlots{1,2} = oPlotter.definePlot({'"Relative Humidity Cabin"'},   'Relative Humidity', tPlotOptions);
            coPlots{2,2} = oPlotter.definePlot({'"CCAA Condensate Heat Flow"', '"CCAA Total Heat Flow"'},   'CCAA Heat Flows', tPlotOptions);
            coPlots{2,1} = oPlotter.definePlot({'"CCAA Condensate Flow Rate"'},'CCAA Condensate Flow Rate', tPlotOptions);
            oPlotter.defineFigure(coPlots,  'CCAA Plots', tFigureOptions);%             

            oPlotter.plot();
        end
        
    end
    
end