classdef branch < solver.matter.iterative.branch
    
    properties (SetAccess = public, GetAccess = public)
        
    end
    
    properties (SetAccess = protected, GetAccess = public)
        afProcCoeffs;
        
        % Formula: PressureDiff = sum(Coeffs) * FlowRate
        fTotalCoeff;
        % I.e. total coeff = 0 --> NO drop, directly coupled. If inf, the
        % branch is closed.
        
        % Max deviation of new vs old coeffs
        rMaxCoeffDeviation = 0.005;
    end
    
    methods
        
        %% Constructor
        function this = branch(oBranch)
            % Settting no time step - inf by default - never triggered by
            % itself!
            this@solver.matter.iterative.branch(oBranch);
            
            
            % Sets the flow rate to 0 which sets matter properties
            this.update();
        end
        
        
    end
    
    methods (Access = protected)
        function updateCoeffs(this, fFlowRate, fPressDiff)
            % No flow rate? Just assume something. As we're not supporting
            % active components, the pressure difference between the
            % connected phases defines the flow direction!
            if fFlowRate == 0
                if fPressDiff < 0
                    fFlowRate = -1 * this.oBranch.oTimer.fMinimumTimeStep;
                else
                    fFlowRate = this.oBranch.oTimer.fMinimumTimeStep;
                end
            end
            
            % First, get drops
            afDrops = zeros(this.oBranch.iFlowProcs, 1);
            
            for iP = this.oBranch.iFlowProcs:1
                afDrops(iP) = this.aoSolverProps(iP).calculateDeltas(fFlowRate);
                
                if afDrops(iP) < 0
                    this.throw('updateCoeffs', 'Linearized solver cannot handle ''active'' components, i.e. processors generating a pressure rise (negative pressure drop)! Model those as a store/phase!');
                end
            end
            
            
            % Conert to coeffs
            % DeltaPress = Coeff * FR ==> Coeff = DeltaPress / FlowRate!
            this.afProcCoeffs = afDrops / abs(fFlowRate);
            this.fTotalCoeff  = sum(this.afProcCoeffs);
            
            %%%fprintf('%f  -  %f  -  %f\n', afDrops, abs(fFlowRate), this.fTotalCoeff);
        end
        
        
        
        %% Update functions, called directly by timer
        function update(this)
            % Only PASSIVE components, which means: never a pressure rise.
            % Pressure difference at connected phases defines flow
            % direction.
            %
            % Only 'inf' as dP possible, i.e. no flow at all.
            %
            %TODO if dP's are 0 ==> coupled phases, i.e. equalize?
            
            %keyboard();
            
            if this.oBranch.oTimer.fTime < 0
                update@solver.matter.base.branch(this, 0);
                
                return;
            
            elseif this.oBranch.oTimer.fTime <= this.fLastUpdate
                return;
            end
            
            
            %%%% Get pressure difference. %%%%
            [ fPressureLeft,  ~ ] = this.oBranch.coExmes{1}.getPortProperties();
            [ fPressureRight, ~ ] = this.oBranch.coExmes{2}.getPortProperties();
            
            fPressureDiff = tools.round.prec(fPressureLeft - fPressureRight, this.oBranch.oTimer.iPrecision);
            
            % No active components - no dP means no flow!
            if fPressureDiff == 0
                update@solver.matter.base.branch(this, 0);
                
                return;
            end
            
            
            
            % Need to initialize pressure drop coefficients? Or direction
            % changed, so need to update (FR < 0 and DP > 0, for example)?
            % Also, if previous coeff was inf, i.e. no flow!
            %TODO in the inf case, remember the last coeff before the value
            %     became inf, and use that initially?
            if isempty(this.fTotalCoeff) || isinf(this.fTotalCoeff) || ...
                (this.fFlowRate < 0 && fPressureDiff > 0) || ...
                (this.fFlowRate > 0 && fPressureDiff < 0) 
                
                this.updateCoeffs(0, fPressureDiff);
                
            end
            
            % Some component returned a pressure drop of Inf? No flow!
            if this.fTotalCoeff == inf
                update@solver.matter.base.branch(this, 0);
                
                return;
                
            elseif this.fTotalCoeff == 0
                this.throw('update', 'Sum of pressure drop coeff through branch is zero. This means that the two phases of this branch would be more or less directly coupled/pressure equalized, however, that''s not yet supported here. Sorry.');
            end
            
            %%%fprintf('[%i][%s] LINEARIZED (old fr:  %f - PRESS DIFF %f)\n', this.oBranch.oTimer.iTick, this.oBranch.sName, this.fFlowRate, fPressureDiff);
            
            
            % Ok, we know now that the coeff is > 0 and < inf, also we know
            % that the pressure difference is not zero. That means that we
            % can caclualte a new flow rate. Yay.
            %
            % However, the coefficiencs might have been calculated for
            % different pressure levels or very different flow rates.
            % Therefore, iterate: calc flow rate, set it. With that, the
            % pressures in the flow objects are updated. Then, calculate
            % coefficients again and compare to original coefficient. Stop
            % iteration if those are close enough. What's close enough?
            % Well ... who cares.
            rCoeffDeviation   = inf;
            iIteration        = 0;
            
            %L%fprintf('[%i] Updating %s at %fs with a pressure difference of %f\n', this.oBranch.oTimer.iTick, this.oBranch.sName, this.oBranch.oTimer.fTime, fPressureDiff);
            
            % There might be a case where e.g. a pipe switch from laminar
            % to turbulent (or vice versa) leads to a 'deadlock' situation.
            % In this case (rCoeffDeviation jumps back and forth between
            % two values), we use the mean flow rate to calculate the new
            % drop coefficients. The variables here are used to recognize
            % such a situation.
            %iJumpCounter = 0;
            %fOlderCoeff  = nan;
            arDeviations = [ 0 2 -1 -5 5 9 8 3 5 ]; % Just any values that do not match condition
            bJumped      = false;
            
            iIterativeIterations = 100;
            
            % (iIteration <= 10) && 
            while (rCoeffDeviation > this.rMaxCoeffDeviation)
                iIteration   = iIteration + 1;
                
                
                % Remember old stuff
                fOldCoeff    = this.fTotalCoeff;
                fOldFlowRate = this.fFlowRate;
                
                %this.updateCoeffs(fOldFlowRate, fPressureDiff);
                
                
                % Calculate new flow rate with iterative solver, doesn't
                % seem that the linearized version works
                if mod(iIteration, iIterativeIterations) == 0
                    fprintf('[%i][%s] ITERATIVE\n', this.oBranch.oTimer.iTick, this.oBranch.sName);
                    [ fFlowRate, afPressureDrops ] = this.solveFlowRate();
                    
                    this.updateCoeffs(fFlowRate, fPressureDiff);
                    fOldCoeff = this.fTotalCoeff;
                
                % Calculate new flow rate with linearized coeffs
                else
                    fFlowRate = fPressureDiff / this.fTotalCoeff;

                    % Calculate according actual pressure drops (see method
                    % updateCoeffs - DP = COEFF * FR).
                    afPressureDrops = this.afProcCoeffs * abs(fFlowRate);
                    
                    this.updateCoeffs(fFlowRate, fPressureDiff);
                end
                
                % Set new flow rate
                update@solver.matter.base.branch(this, fFlowRate, afPressureDrops);
                
                
                % Does the rCoeffDeviation jump back and forth between two
                % values?
                %TODO this also matches [ 1 2 3 4 ]! Not just [ 1 -1 1 -1 ]
                if (mod(iIteration, iIterativeIterations) ~= 0) && ...
                    (bJumped || length(unique(tools.round.prec(abs(diff(arDeviations)), this.oBranch.oTimer.iPrecision))) == 1)
                    
                    %L%fprintf('\n\n JUMPED - %f vs %f \n\n', fFlowRate, fOldFlowRate);
                    %fprintf('[%i][%s] JUMPED\n', this.oBranch.oTimer.iTick, this.oBranch.sName);
                    %keyboard();
                    arDeviations = [ 0 2 -1 -5 5 9 8 3 5 ];
                    bJumped      = true;
                    
                    % Enough jumping! Use mean flow rate between current
                    % and old value!
                    %this.updateCoeffs((fFlowRate + fOldFlowRate) / 2, fPressureDiff);
                    this.updateCoeffs((fFlowRate + fOldFlowRate * 1) / 2, fPressureDiff);
                    
                    %this.updateCoeffs(fFlowRate, fPressureDiff);
                    %this.fTotalCoeff = (this.fTotalCoeff + fOldCoeff) / 2;
                else
                    % Get new coeff
                    %this.updateCoeffs(fFlowRate, fPressureDiff);
                end
                
                
                % Calculate error
                rCoeffDeviation = abs(this.fTotalCoeff / fOldCoeff - 1);
                
                % Log deviations
                arDeviations = [ arDeviations(2:end) rCoeffDeviation ];
                
                
                %L%fprintf('%i[%.12f] ', iIteration, rCoeffDeviation);
                
                if mod(iIteration, 99) == 0
                    %fprintf('\n');
                    %keyboard();
                end
            end
            
            
            
            
            
            
            
            % Ok, check for time step. If e.g. sign switch, set time step
            % to minimum!
            %WAIT ... we know better ... soooo ... yeah. Really directly
            %  check. Like if PressDiff small and stuff. Always set so
            %  parity would be reached within 10 steps!
            % Will need the m2p coeffs for that!
            %
            %TODO hmmm should include fTotalMassInOut of phases, right?
            %     Because could be steady state, right?
            %
            %fMassToPressureLeft  = this.oBranch.coExmes{1}.oPhase.fMassToPressure;
            %fMassToPressureRight = this.oBranch.coExmes{2}.oPhase.fMassToPressure;
            %fMassToPressureMean  = (fMassToPressureLeft + fMassToPressureRight) / 2;
            %fMassDiff            = fPressureDiff / fMassToPressureMean;
            
            fMassDiff          = abs(this.oBranch.coExmes{1}.oPhase.fMass - this.oBranch.coExmes{2}.oPhase.fMass);
            fSecondsToEqualize = fMassDiff / abs(this.oBranch.fFlowRate);
            fEqualizeTimeStep  = fSecondsToEqualize / 25;
            
            
            
