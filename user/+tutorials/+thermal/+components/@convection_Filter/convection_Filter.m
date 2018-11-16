classdef convection_Filter < thermal.procs.conductors.convective
    
    properties (SetAccess = protected)
        fLength;
        fBroadness;
        fFlowArea;
    end
    
    methods
        
        function this = convection_Filter(oContainer, sName, fLength, fBroadness, fFlowArea, oMassBranch, iFlow)
            % Create a convective conductor instance
             
            fArea = fLength * fBroadness;
            this@thermal.procs.conductors.convective(oContainer, sName, fArea, oMassBranch, iFlow);
            
            this.fLength    = fLength;
            this.fBroadness = fBroadness;
            this.fFlowArea  = fFlowArea;
        end
        
        
        function fConvection_alpha = updateHeatTransferCoefficient(this, ~)
            
            % gets the required matter properties
            fDensity = this.oMT.calculateDensity(this.oMassBranch.aoFlows(this.iFlow));
            
            if fDensity == 0
                fConvection_alpha = 0;
                return
            end
            
            fSpecificHeatCapacity       = this.oMT.calculateSpecificHeatCapacity (this.oMassBranch.aoFlows(this.iFlow));
            fThermal_Conductivity       = this.oMT.calculateThermalConductivity(this.oMassBranch.aoFlows(this.iFlow));
            fDyn_Visc                   = this.oMT.calculateDynamicViscosity(this.oMassBranch.aoFlows(this.iFlow));
            
            % calculates the current flow speed
            fFlowSpeed = this.oMassBranch.fFlowRate / (this.fFlowArea * fDensity);
            
            if fFlowSpeed == 0
                fConvection_alpha = 0;
            else
                fConvection_alpha = functions.calculateHeatTransferCoefficient.convectionPlate(this.fLength, fFlowSpeed, fDyn_Visc, fDensity, fThermal_Conductivity, fSpecificHeatCapacity);
            end
        end
        
    end
    
end

