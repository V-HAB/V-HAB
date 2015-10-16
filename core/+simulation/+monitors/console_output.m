classdef console_output < simulation.monitor
    %LOGGER_BASIC Summary of this class goes here
    %   Detailed explanation goes here
    
    
    
    properties (SetAccess = protected, GetAccess = public)
        iMajorReportingInterval = 100;
        iMinorReportingInterval = 10;
        
        % We need this to calculate the delta time between command window outputs.
        fLastTickDisp = 0;
    end
    
    methods
        function this = console_output(oSimulationInfrastructure, iMajorReportingInterval, iMinorReportingInterval)
            %this@simulation.monitor(oSimulationInfrastructure, struct('tick_post', 'logData', 'init_post', 'init'));
            this@simulation.monitor(oSimulationInfrastructure, { 'tick_post', 'pause', 'finish' });
            
            if nargin >= 2 && ~isempty(iMajorReportingInterval)
                this.iMajorReportingInterval = iMajorReportingInterval;
            end
            
            if nargin >= 3 && ~isempty(iMinorReportingInterval)
                this.iMinorReportingInterval = iMinorReportingInterval;
            end
        end
        
        
        function this = setReportingInterval(this, iTicks, iMinorTicks)
            % Set the interval in which the tick and the sim time are
            % reported to the console.
            
            if ~isempty(iTicks)
                
                if mod(iTicks, 1) ~= 0, error('Ticks needs to be integer.'); end;
                
                this.iMajorReportingInterval = iTicks;
            end
            
            if (nargin >= 2) && ~isempty(iMinorTicks)
                
                if mod(iMinorTicks, 1) ~= 0, error('Minor ticks needs to be integer.'); end;
                
                if mod(iTicks / iMinorTicks, 1) ~= 0
                    error('Minor tick needs to be a whole-number divisor of major tick (e.g. 25 vs. 100, 10 vs. 100)');
                end
                
                this.iMinorReportingInterval = iMinorTicks;
            end
        end
    end
    
    
    methods (Access = protected)
        
        function this = onPause(this)
            disp('');
            disp('------------------------------------------------------------------------');
            disp('SIMULATION PAUSED');
            disp('------------------------------------------------------------------------');
        end
        
        
        function this = onFinish(this)
            % The '.'s from the minor tick don't end with a newline, so
            % explicitly display one. Will lead to an extra, unneeded new-
            % line for cases where the simulation did exactly stop after a
            % major tick display.
            disp('');
            
% %             disp('------------------------------------------------------------------------');
% %             disp('SIMULATION FINISHED - STATS!');
% %             disp('------------------------------------------------------------------------');
            
            
            
            oSimInfra = this.oSimulationInfrastructure;
            oTimer    = oSimInfra.oSimulationContainer.oTimer;
            
            disp('------------------------------------------------------------------------');
            disp([ 'Sim Time:     ' num2str(oTimer.fTime) 's in ' num2str(oTimer.iTick) ' ticks' ]);
            disp([ 'Sim Runtime:  ' num2str(oSimInfra.fRuntimeTick + oSimInfra.fRuntimeOther) 's, from that for monitors (e.g. logging): ' num2str(oSimInfra.fRuntimeOther) 's' ]);
            disp([ 'Sim factor:   ' num2str(oSimInfra.fSimFactor) ' [-] (ratio)' ]);
            disp([ 'Avg Time/Tick:' num2str(oTimer.fTime / oTimer.iTick) ' [s]' ]);
            disp([ 'Mass lost:    to be re-implemented' ]);
% %             disp([ 'Mass lost:    ' num2str(sum(this.mfLostMass(end, :))) 'kg' ]);
% %             disp([ 'Mass balance: ' num2str(sum(this.mfTotalMass(1, :)) - sum(this.mfTotalMass(end, :))) 'kg' ]);
            disp([ 'Minimum Time Step * Total Sim Time: ' num2str(oTimer.fTimeStep * oTimer.fTime) ]);
            disp([ 'Minimum Time Step * Total Ticks:    ' num2str(oTimer.fTimeStep * oTimer.iTick) ]);
            disp('------------------------------------------------------------------------');

        end
        
        
        function onTickPost(this)
            
            oSim = this.oSimulationInfrastructure.oSimulationContainer;
            
            
            % Minor tick?
            if (this.iMinorReportingInterval > 0) && (mod(oSim.oTimer.iTick, this.iMinorReportingInterval) == 0) && (oSim.oTimer.fTime > 0)
                % Major tick -> remove printed minor tick characters
                if (mod(oSim.oTimer.iTick, this.iMajorReportingInterval) == 0)
                    %fprintf('\n');
                    
                    % Removed - not really able to handle e.g. other log
                    % messages from other code.
                    %TODO as soon as debug class exists, could be handled 
                    %     through that (used instead of disp/fprintf)
                    %iDeleteChars = 1 * ceil(this.iMajorReportingInterval / this.iMinorReportingInterval) - 1;
                    %fprintf(repmat('\b', 1, iDeleteChars));
                else
                    %fprintf('%f\t', oSim.oTimer.fTime);
                    
                    fprintf('\b .\n');
                end
            end
            
            if mod(oSim.oTimer.iTick, this.iMajorReportingInterval) == 0
                %TODO store last tick disp fTime on some containers.Map!
                %disp([ num2str(oSim.oTimer.iTick) ' (' num2str(oRoot.oData.oTimer.fTime - fLastTickDisp) 's)' ]);
                %fLastTickDisp = oRoot.oData.oTimer.fTime;
                
                fDeltaTime = oSim.oTimer.fTime - this.fLastTickDisp;
                this.fLastTickDisp = oSim.oTimer.fTime;
                
                %disp([ num2str(oSim.oTimer.iTick), ' (', num2str(oSim.oTimer.fTime), 's) (Delta Time ', num2str(fDeltaTime), 's)']);
                fprintf('%i\t(%fs)\t(Tick Delta %fs)\n', oSim.oTimer.iTick, oSim.oTimer.fTime, fDeltaTime);
            end
        end
        
    end
end

