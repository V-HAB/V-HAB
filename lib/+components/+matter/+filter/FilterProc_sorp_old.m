classdef FilterProc_sorp_old < matter.procs.p2ps.stationary
    
    % This is a p2p processor that numerically simulates the sorption and
    % desorption process in an airstream through a filter. 
    % It calculates and sets the sorption flowrate of CO2 and other sorbates  
    % into the sorbent. It also calls the desorption p2p processor if
    % necessary. 
    
    % the numerical model uses:
    %  - for transport(advection + dispersion): extended upwind (dt fixed)
    %  - for reaction phenomena: Linear driving force (LDF)
    
    properties
        
        % General initialization
        sType;                               % type of the chosen filter
        ofilter_table;                       % thermodynamic equilibrium helper class
        DesorptionProc;                      % assigned desorption processor
        
        % Constants
        fUnivGasConst_R;                     % universal gas constant [J/(mol*K)]
        afMolarMass;                         % molar masses of substances [kg/mol]
        mfMolarMass;                         % A matrix with the molar masses of all substances 
                                             % for each grid point. Created
                                             % as a property for speed.
        
        % Bed properties
        fFilterLength = 0;                   % filter length [m]
        rVoidFraction;                       % voidage coefficient [-]
        fHelperConstant_a;                   % Helper constant calculated with void fraction (1-e/e)
        fRhoSorbent;                         % sorbent density [kg/m^3]
        fVolSolid;                           % volume of the solid material [m^3]
        fVolFlow;                            % volume of the free flow volume [m^3]        
        
        % Gas properties
        fVolumetricFlowRate;                 % volumetric flow rate [m^3/s]
        fSorptionTemperature;                % temperature relevant to the sorption process [K]
        fSorptionPressure;                   % pressure relevant to the sorption process [Pa]
        fSorptionDensity;                    % density relevant to the sorption process [kg / m^3]
        afConcentration;                     % feed concentration of sorptives [mol/m^3]
        fFluidVelocity;                      % feed interstitial velocity (homogeneous throughout bed) [m/s]

        % Initial values
        mfC_current;                         % current concentration of substances in fluid [mol/m^3]
        mfQ_current;                         % current loading of substances in fluid [mol/m^3]
        
        % Numerical variables
        afDiscreteLength;                    % numerical bed space grid vector [m]
        fDeltaX;                             % numerical bed space grid spacing [m]
        % IMPORTANT: numerical parameters
        fTimeFactor_1  = 1;                  % transport sub step increasing factor [-]
        fTimeFactor_2  = 1;                  % reaction sub step reduction factor [-]
        iNumGridPoints = 25;                 % number of grid points [-]
        % - increase for a higher precision
        % - decrease for faster computation times 
        
        % Simulation
        iNumSubstances = 0;                  % feed number of adsorptives [-]
        aiPositions;                         % Positions of the current substances in the matter table
        csNames;                             % names in right order of the substances in the flow
        % Time variables
        fCurrentSorptionTime = 0;            % exact time for the calculation (slightly behind timer due remains of the numerical scheme) [s]
        fTimeDifference      = -1;           % time remains due to the subdivision of the numerical time steps         
        fTimeStep            = 0;            % (real) time to simulate [s]        
        fLastExec            = -1;           % saves the time of the last execution of the calculation. 
                                             %  => Take care to set correctly when using multiple sorption processors
        
        % For p2p flow rates
        fFlowRate_ads = 0;
        fFlowRate_des = 0;
        arPartials_ads;
        arPartials_des;
        
        % Transfer variable for plotting
        q_plot;
        c_plot;
        mfBedMasses;
        fFlowPhaseMass = 0;
        fFilterPhaseCO2Mass = 0;
        fFlowPhaseCO2Mass = 0;
        
        % Logging variable to see how long the update method takes to
        % execute.
        fUpdateDuration = 0;
        
        fTimeOffset = 0;
        
    end
    
   
    
    methods
        
        %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%% Constructor %%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        function [this] = FilterProc_sorp_old(oStore, sName, sPhaseIn, sPhaseOut, sType)
            this@matter.procs.p2ps.stationary(oStore, sName, sPhaseIn, sPhaseOut);
            
            % Link sorption processor to desorption processor 
            this.DesorptionProc = this.oStore.toProcsP2P.DesorptionProcessor;
            
            % Define chosen filter type
            this.sType = sType;
            
            % Void fraction of the filter: V_void / V_bulk
            this.rVoidFraction = this.oStore.rVoidFraction;
            
            % Set constants for different filter materials
            switch sType
                case 'FBA'
                    this.fRhoSorbent   = 700;      % zeolite density [kg/m^3]
                    % Set bed length
                    this.fFilterLength = this.oStore.oGeometry.fHeight;     % [m]
                    % Load corresponding helper table
                    this.ofilter_table = components.matter.filter.FBA_Table;  
                    
                case 'RCA'
                    this.fRhoSorbent   = 636.7;    % SA9-T density [kg/m^3]
                    % Set bed length
                    this.fFilterLength = this.oStore.fx;    % [m]
                    % Load corresponding helper table
                    this.ofilter_table = components.matter.filter.RCA_Table(this); 
                    
                case 'MetOx'
                    this.fRhoSorbent   = 636.7;    % TODO: Add right value [kg/m^3]
                    % Set bed length
                    this.fFilterLength = this.oStore.fx;    % [m]
                    % Load corresponding helper table
                    this.ofilter_table = components.matter.filter.MetOx_Table;
                    
                otherwise
                    disp('Choose available filter model');
            end
            
            % Get the filter volumes that are defined in the filter class
            this.fVolSolid = this.oStore.toPhases.FilteredPhase.fVolume;
            this.fVolFlow  = this.oStore.toPhases.FlowPhase.fVolume;
            
            
            %%%%%%%%%%%%
            
            % Position of relevant sorptives in the matter table
            iCO2Index = this.oMT.tiN2I.CO2;
            iH2OIndex = this.oMT.tiN2I.H2O;
            iO2Index  = this.oMT.tiN2I.O2;
            iN2Index  = this.oMT.tiN2I.N2;
            
            this.aiPositions = [ iCO2Index iH2OIndex iO2Index iN2Index ];
            % With their according names
            this.csNames = this.oMT.csSubstances(this.aiPositions);
            this.iNumSubstances = length(this.csNames);
            
            this.mfC_current = zeros(this.iNumSubstances, this.iNumGridPoints,1);
            this.mfQ_current = zeros(this.iNumSubstances, this.iNumGridPoints,1);
            
            % Getting the molar mass of the relevant sorptives
            this.afMolarMass = this.oMT.afMolarMass(this.aiPositions);
            
            % Creating a matrix for later use in the calculation. The
            % matrix has the molar masses of all substances defined above
            % for each internal grid point. 
            this.mfMolarMass = ones(this.iNumSubstances, this.iNumGridPoints);
            for iSubstance = 1:length(this.afMolarMass)
                this.mfMolarMass(iSubstance,:) = this.mfMolarMass(iSubstance,:) .* this.afMolarMass(iSubstance);
            end
            
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%
            
                       
            % Calculate helper constant for concentration switch sorbent <-> sorptive
            this.fHelperConstant_a = (1 - this.rVoidFraction) / this.rVoidFraction;        % [-]
            
            % Get value for the universal gas constant from vhab
            this.fUnivGasConst_R  = this.oMT.Const.fUniversalGas;
            
            % Numerical variables   
            % Exact spacing of the nodes along the filter length
            afSpacing             = linspace(0, this.fFilterLength, this.iNumGridPoints - 1);
            % Add one more 'ghost cell' at the end
            this.fDeltaX          = afSpacing(end) - afSpacing(end-1);
            this.afDiscreteLength = [afSpacing, afSpacing(end) + this.fDeltaX];    
            
            % Initialize
            this.arPartials_ads   = zeros(1, this.oMT.iSubstances);
            this.arPartials_des   = zeros(1, this.oMT.iSubstances);
        end
        
        %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Simulation Helper Functions %
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
         
        
        function [mfMatrix_Transport_A1, afVektor_Transport_b1] = buildMatrix(this, fAxialDispersion_D_l, fTransportTimeStep, mfMatrix_A,mfMatrix_B, mfMatrix_Transport_A1, afVektor_Transport_b1)
            % Build an advection diffusion massbalance matrix
            % Extended Upwind scheme
            fNumericDispersion_D_num = this.fFluidVelocity / 2 * (this.fDeltaX - this.fFluidVelocity * fTransportTimeStep);
            fEntry_a = fTransportTimeStep * this.fFluidVelocity / this.fDeltaX;
            fEntry_b = fTransportTimeStep * (fAxialDispersion_D_l - fNumericDispersion_D_num) / this.fDeltaX^2;
            
            stencilA = [0, 1, 0];
            stencilB = [fEntry_a + fEntry_b, 1 - fEntry_a-2 * fEntry_b, fEntry_b];
            
            for i = 2 : (length(this.afDiscreteLength) - 1)
                mfMatrix_A(i, i-1:i+1) = stencilA;
                mfMatrix_B(i, i-1:i+1) = stencilB;
            end
            
            % Left boundary condition
            mfMatrix_A(1, 1:end-2)     = 1;
            mfMatrix_A(1, end-1:end)   = 0;
            mfMatrix_B(1, 1:end-3)     = 1;
            mfMatrix_B(1, end-2)       = 1 - fEntry_a;
            mfMatrix_B(1, end-1:end)   = 0;
            afVektor_Transport_b1(:,1) = fEntry_a * this.afConcentration';
            
            % Right boundary condition
            mfMatrix_A(end,[end-1,end]) = [1,-1];
            
            % Inverse
            mfMatrix_Transport_A1(:, :) = (mfMatrix_A \ mfMatrix_B)';
            afVektor_Transport_b1(:, :) = afVektor_Transport_b1 * inv(mfMatrix_A)';
            
        end
        
        function desorption(this, rDesorptionRatio)
            % Simplified desorption model
            % Called from the superclass
            % Through a desorption ratio lower than 1 a not complete desorption
            % can be simulated.
            this.mfC_current = (1 - rDesorptionRatio) * this.mfC_current;
            this.mfQ_current = (1 - rDesorptionRatio) * this.mfQ_current;  
            
            this.fFlowPhaseMass = 0;
            
        end
        
        function setNumericalValues(this, iNumGridPoints, fTimeFactor_1, fTimeFactor_2)
            
            % Overwrite the numerical values
            this.iNumGridPoints = iNumGridPoints;
            this.fTimeFactor_1  = fTimeFactor_1;
            this.fTimeFactor_2  = fTimeFactor_2;
              
        end
        
        function setInitialConcentration(this)
            % Phase pressure
            this.fSorptionPressure    = this.oIn.oPhase.fMass * this.oIn.oPhase.fMassToPressure;
            % Phase temperature
            this.fSorptionTemperature = this.oIn.oPhase.fTemperature;
            % Phase mass fractions
            arMassFractions           = this.oIn.oPhase.arPartialMass(this.aiPositions);
            % Calculating the mol fraction [-]
            arMolFractions            = arMassFractions * this.oIn.oPhase.fMolarMass ./ this.afMolarMass;
            % Calculation of phase concentrations in [mol/m^3]
            this.afConcentration      = arMolFractions * this.fSorptionPressure / (this.fUnivGasConst_R * this.fSorptionTemperature);
            
            for iI = 1:this.iNumGridPoints
                this.mfC_current(:,iI) = this.afConcentration';
            end
            
        end
    end
    methods (Access = protected)
        
        %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%% Update Method %%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        function update(this)
            
            % If this method has already been called during this time step,
            % we don't have to execute it again. 
            if this.oStore.oTimer.fTime == this.fLastExec
                if ~base.oDebug.bOff
                    this.out(3,1,'skipping-adsorption','%s: Skipping adsorption calculation because time step is zero', {this.oStore.sName});
                end
                
                return;
            end

            % Calculating the timestep
            this.fTimeStep = this.oStore.oTimer.fTime - this.fLastExec + this.fTimeDifference;        %[s]
            
            if this.fTimeStep == 0
                return;
            end

            
            hTimer = tic();
            
