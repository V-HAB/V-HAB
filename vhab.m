classdef vhab
    %VHAB V-HAB Launch Class
    %   This class provides methods to initialize the MATLAB environment,
    %   methods to construct and run V-HAB simulations and to configure the
    %   logging scheme. 
    
    properties (GetAccess = public, Constant = true)
        poSims   = containers.Map();
        pOptions = containers.Map({ 'iTickRepIntv', 'iTickRepIntvMinor', 'iTimeRepIntv', 'bDump', 'sHost' }, { 100, 10, 60, false, '' });

        fLastDispTime = 0;      % So we can calulate the delta t between the 100*X ticks display
    end
    
    methods (Static = true)
        function init()
            % check if subdirs on path!
            disp('--------------------------------------')
            disp('-------- V-HAB Initialization --------')
            disp('--------------------------------------')
            addpath([ strrep(pwd(), '\', '/') '/lib' ]);
            addpath([ strrep(pwd(), '\', '/') '/core' ]);
            addpath([ strrep(pwd(), '\', '/') '/user' ]);
        end
        
        
        function sSimulation = sim(sSimulation, varargin)
            vhab.init();
            
            %if length(strfind(sSimulation, '.')) == 1
            %    sSimulation = [ sSimulation '.main' ];
            %end
            
            poSims = vhab.poSims;
            
            % Delete old sim of exists
            if poSims.isKey(sSimulation)
                delete(poSims(sSimulation));
            end
            
            % Create new sim and write to poSims by path
            simConstructor      = str2func(sSimulation);
            disp('Assembling Simulation Model...')
            hTimer = tic();
            %TODO seems to not work, vhab.poSims still empty after .exec??
            poSims(sSimulation) = simConstructor(varargin{:});
            disp(['Model Assembly Completed in ', num2str(toc(hTimer)), ' seconds!'])
            
            poSims(sSimulation).bind('tick.post', @vhab.disp);
            
            assignin('base', 'oLastSimObj', poSims(sSimulation));
        end
        
        
        function clear()
            csKeys = vhab.poSims.keys();
            
            for iI = 1:length(csKeys)
                delete(vhab.poSims(csKeys{iI}));
            end
            
            vhab.poSims.remove(csKeys);
            
            % Clearing the workspace and old classes
            % This is done to ensure that all classes are correctly
            % recompiled. If this is not done, some existing classes might
            % be reused without taking into account changes made to them in
            % between simulation runs.
            % If there are still open windows, MATLAB will issue warnings
            % about the window classes, that they can't be deleted. These
            % warnings are supressed by turning off all warnings before
            % clearing. They are turned back on afterwards.
            warning('off','all');
            evalin('base','clear all');
            evalin('base','clear classes');
            warning('on','all');
        end
        
        function oSimRtn = exec(sSimulation, varargin)
            % Clear all existing sims, and run provided sim (uses the
            % default max. time/tick conditions on the sim object)
            disp('Clearing MATLAB classes...')
            hTimer = tic();
            % Save all breakpoints so we can restore them after the clear
            % command.
            tBreakpoints = dbstatus('-completenames');
            vhab.clear();
            disp(['Classes cleared in ', num2str(toc(hTimer)), ' seconds!'])
            
            % Restore breakpoints if there were any.
            if numel(tBreakpoints) > 0
                dbstop(tBreakpoints);
            end
            
            sSimulation = vhab.sim(sSimulation, varargin{:});
            
            oSim = vhab.poSims(sSimulation);
            
            disp('Initialization complete!')
            disp('--------------------------------------')
            disp('Starting simulation run...')
            oSim.run();
            
            
            if nargout >= 1, oSimRtn = oSim; end;
        end
        
        
        function setReportInterval(iTicks, iMinorTicks)
            % Set the interval in which the tick and the sim time are
            % reported to the console.
            
            pOptions = vhab.pOptions;
            
            if ~isempty(iTicks)
                
                if mod(iTicks, 1) ~= 0, error('Ticks needs to be integer.'); end;
                
                pOptions('iTickRepIntv') = iTicks;
            end
            
            if (nargin >= 2) && ~isempty(iMinorTicks)
                
                if mod(iMinorTicks, 1) ~= 0, error('Minor ticks needs to be integer.'); end;
                
                if mod(iTicks / iMinorTicks, 1) ~= 0
                    error('Minor tick needs to be a whole-number divisor of major tick (e.g. 25 vs. 100, 10 vs. 100)');
                end
                
                pOptions('iTickRepIntvMinor') = iMinorTicks;
            end
        end
        
        function setDump(bDump)
            pOptions = vhab.pOptions;
            
            if nargin < 1 || isempty(bDump), bDump = false; end;
            
            pOptions('bDump') = ~~bDump;
            
            if nargin >= 2
                pOptions('sHost') = sHost;
            end
            
            
            % Also set config in base - create serializers
            base.activateSerializers();
        end
        
        function disp(oEvt)
            pOptions = vhab.pOptions;
            
            
            oSim     = oEvt.oCaller;
            %pOptions = vhab.pOptions;
            %TODO better reporting options ... see below
            
            
            % LOGGER / Serializer (ignore for now)
            
            %disp('#######################################################');
            %disp(vhab.pOptions('bDump'));
            %disp('#######################################################');
            if pOptions('bDump')
                %TODO-OKT14 this host thing is a bad hack, probably doesn't always work so change the serializer, either implement some nice way to
                %           send options to serializer (host), or at least serializer should prefix every sURL with something,
                %           so URIs can really be identified (e.g. 'uri:/matter/store/abc' or so) - or just localhost/127.0.0.1?
                % AND also the Inf/NaN stuff!
                
                sHost = pOptions('sHost');
                
                if ~isempty(sHost)
                    %disp([ '>>{{>>' strrep(base.dump(), '":"/', [ '":"' sHost '/' ]) '<<}}<<' ]);
                    disp([ '>>{{>>' strrep(strrep(base.dump(), '"/', [ '"' sHost '/' ]), ':Inf', ':null') '<<}}<<' ]);
                else
                    disp([ '>>{{>>' strrep(base.dump(), ':Inf', ':null') '<<}}<<' ]);
                end
                
                
                return;
            end
            
            
            
            
            % Minor tick?
            if (mod(oSim.oTimer.iTick, vhab.pOptions('iTickRepIntvMinor')) == 0) && (oSim.oTimer.fTime > 0)
                % Major tick -> remove printed minor tick characters
                if (mod(oSim.oTimer.iTick, vhab.pOptions('iTickRepIntv')) == 0)
                    %fprintf('\n');
                    
                    iDeleteChars = 1 * ceil(vhab.pOptions('iTickRepIntv') / vhab.pOptions('iTickRepIntvMinor')) - 1;
                    fprintf(repmat('\b', 1, iDeleteChars));
                else
                    %fprintf('%f\t', oSim.oTimer.fTime);
                    
                    fprintf('.');
                end
            end
            
            if mod(oSim.oTimer.iTick, vhab.pOptions('iTickRepIntv')) == 0
                %TODO store last tick disp fTime on some containers.Map!
                %disp([ num2str(oSim.oTimer.iTick) ' (' num2str(oRoot.oData.oTimer.fTime - fLastTickDisp) 's)' ]);
                %fLastTickDisp = oRoot.oData.oTimer.fTime;
                fDeltaTime = oSim.oTimer.fTime - oSim.oTimer.fLastTickDisp;
                oSim.oTimer.fLastTickDisp = oSim.oTimer.fTime;
                %disp([ num2str(oSim.oTimer.iTick), ' (', num2str(oSim.oTimer.fTime), 's) (Delta Time ', num2str(fDeltaTime), 's)']);
                fprintf('%i\t(%fs)\t(Tick Delta %fs)\n', oSim.oTimer.iTick, oSim.oTimer.fTime, fDeltaTime);
                
                if exist('STOP', 'file') == 2
                    oSim.iSimTicks = oSim.oTimer.iTick + 5;
                    oSim.bUseTime  = false;
                end
            end
            
            %TODO see above, store somewhere. For Sim vs. Real Time, use
            %     the oSim attrs fTime <-> fRuntimeTick, fRuntimeLog
            %     -> sim can be executed in separate runs, using advanceTo
            %        or the likes. Should sim store data, e.g. the start
            %        time (system time) for all runs, and map the runtime
            %        attributes to those runs? (sim vs. real time can be
            %        examined for each run separately ...)
            
            %             if oRoot.oData.oTimer.fTime >= fNextDisp
            %                 fNextDisp = fNextDisp + 60;
            %                 fElapsed  = fElapsed + toc(hElapsed);
            %
            %                 disp([ 'Sim  Time: ' tools.secs2hms(oRoot.oData.oTimer.fTime) ]);
            %                 disp([ 'Real Time: ' tools.secs2hms(fElapsed) ]);
            %
            %                 hElapsed = tic();
            %             end
        end
        
        
        function plot(sSim, tOpt)
            %TODO implement configurable plot functionality?
            %     tOpt on first level -> plot with name, axis labels etc
            %     then 'tData' -> reference mfLog entries and provide name
            %     --> tOpt on simulation object (like csLogs)
        end
    end
    
end

