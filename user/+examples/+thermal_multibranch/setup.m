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
        tiLogIndexes = struct();
    end
    
    methods
        function this = setup(ptConfigParams, tSolverParams, fSimTime) % Constructor function
            
            
            ttMonitorConfig = struct();
            
            % Possible to change the constructor paths and params for the
            % monitors
%             ttMonitorConfig = struct('oTimeStepObserver', struct('sClass', 'simulation.monitors.timestepObserver', 'cParams', {{ 0 }}));
            
            %%%ttMonitorConfig.oConsoleOutput = struct('cParams', {{ 50 5 }});
            
            %tSolverParams.rUpdateFrequency = 0.1;
            %tSolverParams.rHighestMaxChangeDecrease = 100;
            
            % First we call the parent constructor and tell it the name of
            % this simulation we are creating.
            this@simulation.infrastructure('Tutorial_Thermal_Multibranch', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            % Creating the 'Example' system as a child of the root system
            % of this simulation. 
            examples.thermal_multibranch.systems.Example(this.oSimulationContainer, 'Example');
            

            %% Simulation length
            % Stop when specific time in simulation is reached or after 
            % specific amount of ticks (bUseTime true/false).
            this.fSimTime = 1800; % In seconds
            
            if nargin >= 3 && ~isempty(fSimTime)
                this.fSimTime = fSimTime;
            end
            
            this.iSimTicks = 1500;
            this.bUseTime = true;
        end
        
        
        
        function configureMonitors(this)
            
            %% Logging
            % Creating a cell setting the log items. You need to know the
            % exact structure of your model to set log items, so do this
            % when you are done modelling and ready to run a simulation. 
            
            oLog = this.toMonitors.oLogger;
            
            iNodesPerDirection = this.oSimulationContainer.toChildren.Example.iNodesPerDirection;
            
            for iX = 1:iNodesPerDirection
                for iY = 1:iNodesPerDirection
                    for iZ = 1:iNodesPerDirection
                        sNodeName = ['Node_X', num2str(iX),'_Y', num2str(iY),'_Z', num2str(iZ)];
                        
                        oLog.addValue(['Example:s:Cube.toPhases.', sNodeName],	'fTemperature',	'K',   ['Temperature ', sNodeName]);
                    end
                end
            end
        end
        
        function plot(this) % Plotting the results
            
            close all
            %% Define plots
            
            oPlotter = plot@simulation.infrastructure(this);
            oLogger = this.toMonitors.oLogger;
            
            iNodesPerDirection = this.oSimulationContainer.toChildren.Example.iNodesPerDirection;
            
            csTemperatures = cell(iNodesPerDirection^3);
            iNode = 1;
            for iX = 1:iNodesPerDirection
                for iY = 1:iNodesPerDirection
                    for iZ = 1:iNodesPerDirection
                        sNodeName = ['Node_X', num2str(iX),'_Y', num2str(iY),'_Z', num2str(iZ)];
                        
                        csTemperatures{iNode} = ['"Temperature ', sNodeName, '"'];
                        
                        iNode = iNode + 1;
                    end
                end
            end
            
            tPlotOptions = struct('sTimeUnit','seconds');
            coPlots{1,1} = oPlotter.definePlot(csTemperatures, 'Temperatures', tPlotOptions);
            
            oPlotter.defineFigure(coPlots, 'Cube Temperatures');
            
            oPlotter.plot();
            
            
            afTime = oLogger.afTime;
            afTime(isnan(afTime)) = [];
            iTicks = length(afTime);
            
            mfLoggedTemperatures = zeros(iNodesPerDirection, iNodesPerDirection, iNodesPerDirection, iTicks);
            
            for iX = 1:iNodesPerDirection
                for iY = 1:iNodesPerDirection
                    for iZ = 1:iNodesPerDirection
                        
                        sNodeName = ['Node_X', num2str(iX),'_Y', num2str(iY),'_Z', num2str(iZ)];
                        
                        for iLogEntry = 1:oLogger.iNumberOfLogItems
                            if strcmp(oLogger.tLogValues(iLogEntry).sLabel, ['Temperature ', sNodeName])
                                iLogIndex = oLogger.tLogValues(iLogEntry).iIndex;
                                mfLoggedTemperatures(iX, iY, iZ, :) = oLogger.mfLog(1:iTicks, iLogIndex);
                            end
                        end
                        
                    end
                end
            end
            mfFinalTemperatures = mfLoggedTemperatures(:, :, :, end);
            [X,Y,Z] = meshgrid(1:1:iNodesPerDirection);
            [Xq,Yq,Zq] = meshgrid(1:0.5:iNodesPerDirection);

            mfInterpolatedTemperature = interp3(X,Y,Z,mfFinalTemperatures,Xq,Yq,Zq);
            
            xslice = [1, round(iNodesPerDirection / 2, 0), iNodesPerDirection];   
            yslice = iNodesPerDirection;
            zslice = round(iNodesPerDirection / 2, 0);
            figure
            slice(Xq,Yq,Zq,mfInterpolatedTemperature,xslice,yslice,zslice)
            colorbar
            afTimePoints = 0:10:afTime(end);
            
            figure
            uicontrol('style','text','string','Current time:','Position',[ 20 20 65 20]);
            oClock = uicontrol('Style', 'edit', 'Position', [ 90 20 60 20], 'String', '0');
            
            for iTime = 1:length(afTimePoints)
                afTimeDiff = abs(afTime - afTimePoints(iTime));
                iTick = find(afTimeDiff == min(afTimeDiff), 1);
                
                mfTemperatures = mfLoggedTemperatures(:, :, :, iTick);
                
                mfInterpolatedTemperature = interp3(X,Y,Z,mfTemperatures,Xq,Yq,Zq);

                xslice = [1, round(iNodesPerDirection / 2, 0), iNodesPerDirection];   
                yslice = iNodesPerDirection;
                zslice = round(iNodesPerDirection / 2, 0);
                slice(Xq,Yq,Zq,mfInterpolatedTemperature,xslice,yslice,zslice);
                colorbar
                set(oClock, 'String', sprintf('%i',afTimePoints(iTime)));
                
                drawnow
                F(iTime) = getframe(gcf) ;
                pause(0.5);
                
            end
            
%             % create the video writer with 20 fps
%             writerObj = VideoWriter('TemperaturesCube.avi');
%             writerObj.FrameRate = 20; % this results in 20* Time Step as
%             speed for the video
%             % set the seconds per image
%             % open the video writer
%             open(writerObj);
%             % write the frames to the video
%             for i=1:length(F)
%                 % convert the image to a frame
%                 frame = F(i) ;
%                 writeVideo(writerObj, frame);
%             end
%             % close the writer object
%             close(writerObj);
            
        end
        
    end
    
end

