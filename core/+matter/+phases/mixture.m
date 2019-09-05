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
            if strcmp(this.sPhaseType, 'gas')
                this.fMassToPressure = this.oMT.Const.fUniversalGas * this.fTemperature / (this.fMolarMass * this.fVolume);
            else
                if this.fMass == 0
                    this.fMassToPressure = 0;
                else
                    this.fMassToPressure = fPressure / this.fMass;
                end
            end
            this.fDensity = this.oMT.calculateDensity(this);
            this.fVolume = this.fMass / this.fDensity;
            
            this.bMixture = true;
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
            % for mixtures we do not want to include the mass change between
            % updates as a pressure change
            fPressure = this.fMassToPressure * this.fMass;
        end
    end
end

