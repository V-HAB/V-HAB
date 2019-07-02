classdef convectiveConductorPlate < thermal.procs.conductors.convective
    % A convective conductor to model convective heat transfer between a
    % fluid in a pipe and the pipe wall
    
    properties (SetAccess = protected)
        % hydraulic diameter of the pipe
        fBroadness; % [m]
        % length of the plate
        fLength; % [m]
        
        % Area perpendicular to the flow passing along the plate. Necessary
        % to calculate a flow speed from the provided mass flow rate of the
        % matter branch
        fFlowArea; % [m^2]
    end
    
    methods
        
        function this = convectiveConductorPlate(oContainer, sName, oMassBranch, iFlow, fBroadness, fLength, fFlowArea)
            % Create a convective conductor to calculate convective heat
            % transfer over a plat. The necessary inputs are:
            % oContainer:       The system in which the conductor is placed
            % sName:            A name for the conductor which is not
            %                   shared by other conductors within oContainer
            % oMassBranch:      The matter branch which models the mass
            %                   flow through the pipe
            % iFlow:            The number of the flow  within this branch
            %                   which should be modelled by this conductor
            %                   (necessary for matter properties)
            % fBroadness:       The broadness of the plate in m
            % fLength:          The length of the plate
            
            % Calculate the heat transfer area from the provided inputs
            fArea = fLength * fBroadness;
            
            % create the supraclass convective conductor
            this@thermal.procs.conductors.convective(oContainer, sName, fArea, oMassBranch, iFlow)
            
            this.fFlowArea = fFlowArea;
            
            % store properties
            this.fBroadness     = fBroadness;
            this.fLength      	= fLength;
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
                fFlowSpeed = (oFlow.fFlowRate / fDensity) / this.fFlowArea;

                % calculate the convective heat transfer coefficient using a
                % pipe as an assumption
                fConvection_alpha = functions.calculateHeatTransferCoefficient.convectionPlate (this.fLength, fFlowSpeed, fDynamicViscosity, fDensity, fThermalConductivity, fSpecificHeatCapacity);

                % Calculate the thermal conductivity of the connection in [W/m^2 K]
                fHeatTransferCoefficient = fConvection_alpha;
            end
        end
    end
end

