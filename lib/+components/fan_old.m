classdef fan_old < matter.procs.f2f
    %FAN_OLD Linar, static, RPM independent fan model
    %   Interpolates between max flow rate and max pressure rise, values
    %   taken from AIAA-2012-3460 for a fan running at 4630 RMP
    
    properties
        fMaxDeltaP;          % Maximum pressure rise in [Pa]
        iDir = 1;            % Direction of flow
       
    end
        
    methods
        function this = fan_old(oMT, sName, fMaxDeltaP, bReverse)
            this@matter.procs.f2f(oMT, sName);
                        
            this.fMaxDeltaP   = fMaxDeltaP;
            
            if (nargin >= 4) && islogical(bReverse) && bReverse
                this.iDir = -1;
            end
            
            
            this.supportSolver('hydr', -1, 1, true, @this.update);
            this.supportSolver('fct',  @this.solverDeltas);
            this.supportSolver('manual', true, @this.updateManualSolver);
        end
        
        function fDeltaPressure = update(this)
           
            % Getting the flow object if the flow rate is not zero
            if ~(this.aoFlows(1).fFlowRate == 0)
                [ oFlowIn, ~ ] = this.getFlows(this.aoFlows(1).fFlowRate);
            else
                % If the current flow rate is zero, the pressure rise is at
                % maximum
                fDeltaPressure = this.fMaxDeltaP;
                return;
            end
            
            % Calculating the maximum mass flow rate from the maximum
            % volumetric flow rate as given in the datasheet
            fMaxFR = 7 * 0.00047 * sum(oFlowIn.arPartialMass .* this.oMT.tafDensity.gas);
            
            if oFlowIn.fFlowRate > fMaxFR
                % If the flow rate is greater than the max flow rate for the
                % fan, the pressure rise is zero
                fDeltaPressure = 0;
                
            elseif oFlowIn.fFlowRate < 0
                % If the flow rate is negative i.e. against the direction
                % the fan is blowing, then it just becomes another
                % resistance in the branch
            else
                % Iterpolation between max delta P and max flow rate
                fDeltaPressure = -1 * this.fMaxDeltaP / fMaxFR * oFlowIn.fFlowRate + this.fMaxDeltaP;
            end
            
        end
        
        
        function [ fDeltaPress, fDeltaTemp ] = solverDeltas(this, fFlowRate)
            fDeltaTemp = 0;
            
            if fFlowRate == 0
                % If the current flow rate is zero, the pressure rise is at
                % maximum. Negative - pressure rise!
                fDeltaPress = -1 * this.fMaxDeltaP;
                
                return;
            else
                % Possible to turn around fan. Normal flow direction is
                % left to right, i.e. in case of a flow from the left to
                % the right the fan produces a pressure rise, else a
                % pressure drop.
                % Providing bReverse to the constructor can revert that.
                fFlowRate = this.iDir * fFlowRate;
            end
            
            % Get the appropriate matter.flow depending on the 'guessed'
            % flow rate by the solver (positive FR - get 'left' flow)
            [ oFlowIn, ~ ] = this.getFlows(fFlowRate);
            
            % Calculating the maximum mass flow rate from the maximum
            % volumetric flow rate as given in the datasheet
            %TODO document that - where do the 7, 0.00047 come from?
            fMaxFR = 7 * 0.00047 * sum(oFlowIn.arPartialMass .* this.oMT.tafDensity.gas);
            %keyboard();
            
            % Flow rate lower than zero - 'counter flow', i.e. the flow is
            % in the other direction than the fan blows.
            if fFlowRate < 0
                % Fan produces pressure drop
                fDeltaPress = this.fMaxDeltaP;
                
            % If the flow rate is greater than the max flow rate for the
            % fan, the pressure rise is zero
            elseif fFlowRate > fMaxFR
                fDeltaPress = 0;
                
            else
                % Iterpolation between max delta P and max flow rate
                fDeltaPress = -1 * (this.fMaxDeltaP - this.fMaxDeltaP / fMaxFR * fFlowRate);
            end
            
        end
        
        function fDeltaTemperature = updateManualSolver(this)
            fDeltaTemperature = this.fDeltaTemperature;
            
        end
    end
    
end

