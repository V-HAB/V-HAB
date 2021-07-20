classdef setup < simulation.infrastructure
    % setup file for the Greenhouse system
    
    properties
        tmCultureParametersValues = struct();
        tiCultureParametersIndex = struct();
    end
    
    methods
        function this = setup(ptConfigParams, tSolverParams, ttMonitorConfig, fSimTime)
            
            % call superconstructor (with possible altered monitor configs)
            this@simulation.infrastructure('Test_Greenhouse', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            % Create Root Object - Initializing system 'Greenhouse'
            examples.Greenhouse.systems.Greenhouse(this.oSimulationContainer, 'Greenhouse');
            
            % set simulation time
            if nargin < 4 || isempty(fSimTime)
                this.fSimTime = 10e6; % [s]
            else 
                this.fSimTime = fSimTime;
            end
        end
        
        function configureMonitors(this)
            %% Logging Setup
            oLogger = this.toMonitors.oLogger;
            
            % Find the plant cultures to log
            csCultures = {};
            oGreenhouse = this.oSimulationContainer.toChildren.Greenhouse;
            for iChild = 1:length(this.oSimulationContainer.toChildren.Greenhouse.csChildren)
                % culture object gets assigned using its culture name 
                if isa(oGreenhouse.toChildren.(oGreenhouse.csChildren{iChild}), 'components.matter.PlantModule.PlantCulture')
                    csCultures{length(csCultures)+1} = oGreenhouse.csChildren{iChild};
                end
            end
            
            oLogger.addValue('Greenhouse.oTimer',	'fTimeStepFinal',	's',   'Timestep');
            
            % log culture subsystems
            for iI = 1:length(csCultures)                
                % Balance Mass
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}, ':s:Plant_Culture.toPhases.Balance'], 'fMass', 'kg', [csCultures{iI}, ' Balance Mass']);
                
                % Plant Mass
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}, ':s:Plant_Culture.toPhases.Plants'], 'fMass', 'kg', [csCultures{iI}, ' Plant Mass']);
                
                % Plant  Nutrient Masses
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}, ':s:Plant_Culture.toPhases.NutrientSolution'], 'fMass', 'kg', [csCultures{iI}, ' Nutrient Solution Mass']);
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}, ':s:Plant_Culture.toPhases.StorageNitrate'],   'fMass', 'kg', [csCultures{iI}, ' Nitrogen Storage Mass']);
                % Plant Atmosphere Mass
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}, ':s:Plant_Culture.toPhases.PlantAtmosphere'], 'fMass', 'kg', [csCultures{iI}, ' Plant Atmosphere Mass']);
                
                % p2p flowrates
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}, ':s:Plant_Culture.toProcsP2P.BiomassGrowth_P2P'], 'fFlowRate', 'kg/s', [csCultures{iI}, ' BiomassGrowth']);
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}, '.toBranches.Atmosphere_In.aoFlows(1)'], 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2) * -1', 'kg/s', [csCultures{iI}, ' CO2 In Flow']);
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}, '.toBranches.Atmosphere_In.aoFlows(1)'], 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.O2)  * -1', 'kg/s', [csCultures{iI},  ' O2 In Flow']);
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}, '.toBranches.Atmosphere_In.aoFlows(1)'], 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O) * -1', 'kg/s', [csCultures{iI}, ' H2O In Flow']);
                
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}, '.toBranches.Atmosphere_Out.aoFlows(1)'], 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)', 'kg/s', [csCultures{iI}, ' CO2 Out Flow']);
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}, '.toBranches.Atmosphere_Out.aoFlows(1)'], 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.O2)', 'kg/s', [csCultures{iI},  ' O2 Out Flow']);
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}, '.toBranches.Atmosphere_Out.aoFlows(1)'], 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)', 'kg/s', [csCultures{iI}, ' H2O Out Flow']);
                
                oLogger.addVirtualValue(['"', csCultures{iI}, ' CO2 In Flow" - "', csCultures{iI}, ' CO2 Out Flow"'], 'kg/s', [csCultures{iI}, ' Atmosphere CO_2 Flow Rate']);
                oLogger.addVirtualValue(['"', csCultures{iI}, ' O2 In Flow" - "', csCultures{iI}, ' O2 Out Flow"'], 'kg/s',   [csCultures{iI}, ' Atmosphere O_2 Flow Rate']);
                oLogger.addVirtualValue(['"', csCultures{iI}, ' H2O In Flow" - "', csCultures{iI}, ' H2O Out Flow"'], 'kg/s', [csCultures{iI}, ' Atmosphere H_2O Flow Rate']);
                    
                %% MMEC Rates and according flow rates
                
                % MMEC rates
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}], 'this.tfMMECRates.fWC     * this.txInput.fGrowthArea', 'kg/s)', [csCultures{iI}, ' MMEC WC']);
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}], 'this.tfMMECRates.fTR     * this.txInput.fGrowthArea', 'kg/s', [csCultures{iI}, ' MMEC TR']);
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}], 'this.tfMMECRates.fOC     * this.txInput.fGrowthArea', 'kg/s', [csCultures{iI}, ' MMEC OC']);
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}], 'this.tfMMECRates.fOP     * this.txInput.fGrowthArea', 'kg/s', [csCultures{iI}, ' MMEC OP']);
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}], 'this.tfMMECRates.fCO2C   * this.txInput.fGrowthArea', 'kg/s', [csCultures{iI}, ' MMEC CO2C']);
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}], 'this.tfMMECRates.fCO2P   * this.txInput.fGrowthArea', 'kg/s', [csCultures{iI}, ' MMEC CO2P']);
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}], 'this.tfMMECRates.fNC     * this.txInput.fGrowthArea', 'kg/s', [csCultures{iI}, ' MMEC NC']);
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}], 'this.tfMMECRates.fCGR    * this.txInput.fGrowthArea', 'kg/s', [csCultures{iI}, ' MMEC CGR']);
                
                % flow rates
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}], 'this.tfGasExchangeRates.fO2ExchangeRate',                                          'kg/s', [csCultures{iI}, ' FlowRate O2']);
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}], 'this.tfGasExchangeRates.fCO2ExchangeRate',                                         'kg/s', [csCultures{iI}, ' FlowRate CO2']);
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}], 'this.tfGasExchangeRates.fTranspirationRate',                                      	'kg/s', [csCultures{iI}, ' FlowRate H2O']);
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}], 'this.fNutrientConsumptionRate',                                                    'kg/s', [csCultures{iI}, ' FlowRate Nutrients']);
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}], 'this.tfBiomassGrowthRates.fGrowthRateEdible',                                      'kg/s', [csCultures{iI}, ' FlowRate Edible']);
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}], 'this.tfBiomassGrowthRates.fGrowthRateInedible',                                    'kg/s', [csCultures{iI}, ' FlowRate Inedible']);
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}, ':s:Plant_Culture.toProcsP2P.Nitrate_from_NutrientSupply_to_Storage'], 'fFlowRate',  'kg/s', [csCultures{iI}, ' Storage Uptake Rate']);
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}, ':s:Plant_Culture.toProcsP2P.Nitrate_from_Storage_to_Structure'], 'fFlowRate',       'kg/s', [csCultures{iI}, ' Structure Uptake Rate']);
                
                oLogger.addVirtualValue(['cumsum( ( "', csCultures{iI}, ' CO2 In Flow" - "', csCultures{iI}, ' CO2 Out Flow" ) .* "Timestep")'], 'kg', [csCultures{iI}, ' Cumulative Atmosphere CO_2 Flow Rate']);
                oLogger.addVirtualValue(['cumsum( ( "', csCultures{iI}, ' O2 In Flow" - "', csCultures{iI}, ' O2 Out Flow"   ) .* "Timestep")'], 'kg', [csCultures{iI}, ' Cumulative Atmosphere O_2 Flow Rate']);
                oLogger.addVirtualValue(['cumsum( ( "', csCultures{iI}, ' H2O In Flow" - "', csCultures{iI}, ' H2O Out Flow" ) .* "Timestep")'], 'kg', [csCultures{iI}, ' Cumulative Atmosphere H_2O Flow Rate']);
                oLogger.addVirtualValue(['cumsum(   "', csCultures{iI}, ' FlowRate Edible"                                     .* "Timestep")'], 'kg', [csCultures{iI}, ' Cumulative Edible Flow Rate']);
                oLogger.addVirtualValue(['cumsum(   "', csCultures{iI}, ' FlowRate Inedible"                                   .* "Timestep")'], 'kg', [csCultures{iI}, ' Cumulative Inedible Flow Rate']);
            
                % Additional values for the nutrients
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}], 'this.fYieldTreshhold', '-', [csCultures{iI}, ' Equivalent Yield']);
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}], 'this.oPlantYield_equivalent', '-', [csCultures{iI}, ' Plant Yield']);
                % oLogger.addValue(['Greenhouse:c:', csCultures{iI}], 'this.fYieldTreshhold', 'kg/s', [csCultures{iI}, ' MMEC CGR']);
                
            end
            
            oLogger.addValue('Greenhouse', 'fCO2', 'ppm', 'CO2 Concentration');
            
            % greenhouse atmosphere composition
            oLogger.addValue('Greenhouse:s:Atmosphere.toPhases.Atmosphere', 'fPressure', 'Pa', 'Total Pressure');
            oLogger.addValue('Greenhouse:s:Atmosphere.toPhases.Atmosphere', 'afPP(this.oMT.tiN2I.O2)', 'Pa', 'O2 Partial Pressure');
            oLogger.addValue('Greenhouse:s:Atmosphere.toPhases.Atmosphere', 'afPP(this.oMT.tiN2I.CO2)', 'Pa', 'CO2 Partial Pressure');
            oLogger.addValue('Greenhouse:s:Atmosphere.toPhases.Atmosphere', 'afPP(this.oMT.tiN2I.N2)', 'Pa', 'N2 Partial Pressure');
            oLogger.addValue('Greenhouse:s:Atmosphere.toPhases.Atmosphere', 'rRelHumidity', '-', 'Humidity');
            oLogger.addValue('Greenhouse:s:NutrientSupply.toPhases.NutrientSupply', 'this.afMass(this.oMT.tiN2I.NO3) / this.oMT.afMolarMass(this.oMT.tiN2I.NO3) / this.afMass(this.oMT.tiN2I.H2O) / 1000', '-', 'NO3 Concentration');
            
            oLogger.addValue('Greenhouse:s:NutrientSupply.toPhases.NutrientSupply', 'this.afMass(this.oMT.tiN2I.NO3) ', 'kg', 'NO3 Mass');
            
            
        end
        
        function plot(this)
            
            %% Define Plots
            
            close all
           
            oPlotter = plot@simulation.infrastructure(this);
            
            tPlotOptions.sTimeUnit = 'days';
            tFigureOptions = struct('bTimePlot', false, 'bPlotTools', false);
            
            % Find the plant cultures to log
            csCultures = {};
            oGreenhouse = this.oSimulationContainer.toChildren.Greenhouse;
            for iChild = 1:length(this.oSimulationContainer.toChildren.Greenhouse.csChildren)
                % culture object gets assigned using its culture name 
                if isa(oGreenhouse.toChildren.(oGreenhouse.csChildren{iChild}), 'components.matter.PlantModule.PlantCulture')
                    csCultures{length(csCultures)+1} = oGreenhouse.csChildren{iChild};
                end
            end
            
            cBalanceNames = cell(1,length(csCultures));
            cPlantNames = cell(1,length(csCultures));
            cNutrientSupplyNames = cell(1,length(csCultures));
            cYieldNames = cell(1,length(csCultures));
            cPlantYieldNames = cell(1,length(csCultures));
            
            coPlots_P2P = cell(1,length(csCultures));
            coPlots_PlantFlowRates = cell(1,length(csCultures));
            coPlots_PlantNutrients = cell(1,length(csCultures));
            coPlots_NutrientsFlowRates = cell(1,length(csCultures));
            
            
            for iCulture = 1:length(csCultures)
                cNames = {['"', csCultures{iCulture}, ' BiomassGrowth"'],...
                          ['"', csCultures{iCulture}, ' Atmosphere CO_2 Flow Rate"'],...
                          ['"', csCultures{iCulture}, ' Atmosphere O_2 Flow Rate"'],...
                          ['"', csCultures{iCulture}, ' Atmosphere H_2O Flow Rate"']};
                 
                coPlots_P2P{iCulture} = oPlotter.definePlot(cNames, ['P2P Flow Rates ', csCultures{iCulture}], tPlotOptions);
                
                cNames = {['"', csCultures{iCulture}, ' FlowRate O2"'], ['"', csCultures{iCulture}, ' FlowRate CO2"'], ['"', csCultures{iCulture}, ' FlowRate H2O"'],...
                          ['"', csCultures{iCulture}, ' FlowRate Edible"'], ['"', csCultures{iCulture}, ' FlowRate Inedible"']};
                
                coPlots_PlantFlowRates{iCulture} = oPlotter.definePlot(cNames,      ['Plant Module Flow Rates ', csCultures{iCulture}], tPlotOptions);
                
                
                % Plots for nutrient masses
                cNames = {['"', csCultures{iCulture}, ' Nitrogen Storage Mass"']};
                      
                coPlots_PlantNutrients{iCulture} = oPlotter.definePlot(cNames, ['Plant Nutrient Masses', csCultures{iCulture}], tPlotOptions);
                
                % Plots for nutrient flow rates
                cNames = {['"', csCultures{iCulture}, ' Storage Uptake Rate"'], ['"', csCultures{iCulture}, ' Structure Uptake Rate"']};
                      
                coPlots_NutrientsFlowRates{iCulture} = oPlotter.definePlot(cNames, ['Plant Nutrient Flow Rates', csCultures{iCulture}], tPlotOptions);
                
                cBalanceNames{iCulture}   = ['"', csCultures{iCulture}, ' Balance Mass"'];
                cPlantNames{iCulture}     = ['"', csCultures{iCulture}, ' Plant Mass"'];
                cNutrientSupplyNames{iCulture} = ['"', csCultures{iCulture}, ' Nutrient Solution Mass"'];
                cYieldNames{iCulture}   = ['"', csCultures{iCulture}, ' Equivalent Yield"'];
                cPlantYieldNames{iCulture} = ['"', csCultures{iCulture}, ' Plant Yield"'];
            end
           
            oPlotter.defineFigure({coPlots_P2P{:}; coPlots_PlantFlowRates{:}}, 'Plant Module Flow Rates ', tFigureOptions);
            oPlotter.defineFigure({coPlots_PlantNutrients{:}; coPlots_NutrientsFlowRates{:}}, 'Plant Module Nutrition ', tFigureOptions);

            coPlots{1,1} = oPlotter.definePlot(cBalanceNames, 'Balance Mass in Cultures', tPlotOptions);
            coPlots{1,2} = oPlotter.definePlot(cPlantNames,   'Plant Mass in Cultures', tPlotOptions);
            coPlots{1,3} = oPlotter.definePlot(cNutrientSupplyNames,   'Nutrition Mass in Cultures', tPlotOptions);
            
            coPlots{2,1} = oPlotter.definePlot({'"Total Pressure"', '"N2 Partial Pressure"', '"O2 Partial Pressure"', '"CO2 Partial Pressure"', '"CO2 Concentration"'},'Atmosphere Pressures');
            coPlots{2,2} = oPlotter.definePlot({'"Humidity"'},'Humidity');
            
            oPlotter.defineFigure(coPlots,  'Masses, CO2 Concentration, Humidity', tFigureOptions);
            
            coNutri_Plots{1,1} = oPlotter.definePlot(cYieldNames, 'Plant Yield', tPlotOptions);
            coNutri_Plots{1,2} = oPlotter.definePlot(cPlantYieldNames, 'Treshold Yield', tPlotOptions);
            coNutri_Plots{2,1} = oPlotter.definePlot({'"NO3 Concentration"'}, 'NO3 Concentration', tPlotOptions);
            
            
            oPlotter.defineFigure(coNutri_Plots,  'Nutritional Parameters', tFigureOptions);
            
            oPlotter.plot();
            
            %% Plant verification
            % Data from BVAD:
            csPlantNames                  = {'Cabbage', 'Carrot', 'Chard', 'Celery', 'Dry Bean', 'Green Onion', 'Lettuce', 'Onion', 'Pea', 'Peanut', 'Pepper', 'Radish', 'Red Beet', 'Rice', 'Snap Bean', 'Soybean', 'Spinach', 'Strawberry', 'Sweet Potato', 'Tomato', 'Wheat', 'White Potato', 'Chufa', 'Cucumber'};
     
            % Values in percent of dry mass
            mfPlantCarbonContent          = [0.4, 0.41, 0.4, 0.4, 0.4, 0.4, 0.4, 0.4, 0.4, 0.6, 0.4, 0.4, 0.41, 0.42, 0.4, 0.46, 0.4, 0.43, 0.41, 0.43, 0.42, 0.41, 0.6, 0.4];
            % The following values are in g per m^2 and day except for
            % water uptake which is in kg per m^2 and day 
            mfPlantO2Production           = [7.19, 16.36, 11.49, 12.24, 30.67, 10.67, 7.78, 12, 32.92, 35.84, 24.71, 11.86, 7.11, 36.55, 36.43, 13.91, 7.78, 25.32, 41.12, 26.36, 56, 32.23, 56, 36.43];
            mfPlantCO2Consumption         = [9.88, 22.5, 15.79, 16.83, 42.17, 14.67, 10.7, 16.5, 45.26, 49.28, 33.98, 16.31, 9.77, 50.26, 50.09, 19.13, 10.7, 34.82, 56.54, 36.24, 77, 45.23, 77, 50.09];

            mfPlantWaterUptake            = [1.77, 1.77, 1.77, 1.24, 2.53, 1.74, 1.77, 1.74, 2.46, 2.77, 2.77, 1.77, 1.77, 3.43, 2.46, 2.88, 1.77, 2.22, 2.88, 2.77, 11.79, 4, 11.79, 2.46];
            mfPlantEdibleBiomassGrowth    = [75.78, 74.83, 87.5, 103.27, 11.11, 81.82, 131.35, 81.82, 12.2, 5.96, 148.94, 91.67, 32.5, 10.3, 148.5, 5.04, 72.97, 77.88, 51.72, 173.76, 22.73, 105.3, 8.87, 167.17];
            mfPlantInedibleBiomassGrowth  = [6.74, 59.87, 37.69, 11.47, 150, 10, 7.3, 22.5, 161, 168.75, 127.43, 55, 35, 211.58, 178.2, 68.04, 7.3, 144.46, 225, 127.43, 300, 90.25, 300, 178.2];
    
            tBVADdata = table(mfPlantCarbonContent', mfPlantO2Production', mfPlantCO2Consumption', mfPlantWaterUptake', mfPlantEdibleBiomassGrowth', mfPlantInedibleBiomassGrowth', 'VariableNames', {'CO2_Content', 'O2_Production', 'CO2_Consumption', 'Water_Uptake', 'Edible_Growthrate', 'Inedible_Growthrate'}, 'RowNames', csPlantNames');
            
            oLogger = this.toMonitors.oLogger;
            
            csPlantsInCultures = {'Sweet Potato', 'White Potato', 'Rice', 'Dry Bean', 'Soybean', 'Tomato', 'Peanut', 'Lettuce', 'Wheat', 'Wheat', 'White Potato', 'Soybean'};
            
            fFinalSimTime = oLogger.afTime(end);
            
            
            figure('Name', 'BVAD Validation')
            for iCulture = 1:9
                fO2Production   = table2array(tBVADdata(csPlantsInCultures{iCulture}, 'O2_Production'));
                fCO2Consumption = table2array(tBVADdata(csPlantsInCultures{iCulture}, 'CO2_Consumption'));
                fWaterUptake    = table2array(tBVADdata(csPlantsInCultures{iCulture}, 'Water_Uptake'));
                fEdibleGrowth   = table2array(tBVADdata(csPlantsInCultures{iCulture}, 'Edible_Growthrate'));
                fInedibleGrowth = table2array(tBVADdata(csPlantsInCultures{iCulture}, 'Inedible_Growthrate'));
                
                csLogVariableNames = {'Timestep', [csCultures{iCulture}, ' Cumulative Atmosphere CO_2 Flow Rate'], [csCultures{iCulture}, ' Cumulative Atmosphere O_2 Flow Rate'], [csCultures{iCulture}, ' Cumulative Atmosphere H_2O Flow Rate'], [csCultures{iCulture}, ' FlowRate Edible'], [csCultures{iCulture}, ' FlowRate Inedible']};
                [aiLogIndices, aiVirtualLogIndices] = tools.findLogIndices(oLogger, csLogVariableNames);
                
                afTimeStep 	= oLogger.mfLog(:,aiLogIndices(1));
                afTimeStep(isnan(afTimeStep)) = [];
                afCO2       = oLogger.tVirtualValues(aiVirtualLogIndices(2)).calculationHandle(oLogger.mfLog);
                afO2        = oLogger.tVirtualValues(aiVirtualLogIndices(3)).calculationHandle(oLogger.mfLog);
                afH2O       = oLogger.tVirtualValues(aiVirtualLogIndices(4)).calculationHandle(oLogger.mfLog);
                afEdible	= oLogger.mfLog(:,aiLogIndices(5));
                afInedible	= oLogger.mfLog(:,aiLogIndices(6));
                afCO2(isnan(afCO2)) = [];
                afO2(isnan(afO2)) = [];
                afH2O(isnan(afH2O)) = [];
                afEdible(isnan(afEdible)) = [];
                afInedible(isnan(afInedible)) = [];
                
                afEdible	= cumsum(afEdible .* afTimeStep);
                afInedible	= cumsum(afInedible .* afTimeStep);
                
                % Convert the water to hecto gramm (0.1 kg) for better
                % scaling with the other values:
                afH2O           = 10 .* afH2O;
                fWaterUptake    = 10 .* fWaterUptake;
                
                mfBVAD = [fO2Production, fCO2Consumption, fWaterUptake, fEdibleGrowth, fInedibleGrowth];
                
                fDivisionFactor =  ((fFinalSimTime / 86400) * oGreenhouse.toChildren.(csCultures{iCulture}).txInput.fGrowthArea);
                
                fCO2PerDayAndArea    	=       1000 * afCO2(end)       / fDivisionFactor;
                fO2PerDayAndArea        = -1 .* 1000 * afO2(end)        / fDivisionFactor;
                fH2OPerDayAndArea       = -1 .*        afH2O(end)       / fDivisionFactor;
                fEdiblePerDayAndArea    =       1000 * afEdible(end)    / fDivisionFactor;
                finediblePerDayAndArea  =       1000 * afInedible(end)  / fDivisionFactor;
                
                mfVHAB = [fO2PerDayAndArea, fCO2PerDayAndArea, fH2OPerDayAndArea, fEdiblePerDayAndArea, finediblePerDayAndArea];
                
                subplot(2,5,iCulture)
                scatter(0:4,  mfVHAB)
                hold on
                grid on
                scatter(0:4,  mfBVAD, 'x')
                xticks(0:4)
                xticklabels({'O_2','CO_2','H_2O','Edible','Inedible'})
                xtickangle(90)
                title(csPlantsInCultures{iCulture})
                if iCulture == 1
                    legend('Simulation', 'Test Data')
                    %ylabel('Mass / g/m^2/day except for H_2O which is in kg/day')
                end
            end
            
            csDynamicPlants = {'Soybean', 'Wheat', 'Potato'};
            csCultureEquivalents = {'Soybean_I_1', 'Wheat_I_1', 'Whitepotato_I_1'};
            aiDaiShifter = [-6, 0, 0,];
            
            figure('Name', 'Dynamic Plant Validation')
            for iPlant = 1:length(csDynamicPlants)
                mfTestDays  	= xlsread('user\+examples\+Greenhouse\+TestData\PlantTestData.xlsx', csDynamicPlants{iPlant}, 'B5:B107');
                mfTestCO2      	= xlsread('user\+examples\+Greenhouse\+TestData\PlantTestData.xlsx', csDynamicPlants{iPlant}, 'C5:C107'); %  CO2 in (mumol/m2/s)
                mfTestH2O     	= xlsread('user\+examples\+Greenhouse\+TestData\PlantTestData.xlsx', csDynamicPlants{iPlant}, 'G5:G107'); % (l/m2/day)

                % Shifter of days to aling the simulation and the test data,
                % this is necessary since the simulation starts with sprouting
                % will test data starts with sowing
                mfTestDays = mfTestDays + aiDaiShifter(iPlant);
                fFinalTimeData = mfTestDays(end)*86400;
                abSelectedEntries = oLogger.afTime < fFinalTimeData;

                csLogVariableNames = {['"', csCultureEquivalents{iPlant}, ' Atmosphere CO_2 Flow Rate"'], ['"', csCultureEquivalents{iPlant}, ' Atmosphere O_2 Flow Rate"'], ['"', csCultureEquivalents{iPlant}, ' Atmosphere H_2O Flow Rate"']};
                [~, aiVirtualLogIndices] = tools.findLogIndices(oLogger, csLogVariableNames);

                afCO2       = oLogger.tVirtualValues(aiVirtualLogIndices(1)).calculationHandle(oLogger.mfLog);
                afO2        = oLogger.tVirtualValues(aiVirtualLogIndices(2)).calculationHandle(oLogger.mfLog);
                afH2O       = oLogger.tVirtualValues(aiVirtualLogIndices(3)).calculationHandle(oLogger.mfLog);

                % The units of the test data and the simulation data are not
                % yet equivalent:
                oMT = oGreenhouse.oMT;
                fArea = oGreenhouse.toChildren.(csCultureEquivalents{iPlant}).txInput.fGrowthArea;
                afCO2 = (afCO2 ./ oMT.afMolarMass(oMT.tiN2I.CO2)) * 1e6 / fArea;
                afH2O = (afH2O / 0.99823) * 86400 / fArea;

                afSimTimeDays = oLogger.afTime ./ 86400;

                subplot(2,3,iPlant)
                plot(afSimTimeDays(abSelectedEntries), afCO2(abSelectedEntries))
                hold on
                plot(mfTestDays, mfTestCO2, '+');
                grid on
                xlabel('Time / days')
                ylabel('CO_2 exchange / \mumol/m^2/s')
                title(csDynamicPlants{iPlant})

                if iPlant == 1
                    legend('Simulation', 'Test Data')
                end
                
                subplot(2,3,iPlant + 3)
                plot(afSimTimeDays(abSelectedEntries), -afH2O(abSelectedEntries))
                hold on
                plot(mfTestDays, mfTestH2O, '+');
                % legend('Simulation', 'Test Data')
                grid on
                xlabel('Time / days')
                ylabel('H_2O exchange / l/m^2/day')
                title(csDynamicPlants{iPlant})
            end
        end
    end
end