classdef branch < solver.matter.base.branch
    
    properties (SetAccess = public, GetAccess = public)
        rMaxChange = 0.1;
        rSetChange = 0.025;
        iRemChange = 10;
        fMaxStep   = 60;
        
        iDampFR = 0;
        
        % Fixed time step - set to empty ([]) to deactivate
        fFixedTS = [];
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
            this@solver.matter.base.branch(oBranch);
            
            if nargin >= 2, this.rMaxChange = rMaxChange; end;
            if nargin >= 3, this.iRemChange = iRemChange; end;
            
            % Sets the flow rate to 0 which sets matter properties
            this.update();
        end
        
        
    end
    
    methods (Access = protected)
        function update(this)
            if ~(this.oBranch.oContainer.oData.oTimer.fTime >= 0)
                return;
            end
            
            
            
            if this.oBranch.oContainer.oTimer.fTime < 0
                %keyboard();
                
                update@solver.matter.base.branch(this, 0);
            end
            
            if this.oBranch.oContainer.oTimer.fTime < this.fLastUpdate
                return;
            end
            
            
            %keyboard();
            [ fFlowRate, afDeltaP, afDeltaT ] = this.solveFlowRate();
            
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

                    % Change larger than limit? Minimum time step.
                    if this.rFlowRateChange > this.rMaxChange, fNewStep = 0;
                    else
                        % Interpolate
                        fNewStep = interp1([ 0 this.rSetChange this.rMaxChange ], [ 2 * fOldStep fOldStep 0 ], this.rFlowRateChange, 'linear', 'extrap');
                    end
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
            
            % Pressure differences - one should be gt 0, one lt 0!
            %fPressDiffL2R = oExmeL.solverExtract(fFlowRate) - oExmeR.solverMerge(fFlowRate);
            %fPressDiffR2L = oExmeR.solverExtract(fFlowRate) - oExmeL.solverMerge(fFlowRate);
            fPressDiff = oExmeL.getPortProperties() - oExmeR.getPortProperties();
            
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
                    [ mfData(iP, 1), mfData(iP, 2) ] = oBranch.aoFlowProcs(iP).solverDeltas(iDir * fFlowRate);
                    
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
                        [ mfData(iP, 1), mfData(iP, 2) ] = oBranch.aoFlowProcs(iP).solverDeltas(iDir * fFlowRate);
                        
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
                    
                    [ mfData(iP, 1), mfData(iP, 2) ] = oBranch.aoFlowProcs(iP).solverDeltas(iDir * fFlowRate);
                    
                    fPressDrop = fPressDrop + mfData(iP, 1);
                end
                this.fDropTime = this.fDropTime + toc(hX);
                
                
                % Inf? Check opposite flow direction (e.g. regulator in
                % PLSS, returns Inf for flow in 'wrong' direction)
                if isinf(fPressDrop)
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
                        [ mfData(iP, 1), mfData(iP, 2) ] = oBranch.aoFlowProcs(iP).solverDeltas(iDir * fFlowRate);
                        
                        fPressDrop = fPressDrop + mfData(iP, 1);
                    end
                    
                    %disp([' PRESSURE DROP ("' oBranch.sName '") WAS INF, NOW ' num2str(fPressDrop) ]);
                    
                    if isinf(fPressDrop)
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
                    
                    elseif (fCorr < 1.001) && fCorr > 1
                        fCorr = 0.001;
                    elseif (fCorr > 0.999) && fCorr < 1
                        fCorr = 0.999;
                        
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
                    [ mfData(iP, 1), mfData(iP, 2) ] = oBranch.aoFlowProcs(iP).solverDeltas(iDir * fTmpFlowRate);
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
                fNewDrop  = sum(mfData(:, 1));
                if ~(isnan(fPressDrop) || isnan(fNewDrop)|| isnan(fFlowRate) || isnan(fTmpFlowRate) || isnan(fPressDiff))
                    if fPressDrop ~= fNewDrop
                        %keyboard();
                        fFlowRate = interp1([ fPressDrop fNewDrop ], [ fFlowRate fTmpFlowRate ], fPressDiff, 'linear', 'extrap');
                        %disp(['Interpolating ', this.oBranch.sName])
                    else
                        %disp('Skipping interpolation!')
                    end
                
                    %disp('Skipping interpolation!')
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
                    [ mfData(iP, 1), mfData(iP, 2) ] = oBranch.aoFlowProcs(iP).solverDeltas(iDir * fFlowRate);
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