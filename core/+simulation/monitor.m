classdef monitor < base & event.source
    %MONITOR Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (SetAccess = private, GetAccess = public)
        % Sim infra with oSimulationRoot etc
        oSimulationInfrastructure;
    end
    
    
    properties (SetAccess = private, GetAccess = protected)
        % Event name to method name
        tsEvents = struct(...
            'init_pre', 'onInitPre', ...
            'init_post', 'onInitPost', ...
            'tick_pre', 'onTickPre', ...
            'tick_post', 'onTickPost', ...
            'pause', 'onPause', ...
            'finish', 'onFinish', ...
            'run', 'onRun' ...
        );

        % Events that will be auto-registered
        csEvents;
    end
    
    methods
        function this = monitor(oSimulationInfrastructure, csEvents) %tsEvents)
            this.oSimulationInfrastructure = oSimulationInfrastructure;
            
%             if nargin >= 2 && isstruct(tsEvents)
%                 this.tsEvents = tools.struct.mergeStructs(this.tsEvents, tsEvents);
%             end
            
            if nargin >= 2, this.csEvents = csEvents; end
            
            
            %TODO
            % * cbs for step/tick, pause, stop, start, init, finish, ...
            %       (tick post, pre! etc). -> CONFIGURABLE!
            %   INIT pre/post! From .container for addChild?
            this.initializeEvents();
        end
    end
    
    
    methods (Access = protected)
        function initializeEvents(this)
            %csEvents = fieldnames(this.tsEvents);
            
            
            for iE = 1:length(this.csEvents)
                sEvent = this.csEvents{iE};
                
                if isempty(sEvent), continue; end
                
                % Stupid Matlab ... @this.(sMethod) does not work but using
                % the shorthand saves a lot of exec time! So ... eval!
                sMethod  = this.tsEvents.(sEvent);
                %callBack = eval([ '@(~) this.' sMethod '()' ]);
                callBack = eval([ '@this.' sMethod ]);
                
                this.oSimulationInfrastructure.bind(sEvent, callBack);
            end
        end
    end
    
    
    methods (Access = protected)
        
        % Placeholder methods
        function onInitPre(this, ~)

        end

        function onInitPost(this, ~)

        end

        function onTickPre(this, ~)

        end

        function onTickPost(this, ~)

        end

        function onPause(this, ~)

        end

        function onFinish(this, ~)

        end

        function onRun(this, ~)

        end
        
    end
end

