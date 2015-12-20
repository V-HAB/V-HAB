classdef gas_virtual < matter.phases.gas
    %GAS_VIRTUAL Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        % Maximum sum of total flow rates divided by contained mass, i.e.
        % maximum mass change rate in percent (ratio) per second. If change
        % is equal or larger, time step is set to miniumum
        rMaxChangeRate = 0.01;
    end
    
    properties (SetAccess = protected, GetAccess = public)
        % Pressure is adjusted ('virtual', not a real pressure) to minimize
        % the total flow rate
        fVirtualPressure;
        
        % Informative
        fVirtualMassToPressure;
        
        
        % Previous time step - virtual pressure
        fPreviousStepVirtualPressure;
        
        % Previous time step - total mass flow rates (sum of all inwards
        % and outwards flow rates)
        fPreviousStepTotalFlowRate;
        
        
        % Actual pressure - just informative
        fActualPressure;
        
        % Actual mass to pressure - just informative
        fActualMassToPressure;
        
        
        
        fMaxInOut;
        
        fLastFlowRateChangePerPressureChange = 0;
        
        
        fInitialMass;
    end
    
    methods
        function this = gas_virtual(varargin)
            this@matter.phases.gas(varargin{:});
            
            this.bSynced   = true;
            this.fMaxInOut = this.oTimer.fMinimumTimeStep * 100;
            
            this.fInitialMass = this.fMass;
            
            % Make dependent on rUpdateFrequency in .seal()?
            %this.rMaxChangeRate = 0.1;
        end
        
        function setInitialVirtualPressure(this, fVirtualPressure)
            this.fVirtualPressure        = fVirtualPressure;
            this.fVirtualMassToPressure  = this.fVirtualPressure / this.fMass;
        end
        
        
        function massupdate(this, varargin)
            bCalc = this.oStore.oTimer.iTick > -1 && (this.oStore.oTimer.fTime - this.fLastMassUpdate) > 0 && ~this.bOutdatedTS;
            
            massupdate@matter.phases.gas(this, varargin{:});
            
            if bCalc
                %this.oStore.oTimer.bindPostTick(@this.updateVirtualPressure);
                this.updateVirtualPressure();
            end
        end
        
        
        
        
        function update(this, varargin)
            update@matter.phases.gas(this, varargin{:});
            
            
            this.fActualPressure = this.fPressure;
            
            if isempty(this.fActualMassToPressure)
                this.fActualMassToPressure = this.fMassToPressure;
            end
            
            % Just first time step
            if isempty(this.fVirtualPressure)
                this.fVirtualPressure        = this.fPressure;
                this.fVirtualMassToPressure  = this.fMassToPressure;
            else
                this.fActualMassToPressure = this.fMassToPressure;
                this.fMassToPressure = this.fVirtualMassToPressure;
            end
        end
        
        
        
        function this = updateVirtualPressure(this)
            fPrevMassToPressure = this.fMassToPressure;
            fPrevInOut          = this.fCurrentTotalMassInOut;
            
            
            %update@matter.phases.gas(this);
            
            
            %TODO - IMPROVEMENTS
            %  should all this be done in .massupd instead of .upd? Not
            %  really necessary, right? If massupd leads to large change in
            %  mass per sec, calcTS will schedule next .upd accordingly...?
            %
            % fMaxInOut
            %     after iteration finished, compare new / old fMassToPress
            %     and for little differences, decrease fMaxInOut, if large
            %     diff, increase fMaxInOut!! Simply
            %       fMaxInOut = fMaxInOut * abs(fOldM2P / fNewM2P - 1)
            %
            %
            %   check getTotalInOut() vs fCurrTotalMassInOut, why diff???
            %
            %   two interpolations per iteration -> faster results?
            %   store some value for delta_p vs. delta_fr? Assuming that
            %   property stays fairly constant, even if e.g. connected
            %   phases change or even fan setting changed?
            %
            %
            %
            % MASS - CalcTS - interp ... should be independent of
            %        internally stored mass! Wtf?
            %   TS - same as normal phase - store change that already
            %        happened, subtract from remaining rMaxChangeRate
            %
            % => 1) make calcTS only dependent on in or out maxFlowRate?
            % => 2) rMaxError ... ?? Always set back to fTimeStep? BETTER:
            %           maxErr dependent on rMaxChangeRate - if iteration
            %           works well - error not increased - max TS?
            %
            %
            % fMaxInOut
            %   Adjust based on MAX FLOW RATE:
            %  fMaxInOut = this.oTimer.fMinimumTimeStep * max(afFlowRates) * 100;
            %  ... * 100? * 1000?
            %
            %
            % (!!!) BETTER INTERPOLATION
            % * log sensitivity value - change in FR per PA
            % * (kg/s) / Pa
            % * should only depend on branches e.g. FAN, not on connected
            %   phases etc
            % => always use data from last tick, calculate (kg/s)/Pa value
            % 
            % (!!!) ERROR -> if fVirtPress > fActPressure, only accept
            %   negative error and vice versa
            %   => fMass changes towards actual fPressure, which is
            %   important e.g. for a very small phase with very little
            %   fMass (could deplete completely - problem ...)
            %
            % (!!!) completely remove interpolation, just use the FR vs PA
            %   value in while loop? If bReqPos && > threshold, reduce M2P
            %   etc - continue to adapt FR vs PA value; if bReqPos && < 0,
            %   increase M2P! (and vice versa)
            %
            % => try to keep fMass around fInitialMass, so for a large diff
            %    a large chagne rate is actually not a problem - i.e.
            %    increase possible error as long as in right direction?
            
            
            if isempty(this.fActualMassToPressure)
                this.fActualMassToPressure = this.fMassToPressure;
            end
            
            % Just first time step
            if isempty(this.fVirtualPressure)
                this.fVirtualPressure        = this.fPressure;
                this.fVirtualMassToPressure  = this.fMassToPressure;
                %this.fActualMassToPressure    = this.fMassToPressure;
            else
                this.fMassToPressure = this.fVirtualMassToPressure;
            end
            
            
            
            if ~this.bSynced
                this.throw('update', 'Do not set bSynced to false!');
            end
            
            
            % Go through branches, get max. flow rate
            fMaxFlowRate = 0;
            
            for iS = 1:length(this.coProcsEXME)
                if isempty(this.coProcsEXME{iS}.oFlow), continue; end
                
                fFlowRate = abs(this.coProcsEXME{iS}.oFlow.oBranch.fFlowRate);
                
                if fFlowRate > fMaxFlowRate
                    fMaxFlowRate = fFlowRate;
                end
            end
            
            %%%fprintf('\n\nERR: %.13f vs %.13f [%.5f]\n\n', this.oTimer.fMinimumTimeStep, this.oTimer.fMinimumTimeStep * 1e4 * fMaxFlowRate, this.oTimer.fMinimumTimeStep / (this.oTimer.fMinimumTimeStep * 1e4 * fMaxFlowRate));
            %%%fprintf('\n\nERR: %.13f vs %.13f [%.5f]\n\n', this.oTimer.fMinimumTimeStep, fMaxFlowRate / 1000, this.oTimer.fMinimumTimeStep / (fMaxFlowRate / 1000));
            
            
            
            %TODO see iterative solver, use some interpolation to improve
            %     solving process, i.e. speed that up!
            rPressAdjust = 0.1;
            %fMaxInOut    = this.fMaxInOut / 10; % this.oTimer.fMinimumTimeStep
            
            fMaxInOut    = this.oTimer.fMinimumTimeStep;% * 100;
            fMaxInOut    = this.oTimer.fMinimumTimeStep * 1e4 * fMaxFlowRate;% * 100;
            %fMaxInOut    = max([ this.oTimer.fMinimumTimeStep * 100, fMaxFlowRate / 100 ]);% * 100;
            fMaxInOut    = fMaxFlowRate / 1000;
            fMaxInOut    = fMaxFlowRate * (this.rMaxChangeRate / 10);
            
            iSignChanges = 0;
            fCurrInOut   = sum(this.getTotalMassChange()); %this.fCurrentTotalMassInOut;
            iLoopCounter = 0;
            
            %%%fprintf('CURR %.12f vs. MAX %.12f - RATIO %.12f\n', fCurrInOut, fMaxInOut, abs(fCurrInOut / fMaxInOut - 1));
            
            %%%fprintf('CHECK - mass in outs - SHOULD BE EQUAL: %.20f vs. %.20f -> equal? %i\n\n', sum(this.getTotalMassChange()), this.fCurrentTotalMassInOut, sum(this.getTotalMassChange()) == this.fCurrentTotalMassInOut);
            
            
            
