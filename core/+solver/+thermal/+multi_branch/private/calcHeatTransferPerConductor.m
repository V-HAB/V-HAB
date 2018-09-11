% Original logic by Christof Roth.
% Code by Florian Bender (2014) to accommodate the new requirements of
% V-HAB and the refactored lumped parameter solver. Slimmed version.

function [mHeatFlowLinear, mHeatFlowFluidic, mHeatFlowRadiative] = ...
    calcHeatTransferPerConductor(mTimes, mTemps, mLinearConductors, ...
        mFluidicConductors, mRadiativeConductors)
    %CALCHEATTRANSFER Calculate conductor heat transfer of thermal solver
    %   Calculate the heat flow at each iteration per method of conduction.
    %   Expects the solution times and temperatures (per iteration step) as
    %   well as the conductor matrices.

    % Set default values.
    mHeatFlowLinear    = [];
    mHeatFlowFluidic   = [];
    mHeatFlowRadiative = [];

    % Calculate the interval (length of timestep) for each iteration.
    mIntervals = mTimes(2:end) - mTimes(1:end-1);

    % Calculate mean temperatures for every timestep.
    mMeanTemps = (mTemps(1:end-1, :) + mTemps(2:end, :)) / 2;

    % Get the number of conductors.
    iLinearConductors    = size(mLinearConductors, 1);
    iFluidicConductors   = size(mFluidicConductors, 1);
    iRadiativeConductors = size(mRadiativeConductors, 1);

    % Calculate the heat transferred through linear conductors.
    if iLinearConductors > 0

        % Get the left- and right-hand node indices.
        mLeftNodes  = mLinearConductors(:, 1);
        mRightNodes = mLinearConductors(:, 2);
        % Get the conductance values.
        mConductances = mLinearConductors(:, 3);

        % Tile the intervals by the number of conductors.
        mTiledIntervals = repmat(mIntervals, 1, iLinearConductors);

        % Get the temperature difference for each conductor at every
        % timestep.
        mTempDiff = mMeanTemps(:, mLeftNodes) - mMeanTemps(:, mRightNodes);

        % Calculate the total energy transferred through linear conduction.
        mHeatFlowLinear = mConductances' .* sum(mTempDiff .* mTiledIntervals, 1);

    end

    % Calculate the heat transferred through fluidic conductors.
    if iFluidicConductors > 0

        % Get the left-hand node indices only (since heat flow is
        % unidirectional). 
        mLeftNodes  = mFluidicConductors(:, 1);
        % Get the conductance values. 
        mConductances = mFluidicConductors(:, 3);

        % Tile the intervals by the number of conductors.
        mTiledIntervals = repmat(mIntervals, 1, iFluidicConductors);

        % Get the node temperatures (== downstream temperature) for each
        % conductor at every timestep.
        mNodeTemps = mMeanTemps(1:end, mLeftNodes);

        % Calculate the total energy transferred through fluid flow.
        mHeatFlowFluidic = mConductances' .* sum(mNodeTemps .* mTiledIntervals, 1);

    end

    % Calculate the heat transferred through radiative conductors.
    if iRadiativeConductors > 0

        % Get the left- and right-hand node indices. 
        mLeftNodes  = mRadiativeConductors(:, 1);
        mRightNodes = mRadiativeConductors(:, 2);
        % Get the conductance values. 
        mConductances = mRadiativeConductors(:, 3);

        % Tile the intervals by the number of conductors.
        mTiledIntervals = repmat(mIntervals, 1, iRadiativeConductors);

        % Get the temperature^4 difference for each conductor at every time
        % step.
        mDiff = mMeanTemps(:, mLeftNodes).^4 - mMeanTemps(:, mRightNodes).^4;

        % Calculate the total energy transferred through radiation.
        mHeatFlowRadiative = mConductances' .* sum(mDiff .* mTiledIntervals, 1);

    end

end
