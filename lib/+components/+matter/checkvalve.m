classdef checkvalve < matter.procs.f2f
    % This is a checkvalve which only allows fluid to pass in one direction
    % and blocks it if it would flow the other way. This valve currently
    % only works together with the multi branch solver but could be
    % implemented for other solvers (interval iterative) as well. 

    
    properties (SetAccess = protected, GetAccess = public)
        % Current Pressure Drop
        fPressureDrop = 0;
        
        % Coefficient for the pressure drop if fluid is allowed to flow
        % through the valve. Is multiplied with the flowrate^2 to calculate
        % pressure drop
        fFlowThroughPressureDropCoefficient = 0;
        
        % If false, no flow at all (returns inf as pressure drop)
        bReversed = false;
        
        bCheckValve = true;
    end
    
    methods
        function  this = checkvalve(oContainer, sName, bReversed, fFlowThroughPressureDropCoefficient)
            % Input Parameters:
            %   fFlowCoefficient - the bigger, the lower the pressure drop
            %   bValveOpen - if closed, inf pressure drop - no flow!
            
            this@matter.procs.f2f(oContainer, sName);
            
            if nargin >= 3 && ~isempty(bReversed) && islogical(bReversed)
                this.bReversed = bReversed;
            end
            
            if nargin >= 4 && ~isempty(fFlowThroughPressureDropCoefficient)
                this.fFlowThroughPressureDropCoefficient = fFlowThroughPressureDropCoefficient;
            end
            
            
            this.supportSolver('callback',  @this.solverDeltas);
        end
        
        
        
        function fPressureDrop = solverDeltas(this, fFlowRate)
            
            % we only calculate the valve in case that the solver has
            % already converged. Otherwise the valve can result in
            % oscillations in iterative solvers like the iterative
            % multibranch, the iterative or the interval solver!
            try 
                if ~this.oBranch.oHandler.bFinalLoop
                    fPressureDrop = this.fPressureDrop;
                    return
                end
            catch
                % if the solver is not iterative always calculate the valve
            end
                
            
            % No flow - no pressure drop
            if fFlowRate == 0
                this.fPressureDrop = 0;
                
            % NEGATIVE flow for 'normal' checkvalve (matter can only flow
            % from the left to the right side) - return inf to block flow!
            elseif ~this.bReversed && fFlowRate < 0
                this.fPressureDrop = inf;
                
            elseif this.bReversed && fFlowRate > 0
                this.fPressureDrop = inf;
                
            end
            
            fPressureDrop = this.fFlowThroughPressureDropCoefficient * fFlowRate^2;
        end
    end
    
end

