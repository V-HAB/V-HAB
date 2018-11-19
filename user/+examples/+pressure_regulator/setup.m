classdef setup < simulation.infrastructure
    
    methods
        % constructor function
        function this = setup(ptConfigParams, tSolverParams)
            
            % Possible to change the constructor paths and params for the
            % monitors
            ttMonitorConfig = struct();
            
            % call parent constructor
            this@simulation.infrastructure('Pressure_Regulator', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            % Setting a fixed timestep that is passed through the system
            fFixedTimeStep = 0.1;
            
            % create root object
            examples.pressure_regulator.systems.SuitSystem(this.oSimulationContainer, 'SuitSystem', fFixedTimeStep); 
            
            %% Simulation length
            
            % Stop when specific time in sim is reached
            % or after specific amount of ticks (bUseTime true/false).
            this.fSimTime = 200 * 1; % In seconds
            this.iSimTicks = 3000;
            this.bUseTime = true;
        end
        
        function configureMonitors(this)
            %% Logging
            oLog = this.toMonitors.oLogger;
            
            tiLog.Valves.Diameter.Valve1 = oLog.addValue('SuitSystem/Regulator.toProcsF2F.FirstStageValve', 'fHydrDiam', 'm', 'First Stage Valve Hydraulic Diameter');
            tiLog.Valves.Diameter.Valve2 = oLog.addValue('SuitSystem/Regulator.toProcsF2F.SecondStageValve', 'fHydrDiam', 'm', 'Second Stage Valve Hydraulic Diameter');
            
            tiLog.Valves.Position.Valve1 = oLog.addValue('SuitSystem/Regulator.toProcsF2F.FirstStageValve', 'afSSM_VectorXNew(3)', 'm', 'First Stage Valve Position');
            tiLog.Valves.Position.Valve2 = oLog.addValue('SuitSystem/Regulator.toProcsF2F.SecondStageValve', 'afSSM_VectorXNew(3)', 'm', 'Second Stage Valve Position');
            
            tiLog.Valves.Speed.Valve1 = oLog.addValue('SuitSystem/Regulator.toProcsF2F.FirstStageValve', 'afSSM_VectorXNew(2)', 'm', 'First Stage Valve Speed');
            tiLog.Valves.Speed.Valve2 = oLog.addValue('SuitSystem/Regulator.toProcsF2F.SecondStageValve', 'afSSM_VectorXNew(2)', 'm', 'Second Stage Valve Speed');
            
            tiLog.Valves.Setpoint.Valve1 = oLog.addValue('SuitSystem/Regulator.toProcsF2F.FirstStageValve', 'fXSetpoint', 'm', 'First Stage Valve Setpoint');
            tiLog.Valves.Setpoint.Valve2 = oLog.addValue('SuitSystem/Regulator.toProcsF2F.SecondStageValve', 'fXSetpoint', 'm', 'Second Stage Valve Setpoint');
            
            if this.oSimulationContainer.toChildren.SuitSystem.bPPRVExists
                tiLog.Valves.Diameter.PPRV = oLog.addValue('SuitSystem.toProcsF2F.ValvePPRV', 'fHydrDiam', 'm', 'PPRV Hydraulic Diameter');
                
                tiLog.Valves.Position.PPRV = oLog.addValue('SuitSystem.toProcsF2F.ValvePPRV', 'afSSM_VectorXNew(2)', 'm', 'PPRV Position');
                
                tiLog.Valves.Speed.PPRV = oLog.addValue('SuitSystem.toProcsF2F.ValvePPRV', 'afSSM_VectorXNew(1)', 'm', 'PPRV Speed');
            end
            
            csStores = fieldnames(this.oSimulationContainer.toChildren.SuitSystem.toStores);
            for iStore = 1:length(csStores)
                oLog.addValue(['SuitSystem.toStores.', csStores{iStore}, '.aoPhases(1)'],	'this.fMass * this.fMassToPressure',	'Pa', [csStores{iStore}, ' Pressure']);
                oLog.addValue(['SuitSystem.toStores.', csStores{iStore}, '.aoPhases(1)'],	'fTemperature',	'K',  [csStores{iStore}, ' Temperature']);
            end
            
            csBranches = fieldnames(this.oSimulationContainer.toChildren.SuitSystem.toBranches);
            for iBranch = 1:length(csBranches)
                oLog.addValue(['SuitSystem.toBranches.', csBranches{iBranch}],             'fFlowRate',    'kg/s', [csBranches{iBranch}, ' Flowrate']);
            end
            
        end
        
        function plot(this) % Plotting the results
            
            %% Define Plots
            
            close all
            oPlotter = plot@simulation.infrastructure(this);
            
            
            csStores = fieldnames(this.oSimulationContainer.toChildren.SuitSystem.toStores);
            csPressures = cell(length(csStores),1);
            csTemperatures = cell(length(csStores),1);
            for iStore = 1:length(csStores)
                csPressures{iStore} = ['"', csStores{iStore}, ' Pressure"'];
                csTemperatures{iStore} = ['"', csStores{iStore}, ' Temperature"'];
            end
            
            csBranches = fieldnames(this.oSimulationContainer.toChildren.SuitSystem.toBranches);
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

