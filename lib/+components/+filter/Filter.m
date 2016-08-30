classdef Filter < vsys
% TO DO: Description goes here lazy guy
    
    properties (SetAccess = public, GetAccess = public)
        % rMaxChange defines the maximum percentage by which the flow rate
        % can change within one (total) time step
        rMaxChange = 0.05;

        % fMinimumTimeStep defines the minimal total time step
        fMinimumTimeStep = 0.001;

        % fMaximumTimeStep defines the maximum total time step during
        % dynamic calculations
        fMaximumTimeStep = 0.01;

        % fSteadyStateTimeStep defines the time step that will be used once
        % the steady state has been reached
        fSteadyStateTimeStep = 60;
        
        % fMaxSteadyStateFlowRateChange is the criterion for when the
        % steady state has been reached. It defines the maximum difference
        % between the current and the new mass flow in kg/s. For example
        % for a value of 1e-6 the calculation will assume steady state if
        % the difference between the current and the new flow rate is less
        % than 1 milli g/s
        fMaxSteadyStateFlowRateChange = 1e-6;

        % Number of internal partial steps used in the flow rate
        % calculation. In principle the total time step is split into
        % several smaller internal ones for the flow rate calculation and
        % this number defines how many of these partial steps will be made
        iInternalSteps = 100;
    end

    properties (SetAccess = protected, GetAccess = public)
        
        % number of cells used in the filter model
        iCellNumber;
        
        % initialization struct to set the initial parameters of the filter
        % model
        tInitialization = struct();
        % tInitialization has to be a struct with the following fields:
        %       tfMassAbsorber 	 =   Mass struct for the filter material
        %       tfMassFlow       =   Mass struct for the flow material
        %       fTemperature     =   Initial temperature of the filter in K
        %       iCellNumber      =   number of cells used in the filter model
        %       fFrictionFactor  =   Factor used to calculate the pressure loss by multiplying it with the MassFlow^2
        
        % struct that contains information about the geometry of the filter
        tGeometry;
        % Geometry struct for the filter with the following field:
        %       fArea            =   Area perpendicular to the flow direction in m²
        %       fFlowVolume      =   free volume for the gas flow in the filter in m³
        %       fAbsorberVolume  =   volume of the absorber material in m³
        
        % boolean to easier decide if the flow rate through the filter is
        % negative
        bNegativeFlow = false;
    end
    
    methods
        function this = Filter(oParent, sName, tInitialization, tGeometry)
            
            this@vsys(oParent, sName, 30);
            
            this.tInitialization = tInitialization;
            this.iCellNumber = tInitialization.iCellNumber;
            
            this.tGeometry = tGeometry;
            
            eval(this.oRoot.oCfgParams.configCode(this));
            
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            components.filter.components.FilterStore(this, this.sName, (this.tGeometry.fFlowVolume + this.tGeometry.fAbsorberVolume));
            
            % The filter and flow phase total masses provided in the
            % tInitialization struct have to be divided by the number of
            % cells to obtain the tfMass struct for each phase of each
            % cell. The assumption here is that each cell has the same
            % size.
            csAbsorberSubstances = fieldnames(this.tInitialization.tfMassAbsorber);
            for iK = 1:length(csAbsorberSubstances)
                tfMassesAbsorber.(csAbsorberSubstances{iK}) = this.tInitialization.tfMassAbsorber.(csAbsorberSubstances{iK})/this.iCellNumber;
            end
            csFlowSubstances = fieldnames(this.tInitialization.tfMassFlow);
            for iK = 1:length(csFlowSubstances)
                tfMassesFlow.(csFlowSubstances{iK}) = this.tInitialization.tfMassFlow.(csFlowSubstances{iK})/this.iCellNumber;
            end
            
            % Now the phases, exmes, p2ps and branches for the filter model
            % can be created. A for loop is used to allow any number of
            % cells from 2 upwards.
            for iCell = 1:this.iCellNumber
                oFilterPhase = matter.phases.mixture(this.toStores.(this.sName), ['Absorber_',num2str(iCell)], 'solid', tfMassesAbsorber,(this.tGeometry.fAbsorberVolume/this.iCellNumber), this.tInitialization.fTemperature, 1e5);
                
                oFlowPhase = matter.phases.gas(this.toStores.(this.sName), ['Flow_',num2str(iCell)], tfMassesFlow,(this.tGeometry.fFlowVolume/this.iCellNumber), this.tInitialization.fTemperature);
                
                matter.procs.exmes.mixture(oFilterPhase, ['Adsorption_',num2str(iCell)]);
                matter.procs.exmes.mixture(oFilterPhase, ['Desorption_',num2str(iCell)]);
                
                matter.procs.exmes.gas(oFlowPhase, ['Adsorption_',num2str(iCell)]);
                matter.procs.exmes.gas(oFlowPhase, ['Desorption_',num2str(iCell)]);
                matter.procs.exmes.gas(oFlowPhase, ['Inflow_',num2str(iCell)]);
                matter.procs.exmes.gas(oFlowPhase, ['Outflow_',num2str(iCell)]);
                
                % adding two P2P processors, one for desorption and one for
                % adsorption. Two independent P2Ps are required because it
                % is possible that one substance is currently absorber
                % while another is desorbing which results in two different
                % flow directions that can occur at the same time.
                components.filter.components.Desorption_P2P(this.toStores.(this.sName), ['DesorptionProcessor_',num2str(iCell)], ['Absorber_',num2str(iCell),'.Desorption_',num2str(iCell)], ['Flow_',num2str(iCell),'.Desorption_',num2str(iCell)]);
                components.filter.components.Adsorption_P2P(this.toStores.(this.sName), ['AdsorptionProcessor_',num2str(iCell)], ['Flow_',num2str(iCell),'.Adsorption_',num2str(iCell)], ['Absorber_',num2str(iCell),'.Adsorption_',num2str(iCell)]);
                
                % Each cell is connected to the next cell by a branch, the
                % first and last cell also have the inlet and outlet branch
                % attached that connects the filter to the parent system
                if iCell == 1
                    % Inlet branch
                    matter.branch(this, [this.sName,'.','Inflow_',num2str(iCell)], {}, 'Inlet', 'Inlet');
                elseif iCell == this.iCellNumber
                    % branch between the current and the previous cell
                    matter.branch(this, [this.sName,'.','Outflow_',num2str(iCell-1)], {}, [this.sName,'.','Inflow_',num2str(iCell)], ['Flow',num2str(iCell-1),'toFlow',num2str(iCell)]);
                    % Outlet branch
                    matter.branch(this, [this.sName,'.','Outflow_',num2str(iCell)], {}, 'Outlet', 'Outlet');
                else
                    % branch between the current and the previous cell
                    matter.branch(this, [this.sName,'.','Outflow_',num2str(iCell-1)], {}, [this.sName,'.','Inflow_',num2str(iCell)], ['Flow',num2str(iCell-1),'toFlow',num2str(iCell)]);
                end
            end
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            for k = 1:length(this.aoBranches)
                solver.matter.manual.branch(this.aoBranches(k));
            end
        end
        
        function setIfFlows(this, sInterface1, sInterface2)
            if nargin == 3
                this.connectIF('Inlet' , sInterface1);
                this.connectIF('Outlet' , sInterface2);
            else
                error([this.sName,' was given a wrong number of interfaces'])
            end
        end
        
        function setInletFlow(this, fInletFlow)
            
            if fInletFlow >= 0
                this.aoBranches(1).oHandler.setFlowRate(-fInletFlow);
                this.bNegativeFlow = false;
            else
                % for negative flow rates the outlet becomes the inlet
                this.aoBranches(end).oHandler.setFlowRate(fInletFlow);
                this.bNegativeFlow = true;
            end
            
            this.setTimeStep(this.oTimer.fMinimumTimeStep);
        end
    end
    
     methods (Access = protected)
        function updateInterCellFlowrates(this, ~)
            % TO DO: currently calculation only for positive flow rate,
            % have to adapt some things to make them work for both cases
            
            % TO DO: currently the boundary conditions are flow rates on
            % both sides. Change this to have a pressure condition at the
            % outlet (depending on flow direction) and a flowrate condition
            % at the inlet
            
            mfCellPressure  = zeros(this.iCellNumber+1,   this.iInternalSteps);
            mfMassChange    = zeros(this.iCellNumber+1,   this.iInternalSteps);
            mfFlowRates     = zeros(this.iCellNumber+1,   this.iInternalSteps);
            
            mfCellMass      = zeros(this.iCellNumber,     this.iInternalSteps);
            mfPressureLoss  = zeros(this.iCellNumber,     this.iInternalSteps);
            mfDeltaFlowRate = zeros(this.iCellNumber,     this.iInternalSteps);
            
            mfTimeStep      = zeros(1, this.iInternalSteps);
            
            mfCellVolume(:,1)   = [this.toStores.(this.sName).aoPhases(2:2:end).fVolume];
           	mfCellMass(:,1)     = [this.toStores.(this.sName).aoPhases(2:2:end).fMass];
            mfFlowRates(:,1)    = [this.aoBranches.fFlowRate];
            
            
            fHelper1 = ((this.tGeometry.fArea^2) ./ mfCellVolume(1:end));
            rMaxPartialChange   = this.rMaxChange/this.iInternalSteps;
            fMaxPartialTimeStep = this.fMaximumTimeStep/this.iInternalSteps;
            fMinPartialTimeStep = this.fMinimumTimeStep/this.iInternalSteps;
            
            % get in flow side, the flow through the filter can be in both
            % directions, get the flow
            if this.bNegativeFlow
                %%
                if mfFlowRates(end,1) ~= this.aoBranches(end).oHandler.fRequestedFlowRate
                    this.setTimeStep(this.oTimer.fMinimumTimeStep);
                    return
                end
                
                mfFlowRates(1,1) = -mfFlowRates(1,1);
                
                % in case that the flow through the filter is negative, the
                % first cell contains the pressure boundary condition
                mfCellPressure(2:end,1) = [this.toStores.(this.sName).aoPhases(2:2:end).fPressure];
                mfCellPressure(1,1)     = this.aoBranches(1).coExmes{2}.oPhase.fPressure;
                
                for iStep = 1:this.iInternalSteps
                    % pressure loss calculation by setting a factor as property and
                    % factor * cell length * flow speed = pressure loss?
                    mfPressureLoss(:,iStep)  = (this.tInitialization.fFrictionFactor/(this.iCellNumber)) .* abs(mfFlowRates(1:end-1,iStep)).^2;

                    % TO DO get correct cell values  for varying flow directions
                    mfDeltaPressure = (mfCellPressure(1:end-1, iStep) - mfCellPressure(2:end, iStep)) - sign(mfFlowRates(1:end-1,iStep)).*mfPressureLoss(:,iStep);

                    mfDeltaFlowRate(:,iStep) = (mfDeltaPressure .* fHelper1);

                    mfTimeStep(1,iStep) = min(abs((rMaxPartialChange) .* mfFlowRates(1:end-1,iStep)) ./ abs(mfDeltaFlowRate(:,iStep)));

                    if mfTimeStep(1,iStep) > fMaxPartialTimeStep
                        mfTimeStep(1,iStep) = fMaxPartialTimeStep;
                    elseif isnan(mfTimeStep(1,iStep))
                        mfTimeStep(1,iStep) = fMinPartialTimeStep;
                    elseif mfTimeStep(1,iStep)  <= fMinPartialTimeStep
                        mfTimeStep(1,iStep) = fMinPartialTimeStep;
                    end

                    mfFlowRates(1:end-1, iStep+1) = mfFlowRates(1:end-1, iStep) + mfTimeStep(1,iStep) .* mfDeltaFlowRate(:,iStep);
                    mfFlowRates(end, iStep+1) = mfFlowRates(end, iStep);

                    mfCellMass(:,iStep+1) = mfCellMass(:,iStep) + ((mfFlowRates(1:end-1, iStep) - mfFlowRates(2:end, iStep)) * mfTimeStep(1,iStep));

                    mfCellPressure(2:end,iStep+1) = (mfCellMass(:,iStep+1)./mfCellMass(:,iStep)).*mfCellPressure(2:end,iStep);
                    mfCellPressure(1, iStep+1) = mfCellPressure(1, iStep);

                    mfMassChange(:,iStep) = mfFlowRates(:,iStep) * mfTimeStep(iStep);
                end
            else
                %%
                if mfFlowRates(1,1) ~= this.aoBranches(1).oHandler.fRequestedFlowRate
                    this.setTimeStep(this.oTimer.fMinimumTimeStep);
                    return
                end
                % in case that the flow through the filter is positive, the
                % last cell contains the pressure boundary condition
                mfCellPressure(1:end-1,1) = [this.toStores.(this.sName).aoPhases(2:2:end).fPressure];
                mfCellPressure(end,1)     = this.aoBranches(end).coExmes{2}.oPhase.fPressure;
                
                mfFlowRates(1,1) = - mfFlowRates(1,1);
                
                for iStep = 1:this.iInternalSteps
                    % pressure loss calculation by setting a factor as property and
                    % factor * cell length * flow speed = pressure loss?
                    mfPressureLoss(:,iStep)  = (this.tInitialization.fFrictionFactor/(this.iCellNumber)) .* abs(mfFlowRates(2:end,iStep)).^2;

                    % TO DO get correct cell values  for varying flow directions
                    mfDeltaPressure = (mfCellPressure(1:end-1, iStep) - mfCellPressure(2:end, iStep)) - sign(mfFlowRates(2:end,iStep)).*mfPressureLoss(:,iStep);

                    mfDeltaFlowRate(:,iStep) = (mfDeltaPressure .* fHelper1);

                    mfTimeStep(1,iStep) = min(abs((rMaxPartialChange) .* mfFlowRates(2:end,iStep)) ./ abs(mfDeltaFlowRate(:,iStep)));

                    if mfTimeStep(1,iStep) > fMaxPartialTimeStep
                        mfTimeStep(1,iStep) = fMaxPartialTimeStep;
                    elseif isnan(mfTimeStep(1,iStep))
                        mfTimeStep(1,iStep) = fMinPartialTimeStep;
                    elseif mfTimeStep(1,iStep)  <= fMinPartialTimeStep
                        mfTimeStep(1,iStep) = fMinPartialTimeStep;
                    end

                    mfFlowRates(2:end, iStep+1) = mfFlowRates(2:end, iStep) + mfTimeStep(1,iStep) .* mfDeltaFlowRate(:,iStep);
                    mfFlowRates(1, iStep+1) = mfFlowRates(1, iStep);

                    mfCellMass(:,iStep+1) = mfCellMass(:,iStep) + ((mfFlowRates(1:end-1, iStep) - mfFlowRates(2:end, iStep)) * mfTimeStep(1,iStep));

                    mfCellPressure(1:end-1,iStep+1) = (mfCellMass(:,iStep+1)./mfCellMass(:,iStep)).*mfCellPressure(1:end-1,iStep);
                    mfCellPressure(end, iStep+1) = mfCellPressure(end, iStep);

                    mfMassChange(:,iStep) = mfFlowRates(:,iStep) * mfTimeStep(iStep);
                end
                
            end
            
            
            if max(abs(mfFlowRates(:, this.iInternalSteps) - mfFlowRates(:, 1))) < this.fMaxSteadyStateFlowRateChange
                % Steady State case: Small discrepancies between the
                % flowrates will always remain in a dynamic calculation.
                % But if the differences are small enough this calculation
                % is used to set the correct steady state flow rates at
                % which the phase mass will no longer change. Of course
                % other effects like temperature changes will remain and
                % therefore the timestep in this case cannot be infinite
                
                mfDesorptionFlowRate = zeros(this.iCellNumber,1);
                mfAdsorptionFlowRate = zeros(this.iCellNumber,1);
                
                for iK = 1:this.iCellNumber                 
                    mfDesorptionFlowRate(iK) = this.toStores.(this.sName).toProcsP2P.(['DesorptionProcessor_',num2str(iK)]).fFlowRate;
                    mfAdsorptionFlowRate(iK) = this.toStores.(this.sName).toProcsP2P.(['AdsorptionProcessor_',num2str(iK)]).fFlowRate;
                end
                
                if this.bNegativeFlow
                    fInletFlowRate = mfFlowRates(end,1);
                    for iK = 2:length(mfFlowRates(:,1))-1
                        % TO DO: maybe bind this calculation/part of it to
                        % the update functions of the P2Ps?
                        fFlowRate = fInletFlowRate + mfAdsorptionFlowRate(iK-1) - mfDesorptionFlowRate(iK-1);
                        this.aoBranches(iK).oHandler.setFlowRate(fFlowRate);
                    end
                    fFlowRate = abs(fInletFlowRate + mfAdsorptionFlowRate(iK-1) - mfDesorptionFlowRate(iK-1));
                    this.aoBranches(1).oHandler.setFlowRate(fFlowRate);
                else
                    fInletFlowRate = mfFlowRates(1,1);
                    for iK = 2:length(mfFlowRates(:,1))
                        % TO DO: maybe bind this calculation/part of it to
                        % the update functions of the P2Ps?
                        fFlowRate = fInletFlowRate - mfAdsorptionFlowRate(iK-1) + mfDesorptionFlowRate(iK-1);
                        this.aoBranches(iK).oHandler.setFlowRate(fFlowRate);
                    end
                end
                this.setTimeStep(this.fSteadyStateTimeStep);
            else
                % dynamic case where the flow rates that were calculated by
                % the dynamic flow rate calculation are set. The overall
                % timestep is the sum over all partial time steps.
                this.setTimeStep(sum(mfTimeStep));
                mfFlowRatesNew = sum(mfMassChange,2)/this.fTimeStep;
                
                if this.bNegativeFlow
                    for iK = 2:(length(mfFlowRatesNew(:))-1)
                        this.aoBranches(iK).oHandler.setFlowRate(mfFlowRatesNew(iK));
                    end
                  	this.aoBranches(1).oHandler.setFlowRate(abs(mfFlowRatesNew(1)));
                else
                    for iK = 2:length(mfFlowRatesNew(:))
                        this.aoBranches(iK).oHandler.setFlowRate(mfFlowRatesNew(iK));
                    end
                end
                
            end
            
            this.toStores.(this.sName).setNextTimeStep(this.fTimeStep);
        end
        function exec(this, ~)
            % exec(ute) function for this system
            % Here it only calls its parent's exec function
            exec@vsys(this);
            
            this.updateInterCellFlowrates()
        end
     end
end

