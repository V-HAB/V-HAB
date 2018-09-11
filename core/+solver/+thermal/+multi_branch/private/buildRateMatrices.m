% Original logic by Christof Roth.
% Code by Florian Bender (2014) to accommodate the new requirements of
% V-HAB and the refactored lumped parameter solver. 

function [mLinearRate, mFluidFlowRate, mRadiationRate] = ...
    buildRateMatrices(mCapacitancesVector, mLinearConductors, ...
        mFluidicConductors, mRadiativeConductors)
    %BUILDRATEMATRICES Build rate matrices for transient thermal solver
    %   Build the rate matrices for a matrix based solution of a transient
    %   heat transfer problem using an ordinary differential equation
    %   solver.
    %   
    %   The function expects the capacity vector (in |J/K|) as well as the
    %   linear, fluidic (both in |-, -, W/K|) and radiative conductor
    %   (in |-, -, W/K^4|) matrices built by the thermal container (or
    %   solver) as input, and returns the linear & fluid flow rate (both in
    %   |1/s|) and radiation rate (in |1/(s*K^3)|) matrices for the solver.

    % Get the number of available nodes.
    iNumNodes = size(mCapacitancesVector, 1);

    % Pre-allocate matrices (quadratic, size: |m = n = iNumNodes|). 
    mLinearRate    = zeros(iNumNodes);
    mFluidFlowRate = zeros(iNumNodes);
    mRadiationRate = zeros(iNumNodes);
    mMatrixSize = [iNumNodes, iNumNodes]; % == size(mLinearRate) == size(mFluidFlowRate) == size(mRadiationRate)

    % Create a matrix of per-node capacities in each column, repeated for
    % the number of nodes (so it is a |m = n = iNumNodes| matrix). We need
    % this matrix in the last step of building each rate matrix.
    mTiledCapacitances = repmat(mCapacitancesVector, 1, iNumNodes);

    %% Rate matrix for linear conductors
    if size(mLinearConductors, 1) > 0

        % Get the left- and right-hand node indices. 
        mLeftNodes  = mLinearConductors(:, 1);
        mRightNodes = mLinearConductors(:, 2);
        % Get the conductance values. 
        mConductances = mLinearConductors(:, 3);

        % Get the indices of the nodes with links (conductors) in between
        % them. 
        mIndices = sub2ind(mMatrixSize, mLeftNodes, mRightNodes);
        % Set the values at the indices to the conductance values. 
        mLinearRate(mIndices) = mConductances;

        % Mirror entries because linear heat transfer is bidirectional.
        mLinearRate = mLinearRate + triu(mLinearRate, 1)' + tril(mLinearRate, -1)';

        % Calculate the sum of the value of conductance for each node and
        % set it as the diagonal.
        mConductorSum = sum(mLinearRate);
        mLinearRate   = mLinearRate - diag(mConductorSum);

        % Divide by capacitances to finally get a rate (eliminates the
        % energy and temperature term so there is only a rate term left
        % with |1/s|).
        mLinearRate = mLinearRate ./ mTiledCapacitances;

        % Very small capacities would result in the ode solver running
        % endlessly (because the timesteps for the solver become so small
        % that it gets stuck in and endless loop). Therefore the values for
        % very small capacites in the linear rate are set to 0, to prevent 
        mLinearRate(mTiledCapacitances < 1e-5) = 0;
    end

    %% Rate matrix for fluidic conductors
    if size(mFluidicConductors, 1) > 0

        % Get the left- and right-hand node indices.
        mLeftNodes  = mFluidicConductors(:, 1);
        mRightNodes = mFluidicConductors(:, 2);
        % Get the conductance values.
        mConductances = mFluidicConductors(:, 3);

        % Get the indices of the nodes with links (conductors) in between
        % them. 
        %TODO: Why is the reversed order necessary?? Is it because energy
        %    only flows from the upstream to the downstream node? Need to
        %    investigate!
        mIndices = sub2ind(mMatrixSize, mRightNodes, mLeftNodes);
        % Set the values at the indices to the conductance values. 
        mFluidFlowRate(mIndices) = mConductances;

        % No mirroring of entries here because fluidic heat transfer is
        % unidirectional.

        % Calculate the sum of the value of conductance for each node and
        % set it as the diagonal.
        mConductorSum  = sum(mFluidFlowRate);
        mFluidFlowRate = mFluidFlowRate - diag(mConductorSum);

        % Divide by capacitances to finally get a rate (eliminates the
        % energy and temperature term so there is only a rate term left
        % with |1/s|).
        mFluidFlowRate = mFluidFlowRate ./ mTiledCapacitances;

        % Very small capacities would result in the ode solver running
        % endlessly (because the timesteps for the solver become so small
        % that it gets stuck in and endless loop). Therefore the values for
        % very small capacites in the linear rate are set to 0, to prevent 
        mFluidFlowRate(mTiledCapacitances < 1e-5) = 0;
    end

    %% Rate matrix for radiative conductors
    if size(mRadiativeConductors, 1) > 0

        % Get the left- and right-hand node indices.
        mLeftNodes  = mRadiativeConductors(:, 1);
        mRightNodes = mRadiativeConductors(:, 2);
        % Get the conductance values.
        mConductances = mRadiativeConductors(:, 3);

        % Get the indices of the nodes with links (conductors) in between
        % them. 
        mIndices = sub2ind(mMatrixSize, mLeftNodes, mRightNodes);
        % Set the values at the indices to the conductance values. 
        mRadiationRate(mIndices) = mConductances;

        % Mirror entries because radiative heat transfer is bidirectional.
        mRadiationRate = mRadiationRate + triu(mRadiationRate, 1)' + tril(mRadiationRate, -1)';

        % Calculate the sum of the value of conductance for each node and
        % set it as the diagonal.
        mConductorSum  = sum(mRadiationRate);
        mRadiationRate = mRadiationRate - diag(mConductorSum);

        % Divide by capacitances to finally get a rate (eliminates the
        % energy and part of the temperature term so there is only a rate
        % term left with |1/(s*K^3)|).
        mRadiationRate = mRadiationRate ./ mTiledCapacitances;

        % Very small capacities would result in the ode solver running
        % endlessly (because the timesteps for the solver become so small
        % that it gets stuck in and endless loop). Therefore the values for
        % very small capacites in the linear rate are set to 0, to prevent 
        mRadiationRate(mTiledCapacitances < 1e-5) = 0;
    end

end
