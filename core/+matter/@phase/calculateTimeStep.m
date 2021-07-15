function calculateTimeStep(this)
%CALCULATETIMESTEP Calculates the next timestep of the phase
% To calculate the new time step for this phase, we first need some
% information on what has changed since the last time this was done.
% First we'll get the absolute in- and outflows through all
% EXMEs.
% afChange contains the flow rates for all substances, mfDetails contains
% the flow rate, temperature and heat capacity for each INCOMING flow, not
% the outflows!

% Change in kg of partial masses per second
[ afChange, mfDetails, this.arInFlowCompoundMass ] = this.getTotalMassChange();

afTmpCurrentTotalInOuts = this.afCurrentTotalInOuts;

% Setting the properties to the current values
this.afCurrentTotalInOuts   = afChange;
this.mfCurrentInflowDetails = mfDetails;

if this.iSubstanceManipulators ~= 0
    afPartialFlows = this.afCurrentTotalInOuts + this.toManips.substance.afPartialFlows;
else
    afPartialFlows = this.afCurrentTotalInOuts;
end
    
% In case we have a boundary we can just use the maximum time
% step because any change in boundary phases is triggered externally
if this.bBoundary
    fNewStep = this.fMaxStep;
else
    %% Maximum Time Step
    % if the phase is not a boundary phase we always calculate a maximum
    % time step which prevents negative masses!
    %
    % Additional to the normal time steps, which are percentual limits of
    % how much the total or individual masses are allowed to change, a
    % maximum time step must be calculate to prevent negative masses from
    % occuring. It is the time step for which at the current flowrates the
    % first positive mass in the phase reaches 0:
    
    abOutFlows = afPartialFlows < 0;
    
    % This calculation limits the maximum mass loss that occurs within one
    % tick to 1e-8 kg. Adding the 1e-8 kg is necessary to prevent extremly
    % small time steps
    fMaxFlowStep = min(abs((this.fMassErrorLimit + this.afMass(abOutFlows)) ./ afPartialFlows(abOutFlows)));
    
    % If we have set a fixed time step for this phase, we can just continue
    % without doing any calculations.
    if ~isempty(this.fFixedTimeStep)
        fNewStep = this.fFixedTimeStep;
    elseif this.bFlow
        % For flow phases we already limit the maximum mass error. The
        % other changes do not matter for flow phases, therefore we simply
        % use the max step and then compare it to the maximum flow step
        % later on
        fNewStep = this.fMaxStep;
        
    else
        %% Calculating the changes of mass in phase during this update.

        % To calculate the change in partial mass, we only use entries where
        % the change is not zero. If some substance changed a little bit, but
        % less then the precision threshold, and does not change any more, it
        % is not taken into account. It can still change in relation to other
        % substances, where mass flows in/out, but that should be covered by
        % the total mass change check. The unit of arPartialsChange is [1/s],
        % so multiplied by 100 % we would have a percentage change per second
        % for each substance.
        abChange = (afPartialFlows ~= 0);
        arPartialsChange = abs(afPartialFlows(abChange) ./ tools.round.prec(this.fMass, this.iTimeStepPrecision));

        % Only use non-inf values. They would be inf if the current mass of
        % according substance is zero. If a new substance enters the phase, it
        % is still covered through the overall mass check.
        % By getting the maximum of the arPartialsChange array, we have the
        % maximum change of partial mass within the phase.
        rPartialsPerSecond = max(arPartialsChange(~isinf(arPartialsChange)));

        % rPartialsPerSecond can be empty if nothing is flowing in or out
        % because the abChange property is then false for everything, resulting
        % in an empty parameter
        if isempty(rPartialsPerSecond), rPartialsPerSecond = 0; end

        % Calculating the change per second of TOTAL mass. rTotalPerSecond also
        % has the unit [1/s], giving us the percentage change per second of the
        % overall mass of the phase.
        fChange = sum(afPartialFlows);
        
        if fChange == 0
            rTotalPerSecond = 0;
        else
            % The change needs to be calculated with respect to the total mass
            % at the time of the last update, as values like molar mass or the
            % heat capacity were calculated based on that mass.
            % Using fMass could lead to two issues:
            % * prolonged/shortened time steps, if the mass in the
            %   phase in- or decreases (rTotalPerSecond will be smaller if the
            %   current mass is larger than the one at the last update ->
            %   smaller change = larger TS).
            % * the previous change is based on the mass at last
            %   updated whereas the current change is based on the current
            %   mass. This can lead to a change slightly larger than rMaxChange
            %   leading to a negative time step. This however will only happen
            %   if the store would update soon anyways and should therefore not
            %   lead to larger issues.
            rTotalPerSecond = abs(tools.round.prec(fChange, this.iTimeStepPrecision) / this.fMass);
        end
        
        %% Partial mass change compared to partial mas
        % note that rPartialsPerSecond from the calculation is the partial mass
        % change compared to the total mass, while this calculation is the
        % partial mass change compared to the respective partial mass. This
        % second calculation therefore is more restrictive and is normally
        % deactivated but can be activated by setting any value of the
        % arMaxChange property to something other than zero. Only the
        % substances that have non zero values will be limit by this
        % calculation.
        % To further reduce the impact of this calculation in cases where it
        % isn't used a boolean operator is set by the setTimeStepProperties
        % function to check if this part of the calculation is necessary
        if this.bHasSubstanceSpecificMaxChangeValues
            afCurrentMass = this.afMass;

            % Partial masses that are smaller than the minimal time step are
            % rounded to the minimal time step to prevent extremly small
            % partial masses from delaying the simulation (otherwise the
            % timestep will go asymptotically towards zero the smaller the
            % partial mass becomes). An additional check later on will limit
            % the maximum allowed mass error that can occur from one substance
            % beeing removed from a phase to 1e-8 kg.
            afCurrentMass(this.afMass < 10^(-this.iTimeStepPrecision)) = 10^(-this.iTimeStepPrecision);
            arPartialChangeToPartials = abs(afPartialFlows ./ tools.round.prec(afCurrentMass, this.iTimeStepPrecision));
            % Values where the partial mass is zero are set to zero, otherwise
            % the value for these is NaN or Inf
            arPartialChangeToPartials(this.afMass == 0) = 0;

            % The allowed time steps are the allowed maximum changes for each
            % substance divided with the current change per second
            afNewStepPartialChangeToPartials = this.arMaxChange ./ arPartialChangeToPartials;

            % Values where the arMaxChange value is zero are not of interest
            % for the user and are therefore set to inf time steps (setting a
            % max change of zero does not make sense in any situation where I
            % am actually interest in the change of the substance, therefore
            % this logic was chosen)
            afNewStepPartialChangeToPartials(this.arMaxChange == 0) = inf;

            % The new timestep from this logic is the smallest of all partial
            % mass change time steps
            fNewStepPartialChangeToPartials = min(afNewStepPartialChangeToPartials);
        else
            % If the logic is deactivate (arMaxChange is empty or every entry
            % is 0) then the timestep from this calculation is infinite.
            fNewStepPartialChangeToPartials = inf;
        end

        %% Calculating the new time step

        % To derive the timestep, we use the percentage change of the total
        % mass or the maximum percentage change of one of the substances'
        % relative masses.
        fNewStepTotal    = this.rMaxChange / rTotalPerSecond;
        fNewStepPartials = this.rMaxChange / rPartialsPerSecond;

        % The new time step will be set to the smaller one of the three time
        % step candidates
        fNewStep = min([ fNewStepTotal fNewStepPartials fNewStepPartialChangeToPartials]);

        % For phases with zero mass, we limit the error within one time
        % step to 1e-8 kg and the allowed initial mass ( to prevent very small
        % fill up processes) to 0.1 kg. The second logic should not happen
        % for phases with actual physics based solvers and is therefore valid
        if this.fMass == 0
            if fChange < 0
                % limit error to the specified value. Stanard setting is 1e-8 kg
                fNewStep = abs(this.fMassErrorLimit/fChange);
            else
                % limit initial mass after the phase was empty to the specified
                % value. Standard setting is 0.1 kg
                fNewStep = abs(this.fMaximumInitialMass / fChange);
            end
        end

        % Add debugging information in case the time step was calculated to be
        % negative
        if fNewStep < 0
            if ~base.oDebug.bOff, this.out(3, 1, 'time-step-neg', 'Phase %s-%s-%s has neg. time step of %.16f', { this.oStore.oContainer.sName, this.oStore.sName, this.sName, fNewStep }); end
        end

        % If our newly calculated time step is larger than the maximum time
        % step set for this phase, we use this instead.
        if fNewStep > this.fMaxStep
            fNewStep = this.fMaxStep;
            
            % If debugging is on, we display the info
            if ~base.oDebug.bOff
                this.out(2, 1, 'max-time-step', 'Phase %s-%s-%s setting maximum time step of %.16f', { this.oStore.oContainer.sName, this.oStore.sName, this.sName, fNewStep }); 
            end
            
        % If the time step is smaller than the set minimal time step for the
        % phase the minimal time step is used (standard case is that fMinStep
        % is 0, but the user can set it to a different value). Note that 0 does
        % not result in an infinite loop, but would result in the minimum time
        % step of the overall simulation to be used
        elseif fNewStep < this.fMinStep
            fNewStep = this.fMinStep;
            
            % If debugging is on, we display the info
            if ~base.oDebug.bOff
                this.out(2, 1, 'min-time-step', 'Phase %s-%s-%s setting maximum time step of %.16f', { this.oStore.oContainer.sName, this.oStore.sName, this.sName, fNewStep }); 
            end
        end

        % Now we add debugging outputs which can be turned on or off
        if ~base.oDebug.bOff
            this.out(1, 2, 'prev-timestep', 'PREV TS: %.16f s, Actual Time: %.16f s', { this.fTimeStep, this.oTimer.fTime });
            this.out(1, 2, 'prev-timestep', 'Last Update: %.16f s, Mass at Last Update: %.16f s', { this.fLastUpdate, this.fMassLastUpdate });
            this.out(1, 2, 'prev-timestep', 'MASS: %.16f kg, Prevous Mass Change Rate: %.16f kg/s / Total: %.16f kg ', { this.fMass, sum(afTmpCurrentTotalInOuts), sum(afTmpCurrentTotalInOuts)*(this.oTimer.fTime-this.fLastUpdate) });
            this.out(1, 2, 'prev-timestep', 'MASS: %.16f kg, New Mass Change Rate: %.16f kg/s / Total: %.16f kg ', { this.fMass, sum(this.afCurrentTotalInOuts), sum(this.afCurrentTotalInOuts)*fNewStep });

            this.out(1, 1, 'new-timestep', '%s-%s-%s new TS: %.16fs', { this.oStore.oContainer.sName, this.oStore.sName, this.sName, fNewStep });
        end
    end
    
    % Now check if the previously calculated time step is larger than
    % the maximum time step, and if that is the case use the maximum
    % time step
    if fNewStep > fMaxFlowStep
        fNewStep = fMaxFlowStep;
        if fNewStep < this.fMinStep
            fNewStep = this.fMinStep;
        end
    end
end

% Set the time step for this phase. If the update was also called in this
% tick we also reset the time at which the phase was last executed thus
% enforcing the next execution time to be exactly this.oTimer.fTime +
% fNewStep. Otherwise we only overwrite the time step but not the time at
% which the time step was set, because the function was called by a
% massupdate and the last recalculation of phase properties was from an
% earlier tick. If we used setTimeStep(fNewStep, true) in all cases the
% update function of a phase might never be called if massupdates are
% always triggered before!
if this.fLastUpdate == this.oTimer.fTime || this.bFlow
    this.setTimeStep(fNewStep, true);
else
    this.setTimeStep(fNewStep);
end

% Cache - e.g. for logging purposes
this.fTimeStep = fNewStep;
end