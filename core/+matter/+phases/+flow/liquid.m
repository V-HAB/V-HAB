classdef liquid < matter.phases.flow.flow
    %% liquid_flow_node
    % A liquid phase that is modelled as containing no matter. For implementation
    % purposes the phase does have a mass, but the calculations enforce
    % zero mass change for the phase and calculate all values based on the
    % inflows.
    
    properties (Constant)

        % State of matter in phase (e.g. gas, liquid, solid)
        sType = 'liquid';
        
    end
    
    methods
        function this = liquid(oStore, sName, tfMasses, fTemperature, fPressure)
            %% liquid flow node constructor
            % 
            % creates a new liquid flow node which is modelled as containing
            % no mass. The fMass property of the phase must still be
            % present for implementation purposes, but it will not change
            % from it's initial value.
            % Ideally a flow node is used together with a multibranch
            % solver to calculate the pressure of the phase as flow nodes
            % are considered very small phases.
            %
            % Required Inputs:
            % oStore        : Name of parent store
            % sName         : Name of phase
            % tfMasses      : Struct containing mass value for each species
            % fTemperature  : Temperature of matter in phase
            % fPressure     : Pressure of the phase
            
            % Calling the parent constructor
            % Note that the volume passed on here of 1e-6 is only a
            % momentary volume to enable the definition of the phase. This
            % value is overwriten by the calculation:
            % this.fVolume = this.fMass / this.fDensity;
            % within this constructor!
            this@matter.phases.flow.flow(oStore, sName, tfMasses, 1e-6, fTemperature);
            
            % Setting the pressure.
            this.fVirtualPressure = fPressure;
            this.updatePressure();
            
            this.fDensity = this.oMT.calculateDensity(this);
            this.fVolume = this.fMass / this.fDensity;
            
        end
    end
end

