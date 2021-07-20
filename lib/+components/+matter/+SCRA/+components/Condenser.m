classdef Condenser < matter.procs.f2f
    
    properties (SetAccess = protected, GetAccess = public)
        fHydrDiam = 1;          % Hydraulic diameter value irrelevant for manual solver
        fHydrLength = 0;        % hydrauloc length, value irrelevant for manual solver
        fDeltaTemp = 0;         % Temperature difference created by the component in [K]
        fTemperature;
        
        fTempChangeHeatFlow = 0;
        
        fCondensateFlow = 0;
        rHumiditySetPoint = 0.8;
        bActiveTemperatureRegulation = true;
    end
    
    methods
        function this = Condenser(oMT, sName, fTemperature, rHumiditySetPoint)
            this@matter.procs.f2f(oMT, sName);
            
            this.fTemperature = fTemperature;
            
            this.rHumiditySetPoint = rHumiditySetPoint;
            
            this.supportSolver('manual', true, @this.updateManualSolver);
            this.supportSolver('callback',  @this.solverDeltas);
        end
        
        function recalculateCondenser(this)
            
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
                    this.fDeltaTemp = (this.fTemperature - inFlow.fTemperature);
                    this.fTempChangeHeatFlow = (inFlow.fFlowRate*inFlow.fSpecificHeatCapacity)*this.fDeltaTemp;
                else
                    this.fTempChangeHeatFlow = 0;
                end
            end
        end
        
        function updateManualSolver(~)
        end
        function fDeltaPressure = solverDeltas(this, ~)
            fDeltaPressure = 0;
            this.recalculateCondenser();
        end
        function updateThermal(this)
            this.recalculateCondenser();
        end
        
        
        function setActive(this, bActive, ~)
            this.bActiveTemperatureRegulation = bActive;
        end
    end
end