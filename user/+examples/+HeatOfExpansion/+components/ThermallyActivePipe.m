classdef ThermallyActivePipe < components.matter.pipe
    %ThermallyActivePipe a pipe which also models the heat flow from the
    %expansion/compression within it
    
    methods
        %% Constructor
        function this = ThermallyActivePipe(oContainer, sName, fLength, fDiameter, fRoughness)

            if nargin < 5
                fRoughness = 0;                
            end

            this@components.matter.pipe(oContainer, sName, fLength, fDiameter, fRoughness)

        end
        
        %% Update function for callback solver
        function fDeltaPressure = solverDeltas(this, fFlowRate)
            % First we use the standard pipe calculation to calculate the
            % pressure difference
            fDeltaPressure = solverDeltas@components.matter.pipe(this, fFlowRate);
            
            % now we select the in flow to use for matter property values
            if fFlowRate >= 0
                oFlow = this.aoFlows(1);
            else
                oFlow = this.aoFlows(2);
            end
            
            % calculate the joule thomson coefficient in K/Pa
            fJouleThomson = this.oMT.calculateJouleThomson(oFlow);
            
            % calculate the heat flow based on HeatFlow = MassFlow *
            % SpecificHeatCapacity * Delta Temperature, where delta
            % temperature is the pressure difference times the joule
            % thomson coefficient. Since a postivie delta pressure from the
            % pipe is handled as a pressure loss, a negative sign for this
            % calculation is required
            this.fHeatFlow = - abs(fFlowRate) * oFlow.fSpecificHeatCapacity * fJouleThomson * fDeltaPressure;
            
        end
    end
end