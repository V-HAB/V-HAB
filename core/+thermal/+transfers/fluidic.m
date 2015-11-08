classdef fluidic < thermal.conductors.fluidic
    %FLUIDIC Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
    end
    
    methods
        
        function this = fluidic(oUpstreamCapacity, oDownstreamCapacity, fSpecificHeatCapacity, fMassOrVolumetricFlowRate, fDensity)
            
            if nargin > 4
                % We've got a volumetric flow rate, calculate mass flow
                % rate: 
                fMassFlowRate = fMassOrVolumetricFlowRate * fDensity;
            else
                % We've got a mass flow rate. 
                fMassFlowRate = fMassOrVolumetricFlowRate;
            end
            
            calcFunc = str2func([mfilename('class'), '.calculateConductance']);
            conductanceValue = calcFunc(fSpecificHeatCapacity, fMassFlowRate);
            
            sIdentifier = ['fluidic:', oUpstreamCapacity.sName, '+', oDownstreamCapacity.sName];
            this@thermal.conductors.fluidic(oUpstreamCapacity, oDownstreamCapacity, conductanceValue, sIdentifier);
            
        end
        
    end
    
    methods (Static)
        
        function conductanceValue = calculateConductance(fSpecificHeatCapacity, fMassFlowRate)
            
            conductanceValue = fSpecificHeatCapacity * fMassFlowRate;
            
        end
        
    end
    
end

