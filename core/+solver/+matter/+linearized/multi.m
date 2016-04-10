classdef multi < base
    
    properties (SetAccess = public, GetAccess = public)
        
    end
    
    properties (SetAccess = protected, GetAccess = public)
        % Performance
        fTotalTime = 0;
        
        fCalcCoeffsTime   = 0;
        fCalcDepPressures = 0;
        fCalcFlowRates    = 0;
    end
    
    methods
        
        %% Constructor
        function this = multi(aoBranches)
            % Settting no time step - inf by default - never triggered by
            % itself!
            
            % Providing the first branch to the base class to get timer,
            % etc.
            this@solver.matter.base.branch(aoBranches(1), [], 'callback');
            
            
            % Sets the flow rate to 0 which sets matter properties
            this.update();
            
        end
        
        
    end
    
    methods (Access = protected)
        
        %% Update functions, called directly by timer
        function update(this)

            if this.oBranch.oTimer.fTime < 0
                update@solver.matter.base.branch(this, 0);
                
                return;
            
            elseif this.oBranch.oTimer.fTime <= this.fLastUpdate
                return;
            end
            
            
            update@solver.matter.base.branch(this, fFlowRate, afDeltaP);
            
            
            
            
            % Old FR (or, if zero, min TS as initial FR)
            % Get Coeffs (with FR, ask Comps for Drop, divide by FR, sum)
            %   => WAIT. Just use old shit. Initial minTS FR only initially
            %
            % Inf Coeffs --> directly coupled, 0 Coeff -> no Flow Rate!
            % Calc dependent pressures
            % Calc real flow rats
            %
            % SET flow rates including pressure drops via coeffs --> new
            % pressures are set in branches. REDO get coeffs --> compare!
            
            
            mfData = zeros(oBranch.iFlowProcs, 1);
            
            for iP = oBranch.iFlowProcs:1

                mfData(iP, 1) = this.aoSolverProps(iP).calculateDeltas(iDir * fFlowRate);

                fPressDrop = fPressDrop + mfData(iP, 1);

            end
        end
    end
end
