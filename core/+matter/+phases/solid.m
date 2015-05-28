classdef solid < matter.phase
    %SOLID Summary of this class goes here
    %   Detailed explanation goes here

    properties (Constant)

        % State of matter in phase (e.g. gas, liquid, ?)
        % @type string
        %TODO: rename to |sMatterState|
        sType = 'solid';

    end

    properties (SetAccess = protected, GetAccess = public)
        afVolume;       % Array containing the volume of the individual species in m^3
        fVolume = 0;    % Volume of all solid species in m^3
    end
    
    methods
        function this = solid(oStore, sName, tfMasses, fTemp)
            this@matter.phase(oStore, sName, tfMasses, fTemp);
            
            csKeys = fieldnames(tfMasses);
            for iI = 1:length(csKeys)
                sKey = csKeys{iI};
                this.afVolume(this.oMT.tiN2I.(sKey)) = this.afMass(this.oMT.tiN2I.(sKey)) / this.oMT.ttxMatter.(sKey).ttxPhases.solid.fDensity;
            end
            this.fVolume  = sum(this.afVolume);
            this.fDensity = this.fMass / this.fVolume;
        end
    end
    
end

