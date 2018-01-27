classdef convective < thermal.procs.conductor
    %CONVECTIVE Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        fHeatTransferCoeff;
        fArea;
        
        
        bRadiative  = false;
        bConvective = true;
        bConductive = false;
    end
    
    methods
        
        function this = convective(oContainer, sName, fHeatTransferCoeff, fArea)
            
            
            this@thermal.procs.conductor(oContainer, sName);
            
            
            this.fHeatTransferCoeff = fHeatTransferCoeff;
            this.fArea              = fArea;
        end
        
        
        % TO DO:
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

