classdef convectiveConductorPipe < thermal.procs.conductors.convective
    properties (SetAccess = protected)
        % hydraulic diameter of the pipe
        fHydraulicDiameter;
        % length of the pipe
        fLength;
    end
    
    methods
        
        function this = convectiveConductorPipe(oContainer, sName, oMassBranch, iFlow, fHydraulicDiameter, fLength)
            % calculate the heat transfer area from the provided inputs
            fArea = fLength * pi * fHydraulicDiameter;
            
            this@thermal.procs.conductors.convective(oContainer, sName, fArea, oMassBranch, iFlow)
            
            this.fHydraulicDiameter = fHydraulicDiameter;
            this.fLength            = fLength;
            
        end
        
        function fHeatTransferCoefficient = updateHeatTransferCoefficient(this, ~)
            % Get the corresponding flow from the ascociated mass branch
            oFlow = this.oMassBranch.aoFlows(this.iFlow);
            
            if oFlow.fFlowRate == 0
                fHeatTransferCoefficient = 0;
            else
                % calculate the matter properties
                fDensity              = this.oMT.calculateDensity(oFlow);
                fDynamicViscosity     = this.oMT.calculateDynamicViscosity(oFlow);
                fThermalConductivity  = this.oMT.calculateThermalConductivity(oFlow);
                fSpecificHeatCapacity = this.oMT.calculateSpecificHeatCapacity(oFlow);

                fFlowSpeed = (oFlow.fFlowRate / fDensity) / this.fArea;

                % calculate the convective heat transfer coefficient using a
                % pipe as an assumption
                fConvection_alpha = functions.calculateHeatTransferCoefficient.convectionPipe(this.fHydraulicDiameter, this.fLength, fFlowSpeed, fDynamicViscosity, fDensity, fThermalConductivity, fSpecificHeatCapacity, 0);

                % Calculate the thermal conductivity of the connection in [W/K]
                fHeatTransferCoefficient = fConvection_alpha * this.fArea;
            end
        end
    end
end

