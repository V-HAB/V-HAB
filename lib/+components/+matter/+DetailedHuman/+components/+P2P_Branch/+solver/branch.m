
classdef branch < solver.matter.base.branch
% This is a custom solver to implement transfers within the human model
% between the different layers without requiring a lot of interface
% phases. It basically creates a manual P2P as a branch, however this
% can lead to unforseen problems if it is used in a more general
% context, therefore it's usage is currently restricted to the human
% model!
% Base is still a manual solver, so here is the description of the manual
% solver:
% A manual solver where the user can choose from thee different options to
% manually set the mass flow rate:
% 1. Setting mass flowrate directly
% 2. volumetric solver not possible for P2P case
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
        fMassTransferFinishTime;
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
            
            this.fTimeStep = inf;
            
            % Now we register the solver at the timer, specifying the post
            % tick level in which the solver should be executed. For more
            % information on the execution view the timer documentation.
            % Registering the solver with the timer provides a function as
            % output that can be used to bind the post tick update in a
            % tick resulting in the post tick calculation to be executed
            this.hBindPostTickUpdate = this.oBranch.oTimer.registerPostTick(@this.update, 'matter' , 'solver');
            
            this.setTimeStep(this.fTimeStep);
            
        end
        
        
        function this = setFlowRate(this, afFlowRates)
            % Manualy sets the mass flowrate for the solver. 
            if this.bMassTransferActive
                warning(['Manual solver ', this.oBranch.sName, ' is currently transferring a fixed amount of mass, set the new flowrate after this is finished']);
                return
            elseif isempty(afFlowRates)
                this.throw('Setting an empty flowrate for manual branch %s in system %s', this.oBranch.sName, this.oBranch.oContainer.sName);
            end
            
            this.fRequestedFlowRate = sum(afFlowRates);
            this.oBranch.aoFlows.setMatterPropertiesBranch(afFlowRates);
            this.fRequestedVolumetricFlowRate = [];
            
            this.registerUpdate();
        end
        
        function setMassTransfer(this, afMass, fTime)
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
            if isempty(afMass) || isempty(fTime)
                this.throw('Setting an empty mass transfer for manual branch %s in system %s', this.oBranch.sName, this.oBranch.oContainer.sName);
            end
            this.fTimeStep = fTime;
            this.bMassTransferActive = true;
            this.fMassTransferStartTime = this.oBranch.oTimer.fTime;
            this.fMassTransferFinishTime = this.oBranch.oTimer.fTime + fTime;
            
            fMass = sum(afMass);
            this.oBranch.aoFlows.setMatterPropertiesBranch(afMass ./ fTime);
            
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
            if this.bMassTransferActive && abs(this.oBranch.oTimer.fTime - this.fMassTransferFinishTime) < this.oBranch.oTimer.fMinimumTimeStep
                this.bMassTransferActive = false;
                this.fRequestedFlowRate = 0;
                
                this.fTimeStep = inf;
                this.setTimeStep(this.fTimeStep);
            elseif this.bMassTransferActive && abs(this.oBranch.oTimer.fTime - this.fMassTransferFinishTime) > this.oBranch.oTimer.fMinimumTimeStep
                % If the branch is called before the set mass transfer time
                % step, the afLastExec property in the timer for this
                % branch is updated, while the timestep remains. This can
                % lead to the branch missing its update. Therefore, in
                % every update that occurs during a mass transfer that
                % does not fullfill the above conditions we have to reduce
                % the time step:
                this.fTimeStep = this.fMassTransferFinishTime - this.oBranch.oTimer.fTime;
                
                this.setTimeStep(this.fTimeStep, true);
            elseif ~isempty(this.fRequestedVolumetricFlowRate)
                
                if this.fRequestedVolumetricFlowRate >= 0
                    oPhase = this.oBranch.coExmes{1}.oPhase;
                else
                    oPhase = this.oBranch.coExmes{2}.oPhase;
                end
                % During initialization it is possible that the phase
                % fDensity property is empty
                if isempty(oPhase.fDensity)
                    fDensity = this.oMT.calculateDensity(oPhase);
                else
                    fDensity = oPhase.fDensity;
                end

                this.fRequestedFlowRate = this.fRequestedVolumetricFlowRate *  fDensity;
                
                this.fTimeStep = inf;

                this.setTimeStep(this.fTimeStep);
            
                % we have to reset the requested volumetric flowrate to
                % empty now, otherwise setting a mass flow rate in a later
                % tick would be ignored
                this.fRequestedVolumetricFlowRate = [];
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