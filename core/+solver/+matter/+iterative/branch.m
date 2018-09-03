classdef branch < solver.matter.base.branch
    %BRANCH Iterative solver branch for matter flows
    %
    %TODO
    % - if e.g. constant pressure EXME and connected phase becomes empty,
    %   and iDampFR active --> problems with NaN for fTemperature etc!
    % - store debug values like iIterations etc?

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %-- Properties -------------------------------------------------------%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    properties (SetAccess = public, GetAccess = public)
        
        %TODO Add descriptions
        rMaxChange = 0.05;
        rSetChange = 0.02;
        iRemChange = 10;
        
        
        % Sensitivity of the solver towards changes, higher number leading
        % to lower time steps
        fSensitivity = 5;
        
        % Default maximum time step for the branch
        fMaxStep   = 20;
        
        % An integer that defines across how many multiples of the 
        % previously calculated flow rate the new flow rate will be 
        % averaged.
        iDampFR = 0;
        
        % A helper array that saves the last iDampFR flow rates for
        % averaging. 
        afFlowRatesForDampening;
        
        % Fixed time step - set to empty ([]) to deactivate
        fFixedTS = [];
        
        %%%% New TS logic
        %TODO Add descriptions
        bUseAltTimeStepLogic = false;
        
        fMinStep;
        fMaxStepAlt = 25;
        
        
        %TODO can only be set once on initialization?
        iRememberDeltaSign = 10;
        abDeltaPositive    = [ true, false, true, false, true, false, true, false, true, false, true ];
        
        
        fFlowRateUnrounded = 0;
        bFlowRateChangePos = 0;
        iFlowRateCompDamp  = 0;
        
        % Boolean variable to turn the suppression of flow rate
        % oscillations on or off. 
        bOscillationSuppression = false;
        
        
    end
    
    properties (SetAccess = protected, GetAccess = public)
        
        %TODO Add descriptions
        rFlowRateChange  = 0;
        iSignChangeFRCnt = 0;
        
        % Actual time between flow rate calculations
        fTimeStep = 0;
        
        %TODO Add description
        fDropTime = 0;
        
        % Integer counting the number of oscillations that have already
        % happened.
        iOscillationCounter;
        
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %-- Methods ----------------------------------------------------------%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    methods
        
        %% Constructor
        function this = branch(oBranch, fInitialFlowRate)
            
            if nargin < 2
                fInitialFlowRate = [];
            end
            
            this@solver.matter.base.branch(oBranch, fInitialFlowRate, 'callback');
            
            if this.oBranch.iFlowProcs == 0
                this.warn('There are no f2f processors in the iterative solver branch %s.\nThis may cause problems during flow rate calculation.\nIt is recommended to insert a small pipe.');
            end
            
            this.fSensitivity = this.oBranch.oContainer.tSolverParams.fSolverSensitivity;
            this.fMaxStep     = this.oBranch.oContainer.tSolverParams.fMaxTimeStep;
            
            % Sets the flow rate to 0 which sets matter properties
            this.update();
            
        end
        
        %% Method for alternative time step calculation
        function XXXsetAlternativeTimeStepMethod(this, iDampening, iMaxStep)
            
            this.bUseAltTimeStepLogic = true;
            
            if nargin >= 2
                this.iDampFR = iDampening * this.oBranch.oContainer.oData.rSolverDampening;
            end

            if nargin >= 3, this.fMaxStepAlt = iMaxStep; end
            
            this.fMaxStep = this.fMaxStepAlt;
            
        end
        
    end
    
    methods (Access = protected)
        
        %% Update functions, called directly by timer
        function update(this)

            if this.oBranch.oTimer.fTime < 0
                % If we are still constructing the simulation system (time
                % is smaller than zero), do nothing except call the parent
                % class update method.
                update@solver.matter.base.branch(this, 0);
                return;
            end
            
            if this.oBranch.oTimer.fTime == 0
                this.afFlowRatesForDampening = zeros(1, this.iDampFR);
            end
            
            if this.oBranch.oTimer.fTime <= this.fLastUpdate
                % If branch update has been called before during this time
                % step, do nothing. 
                return;
            end
            
            % Actually compute the new flow rate and the associated delta
            % pressures as well as delta temperatures.
            [ fFlowRate, afDeltaP ] = this.solveFlowRate();
            
            % See base branch, same check here - if input phase nearly
            % empty, just set flow rate to zero
            oIn = this.oBranch.coExmes{sif(fFlowRate >= 0, 1, 2)}.oPhase;
            
            if tools.round.prec(oIn.fMass, oIn.oStore.oTimer.iPrecision) == 0
                fFlowRate = 0;
            end
            
            if this.bOscillationSuppression
                % Oscillation suppression is turned on, so we'll check if
                % the flow rate is oscillating and if so, try to do
                % something about it. Action is triggered after 20
                % consecutive flow rate direction changes. If the flow rate
                % is in the same direction twice in a row, the oscillation
                % counter will be reset.
                % If an oscillation is detected, the flow rate is set to 
                % the value calculated in the previous time step. This will
                % keep the flow rate more constant and prevent further
                % oscillations. These usually occur when a fan is involved
                % and the flow rate is around zero at startup or due to
                % large pressure swings in the branch that cause the fan to
                % operate in reverse.
                
                
                % First we need to check, if there was a sign change in the
                % flow rate.
                
                % Detecting the new flow rate direction
                if fFlowRate < 0
                    iNewDirection = -1;
                else
                    iNewDirection = 1;
                end
                
                % Detecting the previous flow rate direction
                if this.fFlowRate < 0
                    iOldDirection = -1;
                else
                    iOldDirection = 1;
                end
                
                % Comparing the two directions
                if iNewDirection ~= iOldDirection
                    % There was a change, so we increase the oscillation
                    % counter.
                    this.iOscillationCounter = this.iOscillationCounter + 1;
                else
                    % There was no change, so we reset the oscillation
                    % counter.
                    this.iOscillationCounter = 0;
                end
                
                % If there have been more than 20 sign changes, the branch
                % is oscillating. So we set the flow rate to the one
                % calculated in the previous time step.
                if this.iOscillationCounter > 20
                    %fprintf('Oscillation detected!\n');
                    fFlowRate = this.afFlowRatesForDampening(end);
                    this.iOscillationCounter = this.iOscillationCounter + 1;
                    bRecalculateFlowProperties = true;
                    
                    % After 60 oscillations, we reset the counter to see if
                    % the system is stable now.
                    if this.iOscillationCounter > 60
                        %fprintf('Max Oscillation reset!\n');
                        this.iOscillationCounter = 0;
                    end
                    
                elseif fFlowRate ~= 0 && this.iDampFR ~= 0
                    % There is no oscillation, so we'll just damp the flow
                    % rate, if iDampFR is non-zero.
                    fFlowRate = (sum(this.afFlowRatesForDampening) + fFlowRate) / (this.iDampFR + 1);
                    this.afFlowRatesForDampening = [ this.afFlowRatesForDampening(2:end) fFlowRate ];
                    bRecalculateFlowProperties = true;
                else
                    % There are no oscillations and not dampening, that
                    % means we can use the flow rate as is and don't have
                    % to do any recalculations of flow properties.
                    bRecalculateFlowProperties = false;
                end
                
            else
                % Oscillation suppression is not turned on, so we just
                % execute the previous behavior. 
                fFlowRate = (this.fFlowRate * this.iDampFR + fFlowRate) / (this.iDampFR + 1);
                bRecalculateFlowProperties = true;
            end
            
            % If we actually damped the flow rate, we need to run the
            % solver specific method on all processors again, since some of
            % them might need to update some internal values, such as the
            % heat flow. 
            %TODO To avoid this, maybe the heat flow should be specific
            %rather than absolute? 
            if this.iDampFR ~= 0 && bRecalculateFlowProperties
                aiProcs = sif(fFlowRate > 0, 1:this.oBranch.iFlowProcs, this.oBranch.iFlowProcs:-1:1);
                for iI = aiProcs
                    this.aoSolverProps(iI).calculateDeltas(fFlowRate);
                end
            end
            
            %TODO remove all this!
            fFlowRateUnroundedNew = fFlowRate;
            
            % If we don't round at some point, flow rates will eventually
            % become something like 1e-13 etc -> don't want that.
