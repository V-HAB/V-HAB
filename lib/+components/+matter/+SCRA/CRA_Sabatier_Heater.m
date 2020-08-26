classdef CRA_Sabatier_Heater < matter.procs.f2f
    
    %This heater calculates the heat flow that has to be transferred into
    %the coolant air flow in order too keep both sabatier reactors
    %constant. It is written specifically for this system (since it uses
    %the subsystem and flow to flow proc names to get the values) and will
    %not work for another system without any changes.

    properties (SetAccess = protected, GetAccess = public)
        fDeltaTemp = 0;        % Temperature difference created by the component in [K]
        fDeltaPress = 0;        % Pressure difference created by the component in [Pa]
    end
    
    methods
        function this = CRA_Sabatier_Heater(oContainer, sName)
            this@matter.procs.f2f(oContainer, sName);
            
            this.supportSolver('manual', true, @this.updateManualSolver);
        end
        
        function ThermalUpdate(this)
            this.updateManualSolver();
        end
        function updateManualSolver(this)
            %Tries to get the flows for this proc and if nothing flows it
            %sets the heat flow and temperature difference to 0
            try
                [Flow1, Flow2] = this.getFlows();
            catch
                this.fHeatFlow = 0;
                this.fDeltaTemp = 0;
                return
            end
            
            %If the flowrate is larger than 0 the first flow is the inlet
            %flow. Otherwise the second flow is the inlet flow
            if Flow1.fFlowRate > 0
                inFlow = Flow1;
            else
                inFlow = Flow2;
            end
            
            %the heat flow produced by the sabatier reactor
            fHeatFlowProducedSabatier = this.oContainer.toStores.CRA_Sabatier.aoPhases(1,1).toManips.substance.fHeatFlowProduced;
            %the heat flow required by the sabatier to maintain its
            %temperature. The difference between the produced heat flow and
            %the one that is required to keep the temperature constant is
            %the heat flow that the coolant air flow has to remove.
            fHeatFlowUpkeepSabatier = this.oContainer.toStores.CRA_Sabatier.aoPhases(1,1).oCapacity.toHeatSources.Sabatier_Constant_Temperature.fHeatFlow;
            
            %the heat flow that has to go into the cooling air to achieve a
            %constant temperature for both sabatier reactors
            this.fHeatFlow = fHeatFlowProducedSabatier - fHeatFlowUpkeepSabatier;
            
            fTemperatureOut = (this.fHeatFlow/(inFlow.fFlowRate*inFlow.fSpecificHeatCapacity))+inFlow.fTemperature;
            
            this.fDeltaTemp = (fTemperatureOut+inFlow.fTemperature);
        end
    end
end