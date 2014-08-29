classdef vhab
    %VHAB Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (GetAccess = public, Constant = true)
        poSims   = containers.Map();
        pOptions = containers.Map({ 'iTickRepIntv', 'iTimeRepIntv' }, { 100, 60 });
    end
    
    methods (Static = true)
        function init()
            % check if subdirs on path!
            
            addpath([ strrep(pwd(), '\', '/') '/lib' ]);
            addpath([ strrep(pwd(), '\', '/') '/core' ]);
            addpath([ strrep(pwd(), '\', '/') '/user' ]);
        end
        
        
        function sSimulation = sim(sSimulation, varargin)
            vhab.init();
            
            if length(strfind(sSimulation, '.')) == 1
                sSimulation = [ sSimulation '.main' ];
            end
            
            poSims = vhab.poSims;
            
            % Delete old sim of exists
            if poSims.isKey(sSimulation)
                delete(poSims(sSimulation));
            end
            
            % Create new sim and write to poSims by path
            simConstructor      = str2func(sSimulation);
            %TODO seems to not work, vhab.poSims still empty after .exec??
            poSims(sSimulation) = simConstructor(varargin{:});
            
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
        
        function oSim = exec(sSimulation, varargin)
            % Clear all existing sims, and run provided sim (uses the
            % default max. time/tick conditions on the sim object)
            
            vhab.clear();
            
            sSimulation = vhab.sim(sSimulation, varargin{:});
            
            oSim = vhab.poSims(sSimulation);
            
            oSim.run();
        end
        
        
        function setReportInterval(iTicks, fTime)
            % Set the interval in which the tick and the sim time are
            % reported to the console.
            
            pOptions = vhab.pOptions;
            
            if ~isempty(iTicks)
                poOptions('iTickRepIntv') = iTicks;
            end
            
            if nargin >= 2
                poOptions('iTimeRepIntv') = fTime;
            end
        end
        
        function disp(oEvt)
            oSim     = oEvt.oCaller;
            %pOptions = vhab.pOptions;
            %TODO better reporting options ... see below
            
            if mod(oSim.oTimer.iTick, vhab.pOptions('iTickRepIntv')) == 0
                %TODO store last tick disp fTime on some containers.Map!
                %disp([ num2str(oSim.oTimer.iTick) ' (' num2str(oRoot.oData.oTimer.fTime - fLastTickDisp) 's)' ]);
                %fLastTickDisp = oRoot.oData.oTimer.fTime;
                disp([ num2str(oSim.oTimer.iTick) ' (' num2str(oSim.oTimer.fTime) 's)' ]);
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

