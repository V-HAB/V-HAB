classdef branch < solver.matter.base.branch
     %BRANCH Linear hydraulic solver branch for matter flows
     %  TODO Insert nice description here   

    %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %-- Properties -------------------------------------------------------%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    properties (SetAccess = public, GetAccess = public)
        rMaxChange = 0.030;
        rSetChange = 0.015;
        iRemChange = 0;
        fMaxStep   = 15;
        
        iDampFR    = 0;
        
        % A helper array that saves the last iDampFR flow rates for
        % averaging. 
        afFlowRatesForDampening;
        
        % Fixed time step - set to empty ([]) to deactivate
        fFixedTS = [];
        
        % Coefficient for FR calculation
        fCoeffFR = 0.00000133;
    end
    
    properties (SetAccess = protected, GetAccess = public)
        rFlowRateChange  = 0;
        iSignChangeFRCnt = 0;
        
        fTimeStep = 0;
        
        
        oTimer;
    end
    
    %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %-- Methods ----------------------------------------------------------%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    methods
        %% Constructor
        function this = branch(oBranch, rMaxChange, iRemChange)
            this@solver.matter.base.branch(oBranch, [], 'hydraulic');
            
            this.fCoeffFR = 0.00000133 * 20;
            
            if nargin >= 2 && ~isempty(rMaxChange), this.rMaxChange = rMaxChange; end
            if nargin >= 3 && ~isempty(iRemChange), this.iRemChange = iRemChange; end
            
            this.hBindPostTickUpdate      = this.oBranch.oTimer.registerPostTick(@this.update, 'matter' , 'solver');
            
        end
    end
    
    methods (Access = protected)
        %% Branch update method
        function update(this)
            if this.oTimer.fTime < this.fLastUpdate
                return;
            end
            
            if this.oBranch.oTimer.fTime == 0
                this.afFlowRatesForDampening = zeros(1, this.iDampFR);
            end
            
            % Checking if there are any active processors in the branch,
            % if yes, update them.
            abActiveProcs = [ this.aoSolverProps.bActive ];
            for iI = 1:length(abActiveProcs)
                if abActiveProcs(iI)
                    % There are two kinds of processors: Ones that create a
                    % pressure rise and ones that just change their
                    % hydraulic parameters. The latter just needs to be
                    % updated, but the former needs to write a new value
                    % for fDeltaPressure to the solver type object. This is
                    % only done, if the updateDeltaPressure() method is
                    % called with one or more return values. This is the
                    % reason for the following if-condition. 
                    if this.aoSolverProps(iI).fHydrDiam < 0
                        [~] = this.aoSolverProps(iI).updateDeltaPressure();
                    else
                        this.aoSolverProps(iI).updateDeltaPressure();
                    end
                end
            end
            
            % Getting all hydraulic diameters and lengths
            afHydrDiam   = [ this.aoSolverProps.fHydrDiam   ];
            afHydrLength = [ this.aoSolverProps.fHydrLength ];
            
            % Find all components with negative hydraulic diameters
            afNegHydrDiam = find(afHydrDiam < 0);
            if ~isempty(afNegHydrDiam)
                % If there are any components that produce a pressure rise
                % sum them up and create new arrays with just the
                % components producing pressure drops
                fPressureRises = sum(this.aoSolverProps(afNegHydrDiam).fDeltaPressure);
                afPosHydrDiam  = afHydrDiam(afHydrDiam>0);
                afHydrLength   = afHydrLength(afHydrDiam>0);
            else
                fPressureRises = 0;
                afPosHydrDiam  = afHydrDiam;
            end
            
            if any(afHydrLength == 0)
                afPosHydrDiam(afHydrLength == 0) = [];
                afHydrLength(afHydrLength == 0)  = [];
            end
           
            %TODO real calcs, also derive pressures/temperatures
            %     check active components - get pressure rise / hydr.
            %     diameter depending on flow rate
            %     -> in constructor, find comps that have some bActive attr
            %        set to true. For these comps, call some updHydrDiam.
            %        The comps use the LAST pressures / flow rate to calc.
            %        a hydraulic diameter and update fHydrDiam.
            fCoeff = sum(afPosHydrDiam * this.fCoeffFR ./ afHydrLength);
            
            fPressureLeft  = this.oBranch.coExmes{1}.getPortProperties();
            fPressureRight = this.oBranch.coExmes{2}.getPortProperties();
            
            fFlowRate = fCoeff * (fPressureLeft - fPressureRight + fPressureRises);
            %TODO see above
            
            % Damp flow rate?
            %TODO only if it gets bigger or smaller? Time-specific? Right
            %     now tick length not taken into account ...
            %fFlowRate = (fFlowRate + this.iDampFR * this.fFlowRate) / (1 + this.iDampFR);

            if this.iDampFR ~= 0
                % Damp the flow rate, if iDampFR is non-zero.
                fFlowRate = (sum(this.afFlowRatesForDampening) + fFlowRate) / (this.iDampFR + 1);
                this.afFlowRatesForDampening = [ this.afFlowRatesForDampening(2:end) fFlowRate ];
                bRecalculateFlowProperties = true;
            else
                bRecalculateFlowProperties = false;
            end
            
            % If we actually damped the flow rate, we need to run the
            % solver specific method on all processors again, since some of
            % them might need to update some internal values, such as the
            % heat flow. 
            %TODO To avoid this, maybe the heat flow should be specific
            %rather than absolute? 
            if this.iDampFR ~= 0 && bRecalculateFlowProperties
                for iI = 1:length(abActiveProcs)
                    if abActiveProcs(iI)
                        % There are two kinds of processors: Ones that create a
                        % pressure rise and ones that just change their
                        % hydraulic parameters. The latter just needs to be
                        % updated, but the former needs to write a new value
                        % for fDeltaPressure to the solver type object. This is
                        % only done, if the updateDeltaPressure() method is
                        % called with one or more return values. This is the
                        % reason for the following if-condition.
                        if this.aoSolverProps(iI).fHydrDiam < 0
                            [~] = this.aoSolverProps(iI).updateDeltaPressure();
                        else
                            this.aoSolverProps(iI).updateDeltaPressure();
                        end
                    end
                end
            end
            
            if ~isempty(this.fFixedTS)
                if this.fTimeStep ~= this.fFixedTS
                    this.setTimeStep(this.fFixedTS);
                    this.fTimeStep = this.fFixedTS;
                end
                
            else


                % Change in flow rate
                %TODO use this.fLastUpdate and this.oBranch.oCont.oTimer.fTime
                %     and set the rChange in relation to elapsed time!
                rChange = abs(fFlowRate / this.fFlowRate - 1);
                
                % In the first execution, fFlowRate and this.fFlowRate can
                % both be zero. This causes rChange to be NaN, in turn
                % causing the new time step to be NaN. If that happens, the
                % branch will never be updated again. So we set rChange to
                % zero if this happens. 
                rChange = sif(isnan(rChange), 0, rChange);

