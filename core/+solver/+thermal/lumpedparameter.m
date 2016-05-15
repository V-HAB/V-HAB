classdef lumpedparameter < base
    %LUMPEDPARAMETER Lumped parameter solver for thermal analysis.
    %   Solves a thermal network described within a |thermal.container|.
    %
    %TODO:
    %    - check naming convetion: "capacity" -> |Capacity| wrapper object,
    %      "heat capacity" -> (scalar) value of capacity
    
    properties
        
        tOdeOptions;    % Result of |odeset| (struct).
        calcChangeRate; % Handle to the rate of change function for the ODE solver.
        
        %bCalcConductorHeatTransfer = false; % Calculate heat transfer of each conductor.
        
    end
    
    properties (SetAccess = protected)
        
        oVSys; % The |vsys| instance associated with the solver.
        
        setTimestep;     % Handle to the |setTimeStep| method of the timer. 
        unbindFromTimer; % Handle to the |unbind| method of the timer.
        
        mPreviousSolverTimes = [];
        mPreviousSolverTemps = [];
        
    end
    
    properties (Access = protected)
        
        fPreviousTimestep = -1; % The time at the previous call to |update|.
        
        % Rate matrices for matrix based solution of a transient heat
        % transfer problem.
        mSourceRateVector    = []; % The source rate vector in |K/s|.
        mLinearRateMatrix    = []; % The linear rate matrix in |1/s|.
        mFluidFlowRateMatrix = []; % The fluid flow rate matrix in |1/s|.
        mRadiationRateMatrix = []; % The radiation rate matrix in |1/(s*K^3)|.
        
        mNodeCapacities = []; % The capacities of all nodes in |J/K|.
        
        % If there is an interface to TherMoS in this simulation, we need
        % to do some extra calculations to add the external energy flows to
        % our simulated system.
        bTherMoSInterface;
        
    end
    
    methods
        
        function this = lumpedparameter(oVSys, fTimestep, bTherMoSInterface)
            % Initialize the lumped parameter solver.
            
            % Set the default options for the ODE solver. 
            this.tOdeOptions = odeset('RelTol', 1e-3, 'AbsTol', 1e-4);
            
            % Store the associated |vsys| instance.
            this.oVSys = oVSys;
            
            % Set default timestep of |1 s|.
            if nargin < 2
                fTimestep = 1;
            end
            
            if nargin < 3 || isempty(bTherMoSInterface)
                this.bTherMoSInterface = false; 
            else
                this.bTherMoSInterface = bTherMoSInterface;
            end
            
            % Register with timer: Call |this.update| each |fTimestep|.
            [this.setTimestep, this.unbindFromTimer] = this.oVSys.oTimer.bind(@(oTimer) this.update(oTimer), fTimestep, struct(...
                'sMethod', 'update', ...
                'sDescription', 'The .update method of the thermal lumped parameter solver', ...
                'oSrcObj', this ...
            ));
            
            % Define rate of change function for ODE solver.
            this.calcChangeRate = @(t, m) this.calcTemperatureChangeRate(m, t);
            
            % Make sure rate matrices are generated in the first call to
            % |update()|.
            this.oVSys.taint();
            
        end
        
        function update(this, oTimer)
            % Solve the thermal network: Calculate the new temperatures
            % after a time step and pass the change in inner heat energy on
            % to the thermal container. 
            
            % Regenerate change rate matrices if container is tainted.
            if this.oVSys.bIsTainted
                this.reloadRateMatrices();
            end
            
            % (Re-)Load the temperatures of the nodes at this point because
            % the matter calculation for the energy transfer may yield
            % different results for the "new" temperatures (which may be
            % expected e.g. when other solvers change the temperature of a
            % phase as well). 
            mNodeTemps = this.oVSys.getNodeTemperatures();
            
            % Make sure we actually can do something.
            if size(mNodeTemps, 1) < 1
                this.warn('update', 'Nothing to calculate.');
                return; % Return early.
            end
            
            % Skip the first call to the solver because we will calculate
            % the temperature change at the "beginning" of the next step.
            % Since we cannot influence the order of the timer callbacks,
            % the calculation might actually happen at the end of each
            % step, beginning with the second step.
            %TODO: Check if this actually needs to be gated on the stored
            %      previous timestep or |oTimer.fTime == 0|.
            if this.fPreviousTimestep < 0
                
                % Remember the current timestep for the next time the
                % solver is executed.
                this.fPreviousTimestep = oTimer.fTime;
                
                return; % Return early.
                
            end
            
            % Get the integral boundaries for the ODE solver. 
            fStepBeginTime = this.fPreviousTimestep;
            fStepEndTime   = oTimer.fTime;
            
            % Solve the equation.
            % http://www.mathworks.com/matlabcentral/answers/101581-why-do-i-receive-a-warning-about-integration-tolerance-when-using-the-ode-solver-functions
            % ode45, ode23s, ode15s, ode23tb?
            [mTimePoints, mSolutionTemps] = ode45(this.calcChangeRate, ...    ode23s
                [fStepBeginTime, fStepEndTime], mNodeTemps, this.tOdeOptions);
            
            % Store solver results. This is mostly for debugging purposes.
            %TODO: Remove??
            this.mPreviousSolverTimes = mTimePoints;
            this.mPreviousSolverTemps = mSolutionTemps;
            
            % Calculate the total temperature difference between the start
            % and end temperatures of the solver.
            mTotalTempDiff = mSolutionTemps(end, :) - mNodeTemps';
            
