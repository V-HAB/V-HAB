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
            tutorials.RCA.systems.Example(this.oSimulationContainer, 'Test');          
        end
        
        function configureMonitors(this)
            %% Logging
            oLogger = this.toMonitors.oLogger;
            
            tiLog.Parent                                 = oLogger.add('Test', 'flow_props');
            tiLog.RCA                                    = oLogger.add('Test/RCA', 'flow_props');
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
            
            %% Plot definition
            
            oPlot = this.toMonitors.oPlotter;
            
            oPlot.definePlotWithFilter(tiLog.Parent,   'Pa', 'PLSS Pressures');
            oPlot.definePlotWithFilter(tiLog.Parent,    'K', 'PLSS Temperatures');
            oPlot.definePlotWithFilter(tiLog.Parent,   'kg', 'PLSS Tank Masses');
            oPlot.definePlotWithFilter(tiLog.Parent, 'kg/s', 'PLSS Flow Rates');
            
            oPlot.definePlotWithFilter(tiLog.RCA,   'Pa', 'RCA Pressures');
            oPlot.definePlotWithFilter(tiLog.RCA,    'K', 'RCA Temperatures');
            oPlot.definePlotWithFilter(tiLog.RCA,   'kg', 'RCA Tank Masses');
            oPlot.definePlotWithFilter(tiLog.RCA, 'kg/s', 'RCA Flow Rates');
            
            oPlot.definePlot(tiLog.RCA_Beds, 'Adsorption Flow Rates');

            oPlot.definePlotWithFilter(tiLog.RCA_CO2_Values, '-',  'RCA CO2 Partial Masses');
            oPlot.definePlotWithFilter(tiLog.RCA_CO2_Values, 'Pa', 'RCA CO2 Partial Pressures');

            % Simulation length - stop when specific time in sim is reached
            % or after specific amount of ticks (bUseTime true/false).
            this.fSimTime  = 3600; % In seconds
            this.iSimTicks = 1100;
            this.bUseTime  = true;

        end
        
        function plot(this, varargin)
            this.toMonitors.oPlotter.plot(varargin{:});
            
        end
        
    end
    
end

