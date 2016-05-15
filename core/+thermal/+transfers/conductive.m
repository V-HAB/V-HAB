classdef conductive < thermal.conductors.linear
    %CONDUCTIVE Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        fThermalConductivity;
        fArea;
        fLength;
    end
    
    methods
        
        function this = conductive(oLeftCapacity, oRightCapacity, fThermalConductivity, fArea, fLength)
            
            calcFunc = str2func([mfilename('class'), '.calculateConductance']);
            conductanceValue = calcFunc(fThermalConductivity, fArea, fLength);
            
            sIdentifier = ['conductive:', oLeftCapacity.sName, '+', oRightCapacity.sName];
            this@thermal.conductors.linear(oLeftCapacity, oRightCapacity, conductanceValue, sIdentifier);
            
            
            this.fThermalConductivity = fThermalConductivity;
            this.fArea                = fArea;
            this.fLength              = fLength;
        end
        
        
        function updateThermalProperties(this, fThermalConductivity, fArea, fLength)
            
            if nargin >= 2 && ~isempty(fThermalConductivity)
                this.fThermalConductivity = fThermalConductivity;
            end
            
            if nargin >= 3 && ~isempty(fArea)
                this.fArea = fArea;
            end
            
            if nargin >= 4 && ~isempty(fLength)
                this.fLength = fLength;
            end
            
            
            
            calcFunc = str2func([mfilename('class'), '.calculateConductance']);
            fConductanceValue = calcFunc(this.fThermalConductivity, this.fArea, this.fLength);
            
            this.setConductivity(fConductanceValue);
        end
        
    end
    
    methods (Static)
        
        function conductanceValue = calculateConductance(fThermalConductivity, fArea, fLength)
            
            conductanceValue = fThermalConductivity * fArea / fLength;
            
        end
        
    end
    
end

