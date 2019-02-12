classdef (Abstract) monitor < base & event.source
    %MONITOR this is the basic class that provdes the framework for all other monitor subclasses. 
    %   The class provides common functionality to all simulation monitors,
    %   most importantly the automatic binding to events posted by the
    %   simulation infrastructure.
    
    % Private SetAccess to make sure there is only one place where this
    % property can be set.
    properties (SetAccess = private, GetAccess = public)
        % A reference to the simulation infrastructure object
        oSimulationInfrastructure;
    end
    
    % Private SetAccess to make sure there is only one place where this
    % property can be set and protected GetAccess because this
    % information should only be visible to the derived classes. 
    properties (SetAccess = private, GetAccess = protected)
        % A struct containing the links between the events that the
        % simulation infrastructure object announces and the methods of
        % this class that will be bound to each one.
        tsEvents = struct(...
            'init_pre',  'onInitPre', ...
            'init_post', 'onInitPost', ...
            'step_pre',  'onStepPre', ...
            'step_post', 'onStepPost', ...
            'pause',     'onPause', ...
            'finish',    'onFinish', ...
            'run',       'onRun' ...
        );

        % A cell of the events that will be auto-registered
        csEvents;
    end
    
    methods
        function this = monitor(oSimulationInfrastructure, csEvents)
            % Setting the reference property
            this.oSimulationInfrastructure = oSimulationInfrastructure;
            
            % The second input argument contains a cell of events that the
            % monitor implements. These must be a subset of the ones given
            % in the tsEvents property.
            if nargin >= 2
                this.csEvents = csEvents;
                
                % Now we loop through all of the events and bind them to
                % the according trigger of the simulation infrastructure
                for iEvent = 1:length(this.csEvents)
                    % Getting the name of the current event
                    sEvent = this.csEvents{iEvent};
                    
                    % Making sure it's not empty
                    if isempty(sEvent), continue; end
                    
                    % Extracting the method name of this class that is
                    % paired with the event in the tsEvents struct.
                    sMethod  = this.tsEvents.(sEvent);
                    
                    % Stupid Matlab ... @this.(sMethod) does not work but
                    % using the shorthand saves a lot of exec time! So we
                    % need to use eval() to get the function handle. 
                    hCallBack = eval([ '@this.' sMethod ]);
                    
                    % And finally we can bind the call back to the event. 
                    this.oSimulationInfrastructure.bind(sEvent, hCallBack);
                end
            end
        end
    end
    
    
   
    methods (Access = protected)
        % All of the methods within this block are placeholder methods that
        % can, but don't have to, be overloaded by child classes derived
        % from this one. Since they are optional, they have to be fully
        % implemented here, rather than making all of them abstract, which
        % would cause the same placeholder methods to be required in all
        % derived classes. This way they are only here once and the child
        % classes can focus only on the ones they actually need. 
        % The comments at the end of each line with the method names
        % suppress code warnings for unused variables. 
        
        function onInitPre(this, ~) %#ok<INUSD>

        end

        function onInitPost(this, ~) %#ok<INUSD>

        end

        function onStepPre(this, ~) %#ok<INUSD>

        end

        function onStepPost(this, ~) %#ok<INUSD>

        end

        function onPause(this, ~) %#ok<INUSD>

        end

        function onFinish(this, ~) %#ok<INUSD>

        end

        function onRun(this, ~) %#ok<INUSD>

        end
        
    end
end

