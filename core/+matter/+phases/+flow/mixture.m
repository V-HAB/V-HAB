classdef mixture < matter.phases.flow.flow
    %% mixture_flow_node
    % A mixture phase that is modelled as containing no matter. For implementation
    % purposes the phase does have a mass, but the calculations enforce
    % zero mass change for the phase and calculate all values based on the
    % inflows.
    
    properties (Constant)
        % State of matter in phase (e.g. gas, liquid, solid)
        sType = 'mixture';
    end
    
    properties (SetAccess = protected, GetAccess = public)
        % Actual phase type of the matter in the phase, e.g. 'liquid',
        % 'solid' or 'gas'.
        sPhaseType;
    end
    
    methods
        function this = mixture(oStore, sName, sPhaseType, tfMass, fTemperature, fPressure)
            %% mixture flow node constructor    
            % 
            % creates a new mixture flow node which is modelled as containing
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
            if ~isempty(tfMass)
                fDensity = oStore.oMT.calculateDensity('mixture', tfMass, fTemperature, fPressure);

                % Now calculating the mass by summing up all entries in the
                % tfMass struct. We have to convert it to a cell first. 
                cfMasses = struct2cell(tfMass);
                fMass = sum([cfMasses{:}]);

                % And now we get the volume by simple division. 
                fVolume = fMass / fDensity;
            else
                fVolume = 0;
            end
            
            this@matter.phases.flow.flow(oStore, sName, tfMass, fVolume, fTemperature);
            
            this.sPhaseType = sPhaseType;
            if nargin > 6
                this.fVirtualPressure = fPressure;
            else
                this.fVirtualPressure = 1e5;
            end
        end
    end
end

