classdef branch < solver.thermal.base.branch
% A basic thermal solver which calculates the heat flow through a thermal
% branch assuming that infinite conductivity is present between the two
% connected capacities
    properties (SetAccess = private, GetAccess = public)
        
        % Actual time between flow rate calculations
        fTimeStep = inf;
        
        fSolverHeatFlow = 0;
        
    end
    
    
    methods
        function this = branch(oBranch)
            this@solver.thermal.base.branch(oBranch, 'basic');
            
            this.iPostTickPriority = 2;
            
            this.oBranch.oTimer.bindPostTick(@this.update, this.iPostTickPriority);
            
            this.bResidual = true;
        end
        
    end
    
    methods (Access = protected)
        function update(this)
            
            oCapacityLeft   = this.oBranch.coExmes{1}.oCapacity;
            oCapacityRight  = this.oBranch.coExmes{2}.oCapacity;
            
            % Get exme flowrates except for this branch
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
            
            % get source flowrates
            fSourceHeatFlowLeft = 0;
            for iSource = 1:length(oCapacityLeft.aoHeatSource)
                fSourceHeatFlowLeft = fSourceHeatFlowLeft + oCapacityLeft.aoHeatSource(iSource).fHeatFlow;
            end
            
            fSourceHeatFlowRight = 0;
            for iSource = 1:length(oCapacityRight.aoHeatSource)
                fSourceHeatFlowRight = fSourceHeatFlowRight + oCapacityRight.aoHeatSource(iSource).fHeatFlow;
            end
            
            fCurrentHeatFlowLeft    = fExmeHeatFlowLeft + fSourceHeatFlowLeft;
            fCurrentHeatFlowRight   = fExmeHeatFlowRight + fSourceHeatFlowRight;
            
            % If we assume an inifinite conductor between the two
            % capacities, the temperature change for each of the capacities
            % is simply the total heat flow divided with the total capacity
            % of both capacities.
            fTemperatureChangePerSecond = (fCurrentHeatFlowLeft + fCurrentHeatFlowRight) / (oCapacityLeft.fTotalHeatCapacity + oCapacityRight.fTotalHeatCapacity);
            
            % Then the required heat flow for each of the phases is:
            fRequiredHeatFlowLeft   = fTemperatureChangePerSecond * oCapacityLeft.fTotalHeatCapacity;
            
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

            this.fSolverHeatFlow = -fSolverHeatFlowLeft + (fEqualizationTemperatureChange * (oCapacityLeft.fTotalHeatCapacity + oCapacityRight.fTotalHeatCapacity) / 2);
            
            this.oBranch.coExmes{1}.setHeatFlow(this.fSolverHeatFlow);
            this.oBranch.coExmes{2}.setHeatFlow(this.fSolverHeatFlow);
            
            % the temperatures between the conductors are not required, but
            % it is possible to define a different thermal branch that
            % calculates them, e.g. to calculate the wall temperature in a
            % heat exchanger
            afTemperatures = []; 
            update@solver.thermal.base.branch(this, this.fSolverHeatFlow, afTemperatures);
            
        end
    end
end
