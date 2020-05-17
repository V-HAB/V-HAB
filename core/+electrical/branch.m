classdef branch < base.branch
    %BRANCH Describes flow path between two terminals
    %	The input parameters are the parent circuit (oCircuit),
    %	the left and right ports (xLeft and xRight), a cell containing
    %	the names of the components to be inlcuded in the
    %	branch (csComponents), and an optional custom name for the branch 
    %	object should the user wish to set it. 
    %	The left and right ports can either be passed into the 
    %	constructor as a string in the following format: 
    %   <object name>.<terminal name>, or implicitly by passing in an
    %   object handle as the second or fourth input parameter.
    
    properties (SetAccess = protected, GetAccess = public)
        % Reference to the parent electrical circuit
        oCircuit;
        
        % A cell containing references to the terminal objects on the
        % left and right side of the branch. 
        coTerminals = { []; [] };
        
        % Flows belonging to this branch
        aoFlows;
        
        % Array with f2f processors in between the flows
        aoComponents = [];
        
        % Number of flows
        iFlows = 0;
        
        % Number of components
        iComponents = 0;
        
        % Overall branch resistance in Ohm.
        fResistance = 0;
        
        % Current electrical current on branch
        fCurrent = 0;
        
        % Last couple of currents - used to test if below rounding prec
        afCurrents = ones(1, 10);
   
    end
    
    methods
        
        function this = branch(oCircuit, sLeft, csComponents, sRight, sCustomName)
            % Can be called with either nodes/ports, components/ports,
            % object handles or interface names (all combinations
            % possible). Connections are always done from subsystem to
            % system.
            
            % Check if a custom name is set
            if nargin < 5
                sCustomName = [];
            end
            
            % Calling the parent constructor
            this@base.branch(oCircuit, sLeft, csComponents, sRight, sCustomName, 'electrical');
            
            % Reference to the electrical.circuit and some shorthand refs.
            this.oCircuit = oCircuit;
            
            % Adding the branch to our electrical.container
            this.oCircuit.addBranch(this);
            
            % Counting the flows and components and setting the properties
            % accordingly.
            this.iFlows      = length(this.aoFlows);
            this.iComponents = length(this.aoComponents);
            
            % Calculating the total resistance of this branch. This value
            % is used by the solver.
            this.calculateResistance();
            
            
        end
        
        function createProcs(this, csComponents)
            %CREATEPROCS Adds the provided components to the branch
            
            % Looping through all members of the provided cell
            for iI = 1:length(csComponents)
                % Getting the name of the current component
                sComponent = csComponents{iI};
                
                % Check if the component exists
                if ~isfield(this.oContainer.toComponents, sComponent)
                    this.throw('electrical.branch', 'Component %s not found on circuit this branch belongs to!', sComponent);
                end
                
                
                % Unless this is the first component in a branch with an
                % interface flow at its left side, we connect the last flow
                % in the aoFlows property to the currently selected
                % component.
                if ~this.abIf(1) || (iI ~= 1)
                    % Connect to previous flow (the 'left' port of the proc
                    % goes to the 'out' port of the previous flow)
                    this.oContainer.toComponents.(sComponent).addFlow(this.aoFlows(end));
                end
                
                % Create a flow
                oFlow = electrical.flow(this);
                this.aoFlows(end + 1) = oFlow;
                
                % Connect the new flow - 'right' of the component to 'in' of flow
                % Because of the possibility that the component is not connected
                % to an in flow (if branch - in flow not yet known), we
                % explicitly provide the port to connect the flow to
                oComponent = this.oContainer.toComponents.(sComponent).addFlow(oFlow, 'Right');
                
                % Adding the component to the aoComponents property. We
                % need to do some checking here because the aoComponents
                % property is initialized empty. We cannot initialize it
                % with electrical.components.empty() because the class is
                % abstract and cannot be instantiated on it's own.
                if isempty(this.aoComponents)
                    this.aoComponents = oComponent;
                else
                    this.aoComponents(end + 1) = oComponent;
                end
                
            end
            
        end
        
        function setFlows(this, aoFlows)
            %SETFLOWS Sets the aoFlows property and counts them
            this.aoFlows    = aoFlows;
            this.iFlows     = length(this.aoFlows);
            
        end
        
        function setOutdated(this)
            %SETOUTDATED
            % Can be used to request recalculation of the flow rate, e.g.
            % after some internal parameters changed (closing a switch).
            
            % Only trigger if not yet set
            if ~this.bOutdated
                this.bOutdated = true;

                % Trigger outdated so e.g. the branch solver can register a
                % postTick callback on the timer to recalc flow rate.
                this.trigger('outdated');
            end
        end
        
        function setCurrent(this, fCurrent)
            %SETCURRENT Sets current for all flow objects
            
            % If the left side is an interface, we shouldn't be doing this
            if this.abIf(1), this.throw('setCurrent', 'Left side is interface, can''t set current on this branch object'); end
            
            % Carried over from matter, if for some reason we want to round
            % over the last ten currents
            this.afCurrents = [ this.afCurrents(2:end) fCurrent ];
            
            % If sum of the last ten flow rates is < precision, set flow
            % rate to zero
            if tools.round.prec(sum(this.afCurrents), this.oCircuit.oTimer.iPrecision) == 0
                fCurrent = 0;
                
            elseif this.fCurrent == 0
                % If flow rate is already zero, more strict rounding! Don't
                % re-set a flow rate until its larger then the precision!
                if tools.round.prec(fCurrent, this.oCircuit.oTimer.iPrecision) == 0
                    fCurrent = 0;
                end
            end
            
            % Actually setting the current
            this.fCurrent  = fCurrent;
            
            % In case this was called via the 'outdated' trigger, we re-set
            % the property
            this.bOutdated = false;
            
            % Update branch components
            for iI = 1:this.iComponents
                this.aoComponents(iI).update();
            end
            
            % Update data in flows
            this.setFlowData();
            
        end
        
        function setTerminal(this, oTerminal, iPosition)
            %SETTERMINAL Setter method to access protected property coTerminals
            this.coTerminals{iPosition} = oTerminal;
            
        end
        
    end
    
    methods (Sealed = true)
        function seal(this)
            %SEAL Seals this branch so nothing can be changed later on
            
            % Check if we're already sealed
            if this.bSealed
                this.throw('seal', 'Already sealed');
            end
            
            % Sealing the flows 
            for iI = 1:length(this.aoFlows)
                % If this is the last flow and the right interface, provide
                % true as param, which means that the .seal() returns a
                % remove callback which allows us to deconnect the flow
                % from the component in the "outer" system (supersystem).
                if this.abIf(2) && (this.iIfFlow == iI)
                    [ this.hSetFlowData, this.hRemoveIfProc ] = this.aoFlows(iI).seal(true);
                
                % Only need the callback reference once ...
                elseif iI == 1
                    this.hSetFlowData = this.aoFlows(iI).seal(false, this);
                else
                    this.aoFlows(iI).seal(false, this);
                end
            end
            
            % Sealing the components
            for iI = 1:length(this.aoComponents)
                this.aoComponents(iI).seal(this);
            end
            
            % Setting the property to true
            this.bSealed = true;
        end
        
        function calculateResistance(this)
            %CALCULATERESISTANCE Calculates the overall branch resistance
            
            % If there are components, we loop through them, check if they
            % are resistors and if so, we add their resistance to the
            % fResistance property of the branch. Otherwise the resistance
            % is zero. 
            if this.iComponents > 0
                for iI = 1:length(this.aoComponents)
                    if isa(this.aoComponents(iI), 'electrical.components.resistor')
                        this.fResistance = this.fResistance + this.aoComponents(iI).fResistance;
                    end
                end
            else
                this.fResistance = 0;
            end
        end
        
        function setFlowData(this)
            %SETFLOWDATA Goes through the aoFlows array, set the current and voltage on all flow objects
            
            % We need to get the flow direction, since the voltage drops
            % returned by the components are absolute. 
            if this.fCurrent < 0
                iSign = -1;
            else
                iSign = 1;
            end
            
            % We're going through the branch from left to right.
            for iI = 1:this.iFlows
                if iI == 1
                    % If we're at the beginning of the branch, we can just
                    % use the voltage from the terminal on the left side. 
                    fVoltage = this.coTerminals{1}.fVoltage;
                elseif iI > 1 && iI < this.iFlows
                    % If we're somewhere inbetween, we subtract the voltage
                    % drop from the preceeding component.
                    fVoltage = fVoltage - this.aoComponents(iI - 1).fVoltageDrop * iSign;
                elseif iI == this.iFlows
                    % If we're at the end of the branch, we can just use
                    % the voltage from the terminal on the right side. 
                    fVoltage = this.coTerminals{2}.fVoltage;
                end
                
                % Setting the properties on the flow objects.
                this.aoFlows(iI).update(this.fCurrent, fVoltage);
            end
            
        end
        
    end
    
end
