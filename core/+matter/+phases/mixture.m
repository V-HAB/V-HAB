classdef mixture < matter.phase
    %mixture phase
    % this phase can be used to implement mixture phases that consist of
    % different substance that normally are at different phases (gas
    % liquid/solid). For example it can be used to create a phase that can
    % contain zeolite (solid) and CO2 (gas) and water (liquid) at the same
    % time. This is achieved by putting each substance into a subtype
    
    properties (Constant)
        % State of matter in phase (e.g. gas, liquid, ?)
        sType = 'mixture';
    end
    
    properties (SetAccess = protected, GetAccess = public)
        % Actual phase type of the matter in the phase, e.g. 'liquid',
        % 'solid' or 'gas'.
        sPhaseType;
        
        % The initial pressure from the phase definition is stored, for
        % cases where no volume manips are used an no fast pressure
        % calculation exists. For those cases the pressure is assumed to be
        % constant
        fInitialPressure;
        
        bGasPhase = false;
    end
    
    properties (Dependent)
        % Partial pressures [Pa]
        afPP;
        
        % Relative humidity in the phase
        rRelHumidity;
    
        % Substance concentrations in ppm. This is a dependent property because it is
        % only calculated on demand because it should rarely be used. if
        % the property is used often, making it not a dependent property or
        % providing a faster calculation option is suggested
        afPartsPerMillion;
    end
    
    methods
        function this = mixture(oStore, sName, sPhaseType, tfMasses, fTemperature, fPressure)
            %% mixture class constructor
            % describes an ideally mixed volume of mixture. The mixture
            % phase can be used to describe phases where the general
            % seperation of matter in different phase types does not work.
            % E.g. for the adsorption of a gas into a solid or liquid
            % (where normally the matter table would crash) or for solids
            % which are aerosols in a gas phase.
            %
            % Different from the boundary and flow type phases the mass of
            % this phase will change and a time step is calculated limiting
            % by how much the phase properties are allowed to change. This
            % type of phase should be used e.g. to model the habitat
            % atmosphere (boundary would be e.g. the martian atmosphere,
            % flow phases would be e.g. individual phases within subsystems
            % that are very small)
            %
            % Required Inputs:
            % oStore        : Name of parent store
            % sName         : Name of phase
            % sPhaseType    : The primary state of the matter. E.g. if it
            %                 is a gas phase which has solids as aerosols
            % tfMasses      : Struct containing mass value for each species
            % fTemperature  : Temperature of matter in phase
            % fPressure     : Pressure of matter in phase
            this@matter.phase(oStore, sName, tfMasses, fTemperature);
            
            this.sPhaseType = sPhaseType;
            this.fInitialPressure = fPressure;
            if strcmp(this.sPhaseType, 'gas')
                this.bGasPhase = true;
            end
            if this.fMass == 0
                this.fMassToPressure = 0;
            else
                this.fMassToPressure = fPressure / this.fMass;
            end
            this.fDensity = this.oMT.calculateDensity(this);
            this.fVolume = this.fMass / this.fDensity;
            
            this.bMixture = true;
        end
        
        
        function afPP = get.afPP(this)
            if ~this.bGasPhase
                error('phase:mixture:invalidAccessPartialPressures', 'you are trying to access a gas property in a mixture phase that is not set a gas type!')
            end
            afPP               = this.oMT.calculatePartialPressures(this);
        end
        
        function rRelHumidity = get.rRelHumidity(this)
            if ~this.bGasPhase
                error('phase:mixture:invalidAccessHumidity', 'you are trying to access a gas property in a mixture phase that is not set a gas type!')
            end
            % Check if there is water in here at all
            if this.afPP(this.oMT.tiN2I.H2O)
                % calculate saturation vapour pressure [Pa];
                fSaturationVapourPressure = this.oMT.calculateVaporPressure(this.fTemperature, 'H2O');
                % calculate relative humidity
                rRelHumidity = this.afPP(this.oMT.tiN2I.H2O) / fSaturationVapourPressure;
            else
                rRelHumidity = 0;
            end
        end
        function afPartsPerMillion = get.afPartsPerMillion(this)
            % Calculates the PPM value on demand.
            % Made this a dependent variable to reduce the computational
            % load during run-time since the value is rarely used. 
            if ~this.bGasPhase
                error('phase:mixture:invalidAccessPartsPerMillion', 'you are trying to access a gas property in a mixture phase that is not set a gas type!')
            end
            afPartsPerMillion = this.oMT.calculatePartsPerMillion(this);
        end
    end
    
    
    methods (Access = protected)
        function this = update(this)
            %% mixture update
            % update the current state of the mixture, pressure is
            % currently only calculated for gas phases
            update@matter.phase(this);
            
            this.fDensity = this.fMass / this.fVolume;
            
            if strcmp(this.sPhaseType, 'gas')
                if this.fMass == 0
                    this.fMassToPressur = 0;
                else
                    this.fMassToPressure = this.oMT.calculatePressure(this) / this.fMass;
                end
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

