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
        %afVolume;        % Array containing the volume of the individual substances in m^3
        fVolume = 0;     % Volume of all solid substances in m^3
        fPressure = NaN; % Placeholder/compatibility "pressure" since solids do not have an actual pressure.
    end
    
    methods
        
        function this = solid(oStore, sName, tfMasses, fIgnoredVolume, fTemperature, bAdsorber)
            %SOLID Create a new solid phase
            
            if nargin < 6
                bAdsorber = false;
            end
            this@matter.phase(oStore, sName, tfMasses, fTemperature, bAdsorber);
            
            
            csKeys = fieldnames(tfMasses);
            afVolumes = zeros(1,length(csKeys));
            for iI = 1:length(csKeys)
                sKey     = csKeys{iI};
                fMass    = this.afMass(this.oMT.tiN2I.(sKey));
                fVolumeSolid = this.oMT.calculateSolidVolume(tfMasses, fTemperature, bAdsorber);
                fDensity = fMass/fVolumeSolid;
                %what is the purpose of this?
                afVolumes(this.oMT.tiN2I.(sKey)) = fMass / fDensity;
            end
            this.fVolume  = sum(afVolumes);
            this.fDensity = this.fMass / this.fVolume;
            
            if ~isempty(fIgnoredVolume) && abs(1 - fIgnoredVolume / this.fVolume) > 1e-3
                this.warn('matter:phases:solid', 'Volume %d m^3 set for solid will be ignored. Instead, the value was set to %d m^3.', fIgnoredVolume, this.fVolume);
            end
            
        end
        
        function bSuccess = setVolume(this, ~)
            % Prevent volume from being set.
            bSuccess = false;
            this.throw('matter:phases:solid', 'Cannot compress a solid, duh!');
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

