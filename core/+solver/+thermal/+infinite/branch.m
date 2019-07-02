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
            for iExme = 1:length(oCapacityLeft.aoExmes)
                if oCapacityLeft.aoExmes(iExme) ~= this.oBranch.coExmes{1}
                    fExmeHeatFlowLeft = fExmeHeatFlowLeft + (oCapacityLeft.aoExmes(iExme).iSign * oCapacityLeft.aoExmes(iExme).fHeatFlow);
                end
            end
            
            fExmeHeatFlowRight = 0;
            for iExme = 1:length(oCapacityRight.aoExmes)
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
                bLeft = true;
            elseif oCapacityRight.oPhase.bFlow
                
                oFlowCapacity   = oCapacityRight;
                oNormalCapacity = oCapacityLeft;
                
                bFlow = true;
                bLeft = false;
            else
                bFlow = false;
            end
            
            % ensure that not both capacities are flow capacities, as that
            % would break the calculation
            if bFlow && oNormalCapacity.oPhase.bFlow
                error('it is not possible to use an infinite conduction solver with two flow capacities! Currently both %s and %s are flow capacities', oCapacityLeft.sName, oCapacityRight.sName)
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
                for iExme = 1:oFlowCapacity.iProcsEXME
                    if isa(oFlowCapacity.aoExmes(iExme).oBranch.oHandler, 'solver.thermal.basic_fluidic.branch')
                        fFlowRate = oFlowCapacity.aoExmes(iExme).oBranch.coConductors{1}.oMassBranch.fFlowRate * oFlowCapacity.oPhase.toProcsEXME.(oFlowCapacity.aoExmes(iExme).sName).iSign;
                        
                        if fFlowRate > 0
                            mfFlowRate(iExme) = fFlowRate;
                            mfSpecificHeatCapacity(iExme) = oFlowCapacity.oPhase.toProcsEXME.(oFlowCapacity.aoExmes(iExme).sName).oFlow.fSpecificHeatCapacity;
                        end
                    end
                end
                
                % sum it up to get the total heat capacity flow of the flow
                % phase
                fOverallHeatCapacityFlow = sum(mfFlowRate .* mfSpecificHeatCapacity);
                
                % now we can calculate what the required heat flow is to
                % enter the flow capacity so that it has the same
                % temperature as the other phase. Note that we use the
                % current flow capacity temperature here, neglecting the
                % impact of the temperatures of the flows entering the flow
                % capacity because these are already considered as heat
                % flows for the corresponding thermal exmes
                fRequiredFlowHeatFlow = (oNormalCapacity.fTemperature - oFlowCapacity.fTemperature) * fOverallHeatCapacityFlow;
                
                % if the flow phase is on the left side we subtract the
                % current heat flow of the left side from the required heat
                % flow to calculate the heat flow that still has to
                % enter/leave that capacity. The negative sign is used
                % because negative values for the left side result in a
                % temperature rise, while for the right side positive
                % values result in a temperature rise. For the right side
                % the calculation is analogous but with a different sign
                % and using the current right side heat flow
                if bLeft
                    fHeatFlow = -(fRequiredFlowHeatFlow - fCurrentHeatFlowLeft);
                else
                    fHeatFlow = fRequiredFlowHeatFlow - fCurrentHeatFlowRight;
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

                % For a positive value of the respective heat flows the
                % phase is supposed to increase in temperature, for the
                % left side a negative value in the solver heat flow would
                % represent an increase in temperature. Therefore we set 
                %
                % In order to equalize small differences in the
                % temperature, the following term is also added (the
                % difference can occur e.g. because the total heat capacity
                % changes etc. However these errors should be small and the
                % temperature of both capacities should be nearly identical
                % all the time)
                fEqualizationTemperatureChange = (oCapacityLeft.fTemperature - oCapacityRight.fTemperature) / 2;

                fHeatFlow = -fSolverHeatFlowLeft + (fEqualizationTemperatureChange * (oCapacityLeft.fTotalHeatCapacity + oCapacityRight.fTotalHeatCapacity) / 2);
                
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