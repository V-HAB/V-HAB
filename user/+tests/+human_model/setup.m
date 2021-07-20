classdef setup < simulation.infrastructure
    
    properties
    end
    
    methods
        function this = setup(ptConfigParams, tSolverParams, ttMonitorConfig, fSimTime) % Constructor function
            
            if nargin < 3
                ttMonitorConfig = struct();
            end
            this@simulation.infrastructure('Test_Human_Model', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            trBaseCompositionUrine.H2O      = 0.9644;
            trBaseCompositionUrine.C2H6O2N2 = 0.0356;
            this.oSimulationContainer.oMT.defineCompoundMass(this, 'Urine', trBaseCompositionUrine)
            
            trBaseCompositionFeces.H2O          = 0.7576;
            trBaseCompositionFeces.C42H69O13N5  = 0.2424;
            this.oSimulationContainer.oMT.defineCompoundMass(this, 'Feces', trBaseCompositionFeces)
            
            examples.human_model.systems.Example(this.oSimulationContainer, 'Example');
            
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
            
            csStoresHuman_1 = fieldnames(this.oSimulationContainer.toChildren.Example.toChildren.Human_1.toStores);
            
            for iStore = 1:length(csStoresHuman_1)
                csPhases = fieldnames(this.oSimulationContainer.toChildren.Example.toChildren.Human_1.toStores.(csStoresHuman_1{iStore}).toPhases);
                for iPhase = 1:length(csPhases)
                    oLog.addValue(['Example:c:Human_1.toStores.', csStoresHuman_1{iStore}, '.toPhases.', csPhases{iPhase}],	'fMass',        'kg', [csStoresHuman_1{iStore}, ' ', csPhases{iPhase}, ' Mass']);
                    oLog.addValue(['Example:c:Human_1.toStores.', csStoresHuman_1{iStore}, '.toPhases.', csPhases{iPhase}],	'fPressure',	'Pa', [csStoresHuman_1{iStore}, ' ', csPhases{iPhase}, ' Pressure']);
                    oLog.addValue(['Example:c:Human_1.toStores.', csStoresHuman_1{iStore}, '.toPhases.', csPhases{iPhase}],	'fTemperature',	'K',  [csStoresHuman_1{iStore}, ' ', csPhases{iPhase}, ' Temperature']);
                end
            end
            
            csBranchesHuman_1 = fieldnames(this.oSimulationContainer.toChildren.Example.toChildren.Human_1.toBranches);
            for iBranch = 1:length(csBranchesHuman_1)
                oLog.addValue(['Example:c:Human_1.toBranches.', csBranchesHuman_1{iBranch}],             'fFlowRate',    'kg/s', [csBranchesHuman_1{iBranch}, ' Flowrate']);
            end
            
            oLog.addValue('Example:c:Human_1', 'fVO2_current',              '-', 'VO2');
            oLog.addValue('Example:c:Human_1', 'fCurrentEnergyDemand',      'W', 'Current Energy Demand');
            
            oLog.addValue('Example:c:Human_1', 'fOxygenDemand',                 'kg/s', 'Oxygen Consumption');
            oLog.addValue('Example:c:Human_1', 'fCO2Production',                'kg/s', 'CO_2 Production');
            oLog.addValue('Example:c:Human_1', 'fRespiratoryCoefficient',       '-',    'Respiratory Coefficient');
            
            
            oLog.addValue('Example:c:Human_1.toStores.Human.toPhases.HumanPhase', 'this.afMass(this.oMT.tiN2I.O2)',          'kg',    'Internal O_2 Mass');
            oLog.addValue('Example:c:Human_1.toStores.Human.toPhases.HumanPhase', 'this.afMass(this.oMT.tiN2I.CO2)',         'kg',    'Internal CO_2 Mass');
            oLog.addValue('Example:c:Human_1.toStores.Human.toPhases.HumanPhase', 'this.afMass(this.oMT.tiN2I.H2O)',         'kg',    'Internal H_2O Mass');
            oLog.addValue('Example:c:Human_1.toStores.Human.toPhases.HumanPhase', 'this.afMass(this.oMT.tiN2I.C4H5ON)',      'kg',    'Internal Protein Mass');
            oLog.addValue('Example:c:Human_1.toStores.Human.toPhases.HumanPhase', 'this.afMass(this.oMT.tiN2I.C16H32O2)',    'kg',    'Internal Fat Mass');
            oLog.addValue('Example:c:Human_1.toStores.Human.toPhases.HumanPhase', 'this.afMass(this.oMT.tiN2I.C6H12O6)',     'kg',    'Internal Carbohydrate Mass');
            oLog.addValue('Example:c:Human_1.toStores.Human.toPhases.HumanPhase', 'this.afMass(this.oMT.tiN2I.C42H69O13N5)', 'kg',    'Internal Feces Solid Mass');
            oLog.addValue('Example:c:Human_1.toStores.Human.toPhases.HumanPhase', 'this.afMass(this.oMT.tiN2I.C2H6O2N2)',    'kg',    'Internal Urine Solid Mass');
            
            oLog.addValue('Example:c:Human_1.toStores.Human.toProcsP2P.Food_P2P', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',            'kg/s',    'Food Conversion H2O Flowrate');
            oLog.addValue('Example:c:Human_1.toStores.Human.toProcsP2P.Food_P2P', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C16H32O2)',       'kg/s',    'Food Conversion Fat Flowrate');
            oLog.addValue('Example:c:Human_1.toStores.Human.toProcsP2P.Food_P2P', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C4H5ON)',         'kg/s',    'Food Conversion Protein Flowrate');
            oLog.addValue('Example:c:Human_1.toStores.Human.toProcsP2P.Food_P2P', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C6H12O6)',        'kg/s',    'Food Conversion Carbohydrates Flowrate');
            oLog.addValue('Example:c:Human_1.toStores.Human.toProcsP2P.Food_P2P', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C)',              'kg/s',    'Food Conversion Ash Flowrate');
            
            oLog.addValue('Example:c:Human_1.toStores.Human.toProcsP2P.Food_P2P', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C)',              'kg/s',    'Food Conversion Ash Flowrate');
            
            
            oLog.addValue('Example:c:Human_1.toBranches.Air_In.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)',                  'kg/s',    'CO2 Inlet Flowrate');
            oLog.addValue('Example:c:Human_1.toBranches.Air_Out.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)',                 'kg/s',    'CO2 Outlet Flowrate');
            
            oLog.addValue('Example:c:Human_1.toBranches.Air_In.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.O2)',                   'kg/s',    'O2 Inlet Flowrate');
            oLog.addValue('Example:c:Human_1.toBranches.Air_Out.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.O2)',                  'kg/s',    'O2 Outlet Flowrate');
            
            oLog.addValue('Example:c:Human_1.toBranches.Air_In.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',                  'kg/s',    'H2O Inlet Flowrate');
            oLog.addValue('Example:c:Human_1.toBranches.Air_Out.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',                 'kg/s',    'H2O Outlet Flowrate');
            
            oLog.addValue('Example:c:Human_1.toBranches.Potable_Water_In.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',    	'kg/s',    'Potable Water Consumption');
            
            oLog.addValue('Example:c:Human_1.toBranches.Urine_Out.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',               'kg/s',    'Urine H2O Outflow');
            oLog.addValue('Example:c:Human_1.toBranches.Urine_Out.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C2H6O2N2)',          'kg/s',    'Urine Solids Outflow');
            
            oLog.addValue('Example:c:Human_1.toBranches.Feces_Out.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',               'kg/s',    'Feces H2O Outflow');
            oLog.addValue('Example:c:Human_1.toBranches.Feces_Out.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C42H69O13N5)',       'kg/s',    'Feces Solids Outflow');
            
            % Inlet flow log values are negative because of branch direction
            % Therefore Outlet + Inlet gives positive values for produced
            % mass and negative values for consumed mass
            oLog.addVirtualValue('"CO2 Outlet Flowrate"    + "CO2 Inlet Flowrate"',   'kg/s', 'Effective CO2 Flow');
            oLog.addVirtualValue( '"O2 Outlet Flowrate"    +  "O2 Inlet Flowrate"',   'kg/s', 'Effective O2 Flow');
            oLog.addVirtualValue('"H2O Outlet Flowrate"    + "H2O Inlet Flowrate"',   'kg/s', 'Effective H2O Flow');
            
        end
        
        function plot(this, varargin) % Plotting the results
            
            %% Define Plots
            
            close all
            oPlotter = plot@simulation.infrastructure(this);
            
            
            csStores = fieldnames(this.oSimulationContainer.toChildren.Example.toStores);
            csMasses = cell(length(csStores),1);
            csPressures = cell(length(csStores),1);
            csTemperatures = cell(length(csStores),1);
            for iStore = 1:length(csStores)
                csMasses{iStore} = ['"', csStores{iStore}, ' Mass"'];
                csPressures{iStore} = ['"', csStores{iStore}, ' Pressure"'];
                csTemperatures{iStore} = ['"', csStores{iStore}, ' Temperature"'];
            end
            
            csBranches = fieldnames(this.oSimulationContainer.toChildren.Example.toBranches);
            csFlowRates = cell(length(csBranches),1);
            for iBranch = 1:length(csBranches)
                csFlowRates{iBranch} = ['"', csBranches{iBranch}, ' Flowrate"'];
            end
            
            
            csStoresHuman_1 = fieldnames(this.oSimulationContainer.toChildren.Example.toChildren.Human_1.toStores);
            csMassesHuman_1 = cell(length(csStoresHuman_1),1);
            csPressuresHuman_1 = cell(length(csStoresHuman_1),1);
            csTemperaturesHuman_1 = cell(length(csStoresHuman_1),1);
            iIndex = 1;
            for iStore = 1:length(csStoresHuman_1)
                csPhases = fieldnames(this.oSimulationContainer.toChildren.Example.toChildren.Human_1.toStores.(csStoresHuman_1{iStore}).toPhases);
                for iPhase = 1:length(csPhases)
                    csMassesHuman_1{iIndex}         = ['"', csStoresHuman_1{iStore}, ' ', csPhases{iPhase}, ' Mass"'];
                    csPressuresHuman_1{iIndex}      = ['"', csStoresHuman_1{iStore}, ' ', csPhases{iPhase}, ' Pressure"'];
                    csTemperaturesHuman_1{iIndex}   = ['"', csStoresHuman_1{iStore}, ' ', csPhases{iPhase}, ' Temperature"'];
                    iIndex = iIndex + 1;
                end
            end
            
            csBranchesHuman_1 = fieldnames(this.oSimulationContainer.toChildren.Example.toChildren.Human_1.toBranches);
            csFlowRatesHuman_1 = cell(length(csBranchesHuman_1),1);
            for iBranch = 1:length(csBranchesHuman_1)
                csFlowRatesHuman_1{iBranch} = ['"', csBranchesHuman_1{iBranch}, ' Flowrate"'];
            end
            
            tPlotOptions.sTimeUnit = 'seconds';
            tFigureOptions = struct('bTimePlot', false, 'bPlotTools', false);

            coPlots{1,1} = oPlotter.definePlot({csPressures{:}, csPressuresHuman_1{:}},     'Pressures', tPlotOptions);
            coPlots{2,1} = oPlotter.definePlot({csFlowRates{:}, csFlowRatesHuman_1{:}},     'Flow Rates', tPlotOptions);
            coPlots{1,2} = oPlotter.definePlot({csTemperatures{:}, csTemperaturesHuman_1{:}},  'Temperatures', tPlotOptions);
            coPlots{2,2} = oPlotter.definePlot({csMasses{:}, csMassesHuman_1{:}},  'Masses', tPlotOptions);
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
            
            oPlotter.plot();
            
            oLogger = oPlotter.oSimulationInfrastructure.toMonitors.oLogger;
            
            for iVirtualLog = 1:length(oLogger.tVirtualValues)
                if strcmp(oLogger.tVirtualValues(iVirtualLog).sLabel, 'Effective CO2 Flow')
                    
                    mfEffectiveCO2Flow = oLogger.tVirtualValues(iVirtualLog).calculationHandle(oLogger.mfLog);
                    
                elseif strcmp(oLogger.tVirtualValues(iVirtualLog).sLabel, 'Effective O2 Flow')
                    
                    mfEffectiveO2Flow = oLogger.tVirtualValues(iVirtualLog).calculationHandle(oLogger.mfLog);
                    
                elseif strcmp(oLogger.tVirtualValues(iVirtualLog).sLabel, 'Effective H2O Flow')
                    
                    mfEffectiveH2OFlow = oLogger.tVirtualValues(iVirtualLog).calculationHandle(oLogger.mfLog);
                    
                end
                
            end
            afTimeSteps = (oLogger.afTime(2:end) - oLogger.afTime(1:end-1));
            
            iLogs = length(oLogger.afTime);
            
            afGeneratedCO2Mass = zeros(iLogs,1);
            afConsumedO2Mass = zeros(iLogs,1);
            afGeneratedH2OMass = zeros(iLogs,1);
            for iLog = 2:iLogs
                afGeneratedCO2Mass(iLog)  = sum(afTimeSteps(1:iLog-1)' .* mfEffectiveCO2Flow(2:iLog));
                afConsumedO2Mass(iLog)    = sum(afTimeSteps(1:iLog-1)' .* mfEffectiveO2Flow(2:iLog));
                afGeneratedH2OMass(iLog)  = sum(afTimeSteps(1:iLog-1)' .* mfEffectiveH2OFlow(2:iLog));
            end
            
            for iLog = 1:length(oLogger.tLogValues)
                if strcmp(oLogger.tLogValues(iLog).sLabel, 'Potable Water Consumption')
                    iPotableWaterIndex = oLogger.tLogValues(iLog).iIndex;
                elseif strcmp(oLogger.tLogValues(iLog).sLabel, 'Urine H2O Outflow')
                    iUrineH2OIndex = oLogger.tLogValues(iLog).iIndex;
                elseif strcmp(oLogger.tLogValues(iLog).sLabel, 'Urine Solids Outflow')
                    iUrineSolidsIndex = oLogger.tLogValues(iLog).iIndex;
                elseif strcmp(oLogger.tLogValues(iLog).sLabel, 'Feces H2O Outflow')
                    iFecesH2OIndex = oLogger.tLogValues(iLog).iIndex;
                elseif strcmp(oLogger.tLogValues(iLog).sLabel, 'Feces Solids Outflow')
                    iFecesSolidsIndex = oLogger.tLogValues(iLog).iIndex;
                end
            end
            
            afConsumedWater = zeros(iLogs,1);
            afProducedUrineWater = zeros(iLogs,1);
            afProducedUrineSolids = zeros(iLogs,1);
            afProducedFecesWater = zeros(iLogs,1);
            afProducedFecesSolids = zeros(iLogs,1);
            for iLog = 2:iLogs
                afConsumedWater(iLog)           = sum(afTimeSteps(1:iLog-1)' .* oLogger.mfLog(2:iLog,iPotableWaterIndex));
                afProducedUrineWater(iLog)      = sum(afTimeSteps(1:iLog-1)' .* oLogger.mfLog(2:iLog,iUrineH2OIndex));
                afProducedUrineSolids(iLog)     = sum(afTimeSteps(1:iLog-1)' .* oLogger.mfLog(2:iLog,iUrineSolidsIndex));
                afProducedFecesWater(iLog)      = sum(afTimeSteps(1:iLog-1)' .* oLogger.mfLog(2:iLog,iFecesH2OIndex));
                afProducedFecesSolids(iLog)     = sum(afTimeSteps(1:iLog-1)' .* oLogger.mfLog(2:iLog,iFecesSolidsIndex));
            end
            
            figure()
            plot(oLogger.afTime./3600, afGeneratedCO2Mass)
            hold on
            grid on
            plot(oLogger.afTime./3600, afConsumedO2Mass)
            plot(oLogger.afTime./3600, afGeneratedH2OMass)
            plot(oLogger.afTime./3600, afConsumedWater)
            plot(oLogger.afTime./3600, afProducedUrineWater)
            plot(oLogger.afTime./3600, afProducedUrineSolids)
            plot(oLogger.afTime./3600, afProducedFecesWater)
            plot(oLogger.afTime./3600, afProducedFecesSolids)
            legend('Generated CO2', 'Consumed O2', 'Generated H2O', 'Consumed Potable H2O', 'Produced Urine H2O', 'Produced Urine Solids', 'Produced Feces H2O', 'Produced Feces Solids')
            xlabel('Time in [h]')
            ylabel('Mass in [kg]')
            hold off
            
            % Average Daily consumptions and productions
            fAverageO2          = afConsumedO2Mass(end) / (oLogger.afTime(end) / (24*3600));
            fAverageCO2         = afGeneratedCO2Mass(end) / (oLogger.afTime(end) / (24*3600));
            fAverageHumidity    = afGeneratedH2OMass(end) / (oLogger.afTime(end) / (24*3600));
            fAveragePotableWater = afConsumedWater(end) / (oLogger.afTime(end) / (24*3600));
            fAverageUrine       = (afProducedUrineWater(end) + afProducedUrineSolids(end)) / (oLogger.afTime(end) / (24*3600));
            fAverageFeces       = (afProducedFecesWater(end) + afProducedFecesSolids(end)) / (oLogger.afTime(end) / (24*3600));
            
            disp(['Average daily O2 consumption:        ', num2str(fAverageO2), ' kg    BVAD value is 0.816 kg'])
            disp(['Average daily Water consumption:     ', num2str(fAveragePotableWater), ' kg  BVAD value is 2.5 kg'])
            disp(['Average daily CO2 production:        ', num2str(fAverageCO2), ' kg   BVAD value is 1.04 kg'])
            disp(['Average daily Humidity production:	', num2str(fAverageHumidity), ' kg  BVAD value is 1.9 kg'])
            disp(['Average daily Urine production:      ', num2str(fAverageUrine), ' kg     BVAD value is 1.659 kg'])
            disp(['Average daily Feces production:      ', num2str(fAverageFeces), ' kg     BVAD value is 0.132 kg'])
            
        end
        
    end
    
end