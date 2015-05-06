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
        
        % Fixed time step - set to empty ([]) to deactivate
        fFixedTS = [];
        
        % Coefficient for FR calculation
        fCoeffFR = 0.00000133;
    end
    
    properties (SetAccess = protected, GetAccess = public)
        rFlowRateChange  = 0;
        iSignChangeFRCnt = 0;
        
        fTimeStep = 0;
        
    end
    
    %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %-- Methods ----------------------------------------------------------%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    methods
        %% Constructor
        function this = branch(oBranch, rMaxChange, iRemChange)
            this@solver.matter.base.branch(oBranch, [], 'hydraulic');
            
            if nargin >= 2 && ~isempty(rMaxChange), this.rMaxChange = rMaxChange; end;
            if nargin >= 3 && ~isempty(iRemChange), this.iRemChange = iRemChange; end;
            
        end
    end
    
    methods (Access = protected)
        %% Branch update method
        function update(this)
            if this.oBranch.oContainer.oTimer.fTime < this.fLastUpdate
                return;
            end
            
            % Checking if there are any active processors in the branch,
            % if yes, update them.
            abActiveProcs = [ this.aoSolverProps.bActive ];
            for iI = 1:length(abActiveProcs)
                if abActiveProcs(iI)
                    this.aoSolverProps(iI).updateDeltaPressure();
                end
            end
            
            % Getting the temperature differences for each processor in the
            % branch
            %TODO-REARRSOLV get fHeatFlows, use FR/c_p to calc delta Temps!
%             afTemps = [ this.aoSolverProps.fDeltaTemperature ];
%             
%             % Check if all the temperature deltas are assigned
%             if ~(length(afTemps) == this.oBranch.iFlowProcs)
%                 this.throw('solver', 'Solver error, make sure all of your flow 2 flow procs have their delta temperatures assigned!');
%             end
           
            
            % Getting all hydraulic diameters and lengths
            afHydrDiam   = [ this.aoSolverProps.fHydrDiam ];
            afHydrLength = [ this.aoSolverProps.fHydrLength ];
            
            % Find all components with negative hydraulic diameters
            afNegHydrDiam = find(afHydrDiam < 0);
            if ~isempty(afNegHydrDiam)
                % If there are any components that produce a pressure rise
                % sum them up and create new arrays with just the
                % components producing pressure drops
                fPressureRises = sum(this.aoSolverProps(afNegHydrDiam).fDeltaPressure);
                afPosHydrDiam = afHydrDiam(afHydrDiam>0);
                afHydrLength  = afHydrLength(afHydrDiam>0);
            else
                fPressureRises = 0;
                afPosHydrDiam = afHydrDiam;
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
            fFlowRate = (fFlowRate + this.iDampFR * this.fFlowRate) / (1 + this.iDampFR);

            
            
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
                    this.rFlowRateChange = (rChange + this.iRemChange * this.rFlowRateChange) / (1 + this.iRemChange);

                    % Change larger than limit? Minimum time step.
                    if this.rFlowRateChange > this.rMaxChange, fNewStep = 0;
                    else
                        % Interpolate
                        fNewStep = interp1([ 0 this.rSetChange this.rMaxChange ], [ 2 * fOldStep fOldStep 0 ], this.rFlowRateChange, 'linear', 'extrap');
                    end
                end

                if fNewStep > this.fMaxStep, fNewStep = this.fMaxStep; end;

                this.setTimeStep(fNewStep);
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