%             if tools.round.prec(fFlowRate, this.oBranch.oContainer.oTimer.iPrecision) == 0
%                 %fFlowRate = 0;
%             end
            
            
            
%             oP1 = this.oBranch.coExmes{1}.oPhase;
%             oP2 = this.oBranch.coExmes{2}.oPhase;
%             coE = this.oBranch.coExmes;
            
            %fprintf('FR %.12f, PRESS LEFT %f, PRESS RIGHT %f, PRESS REL %f, MASS REL %f\n', fFlowRate, oP1.fPressure, oP2.fPressure, oP1.fPressure / oP2.fPressure, oP1.fMass / oP2.fMass);
            %fprintf('FR %.12f, FR UNROUNDED %.12f, PRESS REL %.26f, MASS REL %.12f\n', fFlowRate, fFlowRateUnrounded, oP1.fPressure / oP2.fPressure - 1, oP1.fMass / oP2.fMass - 1);
            
            %fprintf('FR %.15f, FR UNROUNDED %.15f, PRESS REL %.25f, MASS REL %.25f\n', fFlowRate, fFlowRateUnrounded, coE{1}.getPortProperties() / coE{2}.getPortProperties() - 1, oP1.fMass / oP2.fMass - 1);
            %fprintf('%.10f  FR %.15f, dP %.15f, dM %.15f, dP_m %.15f (%.15f %.15f)\n', oP1.oTimer.fTime, fFlowRate, coE{1}.getPortProperties() - coE{2}.getPortProperties(), oP1.fMass - oP2.fMass, oP1.fMassToPressure * oP1.fMass - oP2.fMassToPressure * oP2.fMass, oP1.fCurrentTotalMassInOut, oP2.fCurrentTotalMassInOut);
            
            %%fprintf('%.10f  FR %.25f, dP %.25f, dM %.25f, dP_m %.25f     %.25f\n', oP1.oTimer.fTime, fFlowRate, coE{1}.getPortProperties() - coE{2}.getPortProperties(), oP1.fMass - oP2.fMass, oP1.fMassToPressure * oP1.fMass - oP2.fMassToPressure * oP2.fMass, afDeltaP);
            %%fprintf('avg:  %.25f (dyn %.25f)\n', (oP1.fPressure + oP2.fPressure) / 2, (coE{1}.getPortProperties() + coE{2}.getPortProperties()) / 2);
            
            % Calculating the new timestep for this branch
            this.calculateTimeStep(fFlowRateUnroundedNew, fFlowRate);
            
            
            %%%fprintf('%.16f [rChangeRate: %.7f]\n', this.fTimeStep, this.rFlowRateChange);
            
            %%%fprintf('[%i] %s  -- %f [%.5f]  --  new step: %f, new FR %.13f\n', ...
            %%%    this.oBranch.oTimer.iTick, this.oBranch.sName, ...
            %%%    this.fFlowRate / fFlowRate, this.rFlowRateChange, this.fTimeStep, fFlowRate);
            
            %
            if fFlowRateUnroundedNew ~= this.fFlowRateUnrounded
                bFlowRateChangeIsPositive = fFlowRateUnroundedNew > this.fFlowRateUnrounded;
                
                if this.bFlowRateChangePos ~= bFlowRateChangeIsPositive
                    
                    if this.iFlowRateCompDamp < 5
                        this.iFlowRateCompDamp = this.iFlowRateCompDamp + 1;
                    end
                    
                    
                elseif this.iFlowRateCompDamp > 0
                    this.iFlowRateCompDamp = this.iFlowRateCompDamp - 1;
                end
                
                this.bFlowRateChangePos = bFlowRateChangeIsPositive;
            end
            
            %fprintf('%i, ', this.iFlowRateCompDamp);
            
