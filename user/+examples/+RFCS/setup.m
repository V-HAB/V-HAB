
classdef setup < simulation.infrastructure
    
    properties
        
    end
    
    methods
        
        function this = setup(ptConfigParams, tSolverParams)
            
            ttMonitorConfig = struct();
%             ttMonitorConfig.oTimeStepObserver.sClass = 'simulation.monitors.timestepObserver';
%             ttMonitorConfig.oTimeStepObserver.cParams = { 0 };
            
            this@simulation.infrastructure('RFCS', ptConfigParams, tSolverParams, ttMonitorConfig);
            examples.RFCS.system.RFCS(this.oSimulationContainer,'RFCS');
            
            %simulation length
            this.fSimTime = 4 * 24 * 3600;
            this.bUseTime = true;
        end
        
        function configureMonitors(this)
            
            oLogger = this.toMonitors.oLogger;
            
            oLogger.addValue('RFCS:s:O2_Tank:p:O2', 'fPressure',    'Pa', 'O_2 Tank Pressure');
            oLogger.addValue('RFCS:s:H2_Tank:p:H2', 'fPressure',    'Pa', 'H_2 Tank Pressure');
            
            oLogger.addValue('RFCS:s:Water_Tank:p:Water', 'fMass',	'kg', 'H2O Tank Mass');
            
            oLogger.addValue('RFCS:s:CoolingSystem:p:CoolingWater', 'fTemperature', 'K', 'Coolant Temperature');
            
            oLogger.addValue('RFCS.toBranches.Radiator_Cooling', 'fFlowRate', 'kg/s', 'Radiator Flowrate');
            
            
            % Fuel Cell Logging
            oLogger.addValue('RFCS:c:FuelCell', 'rEfficiency',      '-',  	'Fuel Cell Efficiency');
            oLogger.addValue('RFCS:c:FuelCell', 'fStackCurrent',    'A',    'Fuel Cell Current');
            oLogger.addValue('RFCS:c:FuelCell', 'fStackVoltage',    'V',    'Fuel Cell Voltage');
            oLogger.addValue('RFCS:c:FuelCell', 'fPower',           'W',    'Fuel Cell Power');
            
            oLogger.addValue('RFCS:c:FuelCell:s:FuelCell:p:Membrane.toManips.substance', 'this.afPartialFlows(this.oMT.tiN2I.H2)',	'kg/s',    'Fuel Cell Reaction H_2 Flow');
            oLogger.addValue('RFCS:c:FuelCell:s:FuelCell:p:Membrane.toManips.substance', 'this.afPartialFlows(this.oMT.tiN2I.O2)',	'kg/s',    'Fuel Cell Reaction O_2 Flow');
            oLogger.addValue('RFCS:c:FuelCell:s:FuelCell:p:Membrane.toManips.substance', 'this.afPartialFlows(this.oMT.tiN2I.H2O)',	'kg/s',    'Fuel Cell Reaction H2O Flow');
            
            % Electrolyzer Logging
            oLogger.addValue('RFCS:c:Electrolyzer', 'rEfficiency',      '-',  	'Electrolyzer Efficiency');
            oLogger.addValue('RFCS:c:Electrolyzer', 'fStackCurrent',    'A',    'Electrolyzer Current');
            oLogger.addValue('RFCS:c:Electrolyzer', 'fStackVoltage',    'V',    'Electrolyzer Voltage');
            oLogger.addValue('RFCS:c:Electrolyzer', 'fPower',           'W',    'Electrolyzer Power');
            
            oLogger.addValue('RFCS:c:Electrolyzer:s:Electrolyzer:p:Membrane.toManips.substance', 'this.afPartialFlows(this.oMT.tiN2I.H2)',	'kg/s',    'Electrolyzer Reaction H_2 Flow');
            oLogger.addValue('RFCS:c:Electrolyzer:s:Electrolyzer:p:Membrane.toManips.substance', 'this.afPartialFlows(this.oMT.tiN2I.O2)',	'kg/s',    'Electrolyzer Reaction O_2 Flow');
            oLogger.addValue('RFCS:c:Electrolyzer:s:Electrolyzer:p:Membrane.toManips.substance', 'this.afPartialFlows(this.oMT.tiN2I.H2O)',	'kg/s',    'Electrolyzer Reaction H2O Flow');
            
        end
        function plot(this)
            
            close all % closes all currently open figures
            
            oPlotter = plot@simulation.infrastructure(this);
            
            tPlotOptions = struct('sTimeUnit','hours');
            
            coPlots = [];
            coPlots{1,1} = oPlotter.definePlot({'"O_2 Tank Pressure"', '"H_2 Tank Pressure"'}, 'Tank Pressures', tPlotOptions);
            coPlots{1,2} = oPlotter.definePlot({'"H2O Tank Mass"'}, 'Tank Masses', tPlotOptions);
            coPlots{2,1} = oPlotter.definePlot({'"Coolant Temperature"'}, 'Temperatures', tPlotOptions);
            coPlots{2,2} = oPlotter.definePlot({'"Radiator Flowrate"'}, 'Flow Rates', tPlotOptions);
            oPlotter.defineFigure(coPlots, 'RFCS');
            
            coPlots = [];
            coPlots{1,1} = oPlotter.definePlot({'"Fuel Cell Current"', '"Fuel Cell Voltage"'}, 'Fuel Cell Electric Parameters', tPlotOptions);
            coPlots{1,2} = oPlotter.definePlot({'"Fuel Cell Power"', '"Fuel Cell Efficiency"'}, 'Fuel Cell Power', tPlotOptions);
            coPlots{2,1} = oPlotter.definePlot({'"Fuel Cell Reaction H_2 Flow"', '"Fuel Cell Reaction O_2 Flow"', '"Fuel Cell Reaction H2O Flow"'}, 'Flowrates', tPlotOptions);
            oPlotter.defineFigure(coPlots, 'FuelCell');
            
            coPlots = [];
            coPlots{1,1} = oPlotter.definePlot({'"Electrolyzer Current"', '"Electrolyzer Voltage"'}, 'Electrolyzer Electric Parameters', tPlotOptions);
            coPlots{1,2} = oPlotter.definePlot({'"Electrolyzer Power"', '"Electrolyzer Efficiency"'}, 'Electrolyzer Power', tPlotOptions);
            coPlots{2,1} = oPlotter.definePlot({'"Electrolyzer Reaction H_2 Flow"', '"Electrolyzer Reaction O_2 Flow"', '"Electrolyzer Reaction H2O Flow"'}, 'Flowrates', tPlotOptions);
            oPlotter.defineFigure(coPlots, 'Electrolyzer');
            
            
            oPlotter.plot();
        end
    end
end