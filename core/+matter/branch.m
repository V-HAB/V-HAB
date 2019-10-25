classdef branch < base.branch
    % Matter base branch class definition. Here all basic properties and
    % methodes that all matter branches require are defined
    
    properties (SetAccess = protected, GetAccess = public)
        
        % Flows belonging to this branch
        aoFlows = matter.flow.empty();
        
        % Array with f2f processors in between the flows
        aoFlowProcs = matter.procs.f2f.empty();
        
        % Amount of flows / procs
        iFlows = 0;
        iFlowProcs = 0;
        
        % Current flow rate on branch
        fFlowRate = 0;
        
        % Last couple of flow rates - used to test if below rounding prec
        afFlowRates = ones(1, 10);
        
        % Do we need to trigger the setFlowRate event?
        bTriggerSetFlowRateCallbackBound = false;
        
        % If the RIGHT side of the branch is an interface (i.e. i/f to the
        % parent system), store its index on the aoFlows here to make it
        % possible to remove those connections later!
        iIfFlow;
    end
    
    properties (SetAccess = private, GetAccess = public)
        % Thermal branch which solves the thermal energy transport of this
        % matter branch
        oThermalBranch;
    end
    
    methods
        function this = branch(oContainer, xLeft, csProcs, xRight, sCustomName)
            %% matter branch class constructor
            %
            % creates a new matter branch object which can be used to
            % transport matter between two different phases
            % 
            % Required Inputs:
            % oContainer:   The vsys in which the branch is located
            % xLeft/xRight: The left/right side interface of the branch. It
            %               can be either a 'StoreName.ExMeName' reference
            %               an Interface Name or a phase object. If a phase
            %               object is passed in a corresponding ExMe is
            %               automatically created
            % csProcs:      A cell array with the names of all F2F
            %               processors as entry e.g. {'Pipe_1', 'Fan_1'}
            % sCustomName:  A user defined name for the branch which can be
            %               used to find it in the struct toBranches of the
            %               vsys to access its values. Especially helpful
            %               in larger models
            %
            % Note that if the branch is defined with an interface, the
            % connections must always be from subsystem to parent system.
            % Meaning the parent system has the Interface on the left side
            % (xLeft), while the subsystem has it on the right side
            % (xRight). The branch on the parent system will be deleted
            % while the simulation is constructed and will then no longer
            % be present. Only the subsystem will then have a branch in its
            % toBranches and aoBranches struct which performs the specified
            % connection of the two interface branches
            
            if nargin < 5
                sCustomName = [];
            end
            
            % Calling the parent constructor
            this@base.branch(oContainer, xLeft, csProcs, xRight, sCustomName, 'matter');
            
            % Adding the branch to our matter.container
            this.oContainer.addBranch(this);
            
            % Counting the number of flows and processors in this branch
            this.iFlows     = length(this.aoFlows);
            this.iFlowProcs = length(this.aoFlowProcs);
            
            %% Construct asscociated thermal branch
            % To model the mass-bound heat (advective) transfer we need a
            % thermal branch in parallel to the matter branch. The required
            % thermal exmes on the capacities have already been created in
            % conductor for every f2f processor in this branch. 
            if length(csProcs) >= 1
                for iProc = 1:length(csProcs)
                    thermal.procs.conductors.fluidic(this.oContainer, csProcs{iProc}, this);
                end
            else
                % Branches without a f2f can exist (e.g. manual branches)
                % however for the thermal branch we always require at least
                % one conductor
                
                % Constructing the name of the thermal conductor by adding
                % the string '_Conductor' to either the custom name or
                % regular name of this branch. 
                if ~isempty(this.sCustomName)
                    csProcs{1} = [this.sCustomName, '_Conductor'];
                else
                    csProcs{1} = [this.sName, '_Conductor'];
                end
                
                % Since this name will be used as a struct field name, we
                % need to make sure it doesn't exceed the maximum field
                % name length of 63 characters. 
                if length(csProcs{1}) > 63
                    % Generating some messages for the debugger
                    if ~base.oDebug.bOff
                        this.out(3,1,'matter.branch','Truncating automatically generated thermal conductor name.');
                        this.out(3,2,'matter.branch','Old name: %s', csProcs(1));
                    end
                    
                    % Truncating the name
                    csProcs{1} = csProcs{1}(1:63);
                    
                    % More debugging output
                    if ~base.oDebug.bOff
                        this.out(3,2,'matter.branch','New name: %s', csProcs(1));
                    end
                    
                end
                
                thermal.procs.conductors.fluidic(this.oContainer, csProcs{1}, this);
            end
            
            % Now we have everything we need, so we can call the thermal
            % branch constructor. 
            this.oThermalBranch = thermal.branch(this.oContainer, xLeft, csProcs, xRight, this.sCustomName, this);
        end
        
        function createProcs(this, csProcs)
            %% Creating flow objects between the processors
            %
            % Loops through the provided f2f processors and creates flow
            % object in between all of them, so that the branch always
            % consists of ExMe, Flow, F2F, Flow, F2F, ... , F2F, Flow, ExMe
            %
            % Required Inputs:
            % csProcs:      A cell array with the names of all F2F
            %               processors as entry e.g. {'Pipe_1', 'Fan_1'}
            
            for iI = 1:length(csProcs)
                sProc = csProcs{iI};
                
                if ~isfield(this.oContainer.toProcsF2F, sProc)
                    this.throw('branch', 'F2F proc %s not found on system this branch belongs to!', sProc);
                end
                
                % Unless this is the first processor in a branch with an
                % interface flow at its left side, we connect the last flow
                % in the aoFlows property to the currently selected
                % processor.
                if ~this.abIf(1) || (iI ~= 1)
                    % Connect to previous flow (the 'left' port of the proc
                    % goes to the 'out' port of the previous flow)
                    this.oContainer.toProcsF2F.(sProc).addFlow(this.aoFlows(end));
                end
                
                % Create flow
                oFlow = matter.flow(this);
                this.aoFlows(end + 1) = oFlow;
                
                % Connect the new flow - 'right' of proc to 'in' of flow
                % Because of the possibility that the proc is not connected
                % to an in flow (interface branch - in flow not yet known),
                % we explicitly provide the port to connect the flow to.
                this.aoFlowProcs(end + 1) = this.oContainer.toProcsF2F.(sProc).addFlow(oFlow, 2);
            end
        end
        
        function setOutdated(this)
            %% matter branch setOutdated
            % Can be used by phases or f2f processors to request recalc-
            % ulation of the flow rate, e.g. after some internal parameters
            % changed (closing a valve).
            
            % Only trigger if not yet set
            if ~this.bOutdated
                this.bOutdated = true;

                % Trigger outdated so e.g. the branch solver can register a
                % postTick callback on the timer to recalc flow rate.
                this.trigger('outdated');
            end
        end
        
        function setIfLength(this, iLength)
            %% setIfLength
            % INTERNAL FUNCTION
            % this function is used by the base branch to inform this
            % branch object about the total number of elements within the
            % interface branch
            %
            % Required Input:
            % iLength: Total Number of elements within the Interface branch
            this.iIfFlow = iLength;
        end
        
        function setFlows(this, aoFlows, aoFlowProcs)
            %% setFlows
            % INTERNAL FUNCTIOn
            % this function is used by the base.branch to construct the
            % overall branch out of two interface branches!
            %
            % Required Inputs:
            % aoFlows:      Object Array of all the flows from both
            %               interface branches
            % aoFlowProcs:  Object array of all f2f processors from both
            %               interface branches
            if nargin < 3
                this.aoFlows    = aoFlows;
                this.iFlows     = length(this.aoFlows);
            else
                this.aoFlows    = aoFlows;
                this.iFlows     = length(this.aoFlows);
                
                this.aoFlowProcs = aoFlowProcs;
                this.iFlowProcs = length(this.aoFlowProcs);
            end
        end
        
        function oExme = getInEXME(this)
            %% getInExMe
            %
            % this function can be used to get the current ExMe from which
            % mass is flowing into the branch, depending on the current
            % flowrate. If currently there is no flowrate, the pressures of
            % the two exmes are compared and the one with the higher
            % pressure is used
            
            if this.fFlowRate == 0
                % We have no flow rate, so we use the properties of the
                % phase that contains more mass than the other! This 
                % ensures that the matter properties don't become zero if
                % the coExmes{1} phase is empty.
                
                afPressure = [ this.coExmes{1}.getExMeProperties(), this.coExmes{2}.getExMeProperties() ];
                if afPressure(1) >= afPressure(2); iWhichExme = 1; else; iWhichExme = 2; end
                
                for iI = 1:this.iFlowProcs
                    if isa(this.aoFlowProcs(iI), 'components.matter.valve') && ~this.aoFlowProcs(iI).bOpen
                        oExme = this.coExmes{1};
                        return;
                    end
                    
                    
                end
            else
                iWhichExme = (this.fFlowRate < 0) + 1;
            end

            oExme = this.coExmes{iWhichExme};

        end
        
        function [ this, unbindCallback ] = bind(this, sType, callBack)
            % Catch 'bind' calls, so we can set a specific boolean property to
            % true so the .trigger() method will only be called if there are
            % callbacks registered.
            [ this, unbindCallback ] = bind@event.source(this, sType, callBack);
            
            % Only do for setFlowRate as the other triggers always have
            % something bound to them!
            if strcmp(sType, 'setFlowRate')
                this.bTriggerSetFlowRateCallbackBound = true;
            end
        end
        
        function setFlowRate(this, fFlowRate, afPressureDrops)
            %% matter branch setFlowRate
            % INTERNAL FUNCTION! The registerHandler function of
            % base.branch provides access to this function for ONE solver,
            % and only that solver is allowed to set the flowrate for the
            % branch. Unfortunatly since base.branch is a parent class this
            % function cannot be protected or private.
            %
            % sets the flowrate for the branch and all flow objects, as
            % well as the pressures for the flow objects
            %
            % Required Inputs:
            % fFlowRate:        New flowrate for the branch in kg/s
            % afPressureDrops:  Pressure Drops produced by the f2f
            %                   processors. Negative values in this input
            %                   represent pressure rises from e.g. fans
            
            if this.abIf(1), this.throw('setFlowRate', 'Left side is interface, can''t set flowrate on this branch object'); end
            
            % Connected phases have to do a massupdate before we set the
            % new flow rate - so the mass for the LAST time step, with the
            % old flow rate, is actually moved from tank to tank.
            for iE = 1:2
                this.coExmes{iE}.oPhase.registerMassupdate();
            end
            
            this.afFlowRates = [ this.afFlowRates(2:end) fFlowRate ];
            
            % If sum of the last ten flow rates is < precision, set flow
            % rate to zero
            if tools.round.prec(sum(this.afFlowRates), this.oTimer.iPrecision) == 0
                fFlowRate = 0;
                
                afPressureDrops = zeros(1,this.iFlowProcs);
                
            end
            
            this.fFlowRate = fFlowRate;
            this.bOutdated = false;
            
            % No pressure? Distribute equally.
            if nargin < 3 || isempty(afPressureDrops) || any(isinf(afPressureDrops))
                fPressureDiff = (this.coExmes{1}.getExMeProperties() - this.coExmes{2}.getExMeProperties());
                
                % Each flow proc produces the same pressure drop, the sum
                % being the actual pressure difference.
                afPressureDrops = ones(1, this.iFlowProcs) * (fPressureDiff) / this.iFlowProcs;
                
                % Note: no matter the flow direction, positive values on
                % afPRessure always denote a pressure DROP
            end
            
            % Update data in flows
            this.hSetFlowData(this.aoFlows, this.getInEXME(), fFlowRate, afPressureDrops);
            
            if this.bTriggerSetFlowRateCallbackBound
                this.trigger('setFlowRate');
            end
        end
    end
    
    methods (Sealed = true)
        function seal(this)
            %% matter branch seal
            % seals the branch object and prevents further changes
            % also triggers sealing the flow objects and receives the
            % corresponding function handles to set their data
            if this.bSealed
                this.throw('seal', 'Already sealed');
            end
            
            for iI = 1:length(this.aoFlows)
                % If last flow and right interface, provide true as param,
                % which means that the .seal() returns a remove callback
                % which allows us to deconnect the flow from the f2f proc
                % in the "outer" system (supsystem).
                if this.abIf(2) && (this.iIfFlow == iI)
                    [ this.hSetFlowData, this.hRemoveIfProc ] = this.aoFlows(iI).seal(true);
                
                % Only need the callback reference once ...
                elseif iI == 1
                    this.hSetFlowData = this.aoFlows(iI).seal(false, this);
                else
                    this.aoFlows(iI).seal(false, this);
                end
            end
            
            for iI = 1:length(this.aoFlowProcs)
                this.aoFlowProcs(iI).seal(this);
            end

            % now we no longer need the function to get the exmes from the
            % other IF branch because we created a single branch from it
            this.hGetBranchData = [];
            
            this.bSealed = true;
        end
    end
end