%             % According to the flow save the number of species in the flow
%             % NOT ALWAYS VALID: new substances are accounted for, but
%             % saved values for the concentration and loading are
%             % overwritten!
%             if this.iNumSubstances ~= length(this.aiPositions)
%                 this.iNumSubstances = length(this.aiPositions);
%                 % initiate with the rigth size
%                 this.mfC_current = zeros(this.iNumSubstances, this.iNumGridPoints,1);
%                 this.mfQ_current = zeros(this.iNumSubstances, this.iNumGridPoints,1);
%             end 
            
            % Get inflow flow rate
            % This is a little tricky, since we need to figure out, from
            % where the inflow is coming. In some cases (pressure swing
            % adsorbtion for instance) the filter bed switches are highly
            % dynamic and the inflow can actually come through both the
            % inlet and outlet, because the filter was evacuated prior to
            % the bed switch. 
            % To catch these cases, we check the flow rates on all exmes of
            % the flow phase and then decide what to do.
            
            % To be sure we have the most recent flow data, we perform a
            % massupdate() on the flow phase.
            this.oStore.toPhases.FlowPhase.registerMassupdate();
            
            % Now we can get the inflow rates.
            afInFlowRates = this.oStore.toPhases.FlowPhase.mfCurrentInflowDetails(:,1);
            
            if length(afInFlowRates) > 1
                % There are two inflows, so we use the sum of both. This is
                % equivalent to assuming that all of the mass enters the
                % filter on one side, instead of from both sides. This is a
                % modeling error. It should however be small, because the
                % time period during which the inflow is from both sides
                % should be relatively small, only until the pressures have
                % equalized. 
                fFlowRateIn = sum(this.oStore.toPhases.FlowPhase.mfCurrentInflowDetails(:,1));
                
                % Setting the boolean that decides if we use the flow data
                % or the phase data later on.
                bUseFlow = false;

            else
                % There are one or no inflows
                fInputPortFlowRate  = this.oStore.toPhases.FlowPhase.toProcsEXME.Inlet.oFlow.fFlowRate;
                fOutletPortFlowRate = this.oStore.toPhases.FlowPhase.toProcsEXME.Outlet.oFlow.fFlowRate;
                
                % Initialize flow rate
                fFlowRateIn = 0;
                
                if fInputPortFlowRate > 0
                    % The inlet flow rate is the one that is larger than
                    % zero.
                    fFlowRateIn = fInputPortFlowRate;
                    % Setting the inflow object variable for later use. 
                    oInFlow = this.oStore.toPhases.FlowPhase.toProcsEXME.Inlet.oFlow;
                    % Setting the boolean that decides if we use the flow
                    % data or the phase data later on.
                    bUseFlow = true;
                end
                
                if fOutletPortFlowRate < 0
                    % The outlet flow rate is the one that is larger than
                    % zero
                    fFlowRateIn = fOutletPortFlowRate * -1;
                    % Setting the inflow object variable for later use. 
                    oInFlow = this.oStore.toPhases.FlowPhase.toProcsEXME.Outlet.oFlow;
                    % Setting the boolean that decides if we use the flow
                    % data or the phase data later on.
                    bUseFlow = true;
                end
                
                if fFlowRateIn == 0
                    % The flow rates are both directed out of the phase or
                    % actually zero. In either case, we will use the phase
                    % data for the absorbtion calculation.
                    bUseFlow = false; 
                end
                    

            end
            
            % This is a flow-p2p processor. This means that usually the
            % dominant factor in the calculation of the adsorption rate is
            % the incoming flow. However, in some cases the incoming flow
            % rate will be zero or there might be inflow from both sides.
            % So we have to set some of our variables differently, if this
            % is the case.
            if ~bUseFlow
                % If the incoming flow rate is zero, we use the properties
                % of the phase from which we adsorb.
                % Phase pressure
                this.fSorptionPressure    = this.oIn.oPhase.fMass * this.oIn.oPhase.fMassToPressure;
                % Phase temperature
                this.fSorptionTemperature = this.oIn.oPhase.fTemperature;
                % Phase mass fractions
                arMassFractions           = this.oIn.oPhase.arPartialMass(this.aiPositions);
                % Calculating the mol fraction [-]
                arMolFractions            = arMassFractions * this.oIn.oPhase.fMolarMass ./ this.afMolarMass;      
                % Calculation of phase concentrations in [mol/m^3]
                this.afConcentration      = arMolFractions * this.fSorptionPressure / (this.fUnivGasConst_R * this.fSorptionTemperature);                    
                % Calculating the density of the phase in [kg/m^3]
                this.fSorptionDensity     = this.fSorptionPressure * this.oIn.oPhase.fMolarMass / ...                    
                                            this.fUnivGasConst_R / this.fSorptionTemperature;
                for iI = 1:this.iNumGridPoints
                    this.mfC_current(:,iI) = this.afConcentration';
                end
                
            else
                % Inlet pressure
                this.fSorptionPressure    = oInFlow.fPressure;
                % Inlet temperature
                this.fSorptionTemperature = oInFlow.fTemperature;
                % Inlet mass fractions
                arMassFractions           = oInFlow.arPartialMass(this.aiPositions);
                                       
                % Calculating the mol fraction [-]
                arMolFractions            = arMassFractions * oInFlow.fMolarMass ./ this.afMolarMass;
                % Calculation of the incoming concentrations in [mol/m^3]
                this.afConcentration      = arMolFractions * this.fSorptionPressure / (this.fUnivGasConst_R * this.fSorptionTemperature);
                % Calculating the density of the inflowing matter in [kg/m^3]
                this.fSorptionDensity     = (this.fSorptionPressure * oInFlow.fMolarMass) / ...
                                            (this.fUnivGasConst_R * this.fSorptionTemperature);
            end
            
            % In some cases (manual solver in combination with an empty
            % phase at one end to which this p2p processor is connected)
            % the pressure here can be zero. It should only be zero for one
            % timestep, so we'll just skip this one.
            if this.fSorptionPressure <= 0 
                if ~base.oDebug.bOff
                    this.out(3,1,'skipping-adsorption','%s: Skipping adsorption calculation because of zero or negative pressure', {this.oStore.sName});
                end
                
                return;
            end

            % Convert flow rate into [m^3/s]
            this.fVolumetricFlowRate = fFlowRateIn / this.fSorptionDensity;       % [m^3/s]

            % Calculate flow velocity
            this.fFluidVelocity = this.fVolumetricFlowRate / (this.fVolFlow / this.fFilterLength);      % [m/s]

            % Get dispersion coefficient
            fAxialDispersion_D_l = this.ofilter_table.get_AxialDispersion_D_L(this.fFluidVelocity, this.fSorptionTemperature, this.fSorptionPressure, this.afConcentration, this.csNames, this.afMolarMass);
            
            if fFlowRateIn == 0
                % If the flow rate is zero, we need to set the transport
                % and reaction time steps to the external time step with
                % which the filter has been called.
                fTransportTimeStep = this.fTimeStep;
                fReactionTimeStep  = fTransportTimeStep;
            else
                % Initialize time domain Numerical time grid spacing
                % (dispersive transport stability)
                fTransportTimeStep = this.fDeltaX^2 / (this.fFluidVelocity * this.fDeltaX + 2 * fAxialDispersion_D_l);
                
                % BUT: calculated time step needs to be smaller than current vhab time step
                if this.fTimeFactor_1 * fTransportTimeStep >= this.fTimeStep
                    if ~base.oDebug.bOff
                        this.out(3,1,'skipping-adsorption','%s: Skipping adsorption calculation because inner time step is larger than external timestep', {this.oStore.sName});
                    end
                    
                    return;
                end
                
                % Make reaction time constant a multiple of transport time constant
                fReactionTimeStep = fTransportTimeStep / this.fTimeFactor_2;
            end
            
            % Discretized time domain
            afDiscreteTime = (this.fCurrentSorptionTime : (this.fTimeFactor_1 * fTransportTimeStep) : this.fCurrentSorptionTime + this.fTimeStep);   
            % Number of numerical time grid points
            iTimePoints = length(afDiscreteTime);
            
            % After a bed switch, the volumetric flow rate may become
            % extremely high due to low pressures and high mass flow rates.
            % This can in turn lead to extremely small transport timesteps
            % and cause the number of time points to exeed 100,000... To
            % avoid this, we'll just skip this iteration if  the number of
            % time points exceeds 100,000.
            if iTimePoints > 100000
                if ~base.oDebug.bOff
                    this.out(3,1,'skipping-adsorption','%s: Skipping adsorption calculation because number of internal time steps exceeds 100,000', {this.oStore.sName});
                end
                
                return;
            end
            
            if ~base.oDebug.bOff
                this.out(5,1,'adsorption-proceeding','%s: Passed all checks! Now performing absorbtion calculation', {this.oStore.sName});
            end
            
            % Initialize matrices for dispersive transport
            mfMatrix_A = zeros(this.iNumGridPoints);
            mfMatrix_B = zeros(this.iNumGridPoints);
            mfMatrix_Transport_A1 = zeros(this.iNumGridPoints);
            afVektor_Transport_b1 = zeros(this.iNumSubstances, this.iNumGridPoints);
            [mfMatrix_Transport_A1, afVektor_Transport_b1] = this.buildMatrix(fAxialDispersion_D_l, fTransportTimeStep, mfMatrix_A, mfMatrix_B, mfMatrix_Transport_A1, afVektor_Transport_b1);
            
            % Initialize solution matrices
            mfC = zeros(this.iNumSubstances,this.iNumGridPoints,iTimePoints);
            mfQ = zeros(this.iNumSubstances,this.iNumGridPoints,iTimePoints);
            
            % Apply initial conditions:
            % Current state of the flow phase
            mfC(:,:,1) = this.mfC_current;
            % Set inflow concentrations in boundary cell
            mfC(:,1,1) = this.afConcentration;
            % Current state of the bed loading
            mfQ(:,:,1) = this.mfQ_current;
            
            %----------------------------------------------
            %------------------SOLVE-----------------------
            %----------------------------------------------
            for aiTime_index = 2:iTimePoints
                
                % Read values from previous time step
                mfC( :, :, aiTime_index ) = mfC( :, :, aiTime_index-1 );
                mfQ( :, :, aiTime_index ) = mfQ( :, :, aiTime_index-1 );
                
                for iI = 1:this.fTimeFactor_1
                    
                    %----------------------------------------------
                    %---------------fluid transport----------------
                    %----------------------------------------------
                    
                    % Solve equation system
                    mfC( :, :, aiTime_index ) = mfC( :, :, aiTime_index ) * mfMatrix_Transport_A1 + afVektor_Transport_b1;
                    
                    %---------------------------------------------------------------
                    %-----------------------LDF reaction part-----------------------
                    %---------------------------------------------------------------
                    
                    % Store transportation result values in buffer for later usage
                    mfQ_save = mfQ( :, 1:end-1, aiTime_index );
                    mfC_save = mfC( :, 1:end-1, aiTime_index );
                    
                    for iJ = 1:this.fTimeFactor_2
                       
                        % Concentration and loading for FBA and RCA/Amine absorption
                        if strcmp(this.sType, 'RCA') || strcmp(this.sType, 'FBA')
                            
                            % Update thermodynamic constant
                            mfThermodynConst_K = this.ofilter_table.get_ThermodynConst_K(mfC( :, 1:end-1, aiTime_index ), this.fSorptionTemperature, this.fRhoSorbent, this.csNames, this.afMolarMass);     %linearized adsorption equilibrium isotherm slope [-]
                            
                            % Update kinetic lumped constant
                            mfKineticConst_k_l = this.ofilter_table.get_KineticConst_k_l(mfThermodynConst_K, this.fSorptionTemperature, this.fSorptionPressure, this.fSorptionDensity, this.afConcentration, this.fRhoSorbent, this.fVolumetricFlowRate, this.rVoidFraction, this.csNames, this.afMolarMass);
                            
                            % Calculate local equilibrium value
                            % Equation 3.42 from RT-BA 2013/15
                            mfQ_equ_local = mfThermodynConst_K .* (mfC_save + this.fHelperConstant_a * mfQ_save) ./ (1 + mfThermodynConst_K * this.fHelperConstant_a);
                            
                            % Result of the time step according to LDF
                            % formula (modified equation 3.40 from 
                            % RT-BA 2013/15)
                            mfQ( :, 1:end-1, aiTime_index ) = exp(-mfKineticConst_k_l .* (1 + mfThermodynConst_K * this.fHelperConstant_a) * fReactionTimeStep) .* (mfQ(:, 1:end-1, aiTime_index) - mfQ_equ_local) + mfQ_equ_local;
                            
                            % Equation 3-29 from RT-BA 2013/15
                            mfC( :, 1:end-1, aiTime_index ) = this.fHelperConstant_a * (mfQ_save - mfQ( :, 1:end-1, aiTime_index )) + mfC_save;
                            
                        % Concentration and loading for MetOx absorption
                        elseif strcmp(this.sType, 'MetOx')
                            
                            mfC( :, 1:end-1, aiTime_index ) = this.ofilter_table.calculate_C_new(mfC( :, 1:end-1, aiTime_index ), fReactionTimeStep, this.fSorptionTemperature, this.csNames, this.fVolSolid, this.iNumGridPoints, this.afMolarMass);
                            mfQ( :, 1:end-1, aiTime_index ) = mfQ( :, 1:end-1, aiTime_index ) + (mfC_save - mfC( :, 1:end-1, aiTime_index ));
                        end
                        
                    end
                    
                    % Apply bed r.b.c.
                    mfC(:, end, aiTime_index) = mfC(:, end-1, aiTime_index);
                    
                end
            end
                     
            %% Post Processing

            % Save as transfer variable for plotting
            % Loading of the filter
            %                     Front           Middle             End
            this.q_plot = mfQ(:, [1, ceil(length(mfQ(1, :, end))/2), end-1], end) / this.fRhoSorbent;   % [mol/kg]
            this.c_plot = mfC(:, [1, ceil(length(mfQ(1, :, end))/2), end-1], end) / this.fRhoSorbent;   % [mol/kg]
            
            % Initialize array for filtered mass
            afLoadedMass_ads = zeros(1, this.iNumSubstances);
            afLoadedMass_des = zeros(1, this.iNumSubstances); 
            
            % Sum up loading change in [mol/m3]
            mfQ_mol_change = mfQ(:, :, end) - this.mfQ_current;
            
            % Convert the change to [kg/m3]
            mfQ_density_change = mfQ_mol_change .* this.mfMolarMass;
            
            % Convert the change to mass in [kg]
            mfQ_mass_change = mfQ_density_change(:, 1:end-1) * this.fVolSolid / (this.iNumGridPoints-2);   % in [kg]       % -1 (ghost cell) -1 (2 boundary points)
            
            % Sum up filtered mass during the time step
            afLoadedMass = sum(mfQ_mass_change, 2);
            
            % Distinguish sorption and desorption part
            afLoadedMass_ads(afLoadedMass >= 0) = afLoadedMass(afLoadedMass >= 0);     % [kg]
            afLoadedMass_des(afLoadedMass < 0)  = afLoadedMass(afLoadedMass < 0);       % [kg]
            
            % Sorption
            if sum(afLoadedMass_ads) > 0
                this.arPartials_ads(this.aiPositions) = afLoadedMass_ads / sum(afLoadedMass_ads);
            end
            
            % Desorption
            if sum(afLoadedMass_des) < 0
                this.arPartials_des(this.aiPositions) = afLoadedMass_des / sum(afLoadedMass_des);
            end

                 
            %% Set the matter properties      
            % Update bed status
            this.mfC_current = mfC(:, :, end);
            mfBedDensity = this.mfC_current .* this.mfMolarMass;
            mfCellMasses = mfBedDensity(:, 1:end-1) * this.fVolFlow / (this.iNumGridPoints-2);
            this.fFlowPhaseCO2Mass = sum(mfCellMasses(1,:));
            this.mfBedMasses = sum(mfCellMasses, 2);
            this.fFlowPhaseMass = sum(this.mfBedMasses);
            
            this.mfQ_current = mfQ(:, :, end);
            
            mfBedDensity = this.mfQ_current .* this.mfMolarMass;
            mfCellMasses = mfBedDensity(:, 1:end-1) * this.fVolSolid / (this.iNumGridPoints-2);
            this.fFilterPhaseCO2Mass = sum(mfCellMasses(1,:));
            
            
            this.fTimeDifference = this.fTimeStep - (afDiscreteTime(end) - afDiscreteTime(1));        
            
            this.fCurrentSorptionTime = this.fCurrentSorptionTime + (afDiscreteTime(end) - afDiscreteTime(1));
            % Update the execution time
            this.fLastExec = this.oStore.oTimer.fTime;
            
            % Set flow rates:
            % - Sorption in this p2p processor
            this.fFlowRate_ads = sum(afLoadedMass_ads) / (afDiscreteTime(end) - afDiscreteTime(1));           % [kg/s]
            this.setMatterProperties(this.fFlowRate_ads, this.arPartials_ads);
            
            % - Desorption outsourced in a separate p2p processor     
            this.fFlowRate_des = sum(afLoadedMass_des) / (afDiscreteTime(end) - afDiscreteTime(1));           % [kg/s]     
            this.DesorptionProc.setMatterProperties(this.fFlowRate_des, this.arPartials_des);
            
            this.fUpdateDuration = toc(hTimer);
            
            
            this.fTimeOffset = this.oTimer.fTime - this.fCurrentSorptionTime;
            
        end
        
    end
end
