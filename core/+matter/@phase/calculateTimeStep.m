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
[ afChange, mfDetails ] = this.getTotalMassChange();

afTmpCurrentTotalInOuts = this.afCurrentTotalInOuts;

% Setting the properties to the current values
this.afCurrentTotalInOuts = afChange;
this.mfCurrentInflowDetails = mfDetails;

% If we have set a fixed time steop for this phase, we can just continue
% without doing any calculations.
if ~isempty(this.fFixedTimeStep)
    fNewStep = this.fFixedTimeStep;
else
    rMaxChangeFactor = 1;
    
    % Log the current mass and time to the history arrays
    this.afMassLog = [ this.afMassLog(2:end) this.fMass ];
    this.afLastUpd = [ this.afLastUpd(2:end) this.oTimer.fTime ];
    
    
    %% Provision for adaptive rMaxChange
    % Mass change in percent/second over logged time steps Convert mass
    % change to kg/s, take mean value and divide by mean tank mass -> mean
    % mass change in %/s (...?) If the mass is constant but unstable
    % (jumping around a mean value), the according mass in- and decreases
    % should cancle each other out.
    
    if this.rHighestMaxChangeDecrease > 0
        
        % max or mean?
        fDev = mean(diff(this.afMassLog) ./ diff(this.afLastUpd)) / mean(this.afMassLog);
        %fDev = max(abs(diff(this.afMassLog) ./ diff(this.afLastUpd))) / mean(this.afMassLog);
        
        % Order of magnitude of fDev
        fDevMagnitude = abs(log(abs(fDev))./log(10));
        
        % Inf? -> zero change.
        if fDevMagnitude > this.oTimer.iPrecision, fDevMagnitude = this.oTimer.iPrecision;
        elseif isnan(fDevMagnitude),                      fDevMagnitude = 0;
        end
        
        % Min deviation (order of magnitude of mass change)
        iMaxDev = this.oTimer.iPrecision;
        
        
        % Other try - exp
        afBase = (0:0.01:1) .* iMaxDev;
        afRes  = (0:0.01:1).^3 .* (this.rHighestMaxChangeDecrease - 1);
        
        rFactor = interp1(afBase, afRes, fDevMagnitude, 'linear');
        
        rMaxChangeFactor = 1 / (1 + rFactor);
    end
    
    
    %% Calculating the changes of mass in phase since last mass update.
    
    % Calculate the change in total and partial mass since the phase was
    % last updated
    rPreviousChange  = abs(this.fMass   / this.fMassLastUpdate  - 1);
    % The partial mass changes need to be compared to the total mass in the
    % phase, not to themselves, else if a trace gas mass does change
    % significantly, it will reduce the time step too much even though it
    % does not change the overall phase properties a lot.
    arPreviousChange = abs(this.afMass - this.afMassLastUpdate) / this.fMass;
    
    
    % If rPrevious change is not a number ('NaN'), the mass during the
    % previous update was zero and the current mass is also zero. That
    % means that afMass was also all zeros during this and the previous
    % update. Therfore the relative change between updates is zero.
    if isnan(rPreviousChange)
        rPreviousChange  = 0;
        arPreviousChange = zeros(1, this.oMT.iSubstances);
    end
    
    % If rPreviousChange is infinity ('Inf'), that means that the mass
    % during the last update was zero, but now it is not. The
    % arPreviousChange array will be mostly NaN values, except for the ones
    % where the mass changed from zero to something else. Since the
    % calculation of fNewStepPartials later in this function uses the max()
    % method on arPrevious change, we don't have to do anything here,
    % because it will return one of the 'Inf' values from arPreviousChange.
    
    %% Calculating the changes of mass in phase during this update.
    
    % To calculate the change in partial mass, we only use entries where
    % the change is not zero. If some substance changed a little bit, but
    % less then the precision threshold, and does not change any more, it
    % is not taken into account. It can still change in relation to other
    % substances, where mass flows in/out, but that should be covered by
    % the total mass change check. The unit of arPartialsChange is [1/s],
    % so multiplied by 100 % we would have a percentage change per second
    % for each substance.
    abChange = (afChange ~= 0);
    arPartialsChange = abs(afChange(abChange) ./ tools.round.prec(this.fMass, this.oTimer.iPrecision));
    
    % Only use non-inf values. They would be inf if the current mass of
    % according substance is zero. If a new substance enters the phase, it
    % is still covered through the overall mass check.
    % By getting the maximum of the arPartialsChange array, we have the
    % maximum change of partial mass within the phase.
    rPartialsPerSecond = max(arPartialsChange(~isinf(arPartialsChange)));
    
    %CHECK Why would this be empty?
    if isempty(rPartialsPerSecond), rPartialsPerSecond = 0; end
    
    % Calculating the change per second of TOTAL mass. rTotalPerSecond also
    % has the unit [1/s], giving us the percentage change per second of the
    % overall mass of the phase.
    fChange = sum(afChange);
    
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
        %CHECK use fMassLastUpdate or fMass? The latter leads
        %      to larger time steps but is logically slightly incorrect.
        %      [also above, arPartialsChange!]
        % FOR NOW ... we'll go with fMass, faster and does not seem to
        % introduce big issues ...
        rTotalPerSecond = abs(fChange / this.fMass);
    end
    
    %% Partial mass change compared to partial mas
    % note that rPartialsPerSecond from the calculation is the partial mass
    % change compared to the total mass, while this calculation is the
    % partial mass change compared to the respective partial mass. This
    % second calculation therefore is more restrictive and is normally
    % deactivated but can be activated by setting any value of the
    % arMaxChange property to something other than zero
    if this.bHasSubstanceSpecificMaxChangeValues
        afCurrentMass = this.afMass;
        
        % Partial masses that are smaller than the minimal time step are
        % rounded to the minimal time step to prevent extremly small
        % partial masses from delaying the simulation (otherwise the
        % timestep will go asymptotically towards zero the smaller the
        % partial mass becomes)
        afCurrentMass(this.afMass < 10^(-this.oTimer.iPrecision)) = 10^(-this.oTimer.iPrecision);
        arPartialChangeToPartials = abs(afChange ./ tools.round.prec(afCurrentMass, this.oTimer.iPrecision));
        % Values where the partial mass is zero are set to zero, otherwise
        % the value for these is NaN or Inf
        arPartialChangeToPartials(this.afMass == 0) = 0;
        
        afNewStepPartialChangeToPartials = (this.arMaxChange * rMaxChangeFactor) ./ arPartialChangeToPartials;
        
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
    fNewStepTotal    = (this.rMaxChange * rMaxChangeFactor - rPreviousChange) / rTotalPerSecond;
    fNewStepPartials = (this.rMaxChange * rMaxChangeFactor - max(arPreviousChange)) / rPartialsPerSecond;
    
    %% Maximum Time Step
    % Additional to the normal time steps, which are percentual limits of
    % how much the total or individual masses are allowed to change, a
    % maximum time step must be calculate to prevent negative masses from
    % occuring. It is the time step for which at the current flowrates the
    % first positive mass in the phase reaches 0:
    abOutFlows = this.afCurrentTotalInOuts < 0;
    abOutFlows(this.afMass < 1e-8) = false;
    fMaxFlowStep = min(abs(this.afMass(abOutFlows) ./ this.afCurrentTotalInOuts(abOutFlows)));
    
    % The new time step will be set to the smaller one of these two
    % candidates.
    fNewStep = min([ fNewStepTotal fNewStepPartials fNewStepPartialChangeToPartials fMaxFlowStep]);
    
    if fNewStep < 0
        if ~base.oLog.bOff, this.out(3, 1, 'time-step-neg', 'Phase %s-%s-%s has neg. time step of %.16f', { this.oStore.oContainer.sName, this.oStore.sName, this.sName, fNewStep }); end
    end
    
    % If our newly calculated time step is larger than the maximum time
    % step set for this phase, we use this instead.
    if fNewStep > this.fMaxStep
        fNewStep = this.fMaxStep;
        % If the time step is smaller than the set minimal time step for
        % the phase the minimal time step is used (standard case is that
        % fMinStep is 0, but the user can set it to a different value)
    elseif fNewStep < this.fMinStep
        fNewStep = this.fMinStep;
    end
    
    
    if ~base.oLog.bOff
        this.out(1, 1, 'prev-timestep', 'Previous changes for new time step calc for %s-%s-%s - previous change: %.8f', { this.oStore.oContainer.sName, this.oStore.sName, this.sName, rPreviousChange });
        this.out(1, 2, 'prev-timestep', 'PREV TS: %.16f s, ACtual Time: %.16f s', { this.fTimeStep, this.oTimer.fTime });
        this.out(1, 2, 'prev-timestep', 'Last Update: %.16f s, Mass at Last Update: %.16f s', { this.fLastUpdate, this.fMassLastUpdate });
        this.out(1, 2, 'prev-timestep', 'MASS: %.16f kg, Prevous Mass Change Rate: %.16f kg/s / Total: %.16f kg ', { this.fMass, sum(afTmpCurrentTotalInOuts), sum(afTmpCurrentTotalInOuts)*(this.oTimer.fTime-this.fLastUpdate) });
        this.out(1, 2, 'prev-timestep', 'MASS: %.16f kg, New Mass Change Rate: %.16f kg/s / Total: %.16f kg ', { this.fMass, sum(this.afCurrentTotalInOuts), sum(this.afCurrentTotalInOuts)*fNewStep });
        
        
        this.out(1, 1, 'new-timestep', '%s-%s-%s new TS: %.16fs', { this.oStore.oContainer.sName, this.oStore.sName, this.sName, fNewStep });
    end
end


% Set the time at which the containing store will be updated again. Need to
% pass on an absolute time, not a time step. Value in store is only
% updated, if the new update time is earlier than the currently set next
% update time.
this.oStore.setNextTimeStep(fNewStep);

% Cache - e.g. for logging purposes
this.fTimeStep = fNewStep;
end
