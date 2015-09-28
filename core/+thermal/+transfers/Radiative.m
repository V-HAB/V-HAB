classdef Radiative < thermal.conductors.Radiative
    %RADIATIVE Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
    end
    
    methods
        
        function this = Radiative(oLeftCapacity, oRightCapacity, fEmissivity, fAbsorptivity, fArea, fViewFactor)
            
            calcFunc = str2func([mfilename('class'), '.calculateConductance']);
            conductanceValue = calcFunc(fEmissivity, fAbsorptivity, fArea, fViewFactor);
            
            sIdentifier = ['radiative:', oLeftCapacity.sName, '+', oRightCapacity.sName];
            this@thermal.conductors.Radiative(oLeftCapacity, oRightCapacity, conductanceValue, sIdentifier);
            
        end
        
    end
    
    methods (Static)
        
        function conductanceValue = calculateConductance(fEpsilon, fAlpha, fArea, fViewFactor)
            
            fStefanBoltzmann = 5.67037e-8;
            conductanceValue = fStefanBoltzmann * fEpsilon * fAlpha * fArea * fViewFactor;
            
        end
        
    end
    
end

