classdef pump < solver.matter.linear.procs.f2f
    %PUMP Linar, static, RPM independent fan model
    %   Interpolates between max flow rate and max pressure rise, values
    %   taken from datasheet for a pump running at 1750 RMP
    
    properties
        fMaxFlowRate = 0.027;   % Maximum flow rate in kg/s
        fMinFlowRate = 0.02;    % Maximum flow rate in kg/s
        fMaxDeltaP = 8700000;   % Maximum delta pressure the pump can produce
        
        fFlowRateSP;            % Flow rate setpoint in kg/s
        iDir;                   % Direction of flow [ 1 -1 ]
%         fDeltaPressure = 0;     % Pressure difference created by the pump in Pa
        
    end
    
    properties (SetAccess = protected, GetAccess = public)
%         fHydrDiam   = -1;       % Needs to be smaller than 0 for the solver
%                                 % to recognize it as pump
%         fHydrLength = 0.1;      % Irrelevant
%         fDeltaTemp  = 0;
%         bActive     = true;     % Needs to be true if delta pressure not constant
    end
    
    
    methods
        function this = pump(oMT, sName, fFlowRateSP)
            this@solver.matter.linear.procs.f2f(oMT, sName);
            
            this.fFlowRateSP = abs(fFlowRateSP);
            this.iDir = sif(fFlowRateSP > 0, 1, -1);
            
%             this.fHydrDiam = -5;
%             this.fHydrLength = 0.1;
            
            this.supportSolver('hydraulic', -5, 0.1, true, @this.update);
            %TODO support that!
            %this.supportSolver('callback',  @this.solverDeltas);
        end
        
        function fDeltaPressure = update(this)
            % Getting the flow object unless the flow is smaller than the
            % minimum flow
            %keyboard();
            if ~(abs(this.aoFlows(1).fFlowRate) <= this.fMinFlowRate)
                [ oFlowIn, ~ ] = this.getFlows();
            else
                % If the flow rate is smaller than the minimum flow rate,
                % the pressure delta is maximum
                %this.fDeltaPressure = this.iDir * this.fMaxDeltaP;
                fDeltaPressure = this.fDeltaPressure + 1000;
                return;
            end
            
            if oFlowIn.fFlowRate > this.fMaxFlowRate
                fDeltaPressure = this.fDeltaPressure - 100;
            else
                % Changeing the delta pressure of the fan according to the
                % current flow rate and the flow rate setpoint. 
                % This is not very accurate...
                rFactor = abs((this.fFlowRateSP - oFlowIn.fFlowRate) / this.fFlowRateSP);
                fDeltaPressure = this.fDeltaPressure * (1 + rFactor);
            end
        end
        
    end
end