%             iDampUnrounded = 5;
            %this.fFlowRateUnrounded = (this.fFlowRateUnrounded * this.iFlowRateCompDamp + fFlowRateUnrounded) / (this.iFlowRateCompDamp + 1);
            %this.fFlowRateUnrounded = (this.fFlowRateUnrounded * iDampUnrounded + fFlowRateUnrounded) / (iDampUnrounded + 1);
            this.fFlowRateUnrounded = fFlowRateUnroundedNew;
            
            % Sets new flow rate
            update@solver.matter.base.branch(this, fFlowRate, afDeltaP);
            
        end
    end
    
    
    methods (Access = public)
        
        %% Solve branch
        function [ fFlowRate, afDeltaP ] = solveFlowRate(this)
            % Calculates flow rate for a branch. Flow rate fFlowRate here
            % is NOT signed (negative/positive depending on direction, left
            % to right is positive), therefore iDir value maintained.
            % For solverDeltas, a positive pressure drop that is returned
            % ALWAYS defines a pressure drop, a negative one a pressure
            % rise, so for example a pipe, where the direction of the flow
            % does not matter, can always return a positive value and just
            % abs() the provided flow rate.
            
            oBranch = this.oBranch;
            
            % Data matrix - rows equals amount of flow procs minus two (the
            % EXMEs), columns are the pressure drops and temperature
            % changes returned by the components (f2f processors)
            mfData = zeros(oBranch.iFlowProcs, 1);
            
            afDeltaP = [];
            
            %%% Old flow rate, pressure differences etc
            fFlowRate = oBranch.fFlowRate;
            
            % Connected exmes
            oExmeL = oBranch.coExmes{1};
            oExmeR = oBranch.coExmes{2};
            
            % Calculating the pressure differences between the connected
            % phases
            [ fPressureLeft,  ~ ] = oExmeL.getPortProperties();
            [ fPressureRight, ~ ] = oExmeR.getPortProperties();
            
            fPressDiff = fPressureLeft - fPressureRight;
            
            fPressDiff = tools.round.prec(fPressDiff, this.oBranch.oContainer.oTimer.iPrecision);
            
            
            %QUESTION What is this for?
            fPressDiffOrg = fPressDiff;
            
            %if tools.round.prec(fPressDiffOrg, this.oBranch.oContainer.oTimer.iPrecision) == 0
            %    fFlowRate = 0;
            %    mfData = [];
            %    return;
            %end
            
            
            %fprintf('PRESS DIFF %.16f\n', fPressDiff);
            %fprintf('%.16f\n', fPressDiff);
            
            
            %TODO threat the EXMEs as F2F procs, so just included in the
            %     loops below when F2F solverDeltas() are called! Direction
            %     dependency automatically included!
            

            %%% Flow rate zero? (init sim, or deactivated branch etc)
            %   Calculate all pressure drops in f2f procs - could be a fan
            %   included that just started or a valve was opened. 
            %TODO External update logic calling the solver needs to ensure 
            %     that it is not called unnecessarily (i.e. requires a 
            %     logic for the f2f procs to tell the solver to re-calc the
            %     branch, because something changed). Else, only call
            %     solver if pressures in phases change or prev FR not equal
            %     to current FR.
            if fFlowRate == 0
                
                % First try left to right
                iDir = 1;
                fPressDiff = iDir * fPressDiffOrg;
                
                % Create array with indices of flows in flow direction for 
                % update method
                %aiFlows = sif(iDir > 0, 1:oBranch.iFlows, oBranch.iFlows:-1:1);
                
                % Preset pressure drop to zero, set initial flow rate
                fPressDrop = 0;
                %fFlowRate  = 0.00001 / fTimeStep;
                fFlowRate = this.oBranch.oContainer.oTimer.fMinimumTimeStep * 1;
                
                % Depending on flow direction, initialize values
                % Sets Cp, Molar Mass, rPPs; Temp from IN Exme, Pressure to
                % steps of (P_in - P_out) / Number_flows
                %TODO: figure out what is supposed to happen here and why,
                %      e.g. what's this?: 
                %%REORG%%oBranch.aoFlows(aiFlows).setSolverInit(fFlowRate, oExmeL, oExmeR);
                
                % Preset pressure drop / temperature change matrix
                mfData = zeros(oBranch.iFlowProcs, 2);
                
                % Calculate solver deltas with initial flow rate above for 
                % the 'normal' solver to use as a starting point
                for iP = 1:oBranch.iFlowProcs
                    
                    % Gather the information from each processor
                    %[ mfData(iP, 1), mfData(iP, 2) ] = oBranch.aoFlowProcs(iP).solverDeltas(iDir * fFlowRate);
                    mfData(iP, 1)= this.aoSolverProps(iP).calculateDeltas(iDir * fFlowRate);
                    
                    fPressDrop = fPressDrop + mfData(iP, 1);
                    
                end
                
                % Infinite pressure drop? Test opposite direction
                if isinf(fPressDrop)
                    
                    % Reverse stuff
                    iDir = -1;
                    fPressDiff = iDir * fPressDiffOrg;
                    % fFlowRate unsigned so no change needed
                    
                    % See above
                    fPressDrop = 0;
                    %aiFlows    = sif(iDir > 0, 1:oBranch.iFlows, oBranch.iFlows:-1:1);
                    %TODO Do solverInit again for molar masses etc?
                    
                    for iP = oBranch.iFlowProcs:-1:1
                        
                        mfData(iP, 1) = this.aoSolverProps(iP).calculateDeltas(iDir * fFlowRate);
                        
                        fPressDrop = fPressDrop + mfData(iP, 1);
                        
                    end
                    
                    %disp([' PRESSURE DROP ("' oBranch.sName '") FOR ZERO FR WAS INF, NOW ' num2str(fPressDrop) ]);
                    
                    if isinf(fPressDrop)
                        
                        % Again Inf - both directions suck - fr zero & rtn
                        %TODO external logic might call the solveFR() 
                        %     method for this branch because phases change.
                        %     However, if a valve is shut, that never makes
                        %     sense -> store the 'inf' for that branch, and
                        %     in such a case don't actually execute solveFR
                        %     but only if one of the f2f comps of the flows
                        %     called a method like .outdated() on the
                        %     branch, which means in case of the valve e.g.
                        %     that it opened (or closed) --> immediately
                        %     recalculate branch in next time step even
                        %     with the Inf flag set.
                        %%REORG%%oBranch.aoFlows.setSolverData([], 0);
                        fFlowRate = 0;
                        
                        
                        % Probably this is the wrong workaround and I
                        % don't really understand what the TODO comment
                        % above means, but I can't use valves that produce
                        % an inf pressure drop in the current version,
                        % unless I set the afDeltaP return variable to
                        % zeros.
                        afDeltaP = zeros(1, oBranch.iFlowProcs);
