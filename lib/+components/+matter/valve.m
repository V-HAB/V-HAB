classdef valve < matter.procs.f2f
    % this is a simple closable valve, which can open and close branches.
    % Works with interval and multibranch iterative solver
    
    properties
        % Valve open or closed?
        bOpen = true;
        fFlowCoefficient = 1;
    end
    
    methods
        function  this = valve(oContainer, sName, fFlowCoefficient, bOpen)
            % Input parameters:
            %   sName:              name of the valve [char]
            %   fFlowCoefficient:   
            %   bOpen:              inital value of the valve setting [boolean]
            
            this@matter.procs.f2f(oContainer, sName);
            
            this.fFlowCoefficient   = fFlowCoefficient;
            
            if nargin >= 4 && ~isempty(bOpen) && islogical(bOpen)
                this.bOpen = ~~bOpen;
            end
            
            if bValveOpen
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
        
        function fDeltaPress = solverDeltas(this, fFlowRate)
            
            if (this.fFlowCoefficient == 0) && this.bOpen
                fDeltaPress = 0;
                this.fDeltaPressure = fDeltaPress;
                return;
            end
            
            if (fFlowRate == 0)
                fDeltaPress = 0;
                this.fDeltaPressure = fDeltaPress;
                return;
            end
            
            if this.bOpen == 0
                fDeltaPress = Inf;
                return;
            end
            
            
            % Get in/out flow object references
            [ oFlowIn, oFlowOut ] = this.getFlows(fFlowRate);
            
            % Average pressure in Pa
            fP = (oFlowIn.fPressure + oFlowOut.fPressure) / 2;
            
            % No pressure at all ... normally just return, drop zero
            if fP == 0
                fDeltaPress = 0;
                return;
            end
            
            % Calculate density in kg/m^3 and flow rate in SLM
            fRoh = (fP * oFlowIn.fMolarMass) / (this.oMT.Const.fUniversalGas * oFlowIn.fTemperature);
            fFlowRate = fFlowRate * 60; % Convert to kg/min
            fSLM = (fFlowRate / oFlowIn.fMolarMass * ...
                   this.oMT.Const.fUniversalGas * oFlowIn.fTemperature / oFlowIn.fPressure) * 1000;

               
            % Calculate Pressure Difference in 
            fDeltaPress =  fSLM^2 / (fRoh * this.fFlowCoefficient^2);  
            
            
            %this.fDeltaPressure = fDeltaPress;
        end
        
        function this = setOpen(this, bOpen)
            this.bOpen = ~~bOpen;
            
            % Set branch outdated - needs to recalculate flows!
            this.oBranch.setOutdated();
        end
    end
end

