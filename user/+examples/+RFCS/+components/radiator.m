classdef radiator < matter.procs.f2f
    
    %This Temp_Dummy calculates the necessary heat flow to keep all fluid
    %passing through it at the specified temperature. It does not set the
    %temperature itself (even if it sets a DeltaTemp), the new solver uses
    %the heat flow instead to keep the temperature constant.
    
    properties (SetAccess = protected, GetAccess = public)
        fHydrDiam = 1;          % Hydraulic diameter value irrelevant for manual solver
        fHydrLength = 0;        % hydrauloc length, value irrelevant for manual solver
        fDeltaTemp = 0;         % Temperature difference created by the component in [K]
        fDeltaPress = 0;        % Pressure difference created by the component in [Pa]
        bActive = true;         % Must be true so the update function is called from the branch solver
        fTemperature;
        A=1;
        
    end
    
    methods
        function this = radiator(oMT, sName, A)
            this@matter.procs.f2f(oMT, sName);
            
            this.A = A;
            this.supportSolver('manual', true, @this.updateManualSolver);
        end
        
        function updateManualSolver(this)
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
            
            sigma=5.67*10^-8;
            e=0.4;
            this.fHeatFlow = -sigma*inFlow.fTemperature^4*this.A*e;
        end
        
        function setActive(this, bActive, ~)
            this.bActive = bActive;
        end
    end
end