%                 % Old time step
%                 fOldStep = this.fTimeStep;
% 
%                 if fOldStep < this.oTimer.fMinimumTimeStep
%                     fOldStep = this.oTimer.fMinimumTimeStep;
%                 end

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
                    this.rFlowRateChange = (rChange + this.iRemChange * this.rFlowRateChange) / (1 + this.iRemChange);

                    % Change larger than limit? Minimum time step.
                    if this.rFlowRateChange > this.rMaxChange, fNewStep = 0;
                    else
                        % Interpolate
                        %fNewStep = interp1([ 0 this.rSetChange this.rMaxChange ], [ 2 * fOldStep fOldStep 0 ], this.rFlowRateChange, 'linear', 'extrap');
                        
                        %fInt = interp1([ 0 this.rMaxChange ], [ 1 0 ], this.rFlowRateChange, 'linear', 'extrap');
                        fInt = 1 - this.rFlowRateChange / this.rMaxChange;
                        iI = 3; %this.fSensitivity;
                        fNewStep = fInt.^iI * this.fMaxStep + this.oTimer.fMinimumTimeStep;
                    end
                end

                if fNewStep > this.fMaxStep, fNewStep = this.fMaxStep; end

                this.setTimeStep(fNewStep, true);
                this.fTimeStep = fNewStep;
            end
            
            
            % Sets new flow rate
            %TODO set pressures according to relative weight of hydr.
            %     diameter or length including active stuff -> e.g. in a
            %     fan loop from Atmos back to Atmos, all flows get the same
            %     pressure ...
            update@solver.matter.base.branch(this, fFlowRate, []);
        end
    end
end