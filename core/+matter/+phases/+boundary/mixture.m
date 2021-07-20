classdef mixture < matter.phases.boundary.boundary
    %% mixture_boundary
    % A solid phase that is modelled as containing an infinite amount of matter
    % with specifiable (and changeable) values for the composition and
    % temperature. The intended use case is e.g. to model vacuum in space
    % and environmental conditions in test cases
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
        function this = mixture(oStore, sName, sPhaseType, tfMass, fTemperature, fPressure)
            %% mixture boundary class constructor
            %
            % creates a mixture boundary phase with the specifid conditions.
            % These will remain constant throughout the simulation unless
            % they are directly changed using the setBoundaryProperties
            % function!
            %
            % Required inputs:
            % oStore        : Name of parent store
            % sName         : Name of phase
            % tfMasses      : Struct containing mass value for each species
            % fTemperature  : Temperature of matter in phase
            % fPressure     : Pressure of the phase

            this@matter.phases.boundary.boundary(oStore, sName, tfMass, fTemperature);
            
            this.sPhaseType = sPhaseType;
            this.fMassToPressure =  fPressure / sum(this.afMass);
            
            tProperties.afMass = this.afMass;
            this.setBoundaryProperties(tProperties)
            
        end
    end
end