%             if abs(fCurrInOut) <= fMaxInOut
%                 return;
%             end
            
            
            %CHECK keep this? If diff becomes too large, shorter TS will be
            %      set ... sufficient?
%             if abs(fCurrInOut) <= fMaxInOut
%                 this.fPressure        = this.fVirtualMassToPressure * this.fMass;
%                 this.fVirtualPressure = this.fVirtualMassToPressure * this.fMass;
%                 
%                 fprintf('\n\n[%i] directly skipping iterations, new old virt pressure %.5f [Tot_Fr %.13f, MaxErr %.13f]\n', this.oTimer.iTick, this.fVirtualPressure, fCurrInOut, fMaxInOut);
%                 
%                 return;
%             end
%             
            
            fCurrTmpInOut = fCurrInOut;
            fCurrTmpM2P   = this.fVirtualMassToPressure;
            
            
            if fMaxFlowRate == 0
                this.fPressure        = this.fVirtualMassToPressure * this.fMass;
                this.fVirtualPressure = this.fVirtualMassToPressure * this.fMass;
                
                %%%fprintf('\n\n[%i] directly skipping iterations, Flow Rates ZERO!\n', this.oTimer.iTick);
                
                return;
            end
            
            
            
            % PRE-Calc for interpolation
            hT = tic();
            fFlowRateCurr = this.calcualteFlowRateForVirtMassToPressure(this.fVirtualMassToPressure);
            fT = toc(hT);
            
            afFlowRate    = fFlowRateCurr;
            afMassToPress = this.fMassToPressure;
            
            
            
            
            fCurrInOut = fFlowRateCurr;
            
            if abs(fCurrInOut) <= fMaxInOut
                this.fPressure        = this.fVirtualMassToPressure * this.fMass;
                this.fVirtualPressure = this.fVirtualMassToPressure * this.fMass;
                
                %%%fprintf('\n\n[%i] skipping iterations, new old virt pressure %.5f [Tot_Fr %.13f, MaxErr %.13f] (%.7f)\n', this.oTimer.iTick, this.fVirtualPressure, fCurrInOut, fMaxInOut, fT);
                
                return;
            end
            
            
            %%%fprintf('\n\n[%i] starting iteration, old virt pressure %.13f [Tot_Fr %.13f]\n', this.oTimer.iTick, this.fVirtualPressure, fCurrInOut);
            
            
            
            if fFlowRateCurr ~= 0
                %afMassToPress(end + 1) = this.fMassToPressure * sif(fFlowRateCurr > 0, 1.1, 1 / 1.1);
                
                % From old tick, the change in flow rate per change in
                % virtual pressure is calculated. This is used here to
                % estimate a new pressure (or mass to pressure, to be
                % exact) - assuming that this value only changes e.g. when
                % a fan is turned on/off or a valve is changed.
                if this.fLastFlowRateChangePerPressureChange ~= 0
                    afMassToPress(2) = fCurrTmpM2P + fCurrTmpInOut / this.fLastFlowRateChangePerPressureChange;
                else
                    afMassToPress(2) = this.fMassToPressure * sif(fFlowRateCurr > 0, 1.1, 1 / 1.1);
                end
                
                
                afFlowRate(2) = this.calcualteFlowRateForVirtMassToPressure(afMassToPress(end));
                
                fCurrInOut = afFlowRate(2);
            end
            
            
            
            %TODO check sign - if actual pressure < virtual pressure, only
            %     allow a POSITIVE fCurrInOut, and vice versa.
            
            
            
            %if abs(fCurrInOut) > fMaxInOut
                %%%fprintf('\n\n>>>>>>>> START LOOP AT %.10fs (Tick: %i) <<<<<<<<\nPressAdjust: %.10f, MaxInOut: %.10f\nCurrInOut: %.10f\nMassToPress: %.10f\n', this.oTimer.fTime, this.oTimer.iTick, rPressAdjust, fMaxInOut, fCurrInOut, this.fMassToPressure);
            %end
            
            
            
            while abs(fCurrInOut) > fMaxInOut
