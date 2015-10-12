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
            addpath([ strrep(pwd(), '\', '/') '/lib' ]);
            addpath([ strrep(pwd(), '\', '/') '/core' ]);
            addpath([ strrep(pwd(), '\', '/') '/user' ]);
        end
        
        
        
        function oSim = sim(sSimulation, varargin)
            vhab.init();
            
            disp('Assembling Simulation Model...')
            hTimer = tic();
            
            % Construct the simulation object
            simConstructor = str2func(sSimulation);
            oSim           = simConstructor(varargin{:});
            
            disp(['Model Assembly Completed in ', num2str(toc(hTimer)), ' seconds!'])
        end
        
        
        function clear(bDontPreserveBreakpoints)
            if nargin < 1 || ~islogical(bDontPreserveBreakpoints),
                bDontPreserveBreakpoints = false;
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
            
            % If an old simualtion obj exists in the base workspace, remove
            % that explicitly just to make sure ...
            oSim = evalin('base', 'oLastSimObj');
            delete(oSim);
            
            % Clear all existing sims, and run provided sim (uses the
            % default max. time/tick conditions on the sim object)
            vhab.clear();
            
            % Default values for those parameters, so constructor for the
            % simulation does not have to check if they are present!
            if nargin < 2 || isempty(ptConfigParams), ptConfigParams = containers.Map(); end;
            if nargin < 3 || isempty(tSolverParams),  tSolverParams   = struct(); end;
            
            oSim = vhab.sim(sSimulation, ptConfigParams, tSolverParams, varargin{:});
            
            assignin('base', 'oLastSimObj', oSim);
            
            disp('Initialization complete!');
            disp('--------------------------------------');
            disp('Starting simulation run...');
            
            oSim.run();
            
            if nargout >= 1, oSimRtn = oSim; end;
        end
        
        
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

