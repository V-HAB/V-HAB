classdef vhab
    %VHAB V-HAB Launch Class
    %   This class provides methods to initialize the MATLAB environment,
    %   methods to construct and run V-HAB simulations and to configure the
    %   logging scheme. 
    
    methods (Static = true)
        function init()
            % check if subdirs on path!
            disp('--------------------------------------')
            disp('-------- V-HAB Initialization --------')
            disp('--------------------------------------')
            addpath([ strrep(pwd(), '\', '/') '/lib'  ]);
            addpath([ strrep(pwd(), '\', '/') '/core' ]);
            addpath([ strrep(pwd(), '\', '/') '/user' ]);
            
            % The old V-HAB projects are collected in one big project that
            % is located in the 'old' folder. Users may or may not have
            % this project, so we check for the folder.
            if verLessThan('matlab', '9.4')
                if isdir([ strrep(pwd(), '\', '/') '/old' ]) %#ok<ISDIR>
                    addpath([ strrep(pwd(), '\', '/') '/old' ]);
                end
            else
                if isfolder([ strrep(pwd(), '\', '/') '/old' ])
                    addpath([ strrep(pwd(), '\', '/') '/old' ]);
                end
            end
        end
        
        
        
        function oSim = sim(sSimulation, varargin)
            vhab.init();
            
            % Construct the simulation object
            simConstructor = str2func(sSimulation);
            oSim           = simConstructor(varargin{:});
            
            
            % Now call .initialize() which wraps everything up. Very
            % important if e.g. several sim objs should be created before
            % running one of them (e.g. logging would get mixed up!)
            oSim.initialize();
        end
        
        
        function clear(bDontPreserveBreakpoints)
            if nargin < 1 || ~islogical(bDontPreserveBreakpoints)
                bDontPreserveBreakpoints = false;
            end
            
            
            % If an old simulation obj exists in the base workspace, remove
            % that explicitly just to make sure ...
            try
                oSim = evalin('base', 'oLastSimObj');
                delete(oSim);
            catch
                % Ignore all errors that occur. 
            end
            
            
            % FLUSH serializers / loggers
            % Only required if we're already initialized
            if exist('base','file') > 0
                base.flush();
            end
            
            
            disp('Clearing MATLAB classes...');
            hTimer = tic();
            % Save all breakpoints so we can restore them after the clear
            % command.
            tBreakpoints = dbstatus('-completenames');
            
            
            
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
            
            
            disp(['Classes cleared in ', num2str(toc(hTimer)), ' seconds!'])
            
            % Restore breakpoints if there were any.
            if bDontPreserveBreakpoints && (numel(tBreakpoints) > 0)
                dbstop(tBreakpoints);
            end
        end
        
        
        % The .exec method is basically just a shorthand for doing that:
        %   vhab.clear(); oSim = vhab.sim(...); oSim.run();
        function oSimRtn = exec(sSimulation, ptConfigParams, tSolverParams, varargin)
            
            % Clear all existing sims, and run provided sim (uses the
            % default max. time/tick conditions on the sim object)
            vhab.clear();
            
            % Default values for those parameters, so constructor for the
            % simulation does not have to check if they are present!
            if nargin < 2 || isempty(ptConfigParams), ptConfigParams = containers.Map(); end
            if nargin < 3 || isempty(tSolverParams),  tSolverParams   = struct(); end
            
            oSim = vhab.sim(sSimulation, ptConfigParams, tSolverParams, varargin{:});
            
            assignin('base', 'oLastSimObj', oSim);
            
            oSim.run();
            
            if nargout >= 1, oSimRtn = oSim; end
        end
        
        
        
        
%         function runner(this, tCfg)
%             % FROM runner_*
%             % Allow different configs (solver props and / or ptCfgs)
%             % Create all combinations before running
%             % ONE parfor loop, not nested!
%         end
        
        %TODO-RESTRUCTURING move to a monitor, e.g. json_dumper. Store
        %   bDump in dumpers per-simulation.
        %   Figure out a way to activate serializers in base class, has to
        %   be a global flag or something like that - its too late to set
        %   that in the monitor itself, as for example the
        %   simulation.infrastructure object would have to be serialized as
        %   well, for example!
        % pOptions = containers.Map({ 'bDump', 'sHost' }, { false, '' });
% %         function setDump(bDump)
% %             pOptions = vhab.pOptions;
% %             
% %             if nargin < 1 || isempty(bDump), bDump = false; end;
% %             
% %             pOptions('bDump') = ~~bDump;
% %             
% %             if nargin >= 2
% %                 pOptions('sHost') = sHost;
% %             end
% %             
% %             
% %             % Also set config in base - create serializers
% %             base.activateSerializers();
% %         end
        
        function disp(oEvt)
            %TODO-RESTRUCTURING move to dumper monitor
            %           => base class bDump flag - how to set?
% %             if pOptions('bDump')
% %                 %TODO-OKT14 this host thing is a bad hack, probably doesn't always work so change the serializer, either implement some nice way to
% %                 %           send options to serializer (host), or at least serializer should prefix every sURL with something,
% %                 %           so URIs can really be identified (e.g. 'uri:/matter/store/abc' or so) - or just localhost/127.0.0.1?
% %                 % AND also the Inf/NaN stuff!
% %                 
% %                 sHost = pOptions('sHost');
% %                 
% %                 if ~isempty(sHost)
% %                     %disp([ '>>{{>>' strrep(base.dump(), '":"/', [ '":"' sHost '/' ]) '<<}}<<' ]);
% %                     disp([ '>>{{>>' strrep(strrep(base.dump(), '"/', [ '"' sHost '/' ]), ':Inf', ':null') '<<}}<<' ]);
% %                 else
% %                     disp([ '>>{{>>' strrep(base.dump(), ':Inf', ':null') '<<}}<<' ]);
% %                 end
% %                 
% %                 
% %                 return;
% %             end
            
            
            
            
            %TODO-RESTRUCTURING implement in a monitor (same monitor
            %  that stops the sim when sim time is reached?)
% %             if mod(oSim.oTimer.iTick, vhab.pOptions('iTickRepIntv')) == 0
% %                 if exist('STOP', 'file') == 2
% %                     oSim.iSimTicks = oSim.oTimer.iTick + 5;
% %                     oSim.bUseTime  = false;
% %                 end
% %             end
        end
    end
    
end