%             % Calculate the energy transfer.
%             this.calcHeatTransfer(mTimePoints, mSolutionTemps);
            % Calculate the change in inner heat energy per node.
            mNodeHeatChange = this.mNodeCapacities' .* mTotalTempDiff;
            
            % Notify thermal container / nodes about heat energy transfer.
            this.oVSys.changeNodesInnerEnergy(mNodeHeatChange);
            
            % Remember the current (end) time for the next call to this
            % method, where it is used as the start time.
            this.fPreviousTimestep = fStepEndTime;
            
        end
        
        function reloadRateMatrices(this)
            % Build rate matrices used by the lumped parameter solver.
            %TODO: move some stuff from the thermal container here??
            
            % Update thermal matrices of |container|/|vsys|.
            this.oVSys.generateThermalMatrices();

            % Get heat sources and capacitances. %%%
            %mHeatSources = this.oVSys.getHeatSources();
            mHeatSources = this.oVSys.mHeatSourceVector;
            %mCapacities  = this.oVSys.getCapacitances();
            mCapacities  = this.oVSys.mCapacityVector;
            
            % Build the source rate vector.
            this.mSourceRateVector = mHeatSources ./ mCapacities;
            
            % Get conductors. %%%
            %mLinearConductors    = this.oVSys.getLinearConductors();
            mLinearConductors    = this.oVSys.mLinearConductance;
            %mFluidicConductors   = this.oVSys.getFluidicConductors();
            mFluidicConductors   = this.oVSys.mFluidicConductance;
            %mRadiativeConductors = this.oVSys.getRadiativeConductors();
            mRadiativeConductors = this.oVSys.mRadiativeConductance;
            
            % Build transfer rate matrices.
            [this.mLinearRateMatrix, this.mFluidFlowRateMatrix, ...
                this.mRadiationRateMatrix] = buildRateMatrices( ...
                mCapacities, mLinearConductors, ...
                mFluidicConductors, mRadiativeConductors);
            
            % Remember capacitances.
            this.mNodeCapacities = mCapacities;
            
        end
        
        function mHeatTransferred = calcHeatTransfer(this, mTimes, mTemperatures)
            % Calculates the heat transfer during a timestep. This method
            % is called with the results of the ODE solver.
            
            % Get capacitances. 
            %mCapacities = this.mNodeCapacities;
            
            % Get conductors. %%%
            %mLinearConductors    = this.oVSys.getLinearConductors();
            mLinearConductors    = this.oVSys.mLinearConductance;
            %mFluidicConductors   = this.oVSys.getFluidicConductors();
            mFluidicConductors   = this.oVSys.mFluidicConductance;
            %mRadiativeConductors = this.oVSys.getRadiativeConductors();
            mRadiativeConductors = this.oVSys.mRadiativeConductance;
            
            % Calculate the heat transfer.
            [mHFLinear, mHFFluidic, mHFRadiat] = calcHeatTransfer(mTimes, mTemperatures, ...
                mLinearConductors, mFluidicConductors, mRadiativeConductors);
            
            % Return the assorted result.
            mHeatTransferred = [mHFLinear, mHFFluidic, mHFRadiat];
            
        end
        
        function mTemperatureChangeRate = calcTemperatureChangeRate(this, mCurrentTemperatures, ~)
            % Calculates the rate of temperature change. This function is 
            % called by the ODE solver at each (internal) timestep(?). It 
            % returns the "right side" of the equation |T' = f(t, T)|.
            %
            % The last parameter is the current time at the solver
            % iteration step. It is not used here. 
            % 
            % nonlinear, first order ODE
            % Original logic by Christof Roth.
            
            %mLinearRateMatrices = this.mLinearRateMatrix + this.mFluidFlowRateMatrix;

            mTemperatureChangeRate = this.mSourceRateVector + ...
                (this.mLinearRateMatrix + this.mFluidFlowRateMatrix) * mCurrentTemperatures + ...
                this.mRadiationRateMatrix * mCurrentTemperatures.^4;
            
        end
        
        function fVal = getMatrixValueIfExists(this, sPropName, iPos1, iPos2)
            % This is needed for the logger because it only handles scalar
            % values, and on top of that the matrix sizes of this class may
            % change during simulation. To avoid MATLAB and the logger
            % throwing errors, we need some getter logic that always
            % returns an appropriate scalar value.
            
            fVal = NaN;
            xProp = this.(sPropName);
            mSize = size(xProp);
            
            if mSize(1) == 0 || mSize(2) == 0
                
                return; % Nothing to do here: xProp is empty => return NaN.
                
            elseif isequal(mSize, [1, 1]) % Scalar.
                
                fVal = xProp;
                return; % Return early. 
                
            end
            
            if nargin < 4
                
                iPos2 = 1; % Always use first row item if not specified.
                
                if mSize(1) == 1 % Row vector.
                    iPos2 = iPos1; % Use supplied position as column index.
                    iPos1 = 1;
                end
                
            end
            
            fVal = xProp(iPos1, iPos2);
            
        end
        
    end
    
end

