classdef checkvalve < matter.procs.f2f
    %Valve Summary of this class goes here
    %   Detailed explanation goes here
    

    
    properties (SetAccess = protected, GetAccess = public)
        % Absolute, fixed pressure drop in flow direction
        fPressureDrop = 0;
        %TODO allow e.g. setting an interpolation for fr -> dp, possibly
        %     with an exponent (e.g. ^3 -> cubic dependency)
        
        
        % If false, no flow at all (returns inf as pressure drop)
        bReversed = false;
    end
    
    methods
        function  this = checkvalve(oContainer, sName, bReversed, fPressureDrop)
            % Input Parameters:
            %   fFlowCoefficient - the bigger, the lower the pressure drop
            %   bValveOpen - if closed, inf pressure drop - no flow!
            
            this@matter.procs.f2f(oContainer, sName);
            
            if nargin >= 3 && ~isempty(bReversed) && islogical(bReversed)
                this.bReversed = bReversed;
            end
            
            if nargin >= 4 && ~isempty(fPressureDrop)
                this.fPressureDrop = fPressureDrop;
            end
            
            
            this.supportSolver('callback',  @this.solverDeltas);
        end
        
        
        
        function fPressureDrop = solverDeltas(this, fFlowRate)
            % No flow - no pressure drop
            if fFlowRate == 0
                fPressureDrop = 0;
                
                return;
            
            % NEGATIVE flow for 'normal' checkvalve (matter can only flow
            % from the left to the right side) - return inf to block flow!
            elseif (fFlowRate < 0) && ~this.bReversed
                fPressureDrop = inf;
                
                return;
            
            elseif (fFlowRate > 0) && this.bReversed
                fPressureDrop = inf;
                
                return;
            end
            
            
            fPressureDrop = this.fPressureDrop;
        end
    end
    
end

