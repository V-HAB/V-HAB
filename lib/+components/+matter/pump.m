classdef pump < matter.procs.f2f
    %PUMP Linar, static, RPM independent dummy pump model
    %   Just multiplies the current delta pressure with a factor which is
    %   calculated from the difference between the actual flow rate and the
    %   setpoint flow rate.
    %
    %TODO Currently only supports hydraulic solver type, make compatible
    %   callback solver as well. 
    
    properties
        fMaxFlowRate = 1;       % Maximum flow rate in kg/s
        fMinDeltaP = 1;         % Maximum delta pressure the pump must produce
        fMaxDeltaP = 8700000;   % Maximum delta pressure the pump can produce
        fDampeningFactor = 4;   % This factor controls how fast or slow the 
                                % pump model reacts to changes in setpoint
        
        fFlowRateSP;            % Flow rate setpoint in kg/s
        iDir;                   % Direction of flow [ 1 -1 ]
        
        fPreviousSetpoint;    
        
        
    end
        
    methods
        function this = pump(oContainer, sName, fFlowRateSP)
            this@matter.procs.f2f(oContainer, sName);
            
            this.fFlowRateSP = fFlowRateSP;
            this.fPreviousSetpoint = fFlowRateSP;
            if fFlowRateSP > 0
                this.iDir = 1;
            else
                this.iDir = -1;
            end
            
            this.supportSolver('hydraulic', -5, 0.1, true, @this.update);
            this.supportSolver('callback', @this.solverDeltas);
            
            this.bActive = true;
            %TODO support that!
            %this.supportSolver('callback',  @this.solverDeltas);
        end
        
        function fDeltaPressure = update(this)
            % Getting the flow object unless the current flow rate is zero
            if ~(abs(this.aoFlows(1).fFlowRate) == 0)
                [ oFlowIn, ~ ] = this.getFlows();
                fFlowRate = oFlowIn.fFlowRate;
            else
                % If the flow rate is zero, then we just set the delta
                % pressure to maximum
                % the pressure delta is maximum
                if this.fFlowRateSP ~= 0
                    fFlowRate = 0;
                    this.fDeltaPressure = 1;
                else
                    fDeltaPressure = 0;
                    return;
                end
                
            end
            
            if abs(fFlowRate) > this.fMaxFlowRate
                % If the flow rate is larger than the maximum flow rate, so
                % water is being forced through the pump, then it acts as a
                % resistance and produces a negativ pressure rise; a
                % pressure drop.
                fDeltaPressure = this.fDeltaPressure - 100;
                
            % Check if we need to increase or decrease the flow rate
            else 
                if this.fFlowRateSP * this.iDir > fFlowRate * this.iDir
                    iChangeDir = 1;
                else
                    iChangeDir = -1;
                end
                
                % Changeing the delta pressure of the pump according to the
                % current flow rate and the flow rate setpoint. 
                % This is of course not very accurate...
                rFactor = (this.fFlowRateSP - fFlowRate) / this.fFlowRateSP;
                
                % If the flow rate setpoint is set to zero from a value
                % different than zero, this factor would become 'Inf'. 
                if abs(rFactor) > 2
                    rFactor = 2;
                end
                
                fDeltaPressure = this.fDeltaPressure * (1 + rFactor * iChangeDir / this.fDampeningFactor);
            
            end
            
            % Need to set at least a minimum delta pressure, otherwise it
            % will take the rFactor too long to get to meaningful values.
            % It would start at extremely low numbers (e-55).
            if abs(fDeltaPressure) < this.fMinDeltaP
                fDeltaPressure = this.fMinDeltaP;
            elseif abs(fDeltaPressure) > this.fMaxDeltaP
                fDeltaPressure = this.fMaxDeltaP;
            end
                
            % Saving the current delta pressure for use in the next call of
            % this method.
            this.fDeltaPressure = fDeltaPressure;
        end
        
        function fDeltaPressure = solverDeltas(this, fFlowRate)
            
            
            % Switched off? No dP no matter what
            if ~this.bActive
                
                % VERY IMPORTANT! No flow -> no heat transfer!!
                this.fHeatFlow = 0;
                
                fDeltaPressure = 0;
                this.fDeltaPressure = fDeltaPressure;
                
                return;
            end
            
            if abs(fFlowRate) > this.fMaxFlowRate
                % If the flow rate is larger than the maximum flow rate, so
                % water is being forced through the pump, then it acts as a
                % resistance and produces a negativ pressure rise; a
                % pressure drop.
                fDeltaPressure = this.fMaxDeltaP;
                
            % Check if we need to increase or decrease the flow rate
            else 
                if this.fFlowRateSP * this.iDir > fFlowRate * this.iDir
                    iChangeDir = 1;
                else
                    iChangeDir = -1;
                end
                
                % Changeing the delta pressure of the pump according to the
                % current flow rate and the flow rate setpoint. 
                % This is of course not very accurate...
                rFactor = (this.fFlowRateSP - fFlowRate) / this.fFlowRateSP;
                
                % If the flow rate setpoint is set to zero from a value
                % different than zero, this factor would become 'Inf'. 
                if abs(rFactor) > 2
                    rFactor = 2;
                end
                
                fDeltaPressure = this.fDeltaPressure * (1 + rFactor * iChangeDir / this.fDampeningFactor);
            
            end
            
            % Need to set at least a minimum delta pressure, otherwise it
            % will take the rFactor too long to get to meaningful values.
            % It would start at extremely low numbers (e-55).
            if abs(fDeltaPressure) < this.fMinDeltaP
                fDeltaPressure = - this.fMinDeltaP;
            elseif abs(fDeltaPressure) > this.fMaxDeltaP
                fDeltaPressure = -this.fMaxDeltaP;
            end
                
            % Saving the current delta pressure for use in the next call of
            % this method.
            this.fDeltaPressure = fDeltaPressure;
        end
        function changeSetpoint(this, fNewSetpoint)
            this.fFlowRateSP = fNewSetpoint;
            if fNewSetpoint == 0
                this.bActive = false;
            else
                this.bActive = true;
            end
        end
    end
end


