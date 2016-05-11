classdef radiative < thermal.conductors.radiative
    %RADIATIVE Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        fEmissivity;
        fAbsorptivity;
        fArea;
        fViewFactor;
    end
    
    methods
        
        function this = radiative(oLeftCapacity, oRightCapacity, fEmissivity, fAbsorptivity, fArea, fViewFactor)
            
            calcFunc = str2func([mfilename('class'), '.calculateConductance']);
            conductanceValue = calcFunc(fEmissivity, fAbsorptivity, fArea, fViewFactor);
            
            sIdentifier = ['radiative:', oLeftCapacity.sName, '+', oRightCapacity.sName];
            this@thermal.conductors.radiative(oLeftCapacity, oRightCapacity, conductanceValue, sIdentifier);
            
            
            this.fEmissivity   = fEmissivity;
            this.fAbsorptivity = fAbsorptivity;
            this.fArea         = fArea;
            this.fViewFactor   = fViewFactor;
        end
        
        
        
        % Shortcuts - emissivity/absorptivity can be set with
        % .updateThermalProperties(0.95, 0.75);
        function updateArea(this, fArea)
            this.updateThermalProperties([], [], fArea, []);
        end
        
        function updateViewFactor(this, fViewFactor)
            this.updateThermalProperties([], [], [], fViewFactor);
        end
        
        
        
        function updateThermalProperties(this, fEmissivity, fAbsorptivity, fArea, fViewFactor)
            
            if nargin >= 2 && ~isempty(fEmissivity)
                this.fEmissivity = fEmissivity;
            end
            
            if nargin >= 3 && ~isempty(fAbsorptivity)
                this.fAbsorptivity = fAbsorptivity;
            end
            
            if nargin >= 4 && ~isempty(fArea)
                this.fArea = fArea;
            end
            
            if nargin >= 5 && ~isempty(fViewFactor)
                this.fViewFactor = fViewFactor;
            end
            
            
            
            calcFunc = str2func([mfilename('class'), '.calculateConductance']);
            fConductanceValue = calcFunc(this.fEmissivity, this.fAbsorptivity, this.fArea, this.fViewFactor);
            
            this.setConductivity(fConductanceValue);
        end
    end
    
    methods (Static)
        
        function conductanceValue = calculateConductance(fEpsilon, fAlpha, fArea, fViewFactor)
            
            fStefanBoltzmann = 5.67037e-8;
            conductanceValue = fStefanBoltzmann * fEpsilon * fAlpha * fArea * fViewFactor;
            
        end
        
    end
    
end

