classdef ManualP2P < matter.procs.p2ps.stationary
    % This p2p is designed to function like the manual solver for branches.
    % The user can use the setFlowRate function to specify the desired
    % partial mass flowrates (in kg/s) in an array (array has to be the
    % size of oMT.iSubstances with zeros for unused flowrates). For p2Ps
    % all flowrates have to be in the same direction, there is no check if
    % both a positive and a negative flowrate have been defined because
    % this would require calculation time, just do not do this ;)
    
    properties (SetAccess = protected, GetAccess = public)
        
        afFlowRates;
        
        bMassTransferActive = false;
        fMassTransferStartTime;
        fMassTransferTime;
        fMassTransferFinishTime;
        
    end
    
    properties (SetAccess = private, GetAccess = protected)
        % function handle registered at the timer object that allows this
        % phase to set a time step, which is then enforced by the timer
        setMassTransferTimeStep;
    end
    
    methods
        function this = ManualP2P(oStore, sName, sPhaseAndPortIn, sPhaseAndPortOut)
            this@matter.procs.p2ps.stationary(oStore, sName, sPhaseAndPortIn, sPhaseAndPortOut);
            
            this.setMassTransferTimeStep = this.oTimer.bind(@(~) this.checkMassTransfer(), 0, struct(...
                'sMethod', 'checkMassTransfer', ...
                'sDescription', 'The .checkMassTransfer method of a manual P2P', ...
                'oSrcObj', this ...
            ));
            % initialize the time step to inf
            this.setMassTransferTimeStep(inf, true);
        end
        
        function setFlowRate(this, afPartialFlowRates)
            % transforms the specified flowrates into the overall flowrate
            % and the partial mass ratios.
            if this.bMassTransferActive
                warning('Currently a mass transfer is in progress')
            end
                
            this.afFlowRates = afPartialFlowRates;
            
            % Connected phases have to do a massupdate before we set the
            % new flow rate - so the mass for the LAST time step, with the
            % old flow rate, is actually moved from tank to tank. In the
            % massupdate the update for the P2P will be triggered, which is
            % then executed in the post tick after the phase massupdates
            if this.oIn.oPhase.fLastMassUpdate == this.oTimer.fTime && this.oOut.oPhase.fLastMassUpdate == this.oTimer.fTime
                this.update();
            else
                this.oIn.oPhase.registerMassupdate();
                this.oOut.oPhase.registerMassupdate();
            end
        end
        
        function setMassTransfer(this, afPartialMasses, fTime)
            % This function sets a specific mass that is transferred within
            % a specific time. After the mass has been transferred the
            % flowrate is set to 0 again. If a new mass transfer is
            % initialized while another one is already taking place, a
            % warning is displayed and the original mass transfer is
            % finished. The required input for the transport is an afMass
            % vector with corresponding partial masses
            %
            % Inputs are:
            % afPartialMasses in [kg]
            % fTime in [s]
            if fTime == 0
                error(['Stop joking, nothing can happen instantly. Manual solver ', this.oBranch.sName, ' was provided 0 time to transfer mass']);
            end
            
            if this.bMassTransferActive
                warning('Currently a mass transfer is in progress')
            end
            
            this.bMassTransferActive = true;
            this.fMassTransferStartTime = this.oTimer.fTime;
            this.fMassTransferTime = fTime;
            this.fMassTransferFinishTime = this.oTimer.fTime + fTime;
            
            % transforms the specified flowrates into the overall flowrate
            % and the partial mass ratios.
            this.afFlowRates = afPartialMasses ./ fTime;
            
            % we use true to reset the last time the time step for this
            % manip was bound
            this.setMassTransferTimeStep(fTime, true);
            
            % Connected phases have to do a massupdate before we set the
            % new flow rate - so the mass for the LAST time step, with the
            % old flow rate, is actually moved from tank to tank. In the
            % massupdate the update for the P2P will be triggered, which is
            % then executed in the post tick after the phase massupdates
            this.oIn.oPhase.registerMassupdate();
            this.oOut.oPhase.registerMassupdate();
        end
    end
    methods (Access = protected)
        function checkMassTransfer(this,~)
            if this.bMassTransferActive && this.fMassTransferFinishTime - this.oTimer.fTime < this.oTimer.fMinimumTimeStep
                
                this.afFlowRates = zeros(1,this.oMT.iSubstances);
                
                this.bMassTransferActive = false;
                this.setMassTransferTimeStep(inf, true);
                % Connected phases have to do a massupdate before we set the
                % new flow rate - so the mass for the LAST time step, with the
                % old flow rate, is actually moved from tank to tank. In the
                % massupdate the update for the P2P will be triggered, which is
                % then executed in the post tick after the phase massupdates
                this.oIn.oPhase.registerMassupdate();
                this.oOut.oPhase.registerMassupdate();
                
            elseif this.bMassTransferActive && this.fMassTransferFinishTime - this.oTimer.fTime > this.oTimer.fMinimumTimeStep
                % If the branch is called before the set mass transfer time
                % step, the afLastExec property in the timer for this
                % branch is updated, while the timestep remains. This can
                % lead to the branch missing its update. Therefore, in
                % every update that occurs during a mass transfer that
                % does not fullfill the above conditions we have to reduce
                % the time step:
                fTimeStep = this.fMassTransferFinishTime - this.oTimer.fTime;
                
                this.setMassTransferTimeStep(fTimeStep, true);
            end
        end
        function update(this, ~) 
            % Since the flowrate is set manually no update required, the
            % function still has to be here since it is called within V-HAB
            
            
            fFlowRate = sum(this.afFlowRates);
            if fFlowRate == 0
                arPartialFlowRates = zeros(1,this.oMT.iSubstances);
            else
                arPartialFlowRates = this.afFlowRates/fFlowRate;
            end
            
            update@matter.procs.p2p(this, fFlowRate, arPartialFlowRates);
        end
    end
end