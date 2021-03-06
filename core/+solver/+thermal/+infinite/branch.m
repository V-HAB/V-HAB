classdef branch < solver.thermal.base.branch
% A basic thermal solver which calculates the heat flow through a thermal
% branch assuming that infinite conductivity is present between the two
% connected capacities
    methods
        function this = branch(oBranch)
            % creat a infinite conduction thermal solver specifically
            % written to model an ideal (no resistance) thermal connection
            % between two capacities without imposing limitations on the
            % solver time steps. This is e.g. usefull for small fluid
            % phases flowing through a solid phase with a high surface area
            % (as in CDRA)
            this@solver.thermal.base.branch(oBranch, 'infinite');
            
            % Now we register the solver at the timer, specifying the post
            % tick level in which the solver should be executed. For more
            % information on the execution view the timer documentation.
            % Registering the solver with the timer provides a function as
            % output that can be used to bind the post tick update in a
            % tick resulting in the post tick calculation to be executed
            this.hBindPostTickUpdate = this.oBranch.oTimer.registerPostTick(@this.update, 'thermal' , 'residual_solver');
            
            % we set the residual property to true because the solver must
            % be update at any small change
            this.bResidual = true;
        end
    end
    
    methods (Access = protected)
        function update(this)
            % update the thermal solver
            
            oCapacityLeft   = this.oBranch.coExmes{1}.oCapacity;
            oCapacityRight  = this.oBranch.coExmes{2}.oCapacity;
            
            % Get exme heat flows except for this branch as it will be
            % neglected in the following analysis. The heat flow of this
            % branch will be calculated to have both capacities change
            % their temperature by the same amount per second.
            fExmeHeatFlowLeft = 0;
            for iExme = 1:oCapacityLeft.iProcsEXME
                if oCapacityLeft.aoExmes(iExme) ~= this.oBranch.coExmes{1}
                    fExmeHeatFlowLeft = fExmeHeatFlowLeft + (oCapacityLeft.aoExmes(iExme).iSign * oCapacityLeft.aoExmes(iExme).fHeatFlow);
                end
            end
            
            fExmeHeatFlowRight = 0;
            for iExme = 1:oCapacityRight.iProcsEXME
                if oCapacityRight.aoExmes(iExme) ~= this.oBranch.coExmes{2}
                    fExmeHeatFlowRight = fExmeHeatFlowRight + (oCapacityRight.aoExmes(iExme).iSign * oCapacityRight.aoExmes(iExme).fHeatFlow);
                end
            end
            
            % get heat source flowrates for both capacities as we also have
            % to include these in the analysis for both capacities to
            % change their temperature identically
            fSourceHeatFlowLeft = 0;
            for iSource = 1:length(oCapacityLeft.coHeatSource)
                fSourceHeatFlowLeft = fSourceHeatFlowLeft + oCapacityLeft.coHeatSource{iSource}.fHeatFlow;
            end
            
            fSourceHeatFlowRight = 0;
            for iSource = 1:length(oCapacityRight.coHeatSource)
                fSourceHeatFlowRight = fSourceHeatFlowRight + oCapacityRight.coHeatSource{iSource}.fHeatFlow;
            end
            
            % now sum the exme heat flows and source heat flows to get the
            % total heat flows for the left and right capacity
            fCurrentHeatFlowLeft    = fExmeHeatFlowLeft + fSourceHeatFlowLeft;
            fCurrentHeatFlowRight   = fExmeHeatFlowRight + fSourceHeatFlowRight;
            
            % check if one of the capacities is a flow phase and set
            % identifier accordingly to prevent many checks later on
            if oCapacityLeft.oPhase.bFlow
                oFlowCapacity   = oCapacityLeft;
                oNormalCapacity = oCapacityRight;
                
                bFlow = true;
                bLeftFlow = true;
            elseif oCapacityRight.oPhase.bFlow
                
                oFlowCapacity   = oCapacityRight;
                oNormalCapacity = oCapacityLeft;
                
                bFlow = true;
                bLeftFlow = false;
            else
                bFlow = false;
            end
            
            % check if one of the capacities is a boundary phase and set
            % identifier accordingly to prevent many checks later on
            if oCapacityLeft.oPhase.bBoundary
                oBoundaryCapacity   = oCapacityLeft;
                oNormalCapacity     = oCapacityRight;
                
                bBoundary = true;
                bLeftBoundary = true;
            elseif oCapacityRight.oPhase.bBoundary
                
                oBoundaryCapacity   = oCapacityRight;
                oNormalCapacity     = oCapacityLeft;
                
                bBoundary = true;
                bLeftBoundary = false;
            else
                bBoundary = false;
            end
            % ensure that not both capacities are flow capacities, as that
            % would break the calculation
            if bFlow && oNormalCapacity.oPhase.bFlow
                error('It is not possible to use an infinite conduction solver with two flow capacities! Currently both %s and %s are flow capacities', oCapacityLeft.sName, oCapacityRight.sName)
            end
            
            if bBoundary && oNormalCapacity.oPhase.bBoundary
                error('It is not possible to use an infinite conduction solver with two boundary capacities! Currently both %s and %s are boundary capacities', oCapacityLeft.sName, oCapacityRight.sName)
            end
            
            if bBoundary && bFlow
                error('It is currently not possible to use an infinite conduction solver with a boundary and a flow capacity! Currently both %s and %s are either flow or boundary capacities', oCapacityLeft.sName, oCapacityRight.sName)
            end
            
            if bFlow
                % In the case that one phase is a flow phase it does not
                % actually have a capacity, but just a capacity flow.
                % Therefore, setting a heat flow for this phase directly
                % sets the temperature of the flow phase. For this reason
                % the solver heat flow of this branch is calculated in a
                % way that the flow phase has the same temperature as the
                % other phase while change in temperature only occurs in
                % the normal capacity
                
                % first we calculate the specific heat capacity flows of
                % the different mass flows entering the flow phase
                mfFlowRate              = zeros(1,oFlowCapacity.iProcsEXME);
                mfSpecificHeatCapacity  = zeros(1,oFlowCapacity.iProcsEXME);
                mfTemperature           = zeros(1,oFlowCapacity.iProcsEXME);
                
                for iExme = 1:oFlowCapacity.iProcsEXME
                    if isa(oFlowCapacity.aoExmes(iExme).oBranch.oHandler, 'solver.thermal.basic_fluidic.branch')
                        iExMeSign = oFlowCapacity.aoExmes(iExme).iSign;
                        fFlowRate = oFlowCapacity.aoExmes(iExme).oBranch.oMatterObject.fFlowRate * iExMeSign;
                        
                        if fFlowRate > 0
                            mfFlowRate(iExme) = fFlowRate;
                            oMatterObject = oFlowCapacity.aoExmes(iExme).oBranch.oMatterObject;
                            try
                                iBranchSign = sign(oMatterObject.fFlowRate);
                                if iBranchSign * iExMeSign < 0
                                    mfSpecificHeatCapacity(iExme) = oMatterObject.aoFlows(1).fSpecificHeatCapacity;
                                    mfTemperature(iExme)          = oFlowCapacity.aoExmes(iExme).oBranch.afTemperatures(1); %oMatterObject.aoFlows(1).fTemperature;
                                else
                                    mfSpecificHeatCapacity(iExme) = oMatterObject.aoFlows(end).fSpecificHeatCapacity;
                                    mfTemperature(iExme)          = oFlowCapacity.aoExmes(iExme).oBranch.afTemperatures(end); %oMatterObject.aoFlows(end).fTemperature;
                                end
                            catch oFirstError
                                try
                                    mfSpecificHeatCapacity(iExme) = oMatterObject.fSpecificHeatCapacity;
                                    mfTemperature(iExme)          = oMatterObject.fTemperature;
                                catch oSecondError
                                    if strcmp(oFirstError.identifier, 'MATLAB:noSuchMethodOrField')
                                        rethrow(oSecondError);
                                    else
                                        rethrow(oFirstError);
                                    end
                                end
                            end
                        end
                    end
                end
                
                % sum it up to get the total heat capacity flow of the flow
                % phase
                fOverallHeatCapacityFlow = sum(mfFlowRate .* mfSpecificHeatCapacity);
                fFlowTemperature = sum(mfFlowRate .* mfSpecificHeatCapacity .* mfTemperature) ./ fOverallHeatCapacityFlow;
                
                if isnan(fFlowTemperature)
                    fFlowTemperature = oNormalCapacity.fTemperature;
                end
                
                if oFlowCapacity.iHeatSources > 0
                    fFlowHeatSourceHeatFlow = sum(cellfun(@(cCell) cCell.fHeatFlow, this.coHeatSource));
                else
                    fFlowHeatSourceHeatFlow = 0;
                end
                % now we can calculate what the required heat flow is to
                % enter the flow capacity so that it has the same
                % temperature as the other phase. Note that we use the
                % current flow capacity temperature here, neglecting the
                % impact of the temperatures of the flows entering the flow
                % capacity because these are already considered as heat
                % flows for the corresponding thermal exmes
                fRequiredFlowHeatFlow = ((oNormalCapacity.fTemperature - fFlowTemperature) * fOverallHeatCapacityFlow) + fFlowHeatSourceHeatFlow;
                
                % if the flow phase is on the left side we subtract the
                % current heat flow of the left side from the required heat
                % flow to calculate the heat flow that still has to
                % enter/leave that capacity. The negative sign is used
                % because negative values for the left side result in a
                % temperature rise, while for the right side positive
                % values result in a temperature rise. For the right side
                % the calculation is analogous but with a different sign
                % and using the current right side heat flow
                if bLeftFlow
                    fHeatFlow = -(fRequiredFlowHeatFlow);
                else
                    fHeatFlow = fRequiredFlowHeatFlow;
                end
                
            elseif bBoundary
                % If there is a boundary phase present, the infinite
                % conduction solver will simply keep the other phase at the
                % same temperature as the boundary
                
                % If the normal phase is hotter than the boundary, we need
                % a negative heat flow!
                fEqualizationTemperatureChange = (oNormalCapacity.fTemperature - oBoundaryCapacity.fTemperature) * oNormalCapacity.fTotalHeatCapacity;
                
                if bLeftBoundary
                    % Since the boundary is on the left, we have to invert
                    % the signs for the heat flows
                    fHeatFlow = - fEqualizationTemperatureChange + fCurrentHeatFlowRight;
                else
                    % the normal phase is on the left, and we do not have
                    % to change signs, as the calculations were performed
                    % to ensure that negative heat flows are calculated if
                    % the normal phase should cool down
                    fHeatFlow = fEqualizationTemperatureChange - fCurrentHeatFlowLeft;
                end
                
                % for this case we also have to set a timestep to ensure we
                % do not produce oscillations. The timestep is the time it
                % takes for the normal capacity to reach the temperature of
                % the boundary capacity, which in this case is assumed to
                % be 1 second. Now since that would limit the maximum
                % simulation time step to 1 second, we only want to do this
                % if we actually have a heat flow, otherwise we can set inf
                if abs(fHeatFlow) > 1e-8
                    this.setTimeStep(1, true);
                else
                    fHeatFlow = 0;
                    this.setTimeStep(inf, true);
                end
            else
                % If we assume an inifinite conductor between the two
                % capacities, the temperature change for each of the capacities
                % is simply the total heat flow divided with the total capacity
                % of both capacities.
                fTemperatureChangePerSecond = (fCurrentHeatFlowLeft + fCurrentHeatFlowRight) / (oCapacityLeft.fTotalHeatCapacity + oCapacityRight.fTotalHeatCapacity);

                % Then the required heat flow for each of the phases is
                % that temperature change multiplied with the corresponding
                % heat capacity:
                fRequiredHeatFlowLeft   = fTemperatureChangePerSecond * oCapacityLeft.fTotalHeatCapacity;

                % as the heat flow is passed from one capacity to the
                % other, we only have to calculate it once and can use it
                % for both sides.
                fSolverHeatFlowLeft     = fRequiredHeatFlowLeft  - fCurrentHeatFlowLeft;
                
                % Can be used for sanity check, the heat flow on the ohter side
                % should be identical
                % fRequiredHeatFlowRight  = fTemperatureChangePerSecond * oCapacityRight.fTotalHeatCapacity;
                % fSolverHeatFlowRight    = fRequiredHeatFlowRight - fCurrentHeatFlowRight;

                % If small differences in the temperature occur (e.g.
                % because of changes in the total heat capacity) we
                % calculated the equalization temperature here and use it
                % to calculate a heat flow to normalize the two phase
                % temperatures
                fEqualizationTemperature    = (oCapacityLeft.fTemperature * oCapacityLeft.fTotalHeatCapacity + oCapacityRight.fTemperature * oCapacityRight.fTotalHeatCapacity) / (oCapacityLeft.fTotalHeatCapacity + oCapacityRight.fTotalHeatCapacity);
                % heat flow assuming the equalization occurs within the
                % maximum time step of the smaller capacity
                if oCapacityRight.fTotalHeatCapacity < oCapacityLeft.fTotalHeatCapacity
                    fEqualizationTimeStep = oCapacityRight.fMaxStep;
                else
                    fEqualizationTimeStep = oCapacityLeft.fMaxStep;
                end
                fEqualizationHeatFlowLeft   = ((oCapacityLeft.fTemperature - fEqualizationTemperature) * oCapacityLeft.fTotalHeatCapacity) / fEqualizationTimeStep;
                % can be used for sanity check, should be identical to left
                % fEqualizationHeatFlowRight  = ((fEqualizationTemperature - oCapacityRight.fTemperature ) * oCapacityRight.fTotalHeatCapacity) / fEqualizationTimeStep;

                fHeatFlow = -fSolverHeatFlowLeft + fEqualizationHeatFlowLeft;
                
            end
            
            this.oBranch.coExmes{1}.setHeatFlow(fHeatFlow);
            this.oBranch.coExmes{2}.setHeatFlow(fHeatFlow);
            
            % the temperatures between the conductors are not required, but
            % it is possible to define a different thermal branch that
            % calculates them, e.g. to calculate the wall temperature in a
            % heat exchanger
            afTemperatures = []; 
            update@solver.thermal.base.branch(this, fHeatFlow, afTemperatures);
        end
    end
end