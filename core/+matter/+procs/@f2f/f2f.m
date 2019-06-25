classdef f2f < base & matlab.mixin.Heterogeneous
    %F2F flow2flow processors
    %   Manipulate a matter flow/stream. Is connected to two different
    %   flows the left and right flow. Depending on the flowrate the left
    %   is the in flow and the right the outflow (positive flowrate) or
    %   vice versa (negative flowrate). And can manipulate the pressure or
    %   temperature of the flow but NOT the composition. If you want to
    %   model adsorption processes or somethin similar use P2Ps!
    
    properties (SetAccess = private, GetAccess = public)
        % Connected matter flows first entry aoFlows(1) is considered the
        % left flow while aoFlows(2) is considered the right flow
        aoFlows = matter.flow.empty();
        
        % Matter table
        oMT;
        
        % Timer
        oTimer;
        
        % Name of processor.
        sName;
        
        % Reference to the branch object
        oBranch;
        
        % Container (vsys) the f2f belongs to
        oContainer;
        
        % Sealed?
        bSealed = false;
        
        % Supported sovling mechanisms.
        toSolve = struct();
    end
    
    properties (SetAccess = protected, GetAccess = public)
        
        % Heat flow into/from the component. Together with FR, c_p used to
        % calculate a temperature change for the flowing matter through
        % this component. If the f2f is supposed to update this property
        % automatically the child class f2f must implement the function
        % updateThermal with a specific calculation routine for the heat
        % flow
        fHeatFlow = 0;
        
        % Decide if this processor is an active processor which generates a
        % pressure difference (e.g. a fan).´In this case this property is
        % set to true. Or if it is a passive component which only reacts to
        % the mass flow passing through (e.g. a pipe). In this case the
        % property is false
        bActive = false;
        
        % Pressure difference of the f2f component in [Pa]
        fDeltaPressure = 0;
    end
    
    
    
    methods
        function this = f2f(oContainer, sName)
            %% f2f class constructor
            % creates a new F2F processor, which can change the temperature
            % and/or pressure of the flows passing through it
            %
            % Required Inputs:
            % oContainer:   vsys in which this f2f is located
            % sName:        name of the f2f
            
            this.sName = sName;
            
            
            this.oContainer = oContainer;
            this.oContainer.addProcF2F(this);
            
            this.oMT    = this.oContainer.oMT;
            this.oTimer = this.oContainer.oTimer;
            
            % Preset the flow array with a default, zero FR matter flow
            for iI = 1:this.iPorts
                this.aoFlows(iI) = matter.flow(); 
            end
        end
        
        function seal(this, oBranch)
            %% f2f seal
            %
            % seal the f2f processor and set the oBranch property
            if this.bSealed
                this.throw('seal', 'Already sealed!');
            end
            
            this.oBranch = oBranch;
            this.bSealed = true;
        end
    end
    
    
    %% Sealed to ensure flow handling, e.g. no setting of matter flow
    % properties if inflow
    methods (Sealed = true)
        
        function this = addFlow(this, oFlow, iFlowID)
            %% addFlow
            % INTERNAL FUNCTION!
            % Adds a flow to the f2f processor. This function is called
            % during branch construction and must not be called
            % individually
            
            if ~isa(oFlow, 'matter.flow')
                this.throw('addFlow', 'The provided flow obj has to be a or derive from matter.flow!');
            
            elseif any(this.aoFlows == oFlow)
                this.throw('addFlow', 'The provided flow obj is already registered!');
            end
            
            % Find empty port (first zero in aiSign array) - left or right
            if nargin < 3 || isempty(iFlowID)
                iFlowID = length(this.aoFlows(iFlowID)) + 1;
            elseif (iFlowID < length(this.aoFlows(iFlowID)) && ~isempty(this.aoFlows(iFlowID))) || iFlowID > 2
                this.throw('addFlow', ['The f2f-processor ''',this.sName,...
                           ''' is already in use by another branch.\n', ...
                           'Please check the definition of the following branch: ',...
                           oFlow.oBranch.sName]); 
            end
            
            % Set the flow obj - when we call the addProc of the flow
            % object, it checks if it exists on aoFlows!
            this.aoFlows(iFlowID) = oFlow;
            
            % Call addProc on the flow, provide function handle to
            % enable removing, returns the sign for the flow rate, throws
            % an error if something went wrong.
            try
                % Provide function handle to removeFlow - even though that
                % method is protected, it can be called from outside
                % through that! Wrap in anonymous function so no way to
                % remove another flow.
                oFlow.addProc(this, @() this.removeFlow(oFlow));
            
            catch oErr
                % Reset back to default MF
                this.aoFlows(iFlowID) = this.oMT.oFlowZero;
                
                rethrow(oErr);
            end
        end
    end
    
    
    methods (Access = protected)
        function supportSolver(this, sType, varargin)
            %% supportSolver
            % this function is used to provide compability with specific
            % solver types. For each different solver type the f2f can
            % implement a specific function that handles the solving of the
            % f2f
            %
            % Required Inputs
            % sType:    Define the type of the solver for which the
            %           provdied solve function can be used. E.g.
            %           'callback' or 'manual'
            % varargin: Depends on the solver type, can be a function
            %           handle or specific values. See
            %           lib.components.matter.pipe for some examples
            handleClassConstructor = str2func([ 'solver.matter.base.type.' sType ]);
            
            this.toSolve.(sType) = handleClassConstructor(varargin{:});
        end
    end
    
    
    % Protected methods - get flow rates, set matter properties
    methods (Access = protected, Sealed = true)
        function [ oFlowIn, oFlowOut ] = getFlows(this, fFlowRate)
            %% getFlows
            % get the current in and out flow depending on either the
            % provided fFlowRate or on the current flowrate of the flows
            %
            % Optional Inputs:
            % fFlowRate: defined flowrate for which the in- and outflow are
            %            of interest
            if nargin < 2
                fFlowRate = thia.aoFlows(1).fFlowRate;
            end
            
            if (fFlowRate >= 0)
                oFlowIn  = this.aoFlows(1);
                oFlowOut = this.aoFlows(2);
            else
                oFlowIn  = this.aoFlows(2);
                oFlowOut = this.aoFlows(1);
            end
                
        end
    end
    
    %% Internal methdos for handling the flows/flow rates
    % The removeFlow is private - only accessible through anonymous handle
    methods (Access = private)
        function removeFlow(this)
            %% f2f removeFlow
            % This function can be used to remove the flows from this f2f
            % which is necessary to then reconnect the f2f with another
            % flow (and therefore branch)!
            this.aoFlows = matter.flow.empty();
            this.oBranch = [];
        end
    end
    
end

