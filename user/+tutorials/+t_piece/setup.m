classdef setup < simulation.infrastructure
    %SETUP This class is used to setup a simulation
    %   There should always be a setup file present for each project. It is
    %   used for the following:
    %   - instantiate the root object
    %   - register branches to their appropriate solvers
    %   - determine which items are logged
    %   - set the simulation duration
    %   - provide methods for plotting the results
    
    properties
    end
    
    methods
        function this = setup(ptConfigParams, tSolverParams) % Constructor function
            
%             tSolverParams.rUpdateFrequency = 10;
%             tSolverParams.rHighestMaxChangeDecrease = 1000;
%             
%             tSolverParams.rUpdateFrequency = 1;
%             tSolverParams.rHighestMaxChangeDecrease = 1000;
%             
%             tSolverParams.rUpdateFrequency = 5;
%             tSolverParams.rHighestMaxChangeDecrease = 500;
%             
%             
%             tSolverParams.rUpdateFrequency = 1;
%             tSolverParams.rHighestMaxChangeDecrease = 100;
%             
%             
%             tSolverParams.rUpdateFrequency = 2.5;
%             tSolverParams.rHighestMaxChangeDecrease = 50;
%             
%             
%             tSolverParams.rUpdateFrequency = 0.5;
%             tSolverParams.rHighestMaxChangeDecrease = 100;
            

%             tSolverParams.rUpdateFrequency = 0.2;
%             tSolverParams.rHighestMaxChangeDecrease = 25;
            
            if ~isfield(tSolverParams, 'rUpdateFrequency')
                tSolverParams.rUpdateFrequency = 1;
                tSolverParams.rHighestMaxChangeDecrease = 0;
            end

            
            % First we call the parent constructor and tell it the name of
            % this simulation we are creating.
            this@simulation.infrastructure('T_Piece', ptConfigParams, tSolverParams);
            
            %this.oSimulationContainer.oTimer.setMinStep(1e-12);
%             this.toMonitors.oConsoleOutput.setReportingInterval(10, 1);
            
            
            % Creating the 'Example' system as a child of the root system
            % of this simulation. 
            tutorials.t_piece.systems.Example(this.oSimulationContainer, 'Example');
            

            
            
            %% Simulation length
            % Stop when specific time in simulation is reached or after 
            % specific amount of ticks (bUseTime true/false).
            this.fSimTime = 3600 * 1; % In seconds
            this.iSimTicks = 1500;
            this.bUseTime = false;
            
            
            
% % %             % This is an alternative to providing the ttMonitorConfig above
% % %             %this.toMonitors.oConsoleOutput.setReportingInterval(10, 1);
% % %             
% % %             oP = this.oSimulationContainer.toChildren.Example.toStores.T_Piece.aoPhases(1);
% % %             
% % % %             oP.rMaxChange = 0.01;% oP.rMaxChange * 100000;
% % %             %oP.rMaxChange = oP.rMaxChange * 100;
% % % %             oP.rMaxChange = 0.01;
% % % %             oP.rHighestMaxChangeDecrease = 1000;
% % % %             oP.bSynced = true;
% % %             
% % %             
% % %             
% % %             oSolver1 = this.oSimulationContainer.toChildren.Example.coSolvers{1};
% % %             oSolver2 = this.oSimulationContainer.toChildren.Example.coSolvers{2};
% % %             oSolver3 = this.oSimulationContainer.toChildren.Example.coSolvers{3};
% % %             
% % % %             oSolver1.iDampFR = 5;
% % % %             oSolver2.iDampFR = 5;
% % % %             oSolver3.iDampFR = 5;
            
            
        end
        
        function configureMonitors(this)
            
            %% Logging
            oLog = this.toMonitors.oLogger;
            
            csStores = fieldnames(this.oSimulationContainer.toChildren.Example.toStores);
            for iStore = 1:length(csStores)
                oLog.addValue(['Example.toStores.', csStores{iStore}, '.aoPhases(1)'],	'this.fMass * this.fMassToPressure',	'Pa', [csStores{iStore}, ' Pressure']);
                oLog.addValue(['Example.toStores.', csStores{iStore}, '.aoPhases(1)'],	'fTemperature',	'K',  [csStores{iStore}, ' Temperature']);
            end
            
            csBranches = fieldnames(this.oSimulationContainer.toChildren.Example.toBranches);
            for iBranch = 1:length(csBranches)
                oLog.addValue(['Example.toBranches.', csBranches{iBranch}],             'fFlowRate',    'kg/s', [csBranches{iBranch}, ' Flowrate']);
            end
            
        end
        
        function plot(this, varargin) % Plotting the results
            
            %% Define Plots
            
            close all
            oPlotter = plot@simulation.infrastructure(this);
            
            
            csStores = fieldnames(this.oSimulationContainer.toChildren.Example.toStores);
            csPressures = cell(length(csStores),1);
            csTemperatures = cell(length(csStores),1);
            for iStore = 1:length(csStores)
                csPressures{iStore} = ['"', csStores{iStore}, ' Pressure"'];
                csTemperatures{iStore} = ['"', csStores{iStore}, ' Temperature"'];
            end
            
            csBranches = fieldnames(this.oSimulationContainer.toChildren.Example.toBranches);
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