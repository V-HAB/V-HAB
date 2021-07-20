classdef CondenserTemperatureChange < matter.procs.f2f
    
    properties (SetAccess = protected, GetAccess = public)
        fHydrDiam = 1;          % Hydraulic diameter value irrelevant for manual solver
        fHydrLength = 0;        % hydrauloc length, value irrelevant for manual solver
        fDeltaTemp = 0;         % Temperature difference created by the component in [K]
        fTemperature;
        
        oCondenser;
        bActiveTemperatureRegulation = true;
    end
    
    methods
        function this = CondenserTemperatureChange(oMT, sName, oCondenser)
            this@matter.procs.f2f(oMT, sName);
            
            this.oCondenser = oCondenser;
            
            this.supportSolver('manual', true, @this.updateManualSolver);
            this.supportSolver('callback',  @this.solverDeltas);
        end
        
        function recalculateCondenserTemperatureChange(this)
            
            if ~this.bActiveTemperatureRegulation
                this.fTempChangeHeatFlow = 0;
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
                if this.fTemperature < inFlow.fTemperature
                    this.fDeltaTemp = (this.oCondenser.fTemperature - inFlow.fTemperature);
                    this.fHeatFlow = (inFlow.fFlowRate*inFlow.fSpecificHeatCapacity)*this.fDeltaTemp;
                else
                    this.fHeatFlow = 0;
                end
            end
        end
        
        function updateManualSolver(~)
        end
        function fDeltaPressure = solverDeltas(~, ~)
            fDeltaPressure = 0;
        end
        function updateThermal(this)
            this.recalculateCondenserTemperatureChange();
        end
        
        
        function setActive(this, bActive, ~)
            this.bActiveTemperatureRegulation = bActive;
        end
    end
end