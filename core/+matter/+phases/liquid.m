classdef liquid < matter.phase
    %LIQUID Describes a volume of ideally mixed liquid. Usually liquids are
    % assumed incompressible in V-HAB compressible liquids are in principle
    % possible
    properties (Constant)
        % State of matter in phase (e.g. gas, liquid, ?)
        sType = 'liquid';
    end
        
    properties (SetAccess = protected, GetAccess = public)
        % The initial pressure from the phase definition is stored, for
        % cases where no volume manips are used an no fast pressure
        % calculation exists. For those cases the pressure is assumed to be
        % constant
        fInitialPressure;
    end
    methods
        
        function this = liquid(oStore, sName, tfMasses, fTemperature, fPressure)
            %% liquid class constructor
            % describes an ideally mixed volume of liquid. Different from the
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
            % fPressure     : Pressure of matter in phase
            this@matter.phase(oStore, sName, tfMasses, fTemperature);
            
            this.fTemperature = fTemperature;
            
            if nargin > 4
                this.fMassToPressure    = fPressure / this.fMass;
                this.fInitialPressure   = fPressure;
            else
                this.fMassToPressure    = this.oMT.Standard.Pressure / this.fMass;
                this.fInitialPressure   = this.oMT.Standard.Pressure;
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
            %% liquid update
            % calls the update methods of exmes as well because liquids can
            % be gravity driven!
            update@matter.phase(this);
            
            for k = 1:length(this.coProcsEXME)
                this.coProcsEXME{1, k}.update();
            end
        end
        function fPressure = get_fPressure(this)
            %% get_fPressure
            % defines how to calculate the dependent fPressure property.
            % Can be overloaded by child classes which require a different
            % calculation (e.g. flow phases)
            if this.iVolumeManipulators == 0
                % In this case no volume manipulator is present at all, for
                % this case we assume the initial pressure of the liquid to
                % remain constant
                fPressure = this.fInitialPressure;
                
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

