classdef convectiveConductorPipe < thermal.procs.conductors.convective
    % A convective conductor to model convective heat transfer between a
    % fluid in a pipe and the pipe wall
    
    properties (SetAccess = protected)
        % hydraulic diameter of the pipe
        fHydraulicDiameter; % [m]
        % length of the pipe
        fLength; % [m]
    end
    
    methods
        
        function this = convectiveConductorPipe(oContainer, sName, oMassBranch, iFlow, fHydraulicDiameter, fLength)
            % Create a convective conductor to calculate convective heat
            % transfer within a pipe. The necessary inputs are:
            % oContainer:       The system in which the conductor is placed
            % sName:            A name for the conductor which is not
            %                   shared by other conductors within oContainer
            % oMassBranch:      The matter branch which models the mass
            %                   flow through the pipe
            % iFlow:            The number of the flow  within this branch
            %                   which should be modelled by this conductor
            %                   (necessary for matter properties)
            % fHydraulicDiameter:   The hydraulic diameter of the pipe
            % fLength:              The length of the pipe
            
            % Calculate the heat transfer area from the provided inputs
            fArea = fLength * pi * fHydraulicDiameter;
            
            % create the supraclass convective conductor
            this@thermal.procs.conductors.convective(oContainer, sName, fArea, oMassBranch, iFlow)
            
            % store properties
            this.fHydraulicDiameter = fHydraulicDiameter;
            this.fLength            = fLength;
        end
        
        function fHeatTransferCoefficient = updateHeatTransferCoefficient(this, ~)
            % Update the heat transfer coefficient of this conductor. 
            % This function is bound to the setFlowRate trigger of the
            % asscociated mass branch, meaning it is recalculated once the
            % mass branch calculates a new flow rate. This ensures that the
            % correct value for the heat transfer coefficient is always
            % used.
            % Outputs:
            % fHeatTransferCoefficient in [W/K]
            
            % Get the corresponding flow from the ascociated mass branch
            oFlow = this.oMassBranch.aoFlows(this.iFlow);
            
            % check if the flowrate is 0, if that is the case the transfer
            % coefficient is 0
            if oFlow.fFlowRate == 0
                fHeatTransferCoefficient = 0;
            else
                % calculate the matter properties
                fDensity              = this.oMT.calculateDensity(oFlow);
                fDynamicViscosity     = this.oMT.calculateDynamicViscosity(oFlow);
                fThermalConductivity  = this.oMT.calculateThermalConductivity(oFlow);
                fSpecificHeatCapacity = this.oMT.calculateSpecificHeatCapacity(oFlow);

                % calculate the current flowspeed
                fFlowSpeed = (oFlow.fFlowRate / fDensity) / (0.25 * pi * this.fHydraulicDiameter^2);

                % calculate the convective heat transfer coefficient using a
                % pipe as an assumption
                fConvection_alpha = functions.calculateHeatTransferCoefficient.convectionPipe(this.fHydraulicDiameter, this.fLength, fFlowSpeed, fDynamicViscosity, fDensity, fThermalConductivity, fSpecificHeatCapacity, 0);

                % Calculate the thermal conductivity of the connection in [W/m^2 K]
                fHeatTransferCoefficient = fConvection_alpha;
            end
        end
    end
end

