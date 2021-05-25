classdef ManualManipulator < matter.manips.substance.stationary
    % This manipulator allows the user to define the desired flowrates by
    % using the a setFlowRate function. It contains an internal check to
    % see if the flowrates add up to zero and if that is not the case tries
    % to equalize the flow rates.
    
    properties (SetAccess = protected, GetAccess = public)
        % parent system reference
        oParent;
        
        % Property to store the manual flow rates in kg/s for each
        % substance that the user defned using the setFlowRate function
        afManualFlowRates; % [kg/s]
        aarManualFlowsToCompound;
        
        bAlwaysAutoAdjustFlowRates = false;
        
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
        function this = ManualManipulator(oParent, sName, oPhase, bAutoAdjustFlowRates)
            this@matter.manips.substance.stationary(sName, oPhase);

            this.oParent = oParent;
            
            this.afManualFlowRates = zeros(1,this.oMT.iSubstances);
            this.aarManualFlowsToCompound = zeros(this.oPhase.oMT.iSubstances, this.oPhase.oMT.iSubstances);
            if nargin > 3
                this.bAlwaysAutoAdjustFlowRates = bAutoAdjustFlowRates;
            end
            
            this.setMassTransferTimeStep = this.oTimer.bind(@(~) this.checkMassTransfer(), 0, struct(...
                'sMethod', 'checkMassTransfer', ...
                'sDescription', 'The .checkMassTransfer method of a manual manip', ...
                'oSrcObj', this ...
            ));
            % initialize the time step to inf
            this.setMassTransferTimeStep(inf, true);
        end
        
        function setFlowRate(this, afFlowRates, aarFlowsToCompound, bAutoAdjustFlowRates)
            % required input for the set flowrate function is a vector with
            % the length of oMT.iSubstances. The entries in the vector
            % correspond to substance flowrates with the substances beeing
            % specified by oMT.tiN2I, each entry represents a flowrate for
            % the respective substance in kg/s. The flowrates have to add up to 0! 
            if nargin < 4
                if this.bAlwaysAutoAdjustFlowRates
                    bAutoAdjustFlowRates = true;
                else
                    bAutoAdjustFlowRates = false;
                end
            end
            if this.bMassTransferActive
                warning('Currently a mass transfer is in progress')
            end
            %% for small errors this calculation will minimize the mass balance errors
            fError = sum(afFlowRates);
            if fError < 1e-6 && bAutoAdjustFlowRates
                fPositiveFlowRate = sum(afFlowRates(afFlowRates > 0));
                fNegativeFlowRate = abs(sum(afFlowRates(afFlowRates < 0)));
                
                if fPositiveFlowRate > fNegativeFlowRate
                    % reduce the positive flows by the difference:
                    fDifference = fPositiveFlowRate - fNegativeFlowRate;
                    arRatios = afFlowRates(afFlowRates > 0)./fPositiveFlowRate;
                    
                    afFlowRates(afFlowRates > 0) = afFlowRates(afFlowRates > 0) - fDifference .* arRatios;
                else
                    % reduce the negative flows by the difference:
                    fDifference = fPositiveFlowRate - fNegativeFlowRate;
                    arRatios = abs(afFlowRates(afFlowRates < 0)./fNegativeFlowRate);
                    
                    afFlowRates(afFlowRates < 0) = afFlowRates(afFlowRates < 0) - fDifference .* arRatios;
                end
            elseif fError > 1e-6
            %% For larger errors the manipulator will throw an error
                error('The Manual Manipulator was not provided with a flowrate vector that adds up to zero!')
            end
            
            this.afManualFlowRates = afFlowRates;
            if nargin > 2
                this.aarManualFlowsToCompound = aarFlowsToCompound;
            else
                this.aarManualFlowsToCompound = zeros(this.oPhase.oMT.iSubstances, this.oPhase.oMT.iSubstances);
            end
            
            % In this case, we have to call the phase massupdate to ensure
            % we trigger the updates of the manipulators in the post tick!
            this.oPhase.registerMassupdate();
            
        end
        
        function setMassTransfer(this, afPartialMasses, fTime, aarFlowsToCompound)
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
            % aarFlowsToCompound as ratio
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
            this.afManualFlowRates = afPartialMasses ./ fTime;
            
            % we use true to reset the last time the time step for this
            % manip was bound
            this.setMassTransferTimeStep(fTime, true);
            
            if nargin > 2
                this.aarManualFlowsToCompound = aarFlowsToCompound;
            else
                this.aarManualFlowsToCompound = zeros(this.oPhase.oMT.iSubstances, this.oPhase.oMT.iSubstances);
            end
            
            % In this case, we have to call the phase massupdate to ensure
            % we trigger the updates of the manipulators in the post tick!
            this.oPhase.registerMassupdate();
        end
    end
    methods (Access = protected)
        function checkMassTransfer(this,~)
            if this.bMassTransferActive && abs(this.oTimer.fTime - this.fMassTransferFinishTime) < this.oTimer.fMinimumTimeStep
                
                this.afManualFlowRates = zeros(1,this.oMT.iSubstances);
                this.aarManualFlowsToCompound = zeros(this.oPhase.oMT.iSubstances, this.oPhase.oMT.iSubstances);
                
                this.bMassTransferActive = false;
                this.setMassTransferTimeStep(inf, true);
                
                % In this case, we have to call the phase massupdate to ensure
                % we trigger the updates of the manipulators in the post tick!
                this.oPhase.registerMassupdate();
                
            elseif this.bMassTransferActive && abs(this.oTimer.fTime - this.fMassTransferFinishTime) > this.oTimer.fMinimumTimeStep
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
            %% sets the flowrate values
            update@matter.manips.substance(this, this.afManualFlowRates, this.aarManualFlowsToCompound);
        end
    end
end