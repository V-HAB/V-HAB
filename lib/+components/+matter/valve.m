classdef valve < matter.procs.f2f
    % this is a simple valve, which can open and close branches.
    % Works with interval and multibranch iterative solver
    
    properties
        % Valve open or closed?
        bOpen = true;
    end
    
    methods
        function  this = valve(oContainer, sName, bOpen)
            % Input parameters:
            %   sName: name of the valve [char]
            %   bOpen: inital value of the valve setting [boolean]
            
            this@matter.procs.f2f(oContainer, sName);
            
            if nargin >= 3 && ~isempty(bOpen) && islogical(bOpen)
                this.bOpen = ~~bOpen;
            end
            
            if this.bOpen
                this.fDeltaPressure = 0;
            else
                this.fDeltaPressure = Inf;
            end
            
            this.supportSolver('callback',  @this.solverDeltas);
            this.supportSolver('manual', false);
            this.supportSolver('coefficient',  @this.calculatePressureDropCoefficient);
        end
        
        function fDropCoefficient = calculatePressureDropCoefficient(this, ~)
            if this.bOpen
                fDropCoefficient = 0;
            else
                fDropCoefficient = uint64(18446744073709551615);
            end
        end
        
        function fDeltaPress = solverDeltas(this, ~)
            
            if this.bOpen == 0
                fDeltaPress = Inf;
                this.fDeltaPressure = Inf;
            else
                fDeltaPress = 0;
                this.fDeltaPressure = 0;
            end
            
        end
        
        function this = setOpen(this, bOpen)
            this.bOpen = ~~bOpen;
            
            % Set branch outdated - needs to recalculate flows!
            this.oBranch.setOutdated();
        end
    end
end

