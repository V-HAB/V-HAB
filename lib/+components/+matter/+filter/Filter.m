classdef Filter < vsys
% This is a model of a Filter/Asorber that removes certain substances from
% a gas stream. The typical example for such a component is a CO2 scrubber
% filled with Zeolite. Please view the comments for the properties for
% information about the required input variables!
%
% WARNING: Each cell is composed of two phases (one gas one mixture phase)
% for the flow and the absorber material respectivly. Additionally for each
% cell two additional P2Ps and one additional branch are required.
% Therefore using a very high number of cells will result in a slow model
% assembly.
    
    properties (SetAccess = public, GetAccess = public)
        
        % fSteadyStateTimeStep defines the time step that will be used once
        % the steady state has been reached
        fSteadyStateTimeStep = 60;
        
        % fMaxSteadyStateFlowRateChange is the criterion for when the
        % steady state has been reached. It defines the maximum difference
        % between the current and the new mass flow in %. For example a
        % value of 1e-3 means that if the flow rate changes less than 0.1%
        % the solver assumes it has reached steady state conditions
        fMaxSteadyStateFlowRateChange = 1e-3;
        
        mfAdsorptionFlowRate;
        mfAdsorptionHeatFlow;
    end

    properties (SetAccess = protected, GetAccess = public)
        % rMaxChange defines the maximum percentage by which the flow rate
        % can change within one (total) time step
        rMaxChange = 0.05;
        
        % fMinimumTimeStep defines the minimal total time step
        fMinimumTimeStep = 1e-8;

        % fMaximumTimeStep defines the maximum total time step during
        % dynamic calculations
        fMaximumTimeStep = 1;
        
        % Number of internal partial steps used in the flow rate
        % calculation. In principle the total time step is split into
        % several smaller internal ones for the flow rate calculation and
        % this number defines how many of these partial steps will be made
        iInternalSteps = 100;
        
        rMaxPartialChange;
        fMaxPartialTimeStep;
        fMinPartialTimeStep;
            
        % number of cells used in the filter model
        iCellNumber;
        
        % initialization struct to set the initial parameters of the filter
        % model
        tInitialization = struct();
        % tInitialization has to be a struct with the following fields:
        %       tfMassAbsorber            =   Mass struct for the filter material
        %       tfMassFlow                =   Mass struct for the flow material
        %       fTemperature              =   Initial temperature of the filter in K
        %       iCellNumber               =   number of cells used in the filter model
        %       fFrictionFactor           =   Factor used to calculate the pressure loss 
        %                                     by multiplying it with the MassFlow^2
        %       mfMassTransferCoefficient =   coefficient to calculate the mass transfer to the absorber 
        %                                     (see e.g. k_m from ICES-2014-168 table 3) has to be zero for 
        %                                     all substances that should not be absorbed. Unit is 1/s !!!
        
        % Possible alternative for the Friction Factor would be to use a
        % Hydraulic Diameter and length defined by the user for the pipe
        % pressure loss equation
        
        % struct that contains information about the geometry of the filter
        tGeometry;
        % Geometry struct for the filter with the following field:
        %       fArea                   =   Area perpendicular to the flow direction in m²
        %       fFlowVolume             =   free volume for the gas flow in the filter in m³
        %       fAbsorberVolume         =   volume of the absorber material in m³
        %       fAbsorberSurfaceArea    =   assumed total surface area for the absorber material 
        %       fMaximumFreeGasDistance =   
        
        % boolean to easier decide if the flow rate through the filter is
        % negative
        bNegativeFlow = false;
        
        bDynamicFlowRates = true;
        
        mfDensitiesOld;
        
        % the heating power of the electrical heater attached to this filter
        % can be changed by using the setHeaterPower function
        fHeaterPower = 0;
        
        % struct that contains information about the property from the last
        % update that is used to decide if recalculations should be made or
        % not
        tLastUpdateProps;
        
        mfCellVolume;
        fHelper1;
    end
    
    methods
        function this = Filter(oParent, sName, tInitialization, tGeometry, bDynamicFlowRates)
            this@vsys(oParent, sName, 1);
            
            % The initialization struct is saved as property to be used
            % during the createMatterStructure function
            this.tInitialization = tInitialization;
            % The cell number is also stored as individual property since
            % it is required multiple times
            this.iCellNumber = tInitialization.iCellNumber;
            
            % the geometry struct with additional geometrical information
            % is also saved as property
            this.tGeometry = tGeometry;

            % The struct that contains the references for the properties at
            % the last update is initialized with vectors containing zeros
            this.tLastUpdateProps.mfDensity              = zeros(this.iCellNumber,1);
            this.tLastUpdateProps.mfFlowSpeed            = zeros(this.iCellNumber,1);
            this.tLastUpdateProps.mfSpecificHeatCapacity = zeros(this.iCellNumber,1);
                
            eval(this.oRoot.oCfgParams.configCode(this));
            
            this.mfAdsorptionFlowRate   = zeros(this.iCellNumber,1);
            this.mfAdsorptionHeatFlow 	= zeros(this.iCellNumber,1);
            
            this.rMaxPartialChange   = this.rMaxChange/this.iInternalSteps;
            this.fMaxPartialTimeStep = this.fMaximumTimeStep/this.iInternalSteps;
            this.fMinPartialTimeStep = this.fMinimumTimeStep/this.iInternalSteps;
            
            if nargin > 4
                this.bDynamicFlowRates = bDynamicFlowRates;
            end
            
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            % A special filter store has to be used for the filter to
            % prevent the gas phase volume from beeing overwritten since
            % more than one gas phase is used to implement several cells
            components.matter.filter.components.FilterStore(this, this.sName, (this.tGeometry.fFlowVolume + this.tGeometry.fAbsorberVolume));
            
            % The filter and flow phase total masses provided in the
            % tInitialization struct have to be divided by the number of
            % cells to obtain the tfMass struct for each phase of each
            % cell. Currently the assumption here is that each cell has the
            % same size.
            csAbsorberSubstances = fieldnames(this.tInitialization.tfMassAbsorber);
            for iK = 1:length(csAbsorberSubstances)
                tfMassesAbsorber.(csAbsorberSubstances{iK}) = this.tInitialization.tfMassAbsorber.(csAbsorberSubstances{iK})/this.iCellNumber;
            end
            csFlowSubstances = fieldnames(this.tInitialization.tfMassFlow);
            for iK = 1:length(csFlowSubstances)
                tfMassesFlow.(csFlowSubstances{iK}) = this.tInitialization.tfMassFlow.(csFlowSubstances{iK})/this.iCellNumber;
            end
            
            % Now the phases, exmes, p2ps and branches and thermal
            % representation for the filter model can be created. A for
            % loop is used to allow any number of cells from 2 upwards.
            moCapacity = cell(this.iCellNumber,2);
            for iCell = 1:this.iCellNumber
                % The absorber phases contain the material that removes
                % certain substances from the gas phase which is
                % represented in the flow phases. To better track these the
                % Phase names contain the cell number at the end.
                oFilterPhase = matter.phases.mixture(this.toStores.(this.sName), ['Absorber_',num2str(iCell)], 'solid', tfMassesAbsorber,(this.tGeometry.fAbsorberVolume/this.iCellNumber), this.tInitialization.fTemperature, 1e5);
                
                oFlowPhase = matter.phases.gas(this.toStores.(this.sName), ['Flow_',num2str(iCell)], tfMassesFlow,(this.tGeometry.fFlowVolume/this.iCellNumber), this.tInitialization.fTemperature);
               	
                % An individual adsorption and desorption Exme and P2P is
                % required because it is possible that a few substances are
                % beeing desorbed at the same time as others are beeing
                % adsorbed
                matter.procs.exmes.mixture(oFilterPhase, ['Adsorption_',num2str(iCell)]);
                matter.procs.exmes.mixture(oFilterPhase, ['Desorption_',num2str(iCell)]);
                
                % for the flow phase two addtional exmes for the gas flow
                % through the filter are required
                matter.procs.exmes.gas(oFlowPhase, ['Adsorption_',num2str(iCell)]);
                matter.procs.exmes.gas(oFlowPhase, ['Desorption_',num2str(iCell)]);
                matter.procs.exmes.gas(oFlowPhase, ['Inflow_',num2str(iCell)]);
                matter.procs.exmes.gas(oFlowPhase, ['Outflow_',num2str(iCell)]);
                
                % in order to correctly create the thermal interface a heat
                % source is added to each of the phases
                oHeatSource = thermal.heatsource(this, ['AbsorberHeatSource_',num2str(iCell)], 0);
                moCapacity{iCell,1} = this.addCreateCapacity(oFilterPhase, oHeatSource);
                
                oHeatSource = thermal.heatsource(this, ['FlowHeatSource_',num2str(iCell)], 0);
                moCapacity{iCell,2} = this.addCreateCapacity(oFlowPhase, oHeatSource);
                
                % adding two P2P processors, one for desorption and one for
                % adsorption. Two independent P2Ps are required because it
                % is possible that one substance is currently absorber
                % while another is desorbing which results in two different
                % flow directions that can occur at the same time.
                components.matter.filter.components.Desorption_P2P(this.toStores.(this.sName), ['DesorptionProcessor_',num2str(iCell)], ['Absorber_',num2str(iCell),'.Desorption_',num2str(iCell)], ['Flow_',num2str(iCell),'.Desorption_',num2str(iCell)]);
                components.matter.filter.components.Adsorption_P2P(this.toStores.(this.sName), ['AdsorptionProcessor_',num2str(iCell)], ['Flow_',num2str(iCell),'.Adsorption_',num2str(iCell)], ['Absorber_',num2str(iCell),'.Adsorption_',num2str(iCell)], this.tInitialization.mfMassTransferCoefficient);
                
                % Each cell is connected to the next cell by a branch, the
                % first and last cell also have the inlet and outlet branch
                % attached that connects the filter to the parent system
                if iCell == 1
                    % Inlet branch
                    matter.branch(this, [this.sName,'.','Inflow_',num2str(iCell)], {}, 'Inlet', 'Inlet');
                    % for the first cell only the conductor between the
                    % absorber and the flow phase has to be defined
                    this.addConductor(thermal.conductors.linear(this, moCapacity{iCell,1}, moCapacity{iCell,2}, 0, ['ConvectiveConductor_', num2str(iCell)]));
                elseif iCell == this.iCellNumber
                    % branch between the current and the previous cell
                    matter.branch(this, [this.sName,'.','Outflow_',num2str(iCell-1)], {}, [this.sName,'.','Inflow_',num2str(iCell)], ['Flow',num2str(iCell-1),'toFlow',num2str(iCell)]);
                    % Outlet branch
                    matter.branch(this, [this.sName,'.','Outflow_',num2str(iCell)], {}, 'Outlet', 'Outlet');
                    % for the last cell only the conductor between the
                    % absorber and the flow phase has to be defined
                    this.addConductor(thermal.conductors.linear(this, moCapacity{iCell,1}, moCapacity{iCell,2}, 0, ['ConvectiveConductor_', num2str(iCell)]));

                else
                    % branch between the current and the previous cell
                    matter.branch(this, [this.sName,'.','Outflow_',num2str(iCell-1)], {}, [this.sName,'.','Inflow_',num2str(iCell)], ['Flow',num2str(iCell-1),'toFlow',num2str(iCell)]);
                    % Create and add linear conductors between each cell
                    % absorber material to reflect the thermal conductance
                    % of the absorber material
                    this.addConductor(thermal.conductors.linear(this, moCapacity{iCell-1,1}, moCapacity{iCell,1}, this.tInitialization.fConductance));
                    % and also add a conductor between the absorber
                    % material and the flow phase for each cell to
                    % implement the convective heat transfer
                    this.addConductor(thermal.conductors.linear(this, moCapacity{iCell,1}, moCapacity{iCell,2}, 0, ['ConvectiveConductor_', num2str(iCell)]));
                end
            end
            
            this.mfCellVolume(:,1)   = [this.toStores.(this.sName).aoPhases(2:2:end).fVolume];
           	
            this.mfDensitiesOld(:,1) = [this.toStores.(this.sName).aoPhases(2:2:end).fDensity]; 
            
            % in order to save calculation steps this helper is only
            % calculated once and then used in all iterations since it
            % remains constant.
            this.fHelper1 = ((this.tGeometry.fArea^2) ./ this.mfCellVolume);
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            % the filter model uses manual branches because it has a
            % dedicated flow rate calculation implemented into a specific
            % function that simply sets the correct flowrates into these
            % manual branches
            for k = 1:length(this.aoBranches)
                solver.matter.manual.branch(this.aoBranches(k));
            end
            
            if this.bDynamicFlowRates
                for k = 1:length(this.toStores.(this.sName).aoPhases)
                    this.toStores.(this.sName).aoPhases(k).rMaxChange = inf;
                end
            else
                for k = 1:length(this.toStores.(this.sName).aoPhases)
                    this.toStores.(this.sName).aoPhases(k).rMaxChange = this.rMaxPartialChange;
                end
                
            end
            
            % adds the lumped parameter thermal solver to calculate the
            % convective and conductive heat transfer
            this.oThermalSolver = solver.thermal.lumpedparameter(this);
            
            % sets the minimum time step that can be used by the thermal
            % solver
            this.oThermalSolver.fMinimumTimeStep = 1e-1;
        end
        
        function setIfFlows(this, sInterface1, sInterface2)
            % the filter only has two interfaces, an Inlet and an Outlet.
            % The inlet is defined as the interface through which the gas
            % enters the filter for positive flow rates. While the outlet
            % is defined as the Interface through which the gas exists the
            % filter for positive flow rates. The flow rate through the
            % filter can also be negative but this does not change the
            % naming definition.
            if nargin == 3
                this.connectIF('Inlet' , sInterface1);
                this.connectIF('Outlet' , sInterface2);
            else
                error([this.sName,' was given a wrong number of interfaces'])
            end
        end
        
        function setInletFlow(this, fInletFlow)
            
            if this.bDynamicFlowRates
                % in order to correctly set the inlet flow rate for the filter
                % this function has to be used. It can handle both positive and
                % negative flow rates (and zero) and sets all necessary
                % parameters correctly to enable calculation of the remaining
                % flowrates
                if fInletFlow >= 0
                    this.aoBranches(1).oHandler.setFlowRate(-fInletFlow);
                    this.bNegativeFlow = false;
                else
                    % for negative flow rates the outlet becomes the inlet
                    this.aoBranches(end).oHandler.setFlowRate(fInletFlow);
                    this.bNegativeFlow = true;
                end
                
            else
                % For Non Dynamic Flow Rate calculation the changes are
                % simply set for ALL branches at the same time
                
                
                
                if fInletFlow >= 0
                   	this.bNegativeFlow = false;
                    fVolumetricFlow = fInletFlow/this.aoBranches(1).coExmes{2}.oPhase.fDensity;
                    this.aoBranches(1).oHandler.setFlowRate(-fInletFlow);
                    
                    for iK = (2:length(this.aoBranches))
                        % Assuming a constant volumetric flow rate is
                        % entering the filter
                        % TO DO: Check if generally a volumetric flow rate
                        % should be set
                        fFlowRate = fVolumetricFlow * this.toStores.Filter.aoPhases((iK-1)*2).fDensity;
                        this.aoBranches(iK).oHandler.setFlowRate(fFlowRate);
                    end
                
                else
                    this.bNegativeFlow = true;
                    fVolumetricFlow = fInletFlow/this.aoBranches(end).coExmes{2}.oPhase.fDensity;
                    
                    this.aoBranches(end).oHandler.setFlowRate(fInletFlow);
                    fFlowRate = fVolumetricFlow * this.toStores.Filter.aoPhases(2).fDensity;
                    this.aoBranches(1).oHandler.setFlowRate(-fFlowRate);
                    
                    for iK = (2:length(this.aoBranches)-1)
                        % Assuming a constant volumetric flow rate is
                        % entering the filter
                        % TO DO: Check if generally a volumetric flow rate
                        % should be set
                        fFlowRate = fVolumetricFlow * this.toStores.Filter.aoPhases((iK)*2).fDensity;
                        this.aoBranches(iK).oHandler.setFlowRate(fFlowRate);
                    end
                end
                
            end
            
            % since this usually represents a very heavy impact on the
            % operating conditions of the filter its timestep will be set
            % to the minimum for the next tick.
            this.setTimeStep(this.oTimer.fMinimumTimeStep);
        end
        
        function setHeaterPower(this, fPower)
            % this function is used to set the power of the electrical
            % heaters inside the filter. If no heaters are used just leave
            % this property at zero at all times.
            this.fHeaterPower = fPower;
            
            % in case that a new heater power was set the function to
            % recalculate the thermal properties of the filter has to be
            % called to ensure that the change is recoginzed by the model
            this.calculateThermalProperties();
        end
        
        function setNumericProperties(this,rMaxChange,fMinimumTimeStep,fMaximumTimeStep, iInternalSteps)
            % in order to only recalculate these properties when they are
            % actually reset a specific function has to be used to set them
            
            this.rMaxChange = rMaxChange;

            this.fMinimumTimeStep = fMinimumTimeStep;

            this.fMaximumTimeStep = fMaximumTimeStep;
            
            this.iInternalSteps = iInternalSteps;
            
            % the numerical properties of the filter give the overall
            % allowed changes and timesteps over one complete step. In
            % order to increase the maximum allowable timestep the solver
            % divides this into several internal steps (if the user chose
            % this option)
            this.rMaxPartialChange   = this.rMaxChange/this.iInternalSteps;
            this.fMaxPartialTimeStep = this.fMaximumTimeStep/this.iInternalSteps;
            this.fMinPartialTimeStep = this.fMinimumTimeStep/this.iInternalSteps;
        end
        
    end
    
     methods (Access = protected)
        function updateInterCellFlowrates(this, ~)
            
            % Check if Update is necessary based on the comparison of the
            % flow phase densities:
            
            % TO DO: THe density of the phases has to be calculated based
            % on the current temperature and pressure in the phase (since
            % otherwise the temperature effects are completly neglected)
            mfDensities(:,1) = [this.toStores.(this.sName).aoPhases(2:2:end).fDensity]; 
            
            rDensityChange = abs((this.mfDensitiesOld-mfDensities)./this.mfDensitiesOld);
            
          	if ~this.bNegativeFlow
             	fInletFlow = -this.aoBranches(1).oHandler.fFlowRate;
              	fVolumetricFlow = fInletFlow/this.aoBranches(1).coExmes{2}.oPhase.fDensity;

                for iK = (2:length(this.aoBranches))
                    if rDensityChange(iK-1) > this.rMaxChange
                        % Assuming a constant volumetric flow rate is
                        % entering the filter
                        % TO DO: Check if generally a volumetric flow rate
                        % should be set
                        fFlowRate = fVolumetricFlow * this.toStores.Filter.aoPhases((iK-1)*2).fDensity;
                        this.aoBranches(iK).oHandler.setFlowRate(fFlowRate);
                        this.mfDensitiesOld(iK-1) = mfDensities(iK-1);
                    end
                end
            else
                fInletFlow = this.aoBranches(end).oHandler.fFlowRate;
                fVolumetricFlow = fInletFlow/this.aoBranches(end).coExmes{2}.oPhase.fDensity;
                fFlowRate = fVolumetricFlow * this.toStores.Filter.aoPhases(2).fDensity;
                this.aoBranches(1).oHandler.setFlowRate(-fFlowRate);
                
                for iK = (2:length(this.aoBranches)-1)
                    if rDensityChange(iK) > this.rMaxChange


                        % Assuming a constant volumetric flow rate is
                        % entering the filter
                        % TO DO: Check if generally a volumetric flow rate
                        % should be set
                        fFlowRate = fVolumetricFlow * this.toStores.Filter.aoPhases((iK)*2).fDensity;
                        this.aoBranches(iK).oHandler.setFlowRate(fFlowRate);
                        this.mfDensitiesOld(iK) = mfDensities(iK);
                    end
                end
            end
                    
            % Sets the update time step to the same as the filter
            this.setTimeStep(this.toStores.Filter.fTimeStep);
        end
        function updateInterCellFlowratesDynamic(this, ~)
            % this function is used to calculate the flowrates between the
            % cells of the filter model. It uses a simplified
            % incompressible solution algorithm that was adopted
            % specifically to work for the one dimensional filter model
            % case.
            
            % initialization of the required vectors and matrices
            mfCellPressure  = zeros(this.iCellNumber+1,   this.iInternalSteps);
            mfMassChange    = zeros(this.iCellNumber+1,   this.iInternalSteps);
            mfFlowRates     = zeros(this.iCellNumber+1,   this.iInternalSteps);
            
            mfCellMass      = zeros(this.iCellNumber,     this.iInternalSteps);
            mfPressureLoss  = zeros(this.iCellNumber,     this.iInternalSteps);
            mfDeltaFlowRate = zeros(this.iCellNumber,     this.iInternalSteps);
            
            mfTimeStep      = zeros(1, this.iInternalSteps);
            
            mfCellMass(:,1)     = [this.toStores.(this.sName).aoPhases(2:2:end).fMass];
            mfFlowRates(:,1)    = [this.aoBranches.fFlowRate];
            
            % the bNegatitveFlow property is set by the setInFlow function
            % of the filter and specifies wether the flow is going in
            % positive or negative direction. This saves time on the if
            % querys since it only has to evaulate a boolean
            if this.bNegativeFlow
                % if the flow rate and the requested flow rate of the inlet
                % branch do not match the filter model will abort this
                % calculation and recalculate after one minimal time step
                if abs(mfFlowRates(end,1)) ~= abs(this.aoBranches(end).oHandler.fRequestedFlowRate)
                    this.setTimeStep(this.oTimer.fMinimumTimeStep);
                    return
                end
                
                % the flowrate through the inlet branch (inlet with respect
                % to positive flow direction) is negative for an overall
                % positive flow rate through the filter and positive for an
                % overall negative flow rate through the filter. This is a
                % result of the interface definition in V-HAB. For that
                % reason the sign of the first flow rate has to be changed
                % to get conformity with the other flow rates
                mfFlowRates(1,1) = -mfFlowRates(1,1);
                
                % in case that the flow through the filter is negative, the
                % first cell contains the pressure boundary condition
                mfCellPressure(2:end,1) = [this.toStores.(this.sName).aoPhases(2:2:end).fPressure];
                mfCellPressure(1,1)     = this.aoBranches(1).coExmes{2}.oPhase.fPressure;
                
                % Now the internal steps can be performed. Note that this
                % is not an iteration (it would be possible to add that as
                % well) but just an internal calculation with smaller
                % timesteps
                for iStep = 1:this.iInternalSteps
                    % pressure loss is calculated by multiplying the
                    % friction factor with the mass flow^2. An alternative
                    % way to calculate this would be the pressure loss
                    % calculation for pipes using a specified length and
                    % hydraulic diameter
                    mfPressureLoss(:,iStep)  = (this.tInitialization.fFrictionFactor/(this.iCellNumber)) .* abs(mfFlowRates(1:end-1,iStep)).^2;
                    
                    % the overall pressure difference between the cells is
                    % defined as the difference between the two cell
                    % pressures and from that the pressure loss is
                    % subtracted (times the sign of the mass flow to ensure
                    % it always acts against it)
                    mfDeltaPressure = (mfCellPressure(1:end-1, iStep) - mfCellPressure(2:end, iStep)) - sign(mfFlowRates(1:end-1,iStep)).*mfPressureLoss(:,iStep);
                    
                    % With the pressure difference between the cells the
                    % difference of the mass flow per time can be
                    % calculated for each cell:
                    mfDeltaFlowRate(:,iStep) = (mfDeltaPressure .* this.fHelper1);
                    % The following equations are used in the calculation of the new mass flow:
                    % F = m*a --> P*A = V_cell*rho*a
                    % massflow(t+delta_t) = massflow(t) + rho*A*delta_flowspeed
                    % delta_flowspeed = a*delta_t
                    % massflow(t+delta_t) = massflow(t) + rho*A*(P*A/V_cell*rho)*delta_t
                    % massflow(t+delta_t) = massflow(t) + A*(P*A/V_cell)*delta_t
                    % --> DeltaMassFlow = (P*A^2/V_cell) = fHelper1

                    % the highest possible internal time step can now be
                    % calculated based on the current mass change for each
                    % cell and the current cell mass
                    mfTimeStep(1,iStep) = min(abs(((this.rMaxPartialChange) .* mfCellMass(:,iStep))/((mfFlowRates(1:end-1, iStep) - mfFlowRates(2:end, iStep))))); 
                    
                    % in case the time step is outside of the defined
                    % boundaries it is reset to these boundaries
                    if mfTimeStep(1,iStep) > this.fMaxPartialTimeStep
                        mfTimeStep(1,iStep) = this.fMaxPartialTimeStep;
                    elseif isnan(mfTimeStep(1,iStep))
                        mfTimeStep(1,iStep) = this.fMinPartialTimeStep;
                    elseif mfTimeStep(1,iStep)  <= this.fMinPartialTimeStep
                        mfTimeStep(1,iStep) = this.fMinPartialTimeStep;
                    end

                    % now the new flow rates can be calculated based on the
                    % equation derived above
                    % massflow(t+delta_t) = massflow(t) + A*(P*A/V_cell)*delta_t
                    mfFlowRates(1:end-1, iStep+1) = mfFlowRates(1:end-1, iStep) + mfTimeStep(1,iStep) .* mfDeltaFlowRate(:,iStep) + this.mfAdsorptionFlowRate;
                    % since one boundary condition is a flow rate this
                    % flowrate is simply kept constant for all steps
                    mfFlowRates(end, iStep+1) = mfFlowRates(end, iStep);
                    
                    iCounter = 0;
                    fError = 1;

                    while fError > 1e-2 && iCounter < 500
                        mfTimeStep(1,iStep) = min(abs((this.rMaxChange/iDesorbCells .* mfCellMass(:,iStep))./(( mfFlowRates(1:end-1, iStep+1) -  mfFlowRates(2:end, iStep+1))))); 

                        mfNewInterimFlowRate(2:end) = (mfNewInterimFlowRate(2:end) + (mfFlowRates(2:end, iStep) + mfTimeStep(1,iStep) .* mfDeltaFlowRate(:,iStep)))./2;

                        fError = max(abs((mfNewInterimFlowRate - mfFlowRates(2:end, iStep+1))));
                        mfFlowRates(1:end-1, iStep+1) = mfNewInterimFlowRate;
                        iCounter = iCounter+1;
                    end
                    % now an estimate for the new cell mass after this step
                    % can be calculated
                    mfCellMass(:,iStep+1) = mfCellMass(:,iStep) + ((mfFlowRates(1:end-1, iStep) - mfFlowRates(2:end, iStep)) * mfTimeStep(1,iStep));

                    % and from this an estimate for the new cell pressure
                    mfCellPressure(2:end,iStep+1) = (mfCellMass(:,iStep+1)./mfCellMass(:,iStep)).*mfCellPressure(2:end,iStep);
                    % the second boundary condition is the pressure which
                    % is set here
                    mfCellPressure(1, iStep+1) = mfCellPressure(1, iStep);
                    
                    % to simplify the calculation of the overall flowrate
                    % the mass change for each internal step is calculated
                    mfMassChange(:,iStep) = mfFlowRates(:,iStep) * mfTimeStep(iStep);
                end
            else
                % this part covers the calculation for a positive flowrate
                % which uses the same logic as the approach for the
                % negative flowrate above. The difference is in the
                % boundary conditions and which cell properties are
                % attributed to which flow
                if abs(mfFlowRates(1,1)) ~= abs(this.aoBranches(1).oHandler.fRequestedFlowRate)
                    this.setTimeStep(this.oTimer.fMinimumTimeStep);
                    return
                end
                
                mfCellPressure(1:end-1,1) = [this.toStores.(this.sName).aoPhases(2:2:end).fPressure];
                mfCellPressure(end,1)     = this.aoBranches(end).coExmes{2}.oPhase.fPressure;
                
                mfFlowRates(1,1) = - mfFlowRates(1,1);
                
                for iStep = 1:this.iInternalSteps
                    mfPressureLoss(:,iStep)  = (this.tInitialization.fFrictionFactor/(this.iCellNumber)) .* abs(mfFlowRates(2:end,iStep)).^2;
                    
                    mfDeltaPressure = (mfCellPressure(1:end-1, iStep) - mfCellPressure(2:end, iStep)) - sign(mfFlowRates(2:end,iStep)).*mfPressureLoss(:,iStep);
                    
                    mfDeltaFlowRate(:,iStep) = (mfDeltaPressure .* this.fHelper1);
                    
                    mfTimeStep(1,iStep) = min(abs((this.rMaxPartialChange .* mfCellMass(:,iStep))./((mfFlowRates(1:end-1, iStep) - mfFlowRates(2:end, iStep))))); 
                    
                    if mfTimeStep(1,iStep) > this.fMaxPartialTimeStep
                        mfTimeStep(1,iStep) = this.fMaxPartialTimeStep;
                    elseif isnan(mfTimeStep(1,iStep))
                        mfTimeStep(1,iStep) = this.fMinPartialTimeStep;
                    elseif mfTimeStep(1,iStep)  <= this.fMinPartialTimeStep
                        mfTimeStep(1,iStep) = this.fMinPartialTimeStep;
                    end
                    
                    mfNewInterimFlowRate = mfFlowRates(2:end, iStep) + mfTimeStep(1,iStep) .* mfDeltaFlowRate(:,iStep);
                    
                    % another limiting factor for the time step is the fact
                    % that the pressure loss should not be allowed to act as
                    % a driving force. Therefore, it is necessary to reduce
                    % the time step far enough that no sign switch of the
                    % flowrate occurs within one timestep
                    bDirectionSwitch = sign(mfNewInterimFlowRate) ~= (sign(mfFlowRates(2:end, iStep)));
                    % the sign functions also calls a change if 0 is
                    % changed to positive or negative value. These cases
                    % should not be considered sign changes for this logic
                    bDirectionSwitch(mfFlowRates(2:end, iStep) == 0) = false;
                    
                    mfInterimFlowRate = mfFlowRates(2:end, iStep);
                    
                    fMaxTimeStepDirectionChange = min(abs(0.1*mfInterimFlowRate(bDirectionSwitch)./mfDeltaFlowRate(bDirectionSwitch,iStep)));
                    if mfTimeStep(1,iStep) > fMaxTimeStepDirectionChange
                        mfTimeStep(1,iStep) = fMaxTimeStepDirectionChange;
                        
                        if mfTimeStep(1,iStep) > this.fMaxPartialTimeStep
                            mfTimeStep(1,iStep) = this.fMaxPartialTimeStep;
                        elseif isnan(mfTimeStep(1,iStep))
                            mfTimeStep(1,iStep) = this.fMinPartialTimeStep;
                        elseif mfTimeStep(1,iStep)  <= this.fMinPartialTimeStep
                            mfTimeStep(1,iStep) = this.fMinPartialTimeStep;
                        end
                        
                        mfNewInterimFlowRate = mfFlowRates(2:end, iStep) + mfTimeStep(1,iStep) .* mfDeltaFlowRate(:,iStep);
                    end
                    
                    mfNewInterimFlowRate(mfNewInterimFlowRate > this.mfAdsorptionFlowRate) = mfNewInterimFlowRate(mfNewInterimFlowRate > this.mfAdsorptionFlowRate) - this.mfAdsorptionFlowRate(mfNewInterimFlowRate > this.mfAdsorptionFlowRate);
                    
                    mfFlowRates(2:end, iStep+1) = mfNewInterimFlowRate;
                    
                    mfFlowRates(1, iStep+1) = mfFlowRates(1, iStep);

                    mfCellMass(:,iStep+1) = mfCellMass(:,iStep) + ((mfFlowRates(1:end-1, iStep) - mfFlowRates(2:end, iStep)) * mfTimeStep(1,iStep));

                    mfCellPressure(1:end-1,iStep+1) = (mfCellMass(:,iStep+1)./mfCellMass(:,iStep)).*mfCellPressure(1:end-1,iStep);
                    mfCellPressure(end, iStep+1) = mfCellPressure(end, iStep);

                    mfMassChange(:,iStep) = mfFlowRates(:,iStep) * mfTimeStep(iStep);
                end
                
            end
            
            % check if steady state simplification can be used
            if max(abs((mfFlowRates(:, this.iInternalSteps) - mfFlowRates(:, 1))./mfFlowRates(:, 1)) - abs(this.fMaxSteadyStateFlowRateChange.*mfFlowRates(:, 1))) < 0
                % Steady State case: Small discrepancies between the
                % flowrates will always remain in a dynamic calculation.
                % But if the differences are small enough this calculation
                % is used to set the correct steady state flow rates at
                % which the phase mass will no longer change. Of course
                % other effects like temperature changes will remain and
                % therefore the timestep in this case cannot be infinite
                
                if this.bNegativeFlow
                    fInletFlowRate = mfFlowRates(end,1);
                    for iK = 2:length(mfFlowRates(:,1))-1
                        % TO DO: maybe bind this calculation/part of it to
                        % the update functions of the P2Ps?
                        fFlowRate = fInletFlowRate + this.mfAdsorptionFlowRate(iK-1);
                        this.aoBranches(iK).oHandler.setFlowRate(fFlowRate);
                    end
                    fFlowRate = abs(fInletFlowRate + this.mfAdsorptionFlowRate(iK-1));
                    this.aoBranches(1).oHandler.setFlowRate(fFlowRate);
                else
                    fInletFlowRate = mfFlowRates(1,1);
                    for iK = 2:length(mfFlowRates(:,1))
                        % TO DO: maybe bind this calculation/part of it to
                        % the update functions of the P2Ps?
                        fFlowRate = fInletFlowRate - this.mfAdsorptionFlowRate(iK-1);
                        this.aoBranches(iK).oHandler.setFlowRate(fFlowRate);
                    end
                end
                keyboard()
                this.setTimeStep(this.fSteadyStateTimeStep);
            else
                % dynamic case where the flow rates that were calculated by
                % the dynamic flow rate calculation are set. 
                
                % The overall timestep is the sum over all partial time steps.
                this.setTimeStep(sum(mfTimeStep));
                % The overall flow rate that has to be set is the sum over
                % all internally calculated time steps multiplied with each
                % internal time step and then divided with the overall
                % time step to calculate the time averaged flow rate that
                % results in the same mass changes as the integral over all
                % internal flow rates
                mfFlowRatesNew = sum(mfMassChange,2)/this.fTimeStep;
                
                % for negative and positive flow cases the boundary
                % condition changes the sides and therefore the location of
                % the flow that does not have to be set changes sides
                if this.bNegativeFlow
                    for iK = 2:(length(mfFlowRatesNew(:))-1)
                        this.aoBranches(iK).oHandler.setFlowRate(mfFlowRatesNew(iK));
                    end
                    this.aoBranches(1).oHandler.setFlowRate(-mfFlowRatesNew(1));
                else
                    for iK = 2:length(mfFlowRatesNew(:))
                        this.aoBranches(iK).oHandler.setFlowRate(mfFlowRatesNew(iK));
                    end
                end
            end
            
            if any(abs(mfFlowRatesNew) > 1e5)
                keyboard()
            end
            % sets the update of the store and phases to be in tune with
            % the updated flow rates. Otherwise changes in the flow rate
            % will be reflected in the pressures too slow
            % TO DO: this should be optimizable by setting the rMaxChange
            % of each phase, however when i tested that it did not work as
            % well. So for now this version will be used as it definitly
            % works
            this.toStores.(this.sName).setNextTimeStep(this.fTimeStep);
        end
        
        function calculateThermalProperties(this)
            
            % Sets the heat source power in the absorber material as a
            % combination of the heat of absorption and the heater power.
            % Note that the heater power can also be negative resulting in
            % cooling.
            mfHeatFlow              = zeros(this.iCellNumber,1);
            for iCell = 1:this.iCellNumber
                mfHeatFlow(iCell)              = this.mfAdsorptionHeatFlow(iCell) + this.fHeaterPower/this.iCellNumber;
                
                                              % Subsystem ,     , Store,                                              
                oCapacity = this.poCapacities([this.sName ,'__',this.sName,'__Absorber_',num2str(iCell)]);
                oCapacity.oHeatSource.setPower(mfHeatFlow(iCell));
            end
            
            % Now the convective heat transfer between the absorber material
            % and the flow phases has to be calculated
            
            % alternative solution for the case without flowspeed? Use
            % just thermal conductivity of fluid and the MaxFreeDistance to
            % calculate a HeatTransferCoeff?
            % D_Hydraulic and fLength defined in geometry struct
            mfDensity                       = zeros(this.iCellNumber,1);
            mfFlowSpeed                     = zeros(this.iCellNumber,1);
            mfSpecificHeatCapacity          = zeros(this.iCellNumber,1);
            mfHeatTransferCoefficient       = zeros(this.iCellNumber,1);
            aoPhase                         = cell(this.iCellNumber,1);
            fLength = (this.tGeometry.fFlowVolume/this.tGeometry.fD_Hydraulic)/this.iCellNumber;
            
            % gets the required properties for each cell and stores them in
            % variables for easier access
          	for iCell = 1:this.iCellNumber
                mfDensity(iCell)                = this.toStores.(this.sName).aoPhases(iCell*2).fDensity;
                mfFlowSpeed(iCell)              = (abs(this.aoBranches(iCell).fFlowRate) + abs(this.aoBranches(iCell+1).fFlowRate))/(2*mfDensity(iCell));
                mfSpecificHeatCapacity(iCell)   = this.toStores.(this.sName).aoPhases(iCell*2).fSpecificHeatCapacity;
                
                aoPhase{iCell} = this.toStores.(this.sName).aoPhases(iCell*2);
            end
            
            % In order to limit the recalculation of the convective heat
            % exchange coefficient to a manageable degree they are only
            % recalculated if any relevant property changed by at least 1%
            mbRecalculate = (abs(this.tLastUpdateProps.mfDensity - mfDensity)                            > (1e-2 * mfDensity)) +...
                            (abs(this.tLastUpdateProps.mfFlowSpeed - mfFlowSpeed)                        > (1e-2 * mfFlowSpeed)) + ...
                            (abs(this.tLastUpdateProps.mfSpecificHeatCapacity - mfSpecificHeatCapacity)  > (1e-2 * mfSpecificHeatCapacity));
            
            mbRecalculate = (mbRecalculate ~= 0);
            
            if any(mbRecalculate)
                for iCell = 1:this.iCellNumber
                    if mbRecalculate(iCell)

                        fDynamicViscosity              = this.oMT.calculateDynamicViscosity(aoPhase{iCell});
                        fThermalConductivity           = this.oMT.calculateThermalConductivity(aoPhase{iCell});
                        fConvectionCoeff               = components.matter.filter.functions.convection_pipe(this.tGeometry.fD_Hydraulic, fLength,...
                                                          mfFlowSpeed(iCell), fDynamicViscosity, mfDensity(iCell), fThermalConductivity, mfSpecificHeatCapacity(iCell), 1);
                        mfHeatTransferCoefficient(iCell)= fConvectionCoeff * (this.tGeometry.fAbsorberSurfaceArea/this.iCellNumber);

                        % in case that this was actually recalculated store the
                        % current properties in the LastUpdateProps struct to
                        % decide when the next recalculation is required
                        this.tLastUpdateProps.mfDensity(iCell)              = mfDensity(iCell);
                        this.tLastUpdateProps.mfFlowSpeed(iCell)            = mfFlowSpeed(iCell);
                        this.tLastUpdateProps.mfSpecificHeatCapacity(iCell) = mfSpecificHeatCapacity(iCell);

                        
                        % now the calculated coefficients have to be set to the
                        % conductor of each cell
                        oConductor = this.poLinearConductors(['ConvectiveConductor_', num2str(iCell)]);
                        oConductor.setConductivity(mfHeatTransferCoefficient(iCell));
                    end
                end
            end
            % TO DO: alternative case if the flowrate is 0, currently no
            % heat exchange takes place when the flow rate is zero. For
            % this case the heat exchange would be based on conduction and
            % diffusion. Probably the assumption that only conduction is
            % occuring makes sense and for that case the maximum distance
            % of free gas and the conductivity of the gas could be used to
            % calculate the heat exchange coefficient.
%             this.tGeometry.fMaximumFreeGasDistance
            
        end
        
        function exec(this, ~)
            % exec(ute) function for this system
            % Here it only calls its parent's exec function
            exec@vsys(this);
            
            % in order to keep it somewhat transpart what is calculated
            % when (and to allow individual parts of the code the be called
            % individually) the necessary calculations for the filter are
            % split up into several subfunctions
            
            if this.bDynamicFlowRates
                this.updateInterCellFlowratesDynamic()
            else
                this.updateInterCellFlowrates()
            end
            
            csProcsP2P = this.toStores.(this.sName).csProcsP2P;
            for iProc = 1:length(csProcsP2P)
                this.toStores.(this.sName).toProcsP2P.(csProcsP2P{iProc}).ManualUpdate(this.fTimeStep, zeros(1,this.oMT.iSubstances));
                this.toStores.(this.sName).toProcsP2P.(csProcsP2P{iProc}).ManualUpdateFinal();
            end
            
            this.calculateThermalProperties()
            
            % since the thermal solver currently only has constant time
            % steps it currently uses the same time step as the filter
            % model.
            this.oThermalSolver.setTimestep(this.fTimeStep);
        end
     end
end

