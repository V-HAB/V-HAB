classdef branch < solver.matter.base.branch
% A manual solver where the user can choose from thee different options to
% manually set the mass flow rate:
% 1. Setting mass flowrate directly
% 2. volumetric solver where the user can set a volumetric flowrate
%    in m³/s by using the setVolumetricFlowRate function. The solver then uses
%    this volumetric flowrate and the respective density of the origin phase
%    to calculate the mass flow rate.
% 3. Setting a mass value in kg and a specific time in which that mass
%    shall be transfered. After the specified time the flowrate is
%    automatically set to 0
%
% Please note that the flowrate for all three functions is only set as
% requested flowrate initially and only in the posttick of V-HAB the
% requested flowrate will become the actual flow rate

    properties (SetAccess = protected, GetAccess = public)
        fRequestedFlowRate = 0;
        fRequestedVolumetricFlowRate;
    end
    
    properties (SetAccess = private, GetAccess = public)
        
        % Actual time between flow rate calculations
        fTimeStep = inf;
        
        % This parameter indicates that a fixed amount of mass is beeing
        % transfered
        bMassTransferActive = false;
        fMassTransferStartTime;
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
        
        
        function this = setFlowRate(this, fFlowRate)
            % Manualy sets the mass flowrate for the solver. 
            if this.bMassTransferActive
                warning(['Manual solver ', this.oBranch.sName, ' is currently transferring a fixed amount of mass, set the new flowrate after this is finished']);
                return
            end
            
            this.fRequestedFlowRate = fFlowRate;
            this.fRequestedVolumetricFlowRate = [];
            
            this.fTimeStep = inf;
            
            this.hBindPostTickUpdate      = this.oBranch.oTimer.registerPostTick(@this.update, 'matter' , 'solver');
            
            this.setTimeStep(this.fTimeStep);
            
            this.registerUpdate();
        end
        
        
        function this = setVolumetricFlowRate(this, fVolumetricFlowRate)
            % This function can be used to set the volumetric flowrate of
            % the branch in m³/s. The only required input is:
            % fVolumetricFlowRate   [m³/s]
            if this.bMassTransferActive
                warning(['Manual solver ', this.oBranch.sName, ' is currently transferring a fixed amount of mass, set the new flowrate after this is finished']);
                return
            end
            
            this.fRequestedVolumetricFlowRate = fVolumetricFlowRate;
            
            this.fTimeStep = inf;
            
            this.setTimeStep(this.fTimeStep);
            
            this.registerUpdate();
        end
        
        
        function setMassTransfer(this, fMass, fTime)
            % This function sets a specific mass that is transferred within
            % a specific time. After the mass has been transferred the
            % flowrate is set to 0 again. If a new mass transfer is
            % initialized while another one is already taking place, a
            % warning is displayed and the original mass transfer is
            % finished.
            %
            % Inputs are:
            % fMass in [kg]
            % fTime in [s]
            
            if fTime == 0
                error(['Stop joking, nothing can happen instantly. Manual solver ', this.oBranch.sName, ' was provided 0 time to transfer mass']);
            end
            this.fTimeStep = fTime;
            this.bMassTransferActive = true;
            this.fMassTransferStartTime = this.oBranch.oTimer.fTime;
            
            this.fRequestedFlowRate = fMass / fTime;
            this.fRequestedVolumetricFlowRate = [];
            
            this.setTimeStep(this.fTimeStep, true);
            
            this.registerUpdate();
        end
    end
    
    methods (Access = protected)
        function update(this)
            % We can't set the flow rate directly on this.fFlowRate or on
            % the branch, but have to provide that value to the parent
            % update method.
            
            %TODO distribute pressure drops equally over flows?
            
            % In the case of a fixed mass transfer the flowrate is reset to
            % zero once it is finished (which should occur within one tick)
            if this.bMassTransferActive && abs(this.oBranch.oTimer.fTime - (this.fMassTransferStartTime + this.fTimeStep)) < this.oBranch.oTimer.fMinimumTimeStep
                this.bMassTransferActive = false;
                this.fRequestedFlowRate = 0;
                
                this.fTimeStep = inf;
                this.setTimeStep(this.fTimeStep);
            elseif ~isempty(this.fRequestedVolumetricFlowRate)
                
                if this.fRequestedVolumetricFlowRate >= 0
                    fDensity = this.oBranch.coExmes{1}.oPhase.fDensity;
                else
                    fDensity = this.oBranch.coExmes{2}.oPhase.fDensity;
                end

                this.fRequestedFlowRate = this.fRequestedVolumetricFlowRate *  fDensity;
                
                this.fTimeStep = inf;

                this.setTimeStep(this.fTimeStep);
            
            end
            
            update@solver.matter.base.branch(this, this.fRequestedFlowRate);
            
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
