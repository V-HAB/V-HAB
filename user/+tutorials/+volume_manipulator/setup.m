classdef setup < simulation.infrastructure
    properties
    end
    
    methods
        function this = setup(varargin) 
            this@simulation.infrastructure('Tutorial_Volume_Manipulator', containers.Map(), struct(), struct());
            
            tutorials.volume_manipulator.systems.Example(this.oSimulationContainer, 'Example');
            
            this.fSimTime = 3600;
        end
        
        function configureMonitors(this)
            oLogger = this.toMonitors.oLogger;

            oLogger.addValue('Example:s:Tank_1:p:Tank_1_Phase_1', 'fTemperature', 'K', 'Temperature Phase 1');
            oLogger.addValue('Example:s:Tank_2:p:Tank_2_Phase_1', 'fTemperature', 'K', 'Temperature Phase 2');
            
            oLogger.addValue('Example:s:Tank_1:p:Tank_1_Phase_1', 'fVolume', 'm^3', 'Volume Phase 1');
            oLogger.addValue('Example:s:Tank_2:p:Tank_2_Phase_1', 'fVolume', 'm^3', 'Volume Phase 2');
            
            oLogger.addValue('Example:s:Tank_1:p:Tank_1_Phase_1', 'this.fMass * this.fMassToPressure', 'Pa', 'Pressure Phase 1');
            oLogger.addValue('Example:s:Tank_2:p:Tank_2_Phase_1', 'this.fMass * this.fMassToPressure', 'Pa', 'Pressure Phase 2');
            
            oLogger.addValue('Example.toBranches.Branch', 'fFlowRate', 'kg/s', 'Branch Flow Rate');
        end
        
        function plot(this) 
            oPlotter = plot@simulation.infrastructure(this);
            coPlots{1,1} = oPlotter.definePlot({'"Temperature Phase 1"', '"Temperature Phase 2"'},  'Temperatures');
            coPlots{1,2} = oPlotter.definePlot({'"Pressure Phase 1"',    '"Pressure Phase 2"'},   	'Pressure');
            coPlots{2,1} = oPlotter.definePlot({'"Branch Flow Rate"'},                              'Flowrate');
            coPlots{2,2} = oPlotter.definePlot({'"Volume Phase 1"',      '"Volume Phase 2"'},       'Volume');
            
            oPlotter.defineFigure(coPlots, 'Tank Temperatures', struct('bTimePlot',true));
            
            oPlotter.plot();
            
        end
    end
end