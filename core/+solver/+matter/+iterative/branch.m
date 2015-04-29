classdef branch < solver.matter.base.branch
    %
    %
    %TODO
    % - if e.g. constant pressure EXME and connected phase becomes empty,
    %   and iDampFR active --> problems with NaN for fTemp etc!
    
    
    properties (SetAccess = public, GetAccess = public)
        rMaxChange = 0.1;
        rSetChange = 0.025;
        iRemChange = 10;
        fMaxStep   = 60;
        
        iDampFR = 0;
        
        % Fixed time step - set to empty ([]) to deactivate
        fFixedTS = [];
        
        
        %%%% New TS logic
        bUseAltTimeStepLogic = false;
        
        fMinStep;
        fMaxStepAlt = 25;
        
        
        %TODO can only be set once on initialization?
        iRememberDeltaSign = 10;
        abDeltaPositive    = [ true, false, true, false, true, false, true, false, true, false, true ];
    end
    
    properties (SetAccess = protected, GetAccess = public)
        rFlowRateChange  = 0;
        iSignChangeFRCnt = 0;
        
        fTimeStep = 0;
        
        
        fDropTime = 0;
    end
    
    properties (SetAccess = private, GetAccess = public)
        
    end
    
    
    
    methods
        function this = branch(oBranch, rMaxChange, iRemChange)
            this@solver.matter.base.branch(oBranch, [], 'callback');
            
            if nargin >= 2, this.rMaxChange = rMaxChange; end;
            if nargin >= 3, this.iRemChange = iRemChange; end;
            
            % Sets the flow rate to 0 which sets matter properties
            this.update();
        end
        
        function setAlternativeTimeStepMethod(this, iDampening, iMaxStep)
            this.bUseAltTimeStepLogic = true;
            
            if nargin >= 2
                this.iDampFR = iDampening * this.oBranch.oContainer.oData.rSolverDampening;
            end

            if nargin >= 3, this.fMaxStepAlt = iMaxStep; end;
            
            this.fMaxStep = this.fMaxStepAlt;
        end
    end
    
    methods (Access = protected)
        function update(this)
            if ~(this.oBranch.oContainer.oData.oTimer.fTime >= 0)
                %return;
            end
            
            
            if this.oBranch.oContainer.oTimer.fTime < 0
                
                update@solver.matter.base.branch(this, 0);
                
                return;
            end
            
            
            if this.oBranch.oContainer.oTimer.fTime < this.fLastUpdate
                return;
            end
            
            [ fFlowRate, afDeltaP, afDeltaT ] = this.solveFlowRate();
            % See base branch, same check here - if input phase nearly
            % empty, just set flow rate to zero
            oIn = this.oBranch.coExmes{sif(fFlowRate >= 0, 1, 2)}.oPhase;
                
            if tools.round.prec(oIn.fMass, oIn.oStore.oTimer.iPrecision) == 0
                fFlowRate = 0;
            
            % If we don't round at some point, flow rates will eventually
            % become something like 1e-13 etc -> don't want that.
            elseif tools.round.prec(fFlowRate, this.oBranch.oContainer.oTimer.iPrecision) == 0
                fFlowRate = 0;
            end
            
            
            if fFlowRate ~= 0
                fFlowRate = (this.fFlowRate * this.iDampFR + fFlowRate) / (this.iDampFR + 1);
            end
            %disp([ this.oBranch.sName ' it @' num2str(this.oBranch.oContainer.oTimer.fTime) ]);
            
            
            
            %% TIME STEP
            %TODO should probably depend in flow speed vs. length of
            %     branch or something? Maybe flowrate vs. mass in phases,
            %     and flow speed?
            
            
            if ~isempty(this.fFixedTS)
                if this.fTimeStep ~= this.fFixedTS
                    this.setTimeStep(this.fFixedTS);
                    this.fTimeStep = this.fFixedTS;
                end
                
            else
                if this.bUseAltTimeStepLogic
                    %%%%%%%% Alternative Time Step %%%%%%%%
                    % Just checks for alternating flowrate increase and
                    % decrease from step to step, and reduces flow rate in
                    % that case. Assumes that connected phases have small
                    % enough rMaxChange parameters to deal with the
                    % absolute flow rate change.
                    
                    if isempty(this.fMinStep) || this.fMinStep < this.oBranch.oContainer.oTimer.fTimeStep
                        this.fMinStep = this.oBranch.oContainer.oTimer.fTimeStep;
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

                    if this.oBranch.oContainer.oTimer.iTick == 365
                        %keyboard();
                    end

                    % Change in flow rate
                    %TODO use this.fLastUpdate and this.oBranch.oCont.oBranch.oContainer.oTimer.fTime
                    %     and set the rChange in relation to elapsed time!
                    rChange = abs(fFlowRate / this.fFlowRate - 1);

                    % Old time step
                    fOldStep = this.fTimeStep;

                    if fOldStep < this.oBranch.oContainer.oTimer.fTimeStep
                        fOldStep = this.oBranch.oContainer.oTimer.fTimeStep;
                    end

                    % Change in flow rate direction? Min. time step!
                    if (rChange < 0) || isinf(rChange) || (this.iSignChangeFRCnt > 1)
                        fNewStep = 0;

                        this.iSignChangeFRCnt = this.iSignChangeFRCnt + 1;

                    else
                        if this.iSignChangeFRCnt > 1
                            this.iSignChangeFRCnt = this.iSignChangeFRCnt - 1;
                        else
                            this.iSignChangeFRCnt = 0;
                        end

                        % Remember/damp flow rate changes
                        if rChange >= this.rFlowRateChange
                            this.rFlowRateChange = rChange;
                        else
                            this.rFlowRateChange = (rChange + this.iRemChange * this.rFlowRateChange) / (1 + this.iRemChange);
                        end
                        %disp(this.rFlowRateChange);
                        % Change larger than limit? Minimum time step.
                        if this.rFlowRateChange > this.rMaxChange, fNewStep = 0;
                        else
                            % Interpolate
                            fNewStep = interp1([ 0 this.rSetChange this.rMaxChange ], [ 2 * fOldStep fOldStep 0 ], this.rFlowRateChange, 'linear', 'extrap');
                        end
                        %disp(fNewStep);
                    end

                    if fNewStep > this.fMaxStep, fNewStep = this.fMaxStep; end;

                    this.setTimeStep(fNewStep);
                    %this.setTimeStep(10);
        %             disp(this.rFlowRateChange);
        %             disp(fNewStep);
        %             disp('---------');
                    this.fTimeStep = fNewStep;

                    %disp(fNewStep);
                end
            end
            
            
            
            
            % Sets new flow rate
            update@solver.matter.base.branch(this, fFlowRate, afDeltaP, afDeltaT);
        end
        
        
        
        
        
        %% SOLVE BRANCH
        function [ fFlowRate, afDeltaP, afDeltaT ] = solveFlowRate(this)
            % Calculates flow rate for a branch. Flow rate fFlowRate here
            % is NOT signed (negative/positive depending on direction, left
            % to right is positive), therefore iDir value maintained
            % For solverDeltas, a positive pressure drop that is returned
            % ALWAYS defines a pressure drop, a negative one a pressure
            % rise, so for example a pipe, where the direction of the flow
            % does not matter, can always return a positive value and just
            % abs() the provided flow rate.
            
            oBranch = this.oBranch;
            
            % Data matrix - rows equals amount of flow procs minus two (the
            % EXMEs), columns are the pressure drops and temperature
            % changes returned by the components (f2f processors)
            mfData = zeros(oBranch.iFlowProcs, 2);
            
            afDeltaP = [];
            afDeltaT = [];
            
            
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
            
            %QUESTION What is this for?
            fPressDiffOrg = fPressDiff;
            
            
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
                aiFlows = sif(iDir > 0, 1:oBranch.iFlows, oBranch.iFlows:-1:1);
                
                % Preset pressure drop to zero, set initial flow rate
                fPressDrop = 0;
                %fFlowRate  = 0.00001 / fTimeStep;
                fFlowRate = this.oBranch.oContainer.oTimer.fTimeStep * 1;
                
                % Depending on flow direction, initialize values
                % Sets Cp, MolMass, rPPs; Temp from IN Exme, Pressure to
                % steps of (P_in - P_out) / Number_flows
                %%REORG%%oBranch.aoFlows(aiFlows).setSolverInit(fFlowRate, oExmeL, oExmeR);
                
                % Preset pressure drop / temperature change matrix
                mfData = zeros(oBranch.iFlowProcs, 2);
                
                % Calculate solver deltas with initial flow rate above for 
                % the 'normal' solver to use as a starting point
                for iP = 1:oBranch.iFlowProcs
                    % Gather the information from each processor
                    %[ mfData(iP, 1), mfData(iP, 2) ] = oBranch.aoFlowProcs(iP).solverDeltas(iDir * fFlowRate);
                    [ mfData(iP, 1), mfData(iP, 2) ] = this.aoSolverProps(iP).calculateDeltas(iDir * fFlowRate);
                    
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
                    aiFlows    = sif(iDir > 0, 1:oBranch.iFlows, oBranch.iFlows:-1:1);
                    %TODO Do solverInit again for molar masses etc?
                    for iP = oBranch.iFlowProcs:-1:1
                        [ mfData(iP, 1), mfData(iP, 2) ] = this.aoSolverProps(iP).calculateDeltas(iDir * fFlowRate);
                        
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
                aiFlows = sif(iDir > 0, 1:oBranch.iFlows, oBranch.iFlows:-1:1);
                
                % Update mol mass, partials etc
                %%REORG%%oBranch.aoFlows(aiFlows).setSolverData(sif(iDir > 0, oExmeL, oExmeR));
                
                % Get pressure drop with old flow rate
                %TODO that should be logged and not recalculated!
                fPressDrop = 0;
                
                hX = tic();
                for iP = 1:oBranch.iFlowProcs
                    % Gather the information from each processor
                    
                    [ mfData(iP, 1), mfData(iP, 2) ] = this.aoSolverProps(iP).calculateDeltas(iDir * fFlowRate);
                    
                    fPressDrop = fPressDrop + mfData(iP, 1);
                end
                this.fDropTime = this.fDropTime + toc(hX);
                
                
                % Check if press drop AND diff both zero - test if
                % reversed works.
                %bPressuresZero = (fPressDrop == 0) && (fPressDiff == 0);
                
                % Inf? Check opposite flow direction (e.g. regulator in
                % PLSS, returns Inf for flow in 'wrong' direction)
                if isinf(fPressDrop) % || bPressuresZero
                    % Reverse direction, set default init flow rate (time
                    % step is the current one, current time minus last
                    % execution time)
                    iDir      = -1 * iDir;
                    fPressDiff = iDir * fPressDiffOrg;
                    %TODO everywhere for flowrate assumption, does it make
                    %     sense to use the time step / global time step?
                    %fFlowRate = 0.00001 / fTimeStep;
                    fFlowRate = this.oBranch.oContainer.oTimer.fTimeStep * 1;
                    
                    %%REORG%%oBranch.aoFlows(aiFlows).setSolverData(sif(iDir > 0, oExmeL, oExmeR));
                    
                    fPressDrop = 0;
                    
                    for iP = 1:oBranch.iFlowProcs
                        %TODO Should probably reset the molmass etc
                        [ mfData(iP, 1), mfData(iP, 2) ] = this.aoSolverProps(iP).calculateDeltas(iDir * fFlowRate);
                        
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
            end
            
            
            
            
            %%% Get the pressure difference depending on direction of flow
            %	rate, preset array with indices
            %	of the flow procs in the flow direction, and calculate an
            %	initial error based on NEW pressure difference (using the
            %   NEW pressures in phases, but the old flow rate) and OLD
            %	pressure drop! Also preallocate matrix with data of flow
            %	procs and  the counter for iteration break.
            %fPressDiff = (sif(iDir > 0, fPressDiffL2R, fPressDiffR2L));
            aiProcs    = sif(iDir > 0, 1:oBranch.iFlowProcs, oBranch.iFlowProcs:-1:1);
            rError     = fPressDiff / fPressDrop;
            
            % Loop counter and max. error acceptable (increases)
            iCount = -1;
            %fErrorMax = 0.001; % Increased if too many iterations %prm2
            %fErrorMax = 0.025;
            fErrorMax = this.oBranch.oContainer.oTimer.fTimeStep * 100;
            
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
                if mod(iCount, 10) == 0
                    fErrorMax = fErrorMax * 10;%2;
                end
                
                % Loop counter
                iCount = iCount + 1;
                
                if iCount > 250, this.throw('solveBranch', 'Too many iterations'); end;
                if iCount > 249, keyboard(); end;
                
                % Depending on rError, the new flow rate needs to be in- or
                % decreased. Depending on situation, guess or derive a
                % fTmpFlowRate that is used for another pressure drop loop
                % calculation -> two FRs (old fr with old pressure drop,
                % and tmp one) for interpolation
                
                % First loop (iCount starts with -1!) and old FR zero?
                if oBranch.fFlowRate == 0 && iCount == 0
                    % Initial FR ...
                    %fTmpFlowRate = 0.0001 / fTimeStep; % * 0.001;
                    fTmpFlowRate = this.oBranch.oContainer.oTimer.fTimeStep * 2;
                    
                % Flow rate too small? Use larger one!
                %elseif (fFlowRate < 1e-5 * fTimeStep)
                elseif (fFlowRate < this.oBranch.oContainer.oTimer.fTimeStep)
                    %TODO ok for large timesteps, can be a minute or so...?
                    %fTmpFlowRate = 0.00002 * fTimeStep; % * 0.001;
                    fTmpFlowRate = this.oBranch.oContainer.oTimer.fTimeStep * 2;
                    
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
                            fCorr = 1 / ((rError - 1) / 2 + 1);% - 1;
                            
                        else
                            % Both positive - normal correction guess
                            fCorr = (rError - 1) / 2 + 1;% - 1;
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
                    [ mfData(iP, 1), mfData(iP, 2) ] = this.aoSolverProps(iP).calculateDeltas(iDir * fTmpFlowRate);
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
                if (fFlowRate < 0)
                    % Revert flow rate - is unsigned! Instead set iDir.
                    fFlowRate  = -1 * fFlowRate;
                    iDir       = -1 * iDir;
                    fPressDiff = iDir * fPressDiffOrg;
                    
                    % Get other pressure diff, preset the indices vectors
                    %fPressDiff = sif(iDir > 0, fPressDiffL2R, fPressDiffR2L);
                    aiProcs    = sif(iDir > 0, 1:oBranch.iFlowProcs, oBranch.iFlowProcs:-1:1);
                    aiFlows    = sif(iDir > 0, 1:oBranch.iFlows, oBranch.iFlows:-1:1);
                    
                    % Set initial stuff like Cp etc, DON'T set pressures!
                    %%REORG%%oBranch.aoFlows(aiFlows).setSolverInit(iDir * fFlowRate, oExmeL, oExmeR, true);
                end
                
                
                % Now redo the solverDeltas
                for iP = aiProcs
                    % Gather the information from each processor
                    [ mfData(iP, 1), mfData(iP, 2) ] = this.aoSolverProps(iP).calculateDeltas(iDir * fFlowRate);
                end
                
                % As always - check Inf!
                if any(isinf(mfData(:, 1)))
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
                    aiFlows    = sif(iDir > 0, 1:oBranch.iFlows, oBranch.iFlows:-1:1);

                    %%REORG%%oBranch.aoFlows(aiFlows).setSolverInit(iDir * fFlowRate, oExmeL, oExmeR, true);
                    
                    
                    % New error value
                    rError    = fPressDiff / fNewDrop;
                    
                    % Diff 0, drop 0 -> oook!
                    if isnan(rError) && (fPressDiff == 0), rError = 1; end;
                    
                    % Inf counter - see above
                    iInfCounter = iInfCounter + (-1 * iDir);
                    
                    % Too much tries!
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
                % difference is lt zero, the pressure "drop" should be as
                % well (and therefore be a pressure rise).
                fPressDrop = sum(mfData(:, 1));
                rError = fPressDiff / fPressDrop; %TODO this is not rError but rAccuracy ...
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
                elseif (fFlowRate < this.oBranch.oContainer.oTimer.fTimeStep)
                    rError = 1;
                    
                end
            end