%                         iCount  = -1;
%                         rError  = 1;
%                         afDrops = zeros(oBranch.iFlowProcs, 1);
                        
                        % Branch sets its .fFlowRate
                        %oBranch.update();
                        
                        return;
                        
                    end
                    
                end
                
                % Don't set solver data - flow rate might be very off, so
                % just leave the evenly distributed pressures (see above)
                % in place.
                %oBranch.aoFlows(aiFlows).setSolverData(sif(iDir > 0, oExmeL, oExmeR), iDir * fFlowRate, mfData);
            
            %%% Flow rate not zero - do some preparations
            else
                
                iDir      = sif(fFlowRate > 0, 1, -1);
                fFlowRate = abs(fFlowRate);
                fPressDiff = iDir * fPressDiffOrg;
                
                % Create array with indices of flows in flow direction for 
                % update method
                %aiFlows = sif(iDir > 0, 1:oBranch.iFlows, oBranch.iFlows:-1:1);
                
                % Update molar mass, partials etc
                %%REORG%%oBranch.aoFlows(aiFlows).setSolverData(sif(iDir > 0, oExmeL, oExmeR));
                
                % Old comment?
                % Get pressure drop with old flow rate
                %TODO that should be logged and not recalculated!
                
                % Initializing pressure drop variable
                fPressDrop = 0;
                
                hX = tic();
                for iP = 1:oBranch.iFlowProcs
                    
                    % Gather the information from each processor
                    
                    mfData(iP, 1) = this.aoSolverProps(iP).calculateDeltas(iDir * fFlowRate);
                    
                    fPressDrop = fPressDrop + mfData(iP, 1);
                    
                end
                this.fDropTime = this.fDropTime + toc(hX); % What is this for?
                
                
                % Check if press drop AND diff both zero - test if
                % reversed works.
                %bPressuresZero = (fPressDrop == 0) && (fPressDiff == 0);
                
                % Inf? Check opposite flow direction (e.g. regulator in
                % PLSS, returns Inf for flow in 'wrong' direction)
                if isinf(fPressDrop) % || bPressuresZero
                    
                    % Reverse direction, set default init flow rate (time
                    % step is the current one, current time minus last
                    % execution time)
                    iDir       = -1 * iDir;
                    fPressDiff = iDir * fPressDiffOrg;
                    %TODO everywhere for flowrate assumption, does it make
                    %     sense to use the time step / global time step?
                    %fFlowRate = 0.00001 / fTimeStep;
                    fFlowRate = this.oBranch.oContainer.oTimer.fMinimumTimeStep * 1;
                    
                    %%REORG%%oBranch.aoFlows(aiFlows).setSolverData(sif(iDir > 0, oExmeL, oExmeR));
                    
                    fPressDrop = 0;
                    
                    for iP = 1:oBranch.iFlowProcs
                        
                        %TODO Should probably reset the molar mass etc
                        mfData(iP, 1) = this.aoSolverProps(iP).calculateDeltas(iDir * fFlowRate);
                        
                        fPressDrop = fPressDrop + mfData(iP, 1);
                        
                    end
                    
                    %disp([' PRESSURE DROP ("' oBranch.sName '") WAS INF, NOW ' num2str(fPressDrop) ]);
                    
                    if isinf(fPressDrop) % || (bPressuresZero && (fPressDrop == 0))
                        
                        % Set flow rate zero and return - completely shut!
                        %%REORG%%oBranch.aoFlows.setSolverData(sif(iDir < 0, oExmeL, oExmeR), 0);
                        fFlowRate = 0;
%                         iCount  = -1;
%                         rError  = 1;
%                         afDrops = zeros(oBranch.iFlowProcs, 1);
                        
                        %oBranch.update();
                        
                        return;
                        
                    end
                    
                end
                
            end % end if fFlowRate == 0
            
            
            %%% Get the pressure difference depending on direction of flow
            %	rate, preset array with indices
            %	of the flow procs in the flow direction, and calculate an
            %	initial error based on NEW pressure difference (using the
            %   NEW pressures in phases, but the old flow rate) and OLD
            %	pressure drop! Also preallocate matrix with data of flow
            %	procs and  the counter for iteration break.
            %fPressDiff = (sif(iDir > 0, fPressDiffL2R, fPressDiffR2L));
            aiProcs    = sif(iDir > 0, 1:oBranch.iFlowProcs, oBranch.iFlowProcs:-1:1);
            rError     = fPressDiff / (fPressDrop);
            
            
            %%fprintf('\nDIFF %.15f, DIFFORG %.15f, DROP %.15f, ERR %.15f\n', fPressDiff, fPressDiffOrg, fPressDrop, rError);
            
            
            % Loop counter and max. error acceptable (increases)
            iCount = -1;
            %fErrorMax = 0.001; % Increased if too many iterations %prm2
            %fErrorMax = 0.025;
            
            %TODO-OKT15 BETTER INTERP - REDUCE MAX ERR?
            fErrorMax = this.oBranch.oContainer.oTimer.fMinimumTimeStep * 0.1;%00;% / 1000;
            
            
            fMaxErrorMax = 1e-3;
            
