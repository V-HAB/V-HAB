classdef setup < simulation.infrastructure
    
    properties
    end
    
    methods
        function this = setup(ptConfigParams, tSolverParams) % Constructor function
            
            ttMonitorConfig = struct();
            this@simulation.infrastructure('Tutorial_Human_1_Model', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            tutorials.human_model.systems.Example(this.oSimulationContainer, 'Example');
            
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
                oLog.addValue(['Example.toStores.', csStores{iStore}, '.aoPhases(1)'],	'fPressure',	'Pa', [csStores{iStore}, ' Pressure']);
                oLog.addValue(['Example.toStores.', csStores{iStore}, '.aoPhases(1)'],	'fTemperature',	'K',  [csStores{iStore}, ' Temperature']);
            end
            
            csBranches = fieldnames(this.oSimulationContainer.toChildren.Example.toBranches);
            for iBranch = 1:length(csBranches)
                oLog.addValue(['Example.toBranches.', csBranches{iBranch}],             'fFlowRate',    'kg/s', [csBranches{iBranch}, ' Flowrate']);
            end
            
            csStoresHuman_1 = fieldnames(this.oSimulationContainer.toChildren.Example.toChildren.Human_1.toStores);
            for iStore = 1:length(csStoresHuman_1)
                oLog.addValue(['Example:c:Human_1.toStores.', csStoresHuman_1{iStore}, '.aoPhases(1)'],	'fPressure',	'Pa', [csStoresHuman_1{iStore}, ' Pressure']);
                oLog.addValue(['Example:c:Human_1.toStores.', csStoresHuman_1{iStore}, '.aoPhases(1)'],	'fTemperature',	'K',  [csStoresHuman_1{iStore}, ' Temperature']);
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
            
        end
        
        function plot(this, varargin) % Plotting the results
            
            %% Define Plots
            
            close all
            oPlotter = plot@simulation.infrastructure(this);
            
            
            csStores = fieldnames(this.oSimulationContainer.toChildren.Example.toStores);
            csPressures = cell(length(csStores),1);
            csTemperatures = cell(length(csStores),1);
            for iStore = 1:length(csStores)
                csPressures{iStore} = ['"', csStores{iStore}, ' Pressure"'];
                csTemperatures{iStore} = ['"', csStores{iStore}, ' Temperature"'];
            end
            
            csBranches = fieldnames(this.oSimulationContainer.toChildren.Example.toBranches);
            csFlowRates = cell(length(csBranches),1);
            for iBranch = 1:length(csBranches)
                csFlowRates{iBranch} = ['"', csBranches{iBranch}, ' Flowrate"'];
            end
            
            
            csStoresHuman_1 = fieldnames(this.oSimulationContainer.toChildren.Example.toChildren.Human_1.toStores);
            csPressuresHuman_1 = cell(length(csStoresHuman_1),1);
            csTemperaturesHuman_1 = cell(length(csStoresHuman_1),1);
            for iStore = 1:length(csStoresHuman_1)
                csPressuresHuman_1{iStore} = ['"', csStoresHuman_1{iStore}, ' Pressure"'];
                csTemperaturesHuman_1{iStore} = ['"', csStoresHuman_1{iStore}, ' Temperature"'];
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
            oPlotter.defineFigure(coPlots,  'Plots', tFigureOptions);
            
            csHumansPhaseMassses = {'"Internal O_2 Mass"', '"Internal CO_2 Mass"', '"Internal H_2O Mass"', '"Internal Protein Mass"',  '"Internal Fat Mass"',...
                                    '"Internal Carbohydrate Mass"', '"Internal Feces Solid Mass"', '"Internal Urine Solid Mass"'};
            
            coPlots{1,1} = oPlotter.definePlot(csHumansPhaseMassses,     'Internal Human Masses', tPlotOptions);
            coPlots{2,1} = oPlotter.definePlot({'"Current Energy Demand"'},     'Energy Demand', tPlotOptions);
            coPlots{1,2} = oPlotter.definePlot({'"Oxygen Consumption"', '"CO_2 Production"'},  'Oxygen and CO2 flowrates', tPlotOptions);
            coPlots{2,2} = oPlotter.definePlot({'"Respiratory Coefficient"'},  'Respiratory Coefficient', tPlotOptions);
            oPlotter.defineFigure(coPlots,  'Human Model Plots', tFigureOptions);
            
            oPlotter.plot();
        end
        
    end
    
end