%                 if iSignChanges > 3
%                     iSignChanges = 0;
%                     rPressAdjust = rPressAdjust / 2;
%                     
%                     %%%fprintf('New rPressAdjust: %f\n', rPressAdjust);
%                 end
                
                
                %bReqPos = this.fActualPressure < this.fVirtualPressure;
                
                %bReqPos = this.fInitialMass > this.fMass;
                %fTarget = fMaxInOut * sif(bReqPos, 1, -1);
                %fCurrMassToPress = interp1(afFlowRate, afMassToPress, fTarget, 'linear', 'extrap');
                
                fCurrMassToPress = interp1(afFlowRate, afMassToPress, 0, 'linear', 'extrap');
                
                %fCurrMassToPress = (fCurrMassToPress + this.fMassToPressure * 3) / 4;
                %fCurrMassToPress = (fCurrMassToPress + afMassToPress(2) * 3) / 4;
                
                fCurrInOut = this.calcualteFlowRateForVirtMassToPressure(fCurrMassToPress);
                
                afMassToPress(end + 1) = fCurrMassToPress;
                afFlowRate(end + 1) = fCurrInOut;
                
%                 afMassToPress = [ afMassToPress(2) fCurrMassToPress ];
%                 afFlowRate    = [ afFlowRate(2)    fCurrInOut ];
                
                
%                 if fPrevInOut ~= fCurrInOut
%                     fMassToPressureTest = interp1([ fPrevInOut fCurrInOut ], [ fPrevMassToPressure this.fMassToPressure ], 0, 'linear', 'extrap');
%                     
%                     %%%fprintf('[%i] INTERP VS BS: %f vs. %f\n', iLoopCounter, fMassToPressureTest, this.fMassToPressure);
%                     
%                     
%                     %fMassToPressureTest = (fMassToPressureTest + this.fMassToPressure * 3) / 4;
%                     
%                     fPrevMassToPressure  = this.fMassToPressure;
%                     this.fMassToPressure = fMassToPressureTest;
%                 end
%                 
%                 
%                 fPrevInOut          = fCurrInOut;
%                 
%                 
%                 
%                 if fPrevInOut == fCurrInOut
%                     % Too much inflow? Increase pressure
%                     if fCurrInOut > 0
%                         this.fMassToPressure = this.fMassToPressure * (1 + rPressAdjust);
% 
%                         %%%fprintf('Increased fMassToPressure to: %f\n', this.fMassToPressure);
% 
%                     elseif fCurrInOut < 0
%                         this.fMassToPressure = this.fMassToPressure * (1 - rPressAdjust);
% 
%                         %%%fprintf('Decreased fMassToPressure to: %f\n', this.fMassToPressure);
% 
%                     end
%                 end
%                 
%                 
%                 
%                 
%                 
%                 % Now call solvers to recalc flow rates --> fMassToPressure
%                 % is used by the gas exmes, i.e. solvers use new pressure!
%                 afFlowRates = zeros(1, length(this.coProcsEXME));
%                 
%                 %LOOP
%                 for iS = 1:length(afFlowRates)
%                     if isempty(this.coProcsEXME{iS}.oFlow)
%                         afFlowRates(iS) = 0;
%                         continue;
%                     end
%                     
%                     
%                     oSolver = this.coProcsEXME{iS}.oFlow.oBranch.oHandler;
%                     
%                     afFlowRates(iS) = oSolver.solveFlowRate() * this.coProcsEXME{iS}.iSign;
%                     
%                     if oSolver.iDampFR > 0
%                         this.throw('update', 'Connected solvers must not have iDampFR set!');
%                     end
%                 end
                
                
%                 % New total flow rate
%                 fOldInOut  = fCurrInOut;
%                 fCurrInOut = sum(afFlowRates);
%                 
%                 %%%fprintf('\n%i - NEW FLOW RATES CALCULATED:\n old %f, new %f     [ %f %f %f ]\n', iLoopCounter, fOldInOut, fCurrInOut, afFlowRates(1), afFlowRates(2), afFlowRates(3));
%                 
%                 
%                 % Sign change?
%                 if fOldInOut * fCurrInOut < 0
%                     iSignChanges = iSignChanges + 1;
%                     
%                     %%%fprintf('SIGN CHANGE!!! YAY!\n');
%                 end
                
                
                % Increase max. allowed error
                iLoopCounter = iLoopCounter + 1;
                
                if mod(iLoopCounter, 10) == 0 % , 25
                    fMaxInOut = fMaxInOut * 2; % * 10
                    
                    %fprintf('INCREASED MAX ERROR to %f\n', fMaxInOut);
                end
                
            end
            
            
            this.fLastFlowRateChangePerPressureChange = mean(abs(diff(afFlowRate)) ./ abs(diff(afMassToPress)));
            this.fMassToPressure = afMassToPress(end);%(this.fMassToPressure * 3 + afMassToPress(end)) / 4;
            
            
            bReqPos = this.fInitialMass > this.fMass;
            bIsPos  = fCurrInOut > 0;
            
            %disp(num2str(this.oTimer.iTick));
            
            if bReqPos ~= bIsPos
                fMassToPressDiff = 1.1 * abs(fCurrInOut / this.fLastFlowRateChangePerPressureChange);
                iSign            = sif(bIsPos, 1, -1);
                
                %fOldMassToPressure   = this.fMassToPressure;
                this.fMassToPressure = this.fMassToPressure + iSign * fMassToPressDiff;
                
                %fprintf('\n\nADJUSTED FR because of wrong sign!! ReqPos: %i    FR_tot: %.13f    OldM2P: %.5f    NewM2P: %.5f\n', bReqPos, fCurrInOut, fOldMassToPressure, this.fMassToPressure);
                
                %fFlowRateTot = this.calcualteFlowRateForVirtMassToPressure(this.fMassToPressure);
                %fprintf('CHECK NEW FR: %.13f\n\n', fFlowRateTot);
            else
                %disp('NO')
                
                
                %fMassToPressDiff = 0.9 * abs(fCurrInOut / this.fLastFlowRateChangePerPressureChange);
                %iSign            = sif(bIsPos, -1, 1);
                
                