%             if oBranch.oContainer.oTimer.fTime > 48.5 %71.1 %811.5
%                 keyboard();
%             end
            
            % Counter for final drops calculation Inf result. Depending on
            % iDir, add or subtract one. If abs() > 5, assume that one dir
            % is blocked, the other can't flow because of pressure
            % difference in connected phases.
            iInfCounter = 0;
            
            
            %disp('Entering Iteration')
            %%% Solving iteration - 0.1% or X loops
            % Also solve if rError isnan --> drop was zero .. fan stuff etc
            while (abs(rError - 1) > fErrorMax) || isnan(rError) % || (iCount == 0)
                
                % Increase error tolerance if too many iterations
                if iCount > 0 && mod(iCount, 25) == 0
                    %fprintf('Increasing iterative solver error tolerance.\n');
                    fErrorMax = fErrorMax * 10;%2;
                    if fErrorMax > fMaxErrorMax
                        fFlowRate = this.fFlowRate;
                        afDeltaP  = zeros(1, oBranch.iFlowProcs);
                        %fprintf('Ding!\n');
                        return;
                    end
                    
                end

                

                % Loop counter
                iCount = iCount + 1;
                
                if iCount > 401, this.throw('solveBranch', 'Too many iterations'); end
                if iCount > 400, keyboard(); end
                
                % Depending on rError, the new flow rate needs to be in- or
                % decreased. Depending on situation, guess or derive a
                % fTmpFlowRate that is used for another pressure drop loop
                % calculation -> two FRs (old fr with old pressure drop,
                % and tmp one) for interpolation
                
                % First loop (iCount starts with -1!) and old FR zero?
                if oBranch.fFlowRate == 0 && iCount == 0
                    
                    % Initial FR ...
                    %fTmpFlowRate = 0.0001 / fTimeStep; % * 0.001;
                    fTmpFlowRate = this.oBranch.oContainer.oTimer.fMinimumTimeStep * 2;
                    
                % Flow rate too small? Use larger one!
                %elseif (fFlowRate < 1e-5 * fTimeStep)
                elseif (fFlowRate < this.oBranch.oContainer.oTimer.fMinimumTimeStep)
                    
                    %TODO ok for large timesteps, can be a minute or so...?
                    %fTmpFlowRate = 0.00002 * fTimeStep; % * 0.001;
                    fTmpFlowRate = this.oBranch.oContainer.oTimer.fMinimumTimeStep * 2;
                    
                else
                    
                    % Check for correction: if error < 0, means that either
                    % pressure diff or drop is < 0, but not both
                    % Check for inf, happens when pressure drop zero
                    if rError < 0 && ~isinf(rError)
                        % Absolute correction factor
                        if fPressDiff >= 0
                            fCorr = 1.01;
                        else
                            fCorr = 1 / 1.01;
                        end
                    else
                        % A negative pressure difference means a pressure
                        % rise, which might be ok if an active f2f proc
                        % like a fan produces a pressure increase - which
                        % means also a negative pressure drop.
                        if ((fPressDiff < 0) && (fPressDrop <= 0))
                            % Correction guess
                            fCorr = 1 / 1.01;% ((rError - 1) / 2 + 1);% - 1;
                        else
                            % Both positive - normal correction guess
                            fCorr = 1.01;% (rError - 1) / 2 + 1;% - 1;
                        end
                    end
                    
                    
                    % Stupid values -> fixed correction!
                    if isnan(fCorr) || isinf(fCorr) || (rError == 0)
                        fCorr = 1.001;
                    % Some upper/lower constraints
                    %TODO make configurable? Make dependent on ratio of
                    %     flow rate * time step an mass in phases?
                    elseif (fCorr > 100)
                        fCorr = 100;
                    elseif (fCorr < -100)
                        fCorr = -100;
                    %CHECK for what was this check? Does not seem to make
                    %       any sense ...?
