classdef branch < solver.matter.base.branch
% A manual volumetric solver where the user can set a volumetric flowrate
% in m³/s by using the setVolumetricFlowRate function. The solver then uses
% this volumetric flowrate and the respective density of the origin phase
% to calculate the mass flow rate.

    properties (SetAccess = protected, GetAccess = public)
        fRequestedVolumetricFlowRate = 0;
    end
    
    properties (SetAccess = private, GetAccess = public)
        
    end
    
    properties (SetAccess = private, GetAccess = private) %, Transient = true)
        %TODO These properties should be transient. That requires a static
        % method (loadobj) to be implemented in this class, so when the
        % simulation is re-loaded from a .mat file, the properties are
        % reset to their proper values.
        
    end
    
    methods
        function this = branch(oBranch)
            this@solver.matter.base.branch(oBranch, [], 'manual');
        end
        
        
        function this = setVolumetricFlowRate(this, fVolumetricFlowRate)
            % This function can be used to set the volumetric flowrate of
            % the branch in m³/s. The only required input is:
            % fVolumetricFlowRate   [m³/s]
            this.fRequestedVolumetricFlowRate = fVolumetricFlowRate;
            
            this.registerUpdate();
        end
    end
    
    methods (Access = protected)
        function update(this)
            % We can't set the flow rate directly on this.fFlowRate or on
            % the branch, but have to provide that value to the parent
            % update method.

            %TODO distribute pressure drops equally over flows?
            if this.fRequestedVolumetricFlowRate >= 0
                fDensity = this.oBranch.coExmes{1}.oPhase.fDensity;
            else
                fDensity = this.oBranch.coExmes{2}.oPhase.fDensity;
            end
            fFlowRate = this.fRequestedVolumetricFlowRate *  fDensity;
            
            update@solver.matter.base.branch(this, fFlowRate);
            
            % Checking if there are any active processors in the branch,
            % if yes, update them.
            if ~isempty(this.oBranch.aoFlowProcs)
            
                % Checking if there are any active processors in the branch,
                % if yes, update them.
                abActiveProcs = zeros(1, length(this.oBranch.aoFlowProcs));
                for iI=1:length(this.oBranch.aoFlowProcs)
                    if isfield(this.oBranch.aoFlowProcs(iI).toSolve, 'manual')
                        abActiveProcs(iI) = this.oBranch.aoFlowProcs(iI).toSolve.manual.bActive;
                    else
                        abActiveProcs(iI) = false;
                    end
                end
    
                for iI = 1:length(abActiveProcs)
                    if abActiveProcs(iI)
                        this.oBranch.aoFlowProcs(iI).toSolve.manual.update();
                    end
                end
            end
        end
    end
end
