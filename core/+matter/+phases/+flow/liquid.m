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
            
            
            % The constructor of the flow phase base class requires the
            % volume, so we need to calculate that here. First we get the
            % density. Since we can't use 'this' before calling the parent
            % constructor, we use the parent store's matter table object.
            fDensity = oStore.oMT.calculateDensity('liquid', tfMasses, fTemperature, fPressure);
            
            % Now calculating the mass by summing up all entries in the
            % tfMass struct. We have to convert it to a cell first. 
            cfMasses = struct2cell(tfMasses);
            fMass = sum([cfMasses{:}]);
            
            % And now we get the volume by simple division. 
            fVolume = fMass / fDensity;
            
            % Calling the parent constructor
            this@matter.phases.flow.flow(oStore, sName, tfMasses, fVolume, fTemperature);
            
            % Setting the pressure.
            this.fVirtualPressure = fPressure;
        end
    end
end

