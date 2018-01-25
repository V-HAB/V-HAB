classdef convective < thermal.conductors.linear
    %CONVECTIVE Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        fHeatTransferCoeff;
        fArea;
    end
    
    methods
        
        function this = convective(oLeftCapacity, oRightCapacity, fHeatTransferCoeff, fArea)
            
            calcFunc = str2func([mfilename('class'), '.calculateConductance']);
            conductanceValue = calcFunc(fHeatTransferCoeff, fArea);
            
            sIdentifier = ['convective:', oLeftCapacity.sName, '+', oRightCapacity.sName];
            this@thermal.conductors.linear(oLeftCapacity, oRightCapacity, conductanceValue, sIdentifier);
            
            
            this.fHeatTransferCoeff = fHeatTransferCoeff;
            this.fArea              = fArea;
        end
        
        
        
        function updateThermalProperties(this, fHeatTransferCoeff, fArea)
            
            if nargin >= 2 && ~isempty(fHeatTransferCoeff)
                this.fHeatTransferCoeff = fHeatTransferCoeff;
            end
            
            if nargin >= 3 && ~isempty(fArea)
                this.fArea = fArea;
            end
            
            
            
            calcFunc = str2func([mfilename('class'), '.calculateConductance']);
            fConductanceValue = calcFunc(this.fHeatTransferCoeff, this.fArea);
            
            this.setConductivity( fConductanceValue);
        end
    end
    
    methods (Static)
        
        function conductanceValue = calculateConductance(fHeatTransfCoeff, fArea)
            
            conductanceValue = fHeatTransfCoeff * fArea;
            
        end
        
    end
    
end

