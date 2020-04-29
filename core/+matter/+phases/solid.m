classdef solid < matter.phase
    % SOLID desribes an ideally mixed solid phase. Note that solids will
    % assume standard pressure for the calculations unless the store
    % function addStandardVolumeManipulators is executed to add the
    % required volume manips or the manips are added by hand! Then the
    % solid will receive the pressure from the compressible phases

    properties (Constant)
        % State of matter in phase (e.g. gas, liquid, ?)
        sType = 'solid';
    end

    methods
        function this = solid(oStore, sName, tfMasses, fTemperature)
            %% solid class constructor
            % describes an ideally mixed volume of solid. Different from the
            % boundary and flow type phases the mass of this phase will
            % change and a time step is calculated limiting by how much the
            % phase properties are allowed to change. This type of phase
            % should be used e.g. to model the habitat atmosphere (boundary
            % would be e.g. the martian atmosphere, flow phases would be
            % e.g. individual phases within subsystems that are very small)
            %
            % Required Inputs:
            % oStore        : Name of parent store
            % sName         : Name of phase
            % tfMasses      : Struct containing mass value for each species
            % fTemperature  : Temperature of matter in phase
            this@matter.phase(oStore, sName, tfMasses, fTemperature);
            
            % Initialize to the standard pressure, if a different pressure
            % for solids should be calculated have a solid and gas phase in
            % one store and use the store function addStandardVolumeManipulators
            this.fMassToPressure    = this.oMT.Standard.Pressure / this.fMass;
            this.fDensity = this.oMT.calculateDensity(this);
            
            this.fVolume      = this.fMass / this.fDensity;
        end
    end
    methods (Access = protected)
        function this = update(this)
            %% solid update
            % sets the mass to pressure parameters if the corresponding
            % manips are used
            update@matter.phase(this);
            
            this.fDensity = this.fMass / this.fVolume;
            % the mass to pressure property for solids can only be
            % overwritten by incompressibleMedium volume manipulators.
            % Otherwise it will always be set to reflect the standard
            % pressure
            if ~isempty(this.toManips.volume)
                this.fMassToPressure    = this.oMT.Standard.Pressure / this.fMass;
            end
            
        end
        
        function fPressure = get_fPressure(this)
            %% get_fPressure
            % for solids we do not want to include the mass change between
            % updates as a pressure change
            if this.iVolumeManipulators == 0
                % In this case no volume manipulator is present at all, for
                % this case we assume the initial pressure of the liquid to
                % remain constant
                fPressure = this.oMT.Standard.Pressure;
                
            else
                if this.toManips.volume.bCompressible
                    fMassSinceUpdate = this.fCurrentTotalMassInOut * (this.oStore.oTimer.fTime - this.fLastMassUpdate);

                    fPressure = this.fMassToPressure * (this.fMass + fMassSinceUpdate);
                else
                    fPressure = this.toManips.volume.oCompressibleManip.oPhase.fPressure;
                end
            end
        end
    end
end