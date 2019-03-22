classdef liquid < matter.phases.flow.flow
    %% liquid_flow_node
    % A liquid phase that is modelled as containing no matter. 
    
    properties (Constant)

        % State of matter in phase (e.g. gas, liquid, solid)
        sType = 'liquid';
        
    end
    
    methods
        function this = liquid(oStore, sName, tfMasses, fTemperature, fPressure)
            
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
            this.fPressure = fPressure;
        end
    end
end