%             disp('Leaving iteration')
%             disp(['Flow rate: ', num2str(fFlowRate)])
%             keyboard(); 
            if fFlowRate < this.oBranch.oContainer.oTimer.fTimeStep
                mfData = zeros(oBranch.iFlowProcs, 2);
                afDeltaP = iDir * mfData(:, 1);
                afDeltaT = iDir * mfData(:, 2);
                fFlowRate = 0;
                
            elseif ~isempty(mfData)
                afDeltaP  = iDir * mfData(:, 1);
                afDeltaT  = iDir * mfData(:, 2);
                fFlowRate = iDir * fFlowRate;
            else
                afDeltaP = [];
                afDeltaT = [];
            end
            
            
%             disp(this.oBranch.oContainer.oTimer.fTime);
%             disp(fPressDiff);
%             disp(fFlowRate);
%             disp('----');
            
            
            %disp(oBranch.sName);
            %disp(num2str(this.oBranch.oContainer.oTimer.fTime));
            %disp(fFlowRate);
            
            
            %%% Only update if flow rate changed ...
            if oBranch.fFlowRate ~= fFlowRate
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
            else
                %%REORG%%oBranch.aoFlows(aiFlows).setSolverData(sif(iDir > 0, oExmeL, oExmeR));
                
                % Create NaNs - not written to log by solve()
%                 afDrops = nan(oBranch.iFlowProcs, 1);
            end
        end
        
    end
end
