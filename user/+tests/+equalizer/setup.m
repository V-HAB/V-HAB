classdef setup < simulation.infrastructure
    properties
    end
    
    methods
        function this = setup(ptConfigParams, tSolverParams, ttMonitorConfig, fSimTime)
            this@simulation.infrastructure('Equalizer_Example', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            tests.equalizer.systems.Example(this.oSimulationContainer, 'Example');
            if nargin < 4
                fSimTime = 3600;
            elseif isempty(fSimTime)
                fSimTime = 3600;
            end
            this.fSimTime = fSimTime;
        end
        
        function configureMonitors(this)
            oLogger = this.toMonitors.oLogger;

            % Adding the tank temperatures to the log
            oLogger.addValue('Example:s:Tank_1:p:Tank_1_Phase_1', 'fTemperature', 'K', 'Temperature Phase 1');
            oLogger.addValue('Example:s:Tank_2:p:Tank_2_Phase_1', 'fTemperature', 'K', 'Temperature Phase 2');
            
            % Adding the tank pressures to the log
            oLogger.addValue('Example:s:Tank_1:p:Tank_1_Phase_1', 'this.fMass * this.fMassToPressure', 'Pa', 'Pressure Phase 1');
            oLogger.addValue('Example:s:Tank_2:p:Tank_2_Phase_1', 'this.fMass * this.fMassToPressure', 'Pa', 'Pressure Phase 2');
            
            % Adding the branch flow rate to the log
            oLogger.addValue('Example.toBranches.Branch', 'fFlowRate', 'kg/s', 'Branch Flow Rate');
            
        end
        
        function plot(this)
            oPlotter = plot@simulation.infrastructure(this);
            coPlots{1,1} = oPlotter.definePlot({'"Temperature Phase 1"', '"Temperature Phase 2"'}, 'Temperatures');
            coPlots{1,2} = oPlotter.definePlot({'"Pressure Phase 1"', '"Pressure Phase 2"'}, 'Pressure');
            coPlots{2,1} = oPlotter.definePlot({'"Branch Flow Rate"'}, 'Flowrate');
            
            oPlotter.defineFigure(coPlots, 'Tank Temperatures', struct('bTimePlot',true));
            
            oPlotter.plot();
            
        end
    end
end