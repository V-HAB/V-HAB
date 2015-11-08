classdef convective < thermal.conductors.linear
    %CONVECTIVE Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
    end
    
    methods
        
        function this = convective(oLeftCapacity, oRightCapacity, fHeatTransferCoeff, fArea)
            
            calcFunc = str2func([mfilename('class'), '.calculateConductance']);
            conductanceValue = calcFunc(fHeatTransferCoeff, fArea);
            
            sIdentifier = ['convective:', oLeftCapacity.sName, '+', oRightCapacity.sName];
            this@thermal.conductors.linear(oLeftCapacity, oRightCapacity, conductanceValue, sIdentifier);
            
        end
        
    end
    
    methods (Static)
        
        function conductanceValue = calculateConductance(fHeatTransfCoeff, fArea)
            
            conductanceValue = fHeatTransfCoeff * fArea;
            
        end
        
    end
    
end

