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
            
            this@simulation.infrastructure('SWME_Simulation', ptConfigParams, tSolverParams, ttMonitorConfig);

            % Creating a Test object
            tutorials.SWME.systems.Example(this.oSimulationContainer, 'Test');    
            
            % Simulation length - stop when specific time in sim is reached
            % or after specific amount of ticks (bUseTime true/false).
            this.fSimTime  = 3600; % In seconds
            this.iSimTicks = 1100;
            this.bUseTime  = true;
        end
        
        function configureMonitors(this)
            %% Logging
            % Creating a cell setting the log items. You need to know the
            % exact structure of your model to set log items, so do this
            % when you are done modelling and ready to run a simulation. 
            
            oLogger = this.toMonitors.oLogger;
            
            
            tiLog.ValvePosition = oLogger.addValue('Test/SWME', 'iBPVCurrentSteps', 'steps', 'Valve Position');
            
            tiLog.Combo_1.ValvePosition = tiLog.ValvePosition;
            tiLog.Combo_1.Backpressure  = oLogger.addValue('Test/SWME:s:SWMEStore:p:VaporPhase', 'this.fMass * this.fMassToPressure', 'Pa', 'Vapor Backpressure');
            tiLog.Combo_1.HeatRejection = oLogger.addValue('Test/SWME:s:SWMEStore.toProcsP2P.X50Membrane', 'fHeatRejectionSimple', 'W', 'Heat Rejection');
            
            tiLog.HeatRejection = tiLog.Combo_1.HeatRejection;
            
            tiLog.Combo_2.TotalHeatRejection = tiLog.Combo_1.HeatRejection;
            tiLog.Combo_2.F2FHeatRejection   = oLogger.addValue('Test/SWME.toProcsF2F.TemperatureProcessor', 'fHeatFlow', 'W', 'Processor Heat Flow');
            
            tiLog.OutletTemperature = oLogger.addValue('Test/SWME.toProcsF2F.TemperatureProcessor.aoFlows(2)', 'fTemperature', 'K', 'Outlet Temperature');
            
            tiLog.WaterTemperatures.Inlet  = oLogger.addValue('Test/SWME:s:SWMEStore:p:FlowPhase.toProcsEXME.WaterIn', 'fTemperature', 'K', 'Inlet Temperature');
            tiLog.WaterTemperatures.Outlet = tiLog.OutletTemperature;
            
            tiLog.EnvironmentVaporMass = oLogger.addValue('Test/SWME:s:EnvironmentTank:p:EnvironmentPhase', 'fMass', 'kg', 'Vapor Mass lost to Environment');
            
            tiLog.VaporFlowRates.Membrane = oLogger.addValue('Test/SWME:s:SWMEStore.toProcsP2P.X50Membrane', 'fWaterVaporFlowRate', 'kg/s', 'Membrane Flow Rate');
            tiLog.VaporFlowRates.Vacuum   = oLogger.addValue('Test/SWME:b:EnvironmentBranch', 'fFlowRate', 'kg/s', 'Environment Flow Rate');
            
            tiLog.WaterFlowRates.Inlet  = oLogger.addValue('Test/SWME:b:InletBranch', 'fFlowRate', 'kg/s', 'Inlet Flow Rate');
            tiLog.WaterFlowRates.Outlet = oLogger.addValue('Test/SWME:b:OutletBranch', 'fFlowRate', 'kg/s', 'Outlet Flow Rate');
            
            tiLog.VaporBackpressure = tiLog.Combo_1.Backpressure;
            
            
            %% Define plots
            
            oPlot = this.toMonitors.oPlotter;
            
            oPlot.definePlot(tiLog.ValvePosition,     'Backpressure Valve Position');
            oPlot.definePlot(tiLog.Combo_1,           'Valve Position, Vapor Backpressure and Heat Rejection');
%             oPlot.definePlot(tiLog.HeatRejection,     'Heat Rejection Simple');
            oPlot.definePlot(tiLog.Combo_2,           'Heat Rejection');
            oPlot.definePlot(tiLog.OutletTemperature, 'Outlet Temperature');
            oPlot.definePlot(tiLog.WaterTemperatures, 'Water Temperatures');
            oPlot.definePlot(tiLog.EnvironmentVaporMass,   'Environment Tank Vapor Mass');
            oPlot.definePlot(tiLog.VaporFlowRates,    'Vapor Flow Rates');
            oPlot.definePlot(tiLog.WaterFlowRates,    'Water Flow Rates');
            oPlot.definePlot(tiLog.VaporBackpressure, 'Vapor backpressure');

        end
        
        function plot(this, varargin)
            this.toMonitors.oPlotter.plot(varargin{:});
            
        end
        
    end
    
end