%             fCoeffDevTimeStep = interp1([ 0.1 0.01 ], [ 0 5 ], rCoeffDeviation, 'linear', 'extrap');
            
            
            %fTimeStep = max([ 0 min([ fEqualizeTimeStep fCoeffDevTimeStep ]) ]);
            fTimeStep = fEqualizeTimeStep;
            
            this.setTimeStep(fTimeStep);
            
            %fprintf('done in %i - new TS: %f - new FR %.12f - new FR UNROUDED %.12f\n', iIteration, fTimeStep, this.fFlowRate, this.oBranch.fFlowRate);
            
            
%             if any(this.oBranch.afFlowRates < 0) && any(this.oBranch.afFlowRates > 0)
%                 this.setTimeStep(0);
%             else
%                 this.setTimeStep(inf);
%             end
            
            
            
            return;
            
            
            % REDO if flow rate not zero, re-get coeffs ==> compare!
            
            
            
            % Old FR (or, if zero, min TS as initial FR)
            % Get Coeffs (with FR, ask Comps for Drop, divide by FR, sum)
            %   => WAIT. Just use old shit. Initial minTS FR only initially
            %
            % Inf Coeffs --> directly coupled, 0 Coeff -> no Flow Rate!
            % Calc dependent pressures
            % Calc real flow rats
            %
            % SET flow rates including pressure drops via coeffs --> new
            % pressures are set in branches. REDO get coeffs --> compare!
            
            
%             mfData = zeros(oBranch.iFlowProcs, 1);
%             
%             for iP = oBranch.iFlowProcs:1
% 
%                 mfData(iP, 1) = this.aoSolverProps(iP).calculateDeltas(iDir * fFlowRate);
% 
%                 fPressDrop = fPressDrop + mfData(iP, 1);
% 
%             end
        end
    end
end