%                 fMassToPressDiff = 0.9 * abs(fCurrInOut / this.fLastFlowRateChangePerPressureChange);
%                 iSign            = sif(bIsPos, 1, -1);
                
                %fOldMassToPressure   = this.fMassToPressure;
                %this.fMassToPressure = this.fMassToPressure + iSign * fMassToPressDiff;
                
            end
            
            
            
            %if iLoopCounter > 0
                
            %end
            
            
            
            % Set virtual properties
            this.fVirtualMassToPressure  = this.fMassToPressure;
            
            this.fPressure        = this.fVirtualMassToPressure * this.fMass;
            this.fVirtualPressure = this.fVirtualMassToPressure * this.fMass;
            
            %%%fprintf('[%i] %i iterations, final max error %.12f, new virt pressure %.13f [Tot_Fr %.13f]\n', this.oTimer.iTick, iLoopCounter, fMaxInOut, this.fVirtualPressure, fCurrInOut);
            
            
            %fCurrTmpInOut = fCurrInOut;
            %fCurrTmpM2P   = this.fVirtualMassToPressure;
            
            %fNewTmpM2P = fCurrTmpM2P + fCurrTmpInOut / this.fLastFlowRateChangePerPressureChange;
            %fprintf('TEST: %.7f vs. %.7f [%.7f]\n', this.fVirtualMassToPressure, fNewTmpM2P, this.fVirtualMassToPressure / fNewTmpM2P);
            
            this.fMaxInOut = fMaxInOut;
            
            
            
            return;
            
            if isempty(this.fPreviousStepVirtualPressure)
                % For next step interpolation
                this.fPreviousStepVirtualPressure = this.fPressure;
                this.fPreviousStepTotalFlowRate   = sum(this.getTotalMassChange());
                
                return;
            end
            
            
            if isempty(this.fVirtualPressure)
                % Initialize
                this.fVirtualMassToPressure = this.fMassToPressure;
                this.fVirtualPressure       = this.fPressure;
                this.fActualMassToPressure  = this.fMassToPressure;
                this.fActualPressure        = this.fPressure;
                
                
                return;
            end
            
            % Nothing to inteprolate, total flow rate between last and this
            % step is equal.
            if this.fPreviousStepTotalFlowRate == this.fCurrentTotalMassInOut || fCurrentTotalFlowRate == 0
                return;
            end
            
            
            % Preseve actual, real properties
            this.fActualMassToPressure  = this.fMassToPressure;
            this.fActualPressure        = this.fPressure;
            
            
            % INTERP new fVirtualPressure with 
            
            %afTotalFlowRates   = [ this.fPreviousStepTotalFlowRate   this.fCurrentTotalMassInOut ];
            %%afTotalFlowRates   = [ fCurrentTotalFlowRate this.fCurrentTotalMassInOut ];
            %afTotalFlowRates   = [ this.fPreviousStepTotalFlowRate   fCurrentTotalFlowRate ];
            afTotalFlowRates   = [ fCurrentTotalFlowRate sum(this.getTotalMassChange()) ];
            
            
            afVirtualPressures = [ this.fPreviousStepVirtualPressure this.fVirtualPressure ];
            %afVirtualPressures = [ this.fVirtualPressure this.fPreviousStepVirtualPressure ];
            % this.fCurrentTotalMassInOut
            
            if afVirtualPressures(1) == afVirtualPressures(2)
                disp('XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX');
                fNewVirtualPressure = this.fVirtualPressure * afTotalFlowRates(2) / afTotalFlowRates(1);
                
            else
                fNewVirtualPressure = interp1(afTotalFlowRates, afVirtualPressures, 0, 'linear', 'extrap');
            end
            
            % Use virtual props to interp
            % set virtual properties
            
            fprintf('[ %.15f  %.15f ]\n[ %.15f  %.15f ]\n\n', afTotalFlowRates(1), afTotalFlowRates(2), afVirtualPressures(1), afVirtualPressures(2));
            fprintf('OLD VIRT PRESS: %f, NEW VIRT PRESS %f\n', this.fVirtualPressure, fNewVirtualPressure);
            
            
            % Store old properties for interpolation
            this.fPreviousStepTotalFlowRate   = fCurrentTotalFlowRate;
            this.fPreviousStepVirtualPressure = this.fVirtualPressure;
            
            
            fNewVirtualPressure = (this.fVirtualPressure * 10 + fNewVirtualPressure) / 11;
            
            % Set virtual properties
            this.fPressure        = fNewVirtualPressure;
            this.fVirtualPressure = fNewVirtualPressure;
            
            this.fMassToPressure         = fNewVirtualPressure / this.fMass;
            this.fVirtualMassToPressure  = fNewVirtualPressure / this.fMass;
        end
    end
    
    
    methods (Access = protected)
        function fTotalFlowRate = calcualteFlowRateForVirtMassToPressure(this, fVirtualMassToPressure)
            fOldMassToPressure   = this.fMassToPressure;
            this.fMassToPressure = fVirtualMassToPressure;
            
            
            
            % Now call solvers to recalc flow rates --> fMassToPressure
            % is used by the gas exmes, i.e. solvers use new pressure!
            afFlowRates = zeros(1, length(this.coProcsEXME));

            %LOOP
            for iS = 1:length(afFlowRates)
                if isempty(this.coProcsEXME{iS}.oFlow)
                    afFlowRates(iS) = 0;
                    continue;
                end


                oSolver = this.coProcsEXME{iS}.oFlow.oBranch.oHandler;

                afFlowRates(iS) = oSolver.solveFlowRate() * this.coProcsEXME{iS}.iSign;

                if oSolver.iDampFR > 0
                    this.throw('update', 'Connected solvers must not have iDampFR set!');
                end
            end


            % New total flow rate
            fTotalFlowRate = sum(afFlowRates);
            
            
            
            this.fMassToPressure = fOldMassToPressure;
        end
        
        
        function calculateTimeStep(this)
            % Overload time step calulcation
            
            % EXP curve
            % Interp - minTS = timer min ts
            % Interp - maxTS = from phase
            % For MaxTS if Sum lt precision (1e-8)
            % MinTS if sum >= maxChangeRate
            
            % Don't really need ZERO ... min time step ok? Doesn't work out
            % with units, but need some lower bound ...?
            %fTotalInOut = this.fCurrentTotalMassInOut - this.oTimer.fMinimumTimeStep;
            fTotFlowRate= sum(this.getTotalMassChange());
            fTotalInOut = max([ 0, abs(fTotFlowRate) - this.oTimer.fMinimumTimeStep ]);
            fMass       = this.fVirtualPressure / this.fActualMassToPressure;
            %fMass       = this.fVirtualPressure / this.fVirtualMassToPressure;
            rTotalInOut = abs(fTotalInOut / fMass);
            %TODO better set maxTotalFr instead of ratio?
            
            
