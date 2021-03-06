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
        
        bOpen = true;
    end
    
    methods
        function  this = checkvalve(oContainer, sName, bReversed, fFlowThroughPressureDropCoefficient)
            % Input Parameters:
            %   fFlowCoefficient - the bigger, the lower the pressure drop
            %   bValveOpen - if closed, inf pressure drop - no flow!
            
            this@matter.procs.f2f(oContainer, sName);
            
            this.bCheckValve = true;
            
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
            fPressureDrop = 0;
            try 
                if ~this.oBranch.oHandler.bFinalLoop
                    fPressureDrop = this.fPressureDrop;
                    return
                end
            catch
                % if the solver is not iterative always calculate the valve
            end
                
            % For the case of no flow we still have to model the valve as
            % closed, otherwise the solver we open it even though the flow
            % might only be 0 because it was closed before, which can lead
            % to oscillations.
            if ~this.bReversed && fFlowRate <= 0
                this.fPressureDrop = inf;
                this.bOpen =false;
            elseif this.bReversed && fFlowRate >= 0
                this.fPressureDrop = inf;
                this.bOpen =false;
            else
                this.bOpen = true;
                this.fPressureDrop =  this.fFlowThroughPressureDropCoefficient * fFlowRate^2;
            end
            fPressureDrop = this.fPressureDrop;
        end
    end
    
end

