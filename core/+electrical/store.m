classdef store < base
    %SOURCE Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (SetAccess = private, GetAccess = public)
        % Reference to the circuit (electrical.circuit) in which this source is 
        % contained
        oCircuit;
        
        % Name of source
        % @type string
        sName;
        
        % How much charge is contained in this source? Initialized as inf,
        % because that is the most common application. If this is a battery
        % or some other type of electrical energy storage device, the
        % value will be changed. 
        fCapacity = inf; 
        
        oPositiveTerminal;
        oNegativeTerminal;
        
        
        bSealed = false;
        
        % Timer object, needs to inherit from / implement event.timer
        oTimer;
        fLastUpdate = 0;
        fTimeStep = 0;
    end
    
    
    methods
        function this = store(oCircuit, sName, fCapacity)
            % Create an electrical store object. 
            
            this.oCircuit  = oCircuit;
            this.sName     = sName;
            
            if nargin > 2
                this.fCapacity = fCapacity;
            end
            
            % Add this store object to the electrical.circuit
            this.oCircuit.addStore(this);
            
            this.oPositiveTerminal = electrical.terminal(this);
            this.oNegativeTerminal = electrical.terminal(this);
            
        end
        
%         function addTerminal(this, oTerminal)
%             if oTerminal.iSign < 0
%                 if isempty(this.oNegativeTerminal)
%                     this.throw('addTerminal','This electrical store (%s) already has a negative terminal.',this.sName);
%                 else
%                     this.oNegativeTerminal = oTerminal;
%                 end
%             else 
%                 if isempty(this.oNegativeTerminal)
%                     this.throw('addTerminal','This electrical store (%s) already has a positive terminal.',this.sName);
%                 else
%                     this.oPositiveTerminal = oTerminal;
%                 end
%                 
%             end
%         end
        
        
        function exec(this)
            %TODO-NOW this.toProcsP2P exec, flow and stationary.
            %this.throw('exec', 'Not implemented!');
        end
        
        function update(this)
            % Update 
            
        end
        
        function setNextTimeStep(this, fTimeStep)
            % This method is called from the phase object during its
            % calculation of a new timestep. The phase.calculateTimeStep()
            % method is called in the post-tick of every mass update (NOT
            % phase update!). Within a tick, the first thing that is done,
            % is the calling of store.update(). This sets the fTimeStep
            % property of the store to the default time step (currently 60
            % seconds). After that the phases are updated, which also calls
            % calculateTimeStep(). In this function
            % (store.setNextTimeStep()), the store's time step is only set,
            % if the phase time step is smaller than the currently set time
            % step. This ensures, that the slowest phase sets the time step
            % of the store it is in. 
            
            % So we will first get the next execution time based on the
            % current time step and the last time this store was updated.
            fCurrentNextExec = this.fLastUpdate + this.fTimeStep;
            
            % Since the fTimeStep parameter that is passed on by the phase
            % that called this method is based on the current time, we
            % calculate the potential new execution time based on the
            % timer's current time, rather than the last update time for
            % this store.
            fNewNextExec     = this.oTimer.fTime + fTimeStep;
            
            % Now we can compare the current next execution time and the
            % potential new execution time. If the new execution time would
            % be AFTER the current execution time, it means that the phase
            % that is currently calling this method is faster than a
            % previous caller. In this case we do nothing and just return.
            if fCurrentNextExec < fNewNextExec
                return;
            end
            
            % The new time step is smaller than the old one, so we can
            % actually set then new timestep. The setTimeStep() method
            % calls a function in the timer object that will update the
            % timer values accordingly. This is important because otherwise
            % the time step updates that happen during post-tick operations
            % would not be taken into account when the timer calculates the
            % overall time step during the next tick.
            this.setTimeStep(fTimeStep, true);
            
            % Finally we set this stores fTimeStep property to the new time
            % step.
            this.fTimeStep = fTimeStep;
        end
    end
    
    
    methods
        
        function seal(this)
            % See doc for bSealed attr.
            %
            %TODO create indices of phases, their ports etc! Trigger event?
            %     -> external solver can build stuff ... whatever, matrix,
            %        function handle cells, indices ...
            %     also create indices for amount of phases, in phases for
            %     amount of ports etc
            
            if this.bSealed, return; end;
            
            
            
            % Bind the .update method to the timer, with a time step of 0
            % (i.e. smallest step), will be adapted after each .update
            this.setTimeStep = this.oTimer.bind(@(~) this.update(), 0);
            
            
            this.iPhases    = length(this.aoPhases);
            this.csProcsP2P = fieldnames(this.toProcsP2P);
            
            % Find stationary p2ps
            %TODO split those up completely, stationary/flow p2ps?
            for iI = 1:length(this.csProcsP2P)
                if isa(this.toProcsP2P.(this.csProcsP2P{iI}), 'matter.procs.p2ps.stationary')
                    this.aiProcsP2Pstationary(end + 1) = iI;
                end
            end
            
            
            % Update volume on phases
            this.setVolume();
            
            
            % Seal phases
            for iI = 1:length(this.aoPhases)
                this.aoPhases(iI).seal(); 
            end
            
            this.bSealed = true;
        end
        
        function oTerminal = getTerminal(this, sTerminalName)
            if strcmp(sTerminalName, 'positive')
                oTerminal = this.oPositiveTerminal;
            elseif strcmp(sTerminalName, 'negative')
                oTerminal = this.oNegativeTerminal;
            else
                this.throw('getTerminal','There is no terminal ''%s'' on store %s.', sTerminalName, this.sName);
            end
        end
        
        
        
        function addP2P(this, oProcP2P)
            % Get sName from oProcP2P, add to toProcsP2P
            %
            %TODO better way of handling stationary and flow p2ps!
            
            if this.bSealed
                this.throw('addP2P', 'Store already sealed!');
            elseif isfield(this.toProcsP2P, oProcP2P.sName)
                this.throw('addP2P', 'P2P proc already exists!');
            elseif this ~= oProcP2P.oStore
                this.throw('addP2P', 'P2P proc does not have this store set as parent store!');
            end
            
            this.toProcsP2P.(oProcP2P.sName) = oProcP2P;
        end
    end
    
    
    
   
    
end

