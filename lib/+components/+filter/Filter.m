classdef Filter < vsys
% TO DO: Description goes here lazy guy
    
    properties (SetAccess = protected, GetAccess = public)
        
        % number of cells used in the filter model
        iCellNumber = 3;
        
        % initialization struct to set the initial parameters of the filter
        % model
        tInitialization = struct();
        % tInitialization has to be a struct with the following fields:
        %       tfMassAbsorber 	 =   Mass struct for the filter material
        %       tfMassFlow       =   Mass struct for the flow material
        %       fTemperature     =   Initial temperature of the filter in K
        %       fFlowVolume      =   free volume for the gas flow in the filter in m³
        %       fAbsorberVolume  =   volume of the absorber material in m³
        %       iCellNumber      =   number of cells used in the filter model
        %       fFrictionFactor  =
        
        % TO DO: other properties (like geometry, maybe Volume should be
        % part of geometry struct?)
        
    end
    
    methods
        function this = Filter(oParent, sName, tInitialization)
            
            this@vsys(oParent, sName, 30);
            
            this.tInitialization = tInitialization;
            this.iCellNumber = tInitialization.iCellNumber;
            
            eval(this.oRoot.oCfgParams.configCode(this));
            
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            components.filter.components.FilterStore(this, this.sName, (this.tInitialization.fFlowVolume + this.tInitialization.fAbsorberVolume));
            
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
                oFilterPhase = matter.phases.mixture(this.toStores.(this.sName), ['Absorber_',num2str(iCell)], 'solid', tfMassesAbsorber,(this.tInitialization.fAbsorberVolume/this.iCellNumber), this.tInitialization.fTemperature, 1e5);
                
                oFlowPhase = matter.phases.gas(this.toStores.(this.sName), ['Flow_',num2str(iCell)], tfMassesFlow,(this.tInitialization.fFlowVolume/this.iCellNumber), this.tInitialization.fTemperature);
                
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
                this.aoBranches(end).oHandler.setFlowRate(fInletFlow);
            else
                % for negative flow rates the outlet becomes the inlet
                this.aoBranches(1).oHandler.setFlowRate(fInletFlow);
                this.aoBranches(end).oHandler.setFlowRate(-fInletFlow);
            end
            
            this.setTimeStep(0.01);
        end
    end
    
     methods (Access = protected)
        function updateInterCellFlowrates(this, ~)
            
            %TO DO: make properties
            fArea = 1e-2;
            rMaxChange = 0.05;
            fMinimumTimeStep = 0.001;
            fMaximumTimeStep = 0.01;
            
            fSteadyStateTimeStep = 60;
            
            iInternalSteps = 100;
            
            % TO DO: currently calculation only for positive flow rate,
            % have to adapt some things to make them work for both cases
            
            % TO DO: currently the boundary conditions are flow rates on
            % both sides. Change this to have a pressure condition at the
            % outlet (depending on flow direction) and a flowrate condition
            % at the inlet
            
            mfCellPressure  = zeros(this.iCellNumber,   iInternalSteps);
            mfCellMass      = zeros(this.iCellNumber,   iInternalSteps);
            mfMassChange    = zeros(this.iCellNumber+1, iInternalSteps);
            mfFlowRates     = zeros(this.iCellNumber+1, iInternalSteps);
            mfPressureLoss  = zeros(this.iCellNumber-1, iInternalSteps);
            mfDeltaFlowRate = zeros(this.iCellNumber-1, iInternalSteps);
            mfTimeStep      = zeros(1, iInternalSteps);
            % get in flow side, the flow through the filter can be in both
            % directions, get the flow
            mfCellPressure(:,1) = [this.toStores.(this.sName).aoPhases(2:2:end).fPressure];
            mfCellVolume(:,1)   = [this.toStores.(this.sName).aoPhases(2:2:end).fVolume];
            mfCellMass(:,1)     = [this.toStores.(this.sName).aoPhases(2:2:end).fMass];
            mfFlowRates(:,1)    = [this.aoBranches.fFlowRate];
            
            if mfFlowRates(1) ~= this.aoBranches(1).oHandler.fRequestedFlowRate
            	this.setTimeStep(this.oTimer.fMinimumTimeStep);
                return
            end
            mfFlowRates(1,1) = - mfFlowRates(1,1);
            
            fHelper1 = ((fArea^2) ./ mfCellVolume(1:end-1));
            rMaxPartialChange   = rMaxChange/iInternalSteps;
            fMaxPartialTimeStep = fMaximumTimeStep/iInternalSteps;
            fMinPartialTimeStep = fMinimumTimeStep/iInternalSteps;
            
            for iStep = 1:iInternalSteps
                % pressure loss calculation by setting a factor as property and
                % factor * cell length * flow speed = pressure loss?
                mfPressureLoss(:,iStep)  = (this.tInitialization.fFrictionFactor/(this.iCellNumber-1)) .* abs(mfFlowRates(2:end-1,iStep)).^2;

                % TO DO get correct cell values  for varying flow directions
                mfDeltaPressure = (mfCellPressure(1:end-1, iStep) - mfCellPressure(2:end, iStep)) - sign(mfFlowRates(2:end-1,iStep)).*mfPressureLoss(:,iStep);
                
                mfDeltaFlowRate(:,iStep) = (mfDeltaPressure .* fHelper1);

                mfTimeStep(1,iStep) = min(abs((rMaxPartialChange) .* mfFlowRates(2:end-1,iStep)) ./ abs(mfDeltaFlowRate(:,iStep)));

                if mfTimeStep(1,iStep) > fMaxPartialTimeStep
                    mfTimeStep(1,iStep) = fMaxPartialTimeStep;
                elseif isnan(mfTimeStep(1,iStep))
                    mfTimeStep(1,iStep) = fMinPartialTimeStep;
                elseif mfTimeStep(1,iStep)  <= fMinPartialTimeStep
                    mfTimeStep(1,iStep) = fMinPartialTimeStep;
                end

                mfFlowRates(2:end-1, iStep+1) = mfFlowRates(2:end-1, iStep) + mfTimeStep(1,iStep) .* mfDeltaFlowRate(:,iStep);
                mfFlowRates(1, iStep+1) = mfFlowRates(1, iStep);
                mfFlowRates(end, iStep+1) = mfFlowRates(end, iStep);
                
                mfCellMass(:,iStep+1) = mfCellMass(:,iStep) + ((mfFlowRates(1:end-1, iStep) - mfFlowRates(2:end, iStep)) * mfTimeStep(1,iStep));
                
                mfCellPressure(:,iStep+1) = (mfCellMass(:,iStep+1)./mfCellMass(:,iStep)).*mfCellPressure(:,iStep);
                
                mfMassChange(:,iStep) = mfFlowRates(:,iStep) * mfTimeStep(iStep);
            end
            
            if max(abs(mfFlowRates(:, iInternalSteps) - mfFlowRates(:, 1))) < 1e-7
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
                
                fInletFlowRate = mfFlowRates(1,1);
                if fInletFlowRate >= 0
                    for iK = 2:length(mfFlowRates(:,1))
                        % TO DO: maybe bind this calculation/part of it to
                        % the update functions of the P2Ps?
                        fFlowRate = fInletFlowRate - mfAdsorptionFlowRate(iK-1) + mfDesorptionFlowRate(iK-1);
                        this.aoBranches(iK).oHandler.setFlowRate(fFlowRate);
                    end
                else
                    % TO DO:
                    keyboard()
                end
                this.setTimeStep(fSteadyStateTimeStep);
            else
                % dynamic case where the flow rates that were calculated by
                % the dynamic flow rate calculation are set. The overall
                % timestep is the sum over all partial time steps.
                this.setTimeStep(sum(mfTimeStep));
                mfFlowRatesNew = sum(mfMassChange,2)/this.fTimeStep;
                
                for iK = 2:(length(mfFlowRatesNew(:))-1)
                    this.aoBranches(iK).oHandler.setFlowRate(mfFlowRatesNew(iK));
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

