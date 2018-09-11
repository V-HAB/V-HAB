classdef Pump_and_Heater_Circle_Definition < simulation.infrastructure
    %FLOW Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
    end
    
    methods
        function this = Pump_and_Heater_Circle_Definition(ptConfigParams, tSolverParams) 
            
            % Possible to change the constructor paths and params for the
            % monitors
            ttMonitorConfig = struct();
            
            this@simulation.infrastructure('Compressible_Pump_Heater', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            tutorials.compressible_liquid_solver.systems.Pump_and_Heater_Circle(this.oSimulationContainer, 'Pump_and_Heater_Circle');
            
            
            % Sim time [s]
            this.fSimTime = 5;
        end
        function configureMonitors(this)
            
            %% Logging
            oLog = this.toMonitors.oLogger;
            
            csStores = fieldnames(this.oSimulationContainer.toChildren.Pump_and_Heater_Circle.toStores);
            for iStore = 1:length(csStores)
                oLog.addValue(['Pump_and_Heater_Circle.toStores.', csStores{iStore}, '.aoPhases(1)'],	'fPressure',                            'Pa',   [csStores{iStore}, ' Pressure']);
                oLog.addValue(['Pump_and_Heater_Circle.toStores.', csStores{iStore}, '.aoPhases(1)'],	'fMass',                                'kg',   [csStores{iStore}, ' Mass']);
                oLog.addValue(['Pump_and_Heater_Circle.toStores.', csStores{iStore}, '.aoPhases(1)'],	'fVolume',                              'm^3',  [csStores{iStore}, ' Volume']);
                oLog.addValue(['Pump_and_Heater_Circle.toStores.', csStores{iStore},],                   'fTotalPressureErrorStore',             'Pa', 	[csStores{iStore}, ' Pressure Error']);
                oLog.addValue(['Pump_and_Heater_Circle.toStores.', csStores{iStore},],                   'iNestedIntervallCounterStore',         '-',    [csStores{iStore}, ' Nested Intervall Counter']);
                oLog.addValue(['Pump_and_Heater_Circle.toStores.', csStores{iStore}, '.aoPhases(1)'],	'fTemperature',                         'K',  [csStores{iStore}, ' Temperature']);
            end
            
            csBranches = fieldnames(this.oSimulationContainer.toChildren.Pump_and_Heater_Circle.toBranches);
            for iBranch = 1:length(csBranches)
                oLog.addValue(['Pump_and_Heater_Circle.toBranches.', csBranches{iBranch}],             'fFlowRate',    'kg/s', [csBranches{iBranch}, ' Flowrate']);
            end
            
            oLog.addValue('Pump_and_Heater_Circle.aoBranches(1).oHandler',	'fTimeStepBranch',    's', 'Solver Timestep');
            
            iCellNumber = 4;
            for iCell = 1:iCellNumber
                
                oLog.addValue('Pump_and_Heater_Circle.aoBranches(1).oHandler',	['this.mPressureOld(', num2str(iCell), ')'],    'Pa',       ['Branch 1 Pressure Cell ', num2str(iCell)]);
                oLog.addValue('Pump_and_Heater_Circle.aoBranches(1).oHandler',	['this.mFlowSpeedOld(', num2str(iCell), ')'],  	'm/s',      ['Branch 1 Flowspeed Cell ', num2str(iCell)]);
                oLog.addValue('Pump_and_Heater_Circle.aoBranches(1).oHandler',	['this.mDensityOld(', num2str(iCell), ')'],     'kg/m^3',   ['Branch 1 Density Cell ', num2str(iCell)]);
                oLog.addValue('Pump_and_Heater_Circle.aoBranches(1).oHandler',	['this.mTemperatureOld(', num2str(iCell), ')'], 'K',        ['Branch 1 Temperature Cell ', num2str(iCell)]);
                oLog.addValue('Pump_and_Heater_Circle.aoBranches(1).oHandler',	['this.mPressureLoss(', num2str(iCell), ')'],   'Pa',       ['Branch 1 Pressure Loss Cell ', num2str(iCell)]);
                
            end
            
            oLog.addValue('Pump_and_Heater_Circle.aoBranches(2).oHandler',	'fTimeStepBranch',    's', 'Solver Timestep');
            iCellNumber = 3;
            for iCell = 1:iCellNumber
                
                oLog.addValue('Pump_and_Heater_Circle.aoBranches(2).oHandler',	['this.mPressureOld(', num2str(iCell), ')'],    'Pa',       ['Branch 2 Pressure Cell ', num2str(iCell)]);
                oLog.addValue('Pump_and_Heater_Circle.aoBranches(2).oHandler',	['this.mFlowSpeedOld(', num2str(iCell), ')'],  	'm/s',      ['Branch 2 Flowspeed Cell ', num2str(iCell)]);
                oLog.addValue('Pump_and_Heater_Circle.aoBranches(2).oHandler',	['this.mDensityOld(', num2str(iCell), ')'],     'kg/m^3',   ['Branch 2 Density Cell ', num2str(iCell)]);
                oLog.addValue('Pump_and_Heater_Circle.aoBranches(2).oHandler',	['this.mTemperatureOld(', num2str(iCell), ')'], 'K',        ['Branch 2 Temperature Cell ', num2str(iCell)]);
                oLog.addValue('Pump_and_Heater_Circle.aoBranches(2).oHandler',	['this.mPressureLoss(', num2str(iCell), ')'],   'Pa',       ['Branch 2 Pressure Loss Cell ', num2str(iCell)]);
                
            end
        end
        
        function plot(this, varargin) % Plotting the results
            
            %% Define Plots
            
            close all
            oPlotter = plot@simulation.infrastructure(this);
            
            
            csStores = fieldnames(this.oSimulationContainer.toChildren.Pump_and_Heater_Circle.toStores);
            csPressures = cell(length(csStores),1);
            csTemperatures = cell(length(csStores),1);
            for iStore = 1:length(csStores)
                csPressures{iStore} = ['"', csStores{iStore}, ' Pressure"'];
                csPressureErrors{iStore} = ['"', csStores{iStore}, ' Pressure Error"'];
                csTemperatures{iStore} = ['"', csStores{iStore}, ' Temperature"'];
            end
            
            csBranches = fieldnames(this.oSimulationContainer.toChildren.Pump_and_Heater_Circle.toBranches);
            csFlowRates = cell(length(csBranches),1);
            for iBranch = 1:length(csBranches)
                csFlowRates{iBranch} = ['"', csBranches{iBranch}, ' Flowrate"'];
            end
            
            tPlotOptions.sTimeUnit = 'seconds';
            tFigureOptions = struct('bTimePlot', false, 'bPlotTools', false);

            coPlots{1,1} = oPlotter.definePlot(csPressures,     'Pressures', tPlotOptions);
            coPlots{2,1} = oPlotter.definePlot(csFlowRates,     'Flow Rates', tPlotOptions);
            coPlots{1,2} = oPlotter.definePlot(csTemperatures,  'Temperatures', tPlotOptions);
            coPlots{2,2} = oPlotter.definePlot(csPressureErrors,  'Pressure Errors', tPlotOptions);
            oPlotter.defineFigure(coPlots,  'Plots', tFigureOptions);
            
            
            
            iCellNumber = 4;
            csCellPressures      = cell(1,iCellNumber);
            csCellFlowRates      = cell(1,iCellNumber);
            csCellDensities      = cell(1,iCellNumber);
            csCellTemperatures   = cell(1,iCellNumber);
            csCellPressureLosses = cell(1,iCellNumber);
            
            for iCell = 1:iCellNumber
                csCellPressures{iCell}      = ['"Branch 1 Pressure Cell ', num2str(iCell) ,'"'];
                csCellFlowRates{iCell}      = ['"Branch 1 Flowspeed Cell ', num2str(iCell) ,'"'];
                csCellDensities{iCell}      = ['"Branch 1 Density Cell ', num2str(iCell) ,'"'];
                csCellTemperatures{iCell}   = ['"Branch 1 Temperature Cell ', num2str(iCell) ,'"'];
                csCellPressureLosses{iCell} = ['"Branch 1 Pressure Loss Cell ', num2str(iCell) ,'"'];
            end
            
            coPlots{1,1} = oPlotter.definePlot(csCellPressures,       'Pressures', tPlotOptions);
            coPlots{2,1} = oPlotter.definePlot(csCellFlowRates,       'Flow Speeds', tPlotOptions);
            coPlots{1,2} = oPlotter.definePlot(csCellTemperatures,    'Temperatures', tPlotOptions);
            coPlots{2,2} = oPlotter.definePlot(csCellPressureLosses,  'Pressure Losses', tPlotOptions);
            coPlots{3,1} = oPlotter.definePlot(csCellDensities,       'Densities', tPlotOptions);
            coPlots{3,2} = oPlotter.definePlot({'"Solver Timestep"'}, 'Solver Timestep', tPlotOptions);
            oPlotter.defineFigure(coPlots,  'Internal Solver Properties Branch 1', tFigureOptions);

            
            iCellNumber = 3;
            csCellPressures      = cell(1,iCellNumber);
            csCellFlowRates      = cell(1,iCellNumber);
            csCellDensities      = cell(1,iCellNumber);
            csCellTemperatures   = cell(1,iCellNumber);
            csCellPressureLosses = cell(1,iCellNumber);
            
            for iCell = 1:iCellNumber
                csCellPressures{iCell}      = ['"Branch 2 Pressure Cell ', num2str(iCell) ,'"'];
                csCellFlowRates{iCell}      = ['"Branch 2 Flowspeed Cell ', num2str(iCell) ,'"'];
                csCellDensities{iCell}      = ['"Branch 2 Density Cell ', num2str(iCell) ,'"'];
                csCellTemperatures{iCell}   = ['"Branch 2 Temperature Cell ', num2str(iCell) ,'"'];
                csCellPressureLosses{iCell} = ['"Branch 2 Pressure Loss Cell ', num2str(iCell) ,'"'];
            end
            
            coPlots{1,1} = oPlotter.definePlot(csCellPressures,       'Pressures', tPlotOptions);
            coPlots{2,1} = oPlotter.definePlot(csCellFlowRates,       'Flow Speeds', tPlotOptions);
            coPlots{1,2} = oPlotter.definePlot(csCellTemperatures,    'Temperatures', tPlotOptions);
            coPlots{2,2} = oPlotter.definePlot(csCellPressureLosses,  'Pressure Losses', tPlotOptions);
            coPlots{3,1} = oPlotter.definePlot(csCellDensities,       'Densities', tPlotOptions);
            coPlots{3,2} = oPlotter.definePlot({'"Solver Timestep"'}, 'Solver Timestep', tPlotOptions);
            oPlotter.defineFigure(coPlots,  'Internal Solver Properties Branch 2', tFigureOptions);
            
            oPlotter.plot();
        end
        
    end
    
end