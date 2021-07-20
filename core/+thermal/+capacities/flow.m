classdef flow < thermal.capacity
    % LOW A capacity intent for the use with flow matter phases which are
    % modelled to not contain any mass. Basically the capacity only
    % consists of heat capacity flows and changes in heat flow directly
    % impact the temperature of the capacity
    
    properties (GetAccess = public, SetAccess = protected)
        
    end
    
    methods
        
        function this = flow(oPhase, fTemperature)
            %CAPACITY Create new thermal capacity object
            %   Create a new capacity with a name and associated phase
            %   object. Capacities are generated automatically together
            %   with phases and all thermal calculations are performed here
            
            this@thermal.capacity(oPhase, fTemperature, true);
            
            
        end
        
        function updateTemperature(this, ~)
            % Use fCurrentHeatFlow to calculate the temperature change
            % since the last execution fLastTemperatureUpdate
            
            % Getting the current time and calculating the last time step
            fTime     = this.oTimer.fTime;
            fLastStep = fTime - this.fLastTemperatureUpdate;
            
            % To ensure that we calculate the new energy with the correct
            % total heat capacity we have to get the current mass and the
            % possible mass that was added since the last mass update (in
            % case this was not executed in the same tick) (oPhase.fMass +
            % oPhase.fCurrentTotalInOuts * (this.oTimer.fTime -
            % oPhase.fLastMassUpdate)) * this.fSpecificHeatCapacity There
            % is a small error from this because the specific heat capacity
            % is not perfectly correct. However, as the matter side
            % controls the maximum allowed changes in composition until
            % this is recalculated, these are acceptable errors.
            
            
            % This is a flow phase with 0 mass (and therefore also
            % 0 capacity by itself) the temperature calculation must be
            % adapted to reflect this correctly
            
            % Initializing three arrays that will hold the information
            % gathered from all exmes connected to this capacity.
            afMatterFlowRate       = zeros(1,this.iProcsEXME);
            afSpecificHeatCapacity = zeros(1,this.iProcsEXME);
            afTemperature          = zeros(1,this.iProcsEXME);

            % we cannot use the fCurrentHeatFlow property directly
            % because it would contain mass based heat flows, which are
            % not valid for flow phases
            fSolverHeatFlow = 0;

            % Looping through all the thermal exmes 
            for iExme = 1:this.iProcsEXME
                % for basic_fluidic branches, the thermal branch
                % represent a matter based mass transfer, and therefore
                % we can use this to calculate the overall heat
                % capacity flow entering the phase
                if this.aoExmes(iExme).oBranch.oHandler.bFluidicSolver
                    % Now we need to find out in which direction the
                    % branch is connected. Positive is from left to
                    % right. In this case we are looking at the coExmes
                    % cell and here index 1 is left and index 2 is
                    % right. 
                    % When we compare this capacity's phase to the
                    % phase of the matter exme at one end of the
                    % branch, we can determine if we are at the right
                    % or left side of that branch. 
                    if this.aoExmes(iExme).oBranch.oMatterObject.coExmes{1}.oPhase == this.oPhase
                        % We're at the left side
                        iMatterExme = 1;
                        iOtherExme = 2;
                    else
                        % We're at the right side
                        iMatterExme = 2;
                        iOtherExme = 1;
                    end

                    % Now we can get the flow rate of this exme and
                    % more importantly the sign. 
                    fFlowRate = this.aoExmes(iExme).oBranch.oMatterObject.fFlowRate * this.aoExmes(iExme).oBranch.oMatterObject.coExmes{iMatterExme}.iSign;

                    % We only consider inflows. Outflows change the
                    % temperature through a change in mass and thereby
                    % total heat capacity. 
                    if fFlowRate > 0
                        % Setting the matter flow rate and specific
                        % heat capacity for this exme.
                        afMatterFlowRate(iExme) = fFlowRate;
                        afSpecificHeatCapacity(iExme) = this.aoExmes(iExme).oBranch.oMatterObject.coExmes{iOtherExme}.oFlow.fSpecificHeatCapacity;

                        % To get the temperature of the inflow, we need
                        % to look at the afTemperatures array in the
                        % thermal branch. This is necessary, because
                        % matter f2f processors can change the
                        % temperature via their fHeatFlow property.
                        % This is taken into account in the thermal
                        % solver when the afTemperatures array is
                        % populated. Depending on which end of the
                        % branch this capacity is located (left or
                        % right) we get the first or last element in
                        % the array. 
                        if iMatterExme == 1
                            afTemperature(iExme) = this.aoExmes(iExme).oBranch.afTemperatures(1);
                        else
                            afTemperature(iExme) = this.aoExmes(iExme).oBranch.afTemperatures(end);
                        end
                    end
                else
                    % in case a different solver is used, we need the
                    % heat flow calculated by that solver, to add it to
                    % the heat flows from the sources. The heat flows
                    % from mass transport can be neglected since their
                    % temperature is directly used to calculate the
                    % base temperature
                    fSolverHeatFlow = fSolverHeatFlow + this.aoExmes(iExme).iSign * this.aoExmes(iExme).fHeatFlow;
                end
            end

            % Now we can calculate the overall heat capacity flow into
            % the phase.
            fOverallHeatCapacityFlow = sum(afMatterFlowRate .* afSpecificHeatCapacity);

            % Triggering in case someone wants to do something here
            if this.bTriggerSetCalculateFlowConstantTemperatureCallbackBound
                this.trigger('calculateFlowConstantTemperature');
            end

            % If nothing flows into the phase, we maintain the previous
            % temperature, otherwise we calculate it using all of the
            % information we have gathered so far.
            if fOverallHeatCapacityFlow == 0
                fTemperatureNew = this.fTemperature;
            else
                % We also need to take into account all of the heat
                % sources connected to this capacity.
                fSourceHeatFlow = sum(cellfun(@(cCell) cCell.fHeatFlow, this.coHeatSource));

                % Calculating the new temperature
                fTemperatureNew = (sum(afMatterFlowRate .* afSpecificHeatCapacity .* afTemperature) / fOverallHeatCapacityFlow) + (fSourceHeatFlow + fSolverHeatFlow)/fOverallHeatCapacityFlow;
            end
            
            % Setting the properties that help us determine if we need to
            % do this again next time this method is called. 
            this.fLastTemperatureUpdate     = fTime;
            this.fTemperatureUpdateTimeStep = fLastStep;
            
            if fTemperatureNew ~= this.fTemperature
                bSetBranchesOutdated = true;
            else
                bSetBranchesOutdated = false;
            end
            
            % The temperature is not set directly, because we want to
            % ensure that the phase and capacity have the exact same
            % temperature at all times
            this.setTemperature(fTemperatureNew);
            
            % check if we have to update the specific heat capacity
            if fOverallHeatCapacityFlow ~= 0
                this.updateSpecificHeatCapacity();
            end
            
            % Trigger branch solver updates in post tick for all branches
            if bSetBranchesOutdated
                this.setBranchesOutdated();
            end
            
            % Capacity sets new time step (registered with parent store, used
            % for all phases of that store)
            this.setOutdatedTS();
            
            % Triggering in case someone wants to do something here
            if this.bTriggerSetUpdateTemperaturePostCallbackBound
            	this.trigger('updateTemperature_post');
            end
            
            this.bRegisteredTemperatureUpdated = false;
        end
        
    end
    
    methods (Access = protected)
        
    end
end