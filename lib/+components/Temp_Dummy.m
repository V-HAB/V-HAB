classdef Temp_Dummy < matter.procs.f2f
    
    %This Temp_Dummy calculates the necessary heat flow to keep all fluid
    %passing through it at the specified temperature. It does not set the
    %temperature itself (even if it sets a DeltaTemp), the new solver uses
    %the heat flow instead to keep the temperature constant.

    properties (SetAccess = protected, GetAccess = public)
        fHydrDiam = 1;          % Hydraulic diameter value irrelevant for manual solver
        fHydrLength = 0;        % hydrauloc length, value irrelevant for manual solver
        fDeltaTemp = 0;         % Temperature difference created by the component in [K]
        fDeltaPress = 0;        % Pressure difference created by the component in [Pa]
        fTemperature;
        fMaxHeatFlow = inf;
        
    end
    
    methods
        function this = Temp_Dummy(oMT, sName, fTemperature, fMaxHeatFlow)
            this@matter.procs.f2f(oMT, sName);
            
            this.fTemperature = fTemperature;
            
            if nargin > 3
                this.fMaxHeatFlow = fMaxHeatFlow;
            end
            
            this.supportSolver('manual', true, @this.updateManualSolver);
            this.supportSolver('callback',  @this.solverDeltas);
        end
        
        function updateManualSolver(~)
        end
        function fDeltaPressure = solverDeltas(~, ~)
            fDeltaPressure = 0;
        end
        function updateThermal(this)
            if ~this.bActive
                this.fHeatFlow = 0;
            else
                try
                    [Flow1, Flow2] = this.getFlows();

                    if Flow1.fFlowRate > 0
                        inFlow = Flow1;
                    else
                        inFlow = Flow2;
                    end
                catch
                    inFlow = this.aoFlows(1);
                end
                this.fDeltaTemp = (this.fTemperature - inFlow.fTemperature);
                this.fHeatFlow = (inFlow.fFlowRate*inFlow.fSpecificHeatCapacity)*this.fDeltaTemp;
                if this.fHeatFlow > this.fMaxHeatFlow
                    this.fHeatFlow = this.fMaxHeatFlow;
                end
            end
        end
        
        
        function setActive(this, bActive, ~)
            this.bActive = bActive;
        end
    end
end