classdef circuit < base & event.source
    %CIRCUIT Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        % Reference to the electrical circuit this solver shall solve.
        oCircuit;
        
        % Variable time step
        fTimeStep;
        
        % Fixed time step
        fFixedTS;
    end
    
    properties (SetAccess = private, GetAccess = protected)
        % Callback to set time step (default: inf) in [s]
        setTimeStep;
        
    end
    
    properties (SetAccess = private, GetAccess = public)
        % Solving mechanism supported by the solver
        sSolverType;
        
    end
    
    properties (SetAccess = protected, GetAccess = public)
        % Update method is bound to this post tick priority. Some solvers
        % might need another priority to e.g. ensure that first, all other
        % branches update their flow rates.
        iPostTickPriority = -2;
    end
    
    properties (SetAccess = private, GetAccess = protected) %, Transient = true)
        %TODO These properties should be transient. That requires a static
        % method (loadobj) to be implemented in this class, so when the
        % simulation is re-loaded from a .mat file, the properties are
        % reset to their proper values.
        bRegisteredOutdated = false;
    end

    
    methods
        function this = circuit(oCircuit, fFixedTimeStep)
            this.oCircuit = oCircuit;
            
            if nargin > 1
                this.fFixedTS = fFixedTimeStep;
            end
            
            % Use circuit's container timer reference to bind for time step
            if isempty(this.fFixedTS)
                this.setTimeStep = this.oCircuit.oTimer.bind(@(~) this.solve(), 0);
            else
                this.setTimeStep = this.oCircuit.oTimer.bind(@(~) this.solve(), this.fFixedTS);
            end
            
            % If the circuit triggers the 'outdated' event, need to
            % re-calculate the currents and voltages!
            this.oCircuit.bind('outdated', @this.registerUpdate);
            
            % For now, we'll set the fixed time step, have to change that
            % later on, when variable time steps are actually implemented.
            %TODO Delete this for fully variable time steps.
            this.fFixedTS = 20;

        end
        
        function solve(this)
            % To solve for all of the unknowns in the circuit, we need to
            % solve a system of linear equations in the form of Ax = b,
            % where A is a matrix of coefficients, b is a vector of
            % constants and x is a vector containing all unknowns. In the
            % end we will transform this equation into x = A\b
            % (left-division of A) to get all unknowns. The matrix A will
            % contain one column for each node voltage and each branch
            % current in the circuit. The columns for the nodes come first,
            % then the columns for the branches. The rows represent
            % equations that can be created for each node, a voltage source
            % and each branch. For the nodes, the sum of all currents has
            % to be zero.
            % 
            % I1 + I2 + I3 + ... + IN = 0                               (1)
            %
            % For each branch, the difference between the node voltages has
            % to be equal to the voltage drop over the contained
            % resistances.
            %
            % U2 - U1 - R * I = 0                                       (2)
            %
            % If one of the voltages in the branch is from a voltage
            % source, an equation is added as a row after the other node's
            % equations.
            
            %TODO The coefficients matrix will not change significantly
            %over time, resistances might change and the source voltage.
            %Everything else remains constant. One could figure out a way
            %to only make these changes here and not always re-create the
            %entire matrix. 
            
            
            % Initializing the coefficients matrix A
            iLength = this.oCircuit.iNodes + this.oCircuit.iBranches;
            
            % If there is a source in the circuit, we treat is as a node
            if ~isempty(this.oCircuit.oSource)
                iWidth = iLength + 1;
                iSource = 1;
            else
                iWidth = iLength; 
                iSource = 0;
            end
            
            iNodes = this.oCircuit.iNodes;
            
            mfCoefficients = zeros(iWidth, iLength);
            
            % Initializing the constants vector b
            afConstants = zeros(iLength + iSource, 1);
            
            % Now we fill the matrix and vector with information from the
            % branches and nodes of the circuit. We do this by looping
            % through all branches in the circuit. 
            for iBranch = 1:this.oCircuit.iBranches
                
                oBranch = this.oCircuit.aoBranches(iBranch);
                
                iBranchIndex  = iBranch + iNodes;
                
                % First we add the resistance of the branch to the
                % coefficients matrix. The resistances are the coefficients
                % of the currents. As the resistance is negative in the
                % branch equation (2), we multiply it by -1.
                mfCoefficients(iBranchIndex + iSource, iBranchIndex) = this.oCircuit.aoBranches(iBranch).fResistance * -1;
                
                % Next we look at the nodes at both ends of the branch.
                for iTerminal = 1:2
                    % Since we will be examining the difference between the
                    % voltages of the two, we need to define one as
                    % mathematically positive and the other as negative.
                    % This also applies to the direction of current flow
                    % between the two nodes. Arbitrarily, we set the first
                    % one positive and the second one negative. For the
                    % direction of current flow this means that it flows
                    % out of the first and into the second node. The end
                    % result will not be affected by this, since it is just
                    % a mathematical definition.
                    if iTerminal == 1
                        iSign = 1;
                    else
                        iSign = -1;
                    end
                    
                    
                    % In the node equation (1), set to 1 or -1 depending on
                    % the direction of flow, i.e. the sign.
                    
                    if isa(oBranch.coTerminals{iTerminal}.oParent, 'electrical.store')
                        % The last row of nodes is for the source, if it is
                        % present.
                        iNodeIndex = iNodes + 1;
                        afConstants(iBranchIndex + iSource) = afConstants(iBranchIndex + iSource) - iSign * oBranch.coTerminals{iTerminal}.fVoltage;
                    else
                        % Here we get the index of the node in the aoNodes
                        % array of the parent circuit.
                        iNodeIndex = find(this.oCircuit.aoNodes == oBranch.coTerminals{iTerminal}.oParent);
                        mfCoefficients( iBranchIndex + iSource, iNodeIndex) = iSign * 1;
                    end
                    
                    mfCoefficients( iNodeIndex, iBranchIndex ) = -1 * iSign;
                end
                
            end
            
            afResult = mfCoefficients \ afConstants;
            
            % Rounding Results
            iPrec = this.oCircuit.oTimer.iPrecision;
            for iI = 1:length(afResult)
                if tools.round.prec(afResult(iI), iPrec) == 0
                    afResult(iI) = 0;
                end
            end
            
            % Call method on circuit being handled to set all currents,
            % signs and voltages.
            this.oCircuit.update(afResult);
            
            this.calculateTimeStep();
            
        end
        
        function calculateTimeStep(this)
            if ~isempty(this.fFixedTS)
                this.setTimeStep(this.fFixedTS, true);
                this.fTimeStep = this.fFixedTS;
            else
                %TODO Insert something nice here
                
            end
        end
        
    end
    
    
    
    methods (Access = protected)
        function registerUpdate(this, ~)
            this.oCircuit.oTimer.bindPostTick(@this.solve, this.iPostTickPriority);
            this.bRegisteredOutdated = true;
        end
    end
    
end

