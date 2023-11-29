classdef branch < solver.thermal.base.branch
% A manual thermal solver, which can be told how much heat flow is supposed
% to be transfered between the two connected capacities
    
    properties (SetAccess = protected, GetAccess = public)
        fRequestedHeatFlow = 0;
        
        bEnergyTransferActive = false;
        fEnergyTransferStartTime;
        fEnergyTransferFinishTime;
    end
    methods
        function this = branch(oBranch)
            % creat a basic thermal solver which can solve heat transfer
            % for convective and conductive or radiative conductors. Note
            % that it is not possibe to combine convective/conductive
            % conductors and radiative conductors in one solver, you have
            % to seperate these heat transfers so that the
            % convective/conductive part and the radiative part are solved
            % seperatly
            this@solver.thermal.base.branch(oBranch, 'basic');
            
            % Now we register the solver at the timer, specifying the post
            % tick level in which the solver should be executed. For more
            % information on the execution view the timer documentation.
            % Registering the solver with the timer provides a function as
            % output that can be used to bind the post tick update in a
            % tick resulting in the post tick calculation to be executed
            this.hBindPostTickUpdate = this.oBranch.oTimer.registerPostTick(@this.update, 'thermal' , 'solver');
            
            % and update the solver to initialize everything
            this.update();
        end
        
        function this = setHeatFlow(this, fHeatFlow)
            % Manualy sets the heat flow for the solver. 
            if this.bEnergyTransferActive
                warning(['Manual solver ', this.oBranch.sName, ' is currently transferring a fixed amount of Energy, set the new flowrate after this is finished']);
                return
            elseif isempty(fHeatFlow)
                this.throw('Setting an empty heatflow for manual branch %s in system %s', this.oBranch.sName, this.oBranch.oContainer.sName);
            end
            
            this.fRequestedHeatFlow = fHeatFlow;
            
            this.registerUpdate();
        end
        
        function setEnergyTransfer(this, fEnergy, fTime)
            % This function sets a specific energy that is transferred
            % within a specific time. After the energy has been transferred
            % the flowrate is set to 0 again. If a energy transfer is
            % initialized while another one is already taking place, a
            % warning is displayed and the original Energy transfer is
            % finished.
            %
            % Inputs are:
            % fEnergy in [J]
            % fTime in [s]
            
            if fTime == 0
                error(['Stop joking, nothing can happen instantly. Manual solver ', this.oBranch.sName, ' was provided 0 time to transfer Energy']);
            end
            if isempty(fEnergy) || isempty(fTime)
                this.throw('Setting an empty Energy transfer for manual branch %s in system %s', this.oBranch.sName, this.oBranch.oContainer.sName);
            end
            this.fTimeStep = fTime;
            this.bEnergyTransferActive = true;
            this.fEnergyTransferStartTime  = this.oBranch.oTimer.fTime;
            this.fEnergyTransferFinishTime = this.oBranch.oTimer.fTime + fTime;
            
            this.fRequestedFlowRate = fEnergy / fTime;
            this.fRequestedVolumetricFlowRate = [];
            
            this.setTimeStep(this.fTimeStep, true);
            
            this.registerUpdate();
        end
    end
    
    methods (Access = protected)
        function update(this)
            % update the thermal solver, since it is manual we only have to
            % set the requested heat flow if it is different to the current
            % heat flow of the branch
            
            if this.bEnergyTransferActive && abs(this.oBranch.oTimer.fTime - this.fEnergyTransferFinishTime) < this.oBranch.oTimer.fMinimumTimeStep
                this.bEnergyTransferActive = false;
                this.fRequestedFlowRate = 0;
                
                this.fTimeStep = inf;
                this.setTimeStep(this.fTimeStep);
            elseif this.bEnergyTransferActive && abs(this.oBranch.oTimer.fTime - this.fEnergyTransferFinishTime) > this.oBranch.oTimer.fMinimumTimeStep
                % If the branch is called before the set Energy transfer time
                % step, the afLastExec property in the timer for this
                % branch is updated, while the timestep remains. This can
                % lead to the branch missing its update. Therefore, in
                % every update that occurs during a Energy transfer that
                % does not fullfill the above conditions we have to reduce
                % the time step:
                this.fTimeStep = this.fEnergyTransferFinishTime - this.oBranch.oTimer.fTime;
                
                this.setTimeStep(this.fTimeStep, true);
            end
            
            % set heat flows
            this.oBranch.coExmes{1}.setHeatFlow(this.fRequestedHeatFlow);
            this.oBranch.coExmes{2}.setHeatFlow(this.fRequestedHeatFlow);

            % the temperatures between the conductors are not always
            % required. If it is of interest to model various temperatures
            % multiple thermal branches for each step of the heat transfer
            % can be used e.g. to calculate the wall temperature in a heat
            % exchanger
            afTemperatures = []; 
            update@solver.thermal.base.branch(this, this.fRequestedHeatFlow, afTemperatures);
        end
    end
end
