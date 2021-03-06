classdef solid < matter.phases.boundary.boundary
    %% solid_boundary
    % A solid phase that is modelled as containing an infinite amount of matter
    % with specifiable (and changeable) values for the composition and
    % temperature. The intended use case is e.g. to model vacuum in space
    % and environmental conditions in test cases
    properties (Constant)
        % State of matter in phase (e.g. gas, liquid, ?)
        sType = 'solid';
    end
    
    methods
        function this = solid(oStore, sName, tfMass, fTemperature, fPressure)
            %% solid boundary class constructor
            %
            % creates a solid boundary phase with the specific conditions.
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
            
            this.fMassToPressure =  fPressure / sum(this.afMass);
            
            tProperties.afMass = this.afMass;
            this.setBoundaryProperties(tProperties)
            
        end
    end
end