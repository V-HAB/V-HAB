classdef branch < solver.matter.base.branch
    %BRANCH based on the nested interval principle for matter flows. It is
    % therefore similar to the iterative solver in the final solution
    % (pressure drops are equal to pressure difference from phases and
    % pressure rises from components) but uses a completly different
    % solution method

    properties (SetAccess = protected, GetAccess = public)
        % Actual time between flow rate calculations
        fTimeStep = 0;
        
        fMaxError       = 1e-8; % Maximum allowed error in the solution in Pa
        iMaxIterations  = 500;  % Maximum allowed iterations
    end
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
            
            % Sets the flow rate to 0 which sets matter properties
            this.update();
            
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
            
            if this.oBranch.oTimer.fTime <= this.fLastUpdate
                % If branch update has been called before during this time
                % step, do nothing. 
                return;
            end
            
            % Actually compute the new flow rate and the associated delta
            % pressures as well as delta temperatures.
            [ fFlowRate, afDeltaP ] = this.solveFlowRate();
            
            this.calculateTimeStep(fFlowRate, afDeltaP);
            
            % See base branch, same check here - if input phase nearly
            % empty, just set flow rate to zero
            oIn = this.oBranch.coExmes{sif(fFlowRate >= 0, 1, 2)}.oPhase;
            
            if tools.round.prec(oIn.fMass, oIn.oStore.oTimer.iPrecision) == 0
                fFlowRate = 0;
            end
            
            
            update@solver.matter.base.branch(this, fFlowRate, afDeltaP);
            
        end
    end
    
    
    methods (Access = public)
        
        function setSolverProperties(this, tSolverProperties)
            % currently the possible time step properties that can be set
            % by the user are:
            %
            % fMaxError:    Maximum Error of the solution in Pa, also
            %               decides when the solver should be recalculated
            %               in case the boundary conditions have changed
            % iMaxIterations: Sets the maximum value for iterations, if it
            %                 is exceed the solver throws an error
            %
            % In order to define these provide a struct with the fieldnames
            % as described here to this function for the values that you
            % want to set
            
            csPossibleFieldNames = {'fMaxError', 'iMaxIterations'};
            
            % Gets the fieldnames of the struct to easier loop through them
            csFieldNames = fieldnames(tSolverProperties);
            
            for iProp = 1:length(csFieldNames)
                sField = csFieldNames{iProp};

                % If the current properties is any of the defined possible
                % properties the function will overwrite the value,
                % otherwise it will throw an error
                if ~any(strcmp(sField, csPossibleFieldNames))
                    error(['The function setSolverProperties was provided the unknown input parameter: ', sField, ' please view the help of the function for possible input parameters']);
                end
                

                % checks the type of the input to ensure that the
                % correct type is used.
                xProperty = tSolverProperties.(sField);

                if ~isfloat(xProperty)
                    error(['The ', sField,' value provided to the setSolverProperties function is not defined correctly as it is not a (scalar, or vector of) float']);
                end
                
                this.(sField) = tSolverProperties.(sField);
            end
        end
        
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
            
            %%% Old flow rate, pressure differences etc
            fPreviousFlowRate = oBranch.fFlowRate;
            
            % Connected exmes
            oExmeL = oBranch.coExmes{1};
            oExmeR = oBranch.coExmes{2};
            
            % Calculating the pressure differences between the connected
            % phases
            [ fPressureLeft,  ~ ] = oExmeL.getPortProperties();
            [ fPressureRight, ~ ] = oExmeR.getPortProperties();
            
            fPressureDifference = fPressureLeft - fPressureRight;
            
            if fPreviousFlowRate == 0
                % previous flowrate was 0, check if another solution should
                % apply
                fFlowRate = 1e-8;
                if fPressureDifference >= 0
                    iDir = 1;
                elseif fPressureDifference < 0
                    iDir = -1;
                end
            else
                iDir = sign(fPreviousFlowRate);
                fFlowRate = abs(fPreviousFlowRate);
            end
            
            [fError, fPressureRise, ~, mfData] = this.calculatePressureDrops(iDir, fFlowRate, fPressureDifference);
            
            if abs(fError) < this.fMaxError
                % if the error is already smaller we have the solution
                fFlowRate   = iDir * fFlowRate;
                afDeltaP    = mfData(:, 1);
                return
            elseif any(isinf(mfData(mfData>0)))
                % an infinite pressure drop occurs e.g. if a valve closes
                % to ensure that nothing flows through. Therefore, do not
                % iterate but simply set flowrate to 0
                fFlowRate   = 0;
                mfData(isinf(mfData)) = 0;
                afDeltaP    = mfData(:, 1);
                return
            else
                % Initial guesses for the other side of the intervall
                fSecondError = fError;
                fSecondFlowRate = fFlowRate;
                iCounter = 0;
                while sign(fError) == sign(fSecondError) && iCounter < this.iMaxIterations
                    % we have to find another flowrate for which the error has
                    % the opposite sign, the correct solution is in between
                    % these two options
                    if fError < 0
                        % if the error is already smaller than 0, the pressure
                        % drops are already larger than they should be and the
                        % other side of the solution intervall is 0
                        fSecondFlowRate = 0;

                        [fSecondError, ~, ~, ~] = this.calculatePressureDrops(iDir, fSecondFlowRate, fPressureDifference);
                        
                    elseif sign(fPressureDifference + fPressureRise) ~= sign(iDir)
                        % in this case the possible solution is at the
                        % opposite flow direction than the initial guess
                        iDir = -1 * iDir;
                        
                        % this is the only case where the initial interval
                        % limitiation is changed!
                        [fError, fPressureRise, ~, ~] = this.calculatePressureDrops(iDir, fFlowRate, fPressureDifference);
                        fSecondError = fError;
                    else
                        % if the difference is larger than 0, the pressure rise
                        % is larger than the pressure drops and an absolute
                        % higher flowrate is necessary
                        
                        fSecondFlowRate = fSecondFlowRate * 10;
                        
                        [fSecondError, ~, ~, ~] = this.calculatePressureDrops(iDir, fSecondFlowRate, fPressureDifference);
                        
                    end
                    
                    iCounter = iCounter + 1;
                end
                
                if iCounter == this.iMaxIterations
                   this.throw('solveBranch', 'Too many iterations during interval definition');
                end
            end
            
            iCounter = 0;
            if fFlowRate < fSecondFlowRate
                fLowerBoundary = fFlowRate;
                fUpperBoundary = fSecondFlowRate;
            else
                fLowerBoundary = fSecondFlowRate;
                fUpperBoundary = fFlowRate;
            end
            
            fNewError = fError;
            fIntervallSize = fUpperBoundary - fLowerBoundary;
            
            while (abs(fNewError) > this.fMaxError) && fIntervallSize > this.fMaxError  && iCounter < this.iMaxIterations
                
                % we split the initial intervall down in the middle
                fIntervallSize = fUpperBoundary - fLowerBoundary;
                
                fNewFlowRate = fLowerBoundary + fIntervallSize/2;
                
                [fNewError, ~, ~, mfData] = this.calculatePressureDrops(iDir, fNewFlowRate, fPressureDifference);
                
                % if the error is negative, the pressure rise is higher
                % than the drop, the drop increases with flowrate therefore
                % the lower boundary is changed. In the other case the
                % drops are higher than the pressure rises and therefore
                % the upper boundary is moved
                if fNewError > 0
                    fLowerBoundary = fNewFlowRate;
                elseif fNewError < 0
                    fUpperBoundary = fNewFlowRate;
                else
                    % Error is 0, iteration concludes
                end
                
                % Loop counter
                iCounter = iCounter + 1;
            end
           
            if iCounter == this.iMaxIterations
               this.throw('solveBranch', 'Too many iterations during nested interval solution');
            end
            
            fFlowRate   = iDir * (fUpperBoundary + fLowerBoundary)/2;
            afDeltaP    = mfData(:, 1);
        end
    end
    methods (Access = protected)
        function [fError, fPressureRise, fPressureDrop, mfData] = calculatePressureDrops(this, iDir, fFlowRate, fPressureDifference)
            % This function is used internally to calculate the error and
            % recalculate the pressure drops/rises in the f2fs
            
            % Data matrix - rows equals amount of flow procs minus two (the
            % EXMEs), columns are the pressure drops and temperature
            % changes returned by the components (f2f processors)
            mfData = zeros(this.oBranch.iFlowProcs, 1);
            
            % calculate the pressure drops for the initial assumption
            for iP = 1:this.oBranch.iFlowProcs
                mfData(iP, 1) = this.aoSolverProps(iP).calculateDeltas(iDir * fFlowRate);
            end
            
            % Calculate the pressure rise, drop and the solution error.
            % Note that pressure rise and pressure difference are defined
            % so that positive values result in a positive flow direction.
            % If the sum of both values changes sign the flow direction
            % must be changed!
            if iDir > 0
                fPressureRise   = -sum(mfData(mfData < 0));
            else
                fPressureRise   =  sum(mfData(mfData < 0));
            end
            fPressureDrop   =  sum(mfData(mfData > 0));
            fError          =  abs(fPressureDifference + fPressureRise) - abs(fPressureDrop);
        end
        
        function [fTimeStep] = calculateTimeStep(this, fFlowRate, afDeltaP)
            
            oLeft   = this.oBranch.coExmes{1}.oPhase;
            oRight  = this.oBranch.coExmes{2}.oPhase;
            
            fNewMassChangeLeft = oLeft.fCurrentTotalMassInOut + this.fFlowRate - fFlowRate;
            fNewMassChangeRight = oRight.fCurrentTotalMassInOut - this.fFlowRate + fFlowRate;
            
            
            [ fPressureLeft,  ~ ] = this.oBranch.coExmes{1}.getPortProperties();
            [ fPressureRight, ~ ] = this.oBranch.coExmes{2}.getPortProperties();
            
            fPressureDifference = fPressureLeft - fPressureRight;
            
            fTargetPressureDifference = fPressureDifference + (sign(fFlowRate) * sum(afDeltaP(afDeltaP < 0)));
            
            try
                fMassToPressure = max(oLeft.fMassToPressure, oRight.fMassToPressure);
                fTimeStepLeft = abs(fTargetPressureDifference/(fMassToPressure * fNewMassChangeLeft));
                fTimeStepRight = abs(fTargetPressureDifference/(fMassToPressure * fNewMassChangeRight));
            catch
                if isa(oLeft, 'matter.phase.gas')
                    fTimeStepLeft = abs(fTargetPressureDifference/(oLeft.fMassToPressure * fNewMassChangeLeft));
                    fTimeStepRight = 20;
                    
                elseif isa(oRight, 'matter.phase.gas')
                    fTimeStepRight = abs(fTargetPressureDifference/(oRight.fMassToPressure * fNewMassChangeRight));
                    fTimeStepLeft  = 20;
                else
                    % we do yet have a good calculation for liquid/solid
                    % pressures
                    fTimeStepRight = 20;
                    fTimeStepLeft  = 20;
                end
            end
            
            fTimeStep = min(fTimeStepLeft, fTimeStepRight);
            
            % to assure stability we do not use the maximum possible time
            % step
            fTimeStep = 0.75 * fTimeStep;
            
            this.setTimeStep(fTimeStep);
        end
    end
end