%                     elseif (fCorr < 1.001) && fCorr > 1
%                         %keyboard();
%                         %fCorr = 0.001;
%                         this.warn('solveFlowRate', 'Weird check for fCorr between 1 and 1.001 -> set to 0.001 --> WHY WAS THAT? Deactivated ... should probably be 1.001 instead of 0.001 so changes will not be too small? If yes - should be done with min. time step times 1000 or so.');
%                     elseif (fCorr > 0.999) && fCorr < 1
%                         fCorr = 0.999;
%                         %this.warn('solveFlowRate', 'Weird check for fCorr between 1 and 0.999 -> set to 0.999 --> WHY WAS THAT? Deactivated ...');
                    end
                    
                    
                    % Temporary flow rate, used to get pressure drops and
                    % interpolate new flow rate
                    fTmpFlowRate = fFlowRate * fCorr;
                    
                end
                
                
                % Get pressure drops (and temp changes) from processors.
                % Each processor has to check the fFlowRate for
                % negative/positive value IF the processor depends on the
                % flow direction (e.g. fan) - pipe, doesn't matter.
                % The return value is always a pressure DROP, independently
                % of the direction, if it is positive.
                for iP = aiProcs
                    % Gather the information from each processor
                    mfData(iP, 1) = this.aoSolverProps(iP).calculateDeltas(iDir * fTmpFlowRate);
                end
                
                
                % Pressure drop inf? Probably something in comp changed, 
                % e.g. valve closed, so do nothing.
                if any(isinf(mfData(:, 1)))
                    
                    % Just set to zero, error to 1 so no further iteration
                    fFlowRate = 0;
                    
                    rError    = 1;
                    mfData    = [];
                    
                    
                    %TODO check if old logic with fr reverse and further
                    %     iterations was better?
                    % Reverse flow rate!
                    %iDir      = sif(fTmpFlowRate >= 0, -1, 1);
                    %fFlowRate = abs(oBranch.fFlowRate) / 100; %0;
                    
                    
                    continue;
                    
                end
                
                
                % Now we have two flow rates and two pressure drops, so
                % interpolate new flow rate
                %CHECK how to handle nan/inf, old drop == new drop, interp1 error? FR = 0?
                bDropErr  = false;
                fNewDrop  = sum(mfData(:, 1));
                if ~(isnan(fPressDrop) || isnan(fNewDrop)|| isnan(fFlowRate) || isnan(fTmpFlowRate) || isnan(fPressDiff))
                    if fPressDrop ~= fNewDrop
                        %keyboard();
                        try
                            fFlowRate = interp1([ fPressDrop fNewDrop ], [ fFlowRate fTmpFlowRate ], fPressDiff, 'linear', 'extrap');
                        catch
                            bDropErr = true;
                        end
                        %disp(['Interpolating ', this.oBranch.sName])
                    else
                        %disp('Skipping interpolation!')
                        bDropErr = true;
                    end
                    %disp('Skipping interpolation!')
                else
                    bDropErr = true;
                end
                
                if bDropErr
                    fFlowRate = 0;
                    rError = 1;
                    continue;
                end
                
                
                % Check if the sign of the flowrate changed, so we need to
                % reset some paramters (Cp, M, rPPs, ...)
                bDirectionChanged = false;
                
                if (fFlowRate < 0)
                    
                    % Revert flow rate - is unsigned! Instead set iDir.
                    fFlowRate  = -1 * fFlowRate;
                    iDir       = -1 * iDir;
                    fPressDiff = iDir * fPressDiffOrg;
                    
                    % Get other pressure diff, preset the indices vectors
                    %fPressDiff = sif(iDir > 0, fPressDiffL2R, fPressDiffR2L);
                    aiProcs    = sif(iDir > 0, 1:oBranch.iFlowProcs, oBranch.iFlowProcs:-1:1);
                    %aiFlows    = sif(iDir > 0, 1:oBranch.iFlows, oBranch.iFlows:-1:1);
                    
                    bDirectionChanged = true;
                    
                    % Set initial stuff like Cp etc, DON'T set pressures!
                    %%REORG%%oBranch.aoFlows(aiFlows).setSolverInit(iDir * fFlowRate, oExmeL, oExmeR, true);
                    
                end
                
                
                % Now redo the solverDeltas
                for iP = aiProcs
                    % Gather the information from each processor
                    mfData(iP, 1) = this.aoSolverProps(iP).calculateDeltas(iDir * fFlowRate);
                end
                
                % As always - check Inf!
                if any(isinf(mfData(:, 1)))
                    
                    % Direction already changed? Set FR to zero!
                    if bDirectionChanged
                        % Just set to zero, error to 1 so no further iteration
                        fFlowRate = 0;

                        rError    = 1;
                        mfData    = [];
                        
                        continue;
                    end
                    
                    % Reverse flow rate
                    iDir = -1 * iDir;
                    fPressDiff = iDir * fPressDiffOrg;
                    
                    % Different possibilities ...
                    %fFlowRate = 0;
                    %fFlowRate = abs(oBranch.fFlowRate) / 100; %0;
                    %fFlowRate = abs(oBranch.fFlowRate) / 100;
                    fFlowRate = fTmpFlowRate;
                    
                    % Reverted stuff and set Cp/molar/... but not pressures
                    %fPressDiff = sif(iDir > 0, fPressDiffL2R, fPressDiffR2L);
                    aiProcs    = sif(iDir > 0, 1:oBranch.iFlowProcs, oBranch.iFlowProcs:-1:1);
                    %aiFlows    = sif(iDir > 0, 1:oBranch.iFlows, oBranch.iFlows:-1:1);

                    %%REORG%%oBranch.aoFlows(aiFlows).setSolverInit(iDir * fFlowRate, oExmeL, oExmeR, true);
                    
                    
                    % New error value
                    rError    = fPressDiff / (fNewDrop);
                    
                    % Diff 0, drop 0 -> oook!
                    if isnan(rError) && (fPressDiff == 0), rError = 1; end
                    
                    % Inf counter - see above
                    iInfCounter = iInfCounter + (-1 * iDir);
                    
                    % Too many tries!
                    if iInfCounter > 5
                        
                        % No flow, don't want the mfData to be set in solve
                        fFlowRate = 0;
                        mfData    = [];
                        
                        %disp('max inf');
                        
                        % Break iteration
                        break;
                        
                    end
                    
                    continue;
                    
                end
                
                
                % Check error - should ALWAYS be positive, if pressure
                % difference is lower than zero, the pressure "drop" should 
                % be as well (and therefore be a pressure rise).
                fPressDrop = sum(mfData(:, 1));
                rError = fPressDiff / (fPressDrop); %TODO this is not rError but rAccuracy ...
                                                  %  rError = rAccuracy - 1
                
                
                % Check if rError isnan (drop was zero), and if fPressDiff 
                % is also zero, set rError to 1!
                if isnan(rError) && (fPressDiff == 0)
                    rError = 1;
                % Pressure difference might be zero in some cases (e.g.
                % initial - tanks equalized - just nothing ...?
                elseif rError == 0
                    rError = 1;
                % If flowrate gets too small, continue - accept small error
                %elseif (fFlowRate < 1e-5 * fTimeStep)
                elseif (fFlowRate < this.oBranch.oContainer.oTimer.fMinimumTimeStep)
                    %rError = 1;
                end
                
            end
            %%%fprintf('[%i] %s: Leaving iteration after %i loops\n', this.oBranch.oTimer.iTick, this.oBranch.sName, iCount);
%             disp(['Flow rate: ', num2str(fFlowRate)])
%             keyboard(); 

            if false && fFlowRate < this.oBranch.oContainer.oTimer.fMinimumTimeStep
                mfData = zeros(oBranch.iFlowProcs, 1);
                afDeltaP = mfData(:, 1);
                fFlowRate = 0;

            elseif ~isempty(mfData)
                % Change of behaviour - now, the values are set on the flow
                % objects in the order according to the flow rate (i.e. for
                % a negative flow rate, the last flow in the branch is set
                % first). Therefore no need for iDir.
                %afDeltaP  = iDir * mfData(:, 1);
                afDeltaP  = mfData(:, 1);

                fFlowRate = iDir * fFlowRate;
            else
                afDeltaP = [];
            end
            
            
%             disp(this.oBranch.oContainer.oTimer.fTime);
%             disp(fPressDiff);
%             disp(fFlowRate);
%             disp('----');
            
            
            %disp(oBranch.sName);
            %disp(num2str(this.oBranch.oContainer.oTimer.fTime));
            %disp(fFlowRate);
            
            
            %%% Only update if flow rate changed ...
            %if oBranch.fFlowRate ~= fFlowRate
                % Ok, we have a new flow rate, yay. Also we have all the
                % intermediate values to set for temperature and pressure.
                % Also sets Cp, M, rPPs etc from the inflow EXME
                %%REORG%%oBranch.aoFlows(aiFlows).setSolverData(sif(iDir > 0, oExmeL, oExmeR), iDir * fFlowRate, mfData);

                % Gets the flowrate from the first flow
                %oBranch.update();
                
%                 % Return drops for logging etc
%                 if ~isempty(mfData)
%                     afDrops = mfData(:, 1);
%                     
%                 % Create NaNs - not written to log by solve()
%                 else
%                     afDrops = nan(oBranch.iFlowProcs, 1);
%                 end
                
                
            % No FR change, but still update Cp, Mol, Partials etc
            %else
                %%REORG%%oBranch.aoFlows(aiFlows).setSolverData(sif(iDir > 0, oExmeL, oExmeR));
                
                % Create NaNs - not written to log by solve()
%                 afDrops = nan(oBranch.iFlowProcs, 1);
            %end
        end
    end
    
    
    methods (Access = protected)
        %% Calculate new time step
        function calculateTimeStep(this, fFlowRateUnrounded, fFlowRate)
            %TODO should probably depend in flow speed vs. length of
            %     branch or something? Maybe flowrate vs. mass in phases,
            %     and flow speed?
            
            if ~isempty(this.fFixedTS)
                
                if this.fTimeStep ~= this.fFixedTS
                    this.setTimeStep(this.fFixedTS);
                    this.fTimeStep = this.fFixedTS;
                end
                
            else
                
                if this.bUseAltTimeStepLogic && bXXXXXX
                    %%%%%%%% Alternative Time Step %%%%%%%%
                    % Just checks for alternating flowrate increase and
                    % decrease from step to step, and reduces flow rate in
                    % that case. Assumes that connected phases have small
                    % enough rMaxChange parameters to deal with the
                    % absolute flow rate change.
                    
                    if isempty(this.fMinStep) || this.fMinStep < this.oBranch.oContainer.oTimer.fMinimumTimeStep
                        this.fMinStep = this.oBranch.oContainer.oTimer.fMinimumTimeStep;
                    end

                    fOldStep = this.fTimeStep;
                    iRemDeSi = this.iRememberDeltaSign;
                    iPrec    = this.oBranch.oContainer.oTimer.iPrecision;
                    iExp     = 5;

                    this.abDeltaPositive(1:iRemDeSi)   = this.abDeltaPositive(2:(iRemDeSi + 1));
                    this.abDeltaPositive(iRemDeSi + 1) = fFlowRate > this.fFlowRate;

                    if tools.round.prec(fFlowRate, iPrec) == tools.round.prec(this.fFlowRate, iPrec)
                        this.abDeltaPositive(iRemDeSi + 1) = this.abDeltaPositive(iRemDeSi);
                    end


                    % The abDeltaPositive array stores booleans, true if for
                    % the according time step, the new flow rate was greater
                    % than the old one, and false if it was lower. If the flow
                    % rate was the same, previous bool value used.
                    %
                    % Therefore this creates an array with one element less
                    % than the stored bools, with a 1 if a switch happend (e.g.
                    % flow rate was becoming larger each tick, then smaller),
                    % and a 0 if nothing changed (not the flow rate itself did
                    % not change, the direction in which it was adapted did not
                    % change).
                    aiChanges = abs(diff(this.abDeltaPositive));
                    % This creates an array the length of aiChanges, each index
                    % representing an increasing weight which are then 
                    % converted to relative weights.
                    afExp = (1:iRemDeSi) .^ iExp;
                    arExp     = afExp ./ sum(afExp);
                    % Therefore, delta fr sign changes in more recent ticks
                    % weigh more than 'older' ones as for this array, the
                    % (relative, i.e. the sum is 1) weights are multiplied with
                    % the indicators for delta sign changes.
                    rChanges  = sum(arExp .* aiChanges);
                    % This means if rChanges is 0, no change in the delta sign
                    % has happend. If it is 1, for every time step a change has
                    % happend.


                    % Min and max timestep - interpolate based on rChanges.
                    % Create a base vector for interpolation, between 0 and 1 
                    % to match rChanges
                    arBase = 0:0.01:1;
                    % Create weighted version for results - can't do linear
                    % interpolation between e.g. 1e-8 and 10 based on rChanges,
                    % would tend to be way too large
                    afWeighted = arBase .^ (iExp * 2);
                    % We were between 0 and 1 - which we should still be. So
                    % expand / move to match the min/max TS domain:
                    afWeighted = this.fMinStep + afWeighted * (this.fMaxStep - this.fMinStep);


                    % Now do the interpolation. We have to turn around rChanges
                    % - in our weighted TS vector, at position 0 we have the
                    % smalles TS and vice versa.
                    fNewStep = interp1(arBase, afWeighted, 1 - rChanges);
                    %keyboard();
                    %fprintf('[%s] FR: %f, TS: %f\n', this.oBranch.sName, this.fFlowRate, fNewStep);


                    this.setTimeStep(fNewStep);
                    this.fTimeStep = fNewStep;
                
                else
                    %%%%%%%% Old TS calc %%%%%%%%

                    % Change in flow rate
                    %TODO use this.fLastUpdate and this.oBranch.oCont.oBranch.oContainer.oTimer.fTime
                    %     and set the rChange in relation to elapsed time!
                    %rChange = abs(fFlowRate / this.fFlowRate - 1);
                    
                    %fChange = tools.round.prec(fFlowRateUnrounded - this.fFlowRateUnrounded, this.oBranch.oContainer.oTimer.iPrecision);
                    %rChange = abs(fChange / this.fFlowRateUnrounded);
                    
                    
                    % In case both were zero!
                    if fFlowRateUnrounded == this.fFlowRateUnrounded
                        rChange = 0;
                        
                    else
                        rChange = abs(abs(fFlowRateUnrounded / this.fFlowRateUnrounded) - 1);
                    end
                    
                    
                    if isinf(rChange) || isnan(rChange)
                        rChange = 1;
                    end
                    
                    
                    %fprintf('%.12f\n', rChange);
                    
                    
                    
                    %fMass = min([ this.oBranch.coExmes{1}.oPhase.fMass, this.oBranch.coExmes{1}.oPhase.fMass ]);
                    
                    %if this.oBranch.oContainer.oTimer.iTick > 400
                        %fprintf('rC %.12f, rC_rnd %.12f, rC_new %.12f\n', rChange, tools.round.prec(rChange, this.oBranch.oContainer.oTimer.iPrecision), rChange / fMass);
                    %end
                    
                    
                    %keyboard();
                    rChange = tools.round.prec(rChange, this.oBranch.oContainer.oTimer.iPrecision);
                    
                    
                    % Old time step
%                     fOldStep = this.fTimeStep;
% 
%                     if fOldStep < this.oBranch.oContainer.oTimer.fMinimumTimeStep
%                         fOldStep = this.oBranch.oContainer.oTimer.fMinimumTimeStep;
%                     end

                    % Change in flow rate direction? Min. time step!
                    
                    if false && (fFlowRate == 0) && (this.fFlowRate ~= 0)
                        fNewStep = fOldStep;
                        %disp('FR 0, OLD FR NOT 0');
                        
                    elseif false && (rChange < 0) || isinf(rChange) || (this.iSignChangeFRCnt > 1)
                        fNewStep = 0;
                        
                        %disp('SIGN CHANGE, INF OR NEG CHANGE');

                        this.iSignChangeFRCnt = this.iSignChangeFRCnt + 1;

                    elseif false && (fFlowRate == 0) && (this.fFlowRate == 0)
                        % If both the current and the previous flow rate
                        % are zero, then nothing is happening in the system
                        % at the moment so we can set the new time step to
                        % maximum. 
                        fNewStep = this.fMaxStep;
                        
                        %disp('FR 0, OLD FR 0');
                    else
                        
                        if this.iSignChangeFRCnt > 1
                            this.iSignChangeFRCnt = this.iSignChangeFRCnt - 1;
                        else
                            this.iSignChangeFRCnt = 0;
                        end

                        % Remember/damp flow rate changes
%                         if rChange >= this.rFlowRateChange
%                            this.rFlowRateChange = rChange;
%                         else
                            this.rFlowRateChange = (rChange + this.iRemChange * this.rFlowRateChange) / (1 + this.iRemChange);
%                         end
                        %disp(this.rFlowRateChange);
                        
                        
                        %fprintf('[%i] Damped %f, Curr %f [%.12f vs old %.12f]\n', this.oBranch.oTimer.iTick, this.rFlowRateChange, rChange, fFlowRateUnrounded, this.fFlowRateUnrounded);
                        
                        % Change larger than limit? Minimum time step.
                        if this.rFlowRateChange > this.rMaxChange
                            fNewStep = 0;
                        else
                            % Interpolate
                            %fNewStep = interp1([ 0 this.rSetChange this.rMaxChange ], [ 2 * fOldStep fOldStep 0 ], this.rFlowRateChange, 'linear', 'extrap');
                            
                            %fNewStep = interp1([ 0 this.rSetChange this.rMaxChange ], [ this.fMaxStep fOldStep 0 ], this.rFlowRateChange, 'pchip', 'extrap');
                            %fNewStep = interp1([ 0 this.rSetChange this.rMaxChange ], [ this.fMaxStep fOldStep 0 ], this.rFlowRateChange, 'linear', 'extrap');
                            
                            
                            %fInt = interp1([ 0 this.rMaxChange ], [ 1 0 ], this.rFlowRateChange, 'linear', 'extrap');
                            fInt = 1 - this.rFlowRateChange / this.rMaxChange;
                            iI = this.fSensitivity;
                            fNewStep = fInt.^iI * this.fMaxStep + this.oBranch.oContainer.oTimer.fMinimumTimeStep;
                        end
                        %disp(fNewStep);
                        
                        %fprintf('TS %.12f   FRCHANGE %f    CHANGE %f\n', fNewStep, this.rFlowRateChange, rChange);
                    end
                    
                    %%fprintf('%.10f - %.12fs\n', this.rFlowRateChange, fNewStep);

                    if fNewStep > this.fMaxStep, fNewStep = this.fMaxStep; end

                    this.setTimeStep(fNewStep, true);
        %             disp(this.rFlowRateChange);
        %             disp(fNewStep);
        %             disp('---------');
                    this.fTimeStep = fNewStep;

                end
                
            end
            
        end % end of calculateTimeStep
        
    end
    
end
