classdef console_output < simulation.monitor
    %LOGGER_BASIC Summary of this class goes here
    %   Detailed explanation goes here
    
    
    
    properties (SetAccess = protected, GetAccess = public)
        iMajorReportingInterval = 100;
        iMinorReportingInterval = 10;
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
            disp('------------------------------------------------------------------------');
            disp('SIMULATION PAUSED');
            disp('------------------------------------------------------------------------');
        end
        
        
        function this = onFinish(this)
            disp('------------------------------------------------------------------------');
            disp('SIMULATION FINISHED - STATS!');
            disp('------------------------------------------------------------------------');
        end
        
        
        function onTickPost(this)
            
            oSim = this.oSimulationInfrastructure.oSimulationContainer;
            
            
            % Minor tick?
            if (mod(oSim.oTimer.iTick, this.iMinorReportingInterval) == 0) && (oSim.oTimer.fTime > 0)
                % Major tick -> remove printed minor tick characters
                if (mod(oSim.oTimer.iTick, this.iMajorReportingInterval) == 0)
                    %fprintf('\n');
                    
                    iDeleteChars = 1 * ceil(this.iMajorReportingInterval / this.iMinorReportingInterval) - 1;
                    fprintf(repmat('\b', 1, iDeleteChars));
                else
                    %fprintf('%f\t', oSim.oTimer.fTime);
                    
                    fprintf('.');
                end
            end
            
            if mod(oSim.oTimer.iTick, this.iMajorReportingInterval) == 0
                %TODO store last tick disp fTime on some containers.Map!
                %disp([ num2str(oSim.oTimer.iTick) ' (' num2str(oRoot.oData.oTimer.fTime - fLastTickDisp) 's)' ]);
                %fLastTickDisp = oRoot.oData.oTimer.fTime;
                fDeltaTime = oSim.oTimer.fTime - oSim.oTimer.fLastTickDisp;
                oSim.oTimer.fLastTickDisp = oSim.oTimer.fTime;
                %disp([ num2str(oSim.oTimer.iTick), ' (', num2str(oSim.oTimer.fTime), 's) (Delta Time ', num2str(fDeltaTime), 's)']);
                fprintf('%i\t(%fs)\t(Tick Delta %fs)\n', oSim.oTimer.iTick, oSim.oTimer.fTime, fDeltaTime);
                
% %                 if exist('STOP', 'file') == 2
% %                     oSim.iSimTicks = oSim.oTimer.iTick + 5;
% %                     oSim.bUseTime  = false;
% %                 end
            end
        end
        
    end
end

