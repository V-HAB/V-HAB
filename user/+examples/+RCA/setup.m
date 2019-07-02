classdef setup < simulation.infrastructure
    %SETUP This class is used to setup a simulation
    %   There should always be a setup file present for each project. It is
    %   used for the following:
    %   - instantiate the top-level system
    %   - set the simulation duration
    %   - determine which items are logged
    %   - determine how results are plotted
    %   - provide methods for plotting the results
    
    
    properties
    end
    
    methods
        function this = setup(ptConfigParams, tSolverParams)
            % Possible to change the constructor paths and params for the
            % monitors
            ttMonitorConfig = struct();
            
            if ~isfield(tSolverParams, 'rUpdateFrequency')
                tSolverParams.rUpdateFrequency = 0.1;
            end
            
            this@simulation.infrastructure('RCA_Development_Simulation', ptConfigParams, tSolverParams, ttMonitorConfig);

            % Creating a Test object
            examples.RCA.systems.Example(this.oSimulationContainer, 'Test');      
            
            % Simulation length - stop when specific time in sim is reached
            % or after specific amount of ticks (bUseTime true/false).
            this.fSimTime  = 3600; % In seconds
            this.iSimTicks = 1100;
            this.bUseTime  = true;  
        end
        
        function configureMonitors(this)
            %% Logging
            oLogger = this.toMonitors.oLogger;
            
            tiLog.RCA_Beds.A_sorp                        = oLogger.addValue('Test.toChildren.RCA.toStores.Bed_A.toProcsP2P.SorptionProcessor', 'fFlowRate_ads', 'kg/s', 'Adsorption Flow Rate Bed A');
            tiLog.RCA_Beds.B_sorp                        = oLogger.addValue('Test.toChildren.RCA.toStores.Bed_B.toProcsP2P.SorptionProcessor', 'fFlowRate_ads', 'kg/s', 'Adsorption Flow Rate Bed B');
            tiLog.RCA_CO2_Values.SplitterPartialMass     = oLogger.addValue('Test/RCA:s:Splitter:p:Splitter_Phase_1', 'arPartialMass(this.oMT.tiN2I.CO2)', '-', 'Splitter CO2 Partial Mass');
            tiLog.RCA_CO2_Values.MergerPartialMass       = oLogger.addValue('Test/RCA:s:Merger:p:Merger_Phase_1', 'arPartialMass(this.oMT.tiN2I.CO2)', '-', 'Merger CO2 Partial Mass');
            tiLog.RCA_CO2_Values.BedAFlowPartialMass     = oLogger.addValue('Test/RCA:s:Bed_A:p:FlowPhase', 'arPartialMass(this.oMT.tiN2I.CO2)', '-', 'Bed A Flow Phase CO2 Partial Mass');
            tiLog.RCA_CO2_Values.BedBFlowPartialMass     = oLogger.addValue('Test/RCA:s:Bed_B:p:FlowPhase', 'arPartialMass(this.oMT.tiN2I.CO2)', '-', 'Bed B Flow Phase CO2 Partial Mass');
            tiLog.RCA_CO2_Values.SplitterPartialPressure = oLogger.addValue('Test/RCA:s:Splitter:p:Splitter_Phase_1', 'afPP(this.oMT.tiN2I.CO2)', 'Pa', 'Splitter CO2 Partial Pressure');
            tiLog.RCA_CO2_Values.MergerPartialPressure   = oLogger.addValue('Test/RCA:s:Merger:p:Merger_Phase_1', 'afPP(this.oMT.tiN2I.CO2)', 'Pa', 'Merger CO2 Partial Pressure');
            tiLog.RCA_CO2_Values.BedAFlowPartialPressure = oLogger.addValue('Test/RCA:s:Bed_A:p:FlowPhase', 'afPP(this.oMT.tiN2I.CO2)', 'Pa', 'Bed A Flow Phase CO2 Partial Pressure');
            tiLog.RCA_CO2_Values.BedBFlowPartialPressure = oLogger.addValue('Test/RCA:s:Bed_B:p:FlowPhase', 'afPP(this.oMT.tiN2I.CO2)', 'Pa', 'Bed B Flow Phase CO2 Partial Pressure');
            
            csStores = fieldnames(this.oSimulationContainer.toChildren.Test.toStores);
            for iStore = 1:length(csStores)
                oLogger.addValue(['Test.toStores.', csStores{iStore}, '.aoPhases(1)'],	'this.fMass * this.fMassToPressure',	'Pa', [csStores{iStore}, ' Pressure']);
                oLogger.addValue(['Test.toStores.', csStores{iStore}, '.aoPhases(1)'],	'fTemperature',	'K',  [csStores{iStore}, ' Temperature']);
            end
            
            csBranches = fieldnames(this.oSimulationContainer.toChildren.Test.toBranches);
            for iBranch = 1:length(csBranches)
                oLogger.addValue(['Test.toBranches.', csBranches{iBranch}],             'fFlowRate',    'kg/s', [csBranches{iBranch}, ' Flowrate']);
            end
            
        end
        
        function plot(this) % Plotting the results
            
            %% Define Plots
            
            close all
            oPlotter = plot@simulation.infrastructure(this);
            
            
            csStores = fieldnames(this.oSimulationContainer.toChildren.Test.toStores);
            csPressures = cell(length(csStores),1);
            csTemperatures = cell(length(csStores),1);
            for iStore = 1:length(csStores)
                csPressures{iStore} = ['"', csStores{iStore}, ' Pressure"'];
                csTemperatures{iStore} = ['"', csStores{iStore}, ' Temperature"'];
            end
            
            csBranches = fieldnames(this.oSimulationContainer.toChildren.Test.toBranches);
            csFlowRates = cell(length(csBranches),1);
            for iBranch = 1:length(csBranches)
                csFlowRates{iBranch} = ['"', csBranches{iBranch}, ' Flowrate"'];
            end
            
            tPlotOptions.sTimeUnit = 'seconds';
            tFigureOptions = struct('bTimePlot', false, 'bPlotTools', false);

            coPlots{1,1} = oPlotter.definePlot(csPressures,     'Pressures', tPlotOptions);
            coPlots{2,1} = oPlotter.definePlot(csFlowRates,     'Flow Rates', tPlotOptions);
            coPlots{1,2} = oPlotter.definePlot(csTemperatures,  'Temperatures', tPlotOptions);
            oPlotter.defineFigure(coPlots,  'Plots', tFigureOptions);
            
            oPlotter.plot();
        end
        
    end
    
end

