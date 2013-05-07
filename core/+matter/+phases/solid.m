classdef Solid < Matter
    %SOLID Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        afVolume;       % Array containing the volume of the individual species in m^3
        fVolume = 0;    % Volume of all solid species in m^3
    end
    
    methods
        function this = Solid(tfMasses, fTemp)
            this@Matter(tfMasses, fTemp);
            
            csKeys = fieldnames(tfMasses);
            for iI = 1:length(csKeys)
                sKey = csKeys{iI};
                this.afVolume(this.oMT.tiN2I.(sKey)) = this.afMass(this.oMT.tiN2I.(sKey)) / this.oMT.ttxMatter.(sKey).fSolidDensity;
            end
            this.fVolume  = sum(this.afVolume);
            this.fDensity = this.fMass / this.fVolume;
        end
    end
    
end

