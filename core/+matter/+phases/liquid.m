classdef liquid < matter.phase
    %LIQUID Describes a volume of ideally mixed liquid. Usually liquids are
    % assumed incompressible in V-HAB compressible liquids are in principle
    % possible
    properties (Constant)

        % State of matter in phase (e.g. gas, liquid, ?)
        sType = 'liquid';

    end
    
    methods
        % oStore        : Name of parent store
        % sName         : Name of phase
        % tfMasses      : Struct containing mass value for each species
        % fTemperature  : Temperature of matter in phase
        % fPressure     : Pressure of matter in phase
        
        function this = liquid(oStore, sName, tfMasses, fTemperature, fPressure)

            this@matter.phase(oStore, sName, tfMasses, fTemperature);
            
            this.fTemperature = fTemperature;
            
            if nargin > 4
                this.fMassToPressure    = fPressure / this.fMass;
            else
                this.fMassToPressure    = this.oMT.Standard.Pressure / this.fMass;
            end
            
            this.fDensity = this.oMT.calculateDensity(this);
            
            if this.fMass == 0
                this.fVolume = 0;
            else
                this.fVolume      = this.fMass / this.fDensity;
            end
            
        end
    end
    %% Protected methods, called internally to update matter properties %%%
    methods (Access = protected)
        function this = update(this)
            update@matter.phase(this);
            
            for k = 1:length(this.coProcsEXME)
                this.coProcsEXME{1, k}.update();
            end
        end
    end
end

