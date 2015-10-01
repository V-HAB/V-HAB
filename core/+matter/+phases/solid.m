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
        function this = solid(oStore, sName, tfMasses, fTemperature)
            this@matter.phase(oStore, sName, tfMasses, fTemperature);
            
            csKeys = fieldnames(tfMasses);
            for iI = 1:length(csKeys)
                sKey = csKeys{iI};
                this.afVolume(this.oMT.tiN2I.(sKey)) = this.afMass(this.oMT.tiN2I.(sKey)) / this.oMT.ttxMatter.(sKey).ttxPhases.solid.fDensity;
            end
            this.fVolume  = sum(this.afVolume);
            this.fDensity = this.fMass / this.fVolume;
        end
    end
    
    %% Protected methods, called internally to update matter properties %%%
    methods (Access = protected)
        function setAttribute(this, sAttribute, xValue)
            % Internal helper, see @matter.phase class.
            %
            %TODO throw out, all done with events hm?
            
            this.(sAttribute) = xValue;
        end
    end
    
end