%             % TOTAL IN OUT vs. Max. FR!
            fMaxFlowRate = 0;
            
            for iS = 1:length(this.coProcsEXME)
                if isempty(this.coProcsEXME{iS}.oFlow), continue; end
                
                fFlowRate = abs(this.coProcsEXME{iS}.oFlow.oBranch.fFlowRate);
                
                if fFlowRate > fMaxFlowRate
                    fMaxFlowRate = fFlowRate;
                end
            end
            
            rTotalInOut = abs(fTotalInOut / fFlowRate);
            
            
            
            
            
            if fFlowRate == 0 || fTotalInOut == 0
                fInt = 1;
                
            elseif rTotalInOut > this.rMaxChangeRate
                fInt = 0;
            else
                fInt = interp1([ this.oTimer.fMinimumTimeStep this.rMaxChangeRate ], [ 1 0 ], rTotalInOut, 'linear', 'extrap');
            end
            
            
            iI = 5;
            fNewStep = fInt.^iI * this.fMaxStep + this.oTimer.fMinimumTimeStep;
            
            
            % Last Update? Subtract from new time step!
            fTimeSinceLastUpdate = this.oTimer.fTime - this.fLastMassUpdate;
            fNewStep             = max([ 0, fNewStep - fTimeSinceLastUpdate ]);
            
            
            if fTotFlowRate < 0 && (this.fMass / 2) < abs(fTotalInOut) * fNewStep
                fNewStep = (this.fMass / 2) / abs(fTotalInOut);
            end
            
            
            %%%fprintf('[%i][%.13f] OLD TS: %f, NEW TS %f     TOT FR: %.13f    CHANGE %f\n', this.oTimer.iTick, this.oTimer.fTime, this.fTimeStep, fNewStep, sum(this.getTotalMassChange()), rTotalInOut);
            
            
            % To reset e.g. bOutdatedTS
            %calculateTimeStep@matter.phases.gas(this);
            this.oStore.setNextUpdateTime(this.fLastMassUpdate + fNewStep);
            
            %TODO iun matter.phases, was set to access protrected so it can
            %be overwritten here. Don't do that, right? Better e.g.
            %this.calcTS(fNewSteP) -> does set that new step instead of
            %calculating an own one!
            this.bOutdatedTS = false;
            this.fTimeStep   = fNewStep;
            
            
            
            % Now up to date!
            %this.bOutdatedTS = false;
            
            
            %TODO
            % MAKE SURE - if virt. pressure > actual pressure, we require a
            %     POSITIVE total flow rate, and vice versa.
            % This means if wrong sign of total flow rate --> immediately
            % set to minTS?
            % In .update(), try to interpolate to iSign * 1e-8, not 0?
        end
    end
end

