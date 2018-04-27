classdef Two_Tanks_Definition < simulation.infrastructure
    %FLOW Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
    end
    
    methods
        function this = Two_Tanks_Definition(ptConfigParams, tSolverParams)
            
            ttMonitorConfig = struct();
            
            % First we call the parent constructor and tell it the name of
            % this simulation we are creating.
            this@simulation.infrastructure('TestCase_SimpleFlow', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            % Creating the 'Example' system as a child of the root system
            % of this simulation. 
            
            tutorials.compressible_liquid_solver.systems.Two_Tanks(this.oSimulationContainer, 'Two_Tanks');
            
            % Sim time [s]
            this.fSimTime = 0.05;
            
        end
        
        function configureMonitors(this)
            
            %% Logging
            oLog = this.toMonitors.oLogger;
            
            csStores = fieldnames(this.oSimulationContainer.toChildren.Two_Tanks.toStores);
            for iStore = 1:length(csStores)
                oLog.addValue(['Two_Tanks.toStores.', csStores{iStore}, '.aoPhases(1)'],	'fPressure',                            'Pa',   [csStores{iStore}, ' Pressure']);
                oLog.addValue(['Two_Tanks.toStores.', csStores{iStore}, '.aoPhases(1)'],	'fMass',                                'kg',   [csStores{iStore}, ' Mass']);
                oLog.addValue(['Two_Tanks.toStores.', csStores{iStore}, '.aoPhases(1)'],	'fVolume',                              'm^3',  [csStores{iStore}, ' Volume']);
                oLog.addValue(['Two_Tanks.toStores.', csStores{iStore},],                   'fTotalPressureErrorStore',             'Pa', 	[csStores{iStore}, ' Pressure Error']);
                oLog.addValue(['Two_Tanks.toStores.', csStores{iStore},],                   'iNestedIntervallCounterStore',         '-',    [csStores{iStore}, ' Nested Intervall Counter']);
                oLog.addValue(['Two_Tanks.toStores.', csStores{iStore}, '.aoPhases(1)'],	'fTemperature',                         'K',  [csStores{iStore}, ' Temperature']);
            end
            
            csBranches = fieldnames(this.oSimulationContainer.toChildren.Two_Tanks.toBranches);
            for iBranch = 1:length(csBranches)
                oLog.addValue(['Two_Tanks.toBranches.', csBranches{iBranch}],             'fFlowRate',    'kg/s', [csBranches{iBranch}, ' Flowrate']);
            end
            
            oLog.addValue('Two_Tanks.aoBranches(1).oHandler',	'fTimeStepBranch',    's', 'Solver Timestep');
            
            iCellNumber = 10;
            for iCell = 1:iCellNumber
                
                oLog.addValue('Two_Tanks.aoBranches(1).oHandler',	['this.mPressureOld(', num2str(iCell), ')'],    'Pa',       ['Pressure Cell ', num2str(iCell)]);
                oLog.addValue('Two_Tanks.aoBranches(1).oHandler',	['this.mFlowSpeedOld(', num2str(iCell), ')'],  	'kg/s',     ['Flowrate Cell ', num2str(iCell)]);
                oLog.addValue('Two_Tanks.aoBranches(1).oHandler',	['this.mDensityOld(', num2str(iCell), ')'],     'kg/m^3',    ['Density Cell ', num2str(iCell)]);
                oLog.addValue('Two_Tanks.aoBranches(1).oHandler',	['this.mTemperatureOld(', num2str(iCell), ')'], 'K',        ['Temperature Cell ', num2str(iCell)]);
                oLog.addValue('Two_Tanks.aoBranches(1).oHandler',	['this.mPressureLoss(', num2str(iCell), ')'],   'Pa',       ['Pressure Loss Cell ', num2str(iCell)]);
                
            end
        end
        
        function plot(this, varargin) % Plotting the results
            
            %% Define Plots
            
            close all
            oPlotter = plot@simulation.infrastructure(this);
            
            
            csStores = fieldnames(this.oSimulationContainer.toChildren.Two_Tanks.toStores);
            csPressures = cell(length(csStores),1);
            csTemperatures = cell(length(csStores),1);
            for iStore = 1:length(csStores)
                csPressures{iStore} = ['"', csStores{iStore}, ' Pressure"'];
                csPressureErrors{iStore} = ['"', csStores{iStore}, ' Pressure Error"'];
                csTemperatures{iStore} = ['"', csStores{iStore}, ' Temperature"'];
            end
            
            csBranches = fieldnames(this.oSimulationContainer.toChildren.Two_Tanks.toBranches);
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
            
            
            
            iCellNumber = 10;
            csCellPressures      = cell(1,iCellNumber);
            csCellFlowRates      = cell(1,iCellNumber);
            csCellDensities      = cell(1,iCellNumber);
            csCellTemperatures   = cell(1,iCellNumber);
            csCellPressureLosses = cell(1,iCellNumber);
            
            for iCell = 1:iCellNumber
                csCellPressures{iCell}      = ['"Pressure Cell ', num2str(iCell) ,'"'];
                csCellFlowRates{iCell}      = ['"Flowrate Cell ', num2str(iCell) ,'"'];
                csCellDensities{iCell}      = ['"Density Cell ', num2str(iCell) ,'"'];
                csCellTemperatures{iCell}   = ['"Temperature Cell ', num2str(iCell) ,'"'];
                csCellPressureLosses{iCell} = ['"Pressure Loss Cell ', num2str(iCell) ,'"'];
            end
            
            coPlots{1,1} = oPlotter.definePlot(csCellPressures,       'Pressures', tPlotOptions);
            coPlots{2,1} = oPlotter.definePlot(csCellFlowRates,       'Flow Rates', tPlotOptions);
            coPlots{1,2} = oPlotter.definePlot(csCellTemperatures,    'Temperatures', tPlotOptions);
            coPlots{2,2} = oPlotter.definePlot(csCellPressureLosses,  'Pressure Losses', tPlotOptions);
            coPlots{3,1} = oPlotter.definePlot(csCellDensities,       'Densities', tPlotOptions);
            coPlots{3,2} = oPlotter.definePlot({'"Solver Timestep"'}, 'Solver Timestep', tPlotOptions);
            oPlotter.defineFigure(coPlots,  'Internal Solver Properties', tFigureOptions);
            
            oPlotter.plot();
        end
        
    end
    
end
