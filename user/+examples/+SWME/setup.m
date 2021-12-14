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
        % Struct with log item indexes
        tciLog;
    end
    
    methods
        function this = setup(ptConfigParams, tSolverParams, fSimTime)
            
            this@simulation.infrastructure('SWME_Simulation', ptConfigParams, tSolverParams);

            examples.SWME.systems.Example(this.oSimulationContainer, 'Test');    
            
            if nargin > 2 && ~isempty(fSimTime)
                this.fSimTime = fSimTime;
            else
                this.fSimTime = 120;
            end
            
            % This simulation runs pretty fast regarding individual ticks,
            % so we decrease the reporting interval in the console. 
            this.toMonitors.oConsoleOutput.setReportingInterval(1000, 100);
        end
        
        % Logging function
        function configureMonitors(this)
            % To make the code more legible, we create a local variable for
            % the logger object.
            oLogger = this.toMonitors.oLogger;
            
            this.tciLog.Temperatures{1} = oLogger.addValue('Test/SWME:s:SWMEStore.toProcsP2P.X50Membrane', 'fSWMEInletTemperature', 'K', 'SWME In');
            this.tciLog.Temperatures{2} = oLogger.addValue('Test/SWME:s:SWMEStore.toProcsP2P.X50Membrane', 'fSWMEOutletTemperature', 'K', 'SWME Out');
            
            this.tciLog.FlowRates{1} = oLogger.addValue('Test/SWME:b:InletBranch',  'fFlowRate * -1', 'kg/s', 'Inflow');
            this.tciLog.FlowRates{2} = oLogger.addValue('Test/SWME:b:OutletBranch', 'fFlowRate',      'kg/s', 'Outflow');
            
            this.tciLog.ValvePosition{1} = oLogger.addValue('Test/SWME', 'iBPVCurrentSteps', '-', 'Valve Steps');
            
            this.tciLog.ValveArea{1} = oLogger.addValue('Test/SWME', 'fValveCurrentArea', 'm^2', 'Valve Area');
            
            this.tciLog.Masses{1} = oLogger.addValue('Test/SWME:s:SWMEStore:p:VaporPhase', 'this.fMass', 'kg', 'Vapor Phase');
            this.tciLog.Masses{2} = oLogger.addValue('Test/SWME:s:SWMEStore:p:FlowPhase', 'this.fMass', 'kg',  'Flow Phase');
            
            this.tciLog.Combo{1} = oLogger.addValue('Test/SWME:s:SWMEStore:p:VaporPhase',             'this.fMass * this.fMassToPressure', 'Pa',    'Vapor Backpressure');
            this.tciLog.Combo{2} = oLogger.addValue('Test/SWME:s:SWMEStore.toProcsP2P.X50Membrane',   'fHeatRejectionSimple',              'W',     'Heat Rejection');
            
            this.tciLog.VaporMass{1} = oLogger.addValue('Test:s:EnvironmentTank:p:EnvironmentPhase', 'this.afMassChange(this.oMT.tiN2I.H2O)', 'kg', 'Vapor Mass lost to Environment');
            
            this.tciLog.VaporFlowRates{1} = oLogger.addValue('Test/SWME:s:SWMEStore.toProcsP2P.X50Membrane', 'fWaterVaporFlowRate', 'kg/s', 'Membrane Flow Rate');
            this.tciLog.VaporFlowRates{2} = oLogger.addValue('Test/SWME:b:EnvironmentBranch',                'fFlowRate',           'kg/s', 'Environment Flow Rate');
            
            
        end
        
        % Plotting function
        function plot(this, tInputFigureOptions) 
            % First we get a handle to the plotter object associated with
            % this simulation.
            oPlotter = plot@simulation.infrastructure(this);
            
            % Initializing the figure options struct
            tFigureOptions = struct();
            
            % Turing on the time plot
            tFigureOptions.bTimePlot = true;
            
            % Creating the cell that contains all plots.
            coPlots = cell(3,3);
            
            coPlots{1,1} = oPlotter.definePlot(this.tciLog.Temperatures, 'Temperatures');
            coPlots{1,2} = oPlotter.definePlot(this.tciLog.FlowRates, 'Water Flow Rates');
            coPlots{1,3} = oPlotter.definePlot(this.tciLog.ValvePosition, 'Valve Position');
            coPlots{2,1} = oPlotter.definePlot(this.tciLog.Masses, 'Masses'); 
            coPlots{2,2} = oPlotter.definePlot(this.tciLog.Combo, 'Heat Rejection', struct('csUnitOverride', {{ {'W'},{'Pa'} }}));
            coPlots{2,3} = oPlotter.definePlot(this.tciLog.ValveArea, 'ValveArea');
            coPlots{3,1} = oPlotter.definePlot(this.tciLog.VaporMass, 'Vapor Mass');
            coPlots{3,2} = oPlotter.definePlot(this.tciLog.VaporFlowRates, 'Vapor Flow Rates');
            
            sName = 'SWME Simulation Results';
            
            if nargin > 2 && ~isempty(tInputFigureOptions)
                tFigureOptions = tools.mergeStructs(tFigureOptions, tInputFigureOptions);
            end
            
            oPlotter.defineFigure(coPlots, sName, tFigureOptions);
            
            % Plotting all figures (in this case just one). 
            oPlotter.plot();
            
        end
        
    end
    
end

