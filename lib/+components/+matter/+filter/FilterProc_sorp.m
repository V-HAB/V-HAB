classdef FilterProc_sorp < matter.procs.p2ps.flow & event.source
    
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
        fTimeDifference      = 0;            % time remains due to the subdivision of the numerical time steps         
        fTimeStep            = 0;            % (real) time to simulate [s]        
        fLastExec            = 0;            % saves the time of the last execution of the calculation. 
                                             %  => Take care to set correctly when using multiple sorption processors
        
        % For p2p flow rates
        fFlowRate_ads = 0;
        fFlowRate_des = 0;
        arPartials_ads;
        arPartials_des;
        
        % kinematic constant for the adsorption calculation. This parameter
        % is only used if static values are used, otherwise a calculation
        % in the Filter Table has to be provided.
        k_l;
        
        % parameter to decide if the toth equation should only be evaluated
        % if a sufficient change in the concentration has occured. The
        % limit for this is set by the user and should be given as
        % concentration in mol/m³. For example a limit of 1e-3 results in a
        % recalculation of the toth equation if a change of ~2.5 Pa for the
        % partial pressure occurs.
        fLimitTothCalculation;
        
        % Transfer variable for plotting
        q_plot;
        c_plot;
        
        % Logging variable to see how long the update method takes to
        % execute.
        fUpdateDuration;
        
        
        % For Debuggin: internal loading in kg
        fInternalLoading = 0;
        
        iImaginaryOccCounter = 0;
    end
    
   
    
    methods
        
        %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%% Constructor %%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        function [this] = FilterProc_sorp(oStore, sName, sPhaseIn, sPhaseOut, sType, fLimitTothCalculation)
            this@matter.procs.p2ps.flow(oStore, sName, sPhaseIn, sPhaseOut);
            
            % Link sorption processor to desorption processor 
            this.DesorptionProc = this.oStore.toProcsP2P.DesorptionProcessor;
            
            % Define chosen filter type
            this.sType = sType;
            
            if nargin > 5
                this.fLimitTothCalculation = fLimitTothCalculation;
            end
            
            % Get the filter volumes that are defined in the filter class
            try
                this.fVolSolid = this.oStore.tGeometryParameters.fVolumeSolid;
            catch
                this.fVolSolid = this.oStore.toPhases.FilteredPhase.fVolume;
            end
            
            % tries to get the flow volume from the geometry parameter
            % struct. This was implemented since it can be necessary to use
            % a larger volume for the phase in the V-HAB model to allow
            % large enough time steps. But that increased volume should not
            % be used for the filter calculation!
            try
                this.fVolFlow = this.oStore.tGeometryParameters.fVolumeFlow;
            catch
               this.fVolFlow  = this.oStore.toPhases.FlowPhase.fVolume;
            end
            
            
            
            % Void fraction of the filter: V_void / V_bulk
            try
                this.rVoidFraction = this.oStore.tGeometryParameters.rVoidFraction;
            catch
                this.rVoidFraction = this.fVolFlow / this.fVolSolid;
            end
            
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
                    this.ofilter_table = components.matter.filter.RCA_Table; 
                    
                case 'MetOx'
                    this.fRhoSorbent   = 636.7;    % TODO: Add right value [kg/m^3]
                    % Set bed length
                    this.fFilterLength = this.oStore.fx;    % [m]
                    % Load corresponding helper table
                    this.ofilter_table = components.matter.filter.MetOx_Table;
                    
                case '13x'
                    % Density of the sorbend from matter table
                    this.fRhoSorbent   = this.oMT.ttxMatter.Zeolite13x.ttxPhases.tSolid.Density;
                    % Length of the filter from store geometry
                    this.fFilterLength = this.oStore.tGeometryParameters.fLength;     % [m]
                    % Load corresponding helper table
                    this.ofilter_table = components.matter.filter.Zeolite13x_Table; 
                    
                    if ~isnan(this.ofilter_table.k_l)
                        k_l_temp = this.ofilter_table.get_KineticConst_k_l([0;0;0;0], 0, 0, 0, 0, 0, 0, 0, {'CO2'; 'H2O'; 'O2'; 'N2'}, 0);
                        this.k_l = zeros(4,100);
                        for iK = 1:100
                            this.k_l(:,iK) = k_l_temp;
                        end
                    end
                    
                case '5A'
                    % Density of the sorbend from matter table
                    this.fRhoSorbent   = this.oMT.ttxMatter.Zeolite5A.ttxPhases.tSolid.Density;
                    % Length of the filter from store geometry
                    this.fFilterLength = this.oStore.tGeometryParameters.fLength;     % [m]
                    % Load corresponding helper table
                    this.ofilter_table = components.matter.filter.Zeolite5A_Table; 
                    
                    if ~isnan(this.ofilter_table.k_l)
                        k_l_temp = this.ofilter_table.get_KineticConst_k_l([0;0;0;0], 0, 0, 0, 0, 0, 0, 0, {'CO2'; 'H2O'; 'O2'; 'N2'}, 0);
                        this.k_l = zeros(4,100);
                        for iK = 1:100
                            this.k_l(:,iK) = k_l_temp;
                        end
                    end
                    
                case '5A-RK38'
                    % Density of the sorbend from matter table
                    this.fRhoSorbent   = this.oMT.ttxMatter.Zeolite5A_RK38.ttxPhases.tSolid.Density;
                    % Length of the filter from store geometry
                    this.fFilterLength = this.oStore.tGeometryParameters.fLength;     % [m]
                    % RK38 uses the same table as the normal 5A but adapts
                    % the kinematic constant to RK38
                    % LDF model kinetic lumped constant in order (H2O, CO2, N2, O2) [1/s] from ICES-2014-168
                    LDF_KinConst = [0.0007, 0.003, 0, 0]; 
                    % Load corresponding helper table
                    this.ofilter_table = components.matter.filter.Zeolite5A_Table(LDF_KinConst); 
                    
                    if ~isnan(this.ofilter_table.k_l)
                        k_l_temp = this.ofilter_table.get_KineticConst_k_l([0;0;0;0], 0, 0, 0, 0, 0, 0, 0, {'CO2'; 'H2O'; 'O2'; 'N2'}, 0);
                        this.k_l = zeros(4,100);
                        for iK = 1:100
                            this.k_l(:,iK) = k_l_temp;
                        end
                    end
                    
                case 'Sylobead'
                    % Density of the sorbend from matter table
                    this.fRhoSorbent   = this.oMT.ttxMatter.Sylobead_B125.ttxPhases.tSolid.Density;
                    % Length of the filter from store geometry
                    this.fFilterLength = this.oStore.tGeometryParameters.fLength;     % [m]
                    % Sylobead uses the same table as the normal Silicgel but adapts
                    % the kinematic constant to Sylobead
                    % LDF model kinetic lumped constant in order (H2O, CO2, N2, O2) [1/s] from ICES-2014-168
                    LDF_KinConst = [0.002, 0, 0, 0]; 
                    % Load corresponding helper table
                    this.ofilter_table = components.matter.filter.SilicaGel_Table(LDF_KinConst); 
                    
                    if ~isnan(this.ofilter_table.k_l)
                        k_l_temp = this.ofilter_table.get_KineticConst_k_l([0;0;0;0], 0, 0, 0, 0, 0, 0, 0, {'CO2'; 'H2O'; 'O2'; 'N2'}, 0);
                        this.k_l = zeros(4,100);
                        for iK = 1:100
                            this.k_l(:,iK) = k_l_temp;
                        end
                    end
                    
                case 'SilicaGel'
                    % Density of the sorbend from matter table
                    this.fRhoSorbent   = this.oMT.ttxMatter.SilicaGel_40.ttxPhases.tSolid.Density;
                    % Length of the filter from store geometry
                    this.fFilterLength = this.oStore.tGeometryParameters.fLength;     % [m]
                    % Load corresponding helper table
                    this.ofilter_table = components.matter.filter.SilicaGel_Table; 
                    
                    if ~isnan(this.ofilter_table.k_l)
                        k_l_temp = this.ofilter_table.get_KineticConst_k_l([0;0;0;0], 0, 0, 0, 0, 0, 0, 0, {'CO2'; 'H2O'; 'O2'; 'N2'}, 0);
                        this.k_l = zeros(4,100);
                        for iK = 1:100
                            this.k_l(:,iK) = k_l_temp;
                        end
                    end
                    
                otherwise
                    disp('Choose available filter model');
            end
            
            
            
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
            
            % Getting the molar mass of the relevant sorptives
            this.afMolarMass = this.oMT.afMolarMass(this.aiPositions);
            
            % current concentration of substances in fluid [mol/m^3]
            this.mfC_current = zeros(this.iNumSubstances, this.iNumGridPoints,1);
            mfC_current_Flow = (this.oIn.oPhase.afMass(this.aiPositions)./this.afMolarMass) / this.oIn.oPhase.fVolume;
            mfC_current_Flow = mfC_current_Flow';
            for iK = 1:this.iNumGridPoints
                this.mfC_current(:,iK) = mfC_current_Flow;
            end

            % TO DO: for the loading mfQ this is actually too simplified since the
            % loading in the filter is not actually uniform for all cells
            % but has certain differences. Therefore the desorption with a
            % uniform spread of the loading in the filter does not work!
            
        	% current loading of substances in fluid [mol/m^3]
            this.mfQ_current = zeros(this.iNumSubstances, this.iNumGridPoints,1);
            % current loading in adsorber phase
            mfQ_current_Adsorber = (this.oOut.oPhase.afMass(this.aiPositions)./this.afMolarMass) / this.fVolSolid;
            mfQ_current_Adsorber = mfQ_current_Adsorber';
            for iK = 1:(this.iNumGridPoints - 1)
                this.mfQ_current(:,iK) = mfQ_current_Adsorber;
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
        
        %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%% Update Method %%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        function update(this)
            
            % If this method has already been called during this time step,
            % we don't have to execute it again. 
            if this.oStore.oTimer.fTime == this.fLastExec
                return;
            end
            
            % gets the current inlet flow
            iNumberOfExmes = length(this.oIn.oPhase.coProcsEXME);
            mbInFlows = zeros(iNumberOfExmes,1);
            for iK = 1:iNumberOfExmes
                fFlowRateEXME = this.oIn.oPhase.coProcsEXME{iK}.oFlow.fFlowRate * this.oIn.oPhase.coProcsEXME{iK}.iSign;
                % only considers this as inlet flow if it is NOT a p2p
                % flow!
                if (fFlowRateEXME > 0) && ~this.oIn.oPhase.coProcsEXME{iK}.bFlowIsAProcP2P...
                        && ~strcmp(this.oIn.oPhase.coProcsEXME{iK}.sName, 'Vent')... also disregard vent or air safe exmes
                        && ~strcmp(this.oIn.oPhase.coProcsEXME{iK}.sName, 'AirSafe')
                    mbInFlows(iK) = true;
                end
            end
            iInFlowEXME = find(mbInFlows);
            
            if length(iInFlowEXME) >= 1
                coInFlow = cell(length(iInFlowEXME),1);
                mfFlowRateIn = zeros(length(iInFlowEXME),1);
                for iK = 1:length(iInFlowEXME)
                    coInFlow{iK} = this.oIn.oPhase.coProcsEXME{iInFlowEXME(iK)}.oFlow;
                    mfFlowRateIn(iK) = coInFlow{iK}.fFlowRate * this.oIn.oPhase.coProcsEXME{iInFlowEXME(iK)}.iSign;
                end
                mbMaxInFlow = mfFlowRateIn == max(mfFlowRateIn);
                oInFlow = coInFlow{mbMaxInFlow};
                fFlowRateIn = mfFlowRateIn(mbMaxInFlow);
            elseif isempty(iInFlowEXME)
%                 oInFlow = [];
                fFlowRateIn = 0;
            else
                keyboard()
                % this should not occur, the filter is only allowed to have
                % one inlet flow from branches (p2p procs are not
                % considered)
            end
            
            hTimer = tic();
            
%             % Position of relevant sorptives in the matter table
% %             this.aiPositions = (find(this.oStore.toPhases.FlowPhase.toProcsEXME.Inlet.oFlow.arPartialMass > 0));
%             this.aiPositions = [190 193 194];
%             % With their according names
%             this.csNames = this.oMT.csSubstances(this.aiPositions);
%             
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
            
            % Calculating the timestep
            this.fTimeStep = this.oStore.oTimer.fTime - this.fLastExec + this.fTimeDifference;        %[s]
            
            
            
            % If there is matter flowing out of the inlet, then we are in
            % some sort of transient phase at the beginning of a simulation
            % or right after a bed switch. To avoid problems later on,
            % we'll just skip this execution and try next time. 
            if fFlowRateIn < 0
                if ~base.oDebug.bOff
                    this.out(3,1,'skipping-adsorption','%s: Skipping adsorption calculation because of negative flow rate', {this.oStore.sName});
                end
                
                return;
            end
            
            % Getting the molar mass of the relevant sorptives
            this.afMolarMass = this.oMT.afMolarMass(this.aiPositions);
            
            % This is a flow-p2p processor. This means that the dominant
            % factor in the calculation of the adsorption rate is the
            % incoming flow. However, if this adsorber is connected to a
            % lower pressure, or cooled or heated, all depending on the
            % adsorbent properties, desorption may be ocurring. If this is
            % wanted, then the incoming flow rate will be zero. So we have
            % to set some of our variables differently, if this is the
            % case. 
            if (fFlowRateIn == 0) || strcmp(this.sType, '5A-RK38') || strcmp(this.sType, '13x') || strcmp(this.sType, 'Sylobead') 
                % If the incoming flow rate is zero, we use the properties
                % of the phase from which we adsorb.
                % Phase pressure
                this.fSorptionPressure    = this.oIn.oPhase.fPressure;
                % Phase temperature
                this.fSorptionTemperature = this.oOut.oPhase.fTemperature;
                % Phase mass fractions
                arMassFractions           = this.oIn.oPhase.arPartialMass(this.aiPositions);
                
                % Calculating the mol fraction [-]
                arMolFractions            = arMassFractions * this.oIn.oPhase.fMolarMass ./ this.afMolarMass;      
                % Calculation of phase concentrations in [mol/m^3]
                this.afConcentration      = arMolFractions * this.fSorptionPressure / (this.fUnivGasConst_R * this.fSorptionTemperature);                    
                % Calculating the density of the phase in [kg/m^3]
                this.fSorptionDensity     = this.oIn.oPhase.fDensity;
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
                    this.out(3,1,'skipping-adsorption','%s: Skipping adsorption calculation because zero or negative pressure', {this.oStore.sName});
                end
                
                return;
            end

            % Convert flow rate into [m^3/s]
            this.fVolumetricFlowRate = fFlowRateIn / this.fSorptionDensity;       % [m^3/s]

            % Calculate flow velocity
            this.fFluidVelocity = this.fVolumetricFlowRate / (this.fVolFlow / this.fFilterLength);      % [m/s]

            % Get dispersion coefficient
            fAxialDispersion_D_l = this.ofilter_table.get_AxialDispersion_D_L(this.fFluidVelocity, this.fSorptionTemperature, this.fSorptionPressure, this.afConcentration, this.csNames, this.afMolarMass);
            
            % Initialize time domain
            % Numerical time grid spacing (dispersive transport stability)
            fTransportTimeStep = this.fDeltaX^2 / (this.fFluidVelocity * this.fDeltaX + 2 * fAxialDispersion_D_l);
            % BUT: calculated time step needs to be smaller than current vhab time step
            
            if this.fTimeFactor_1 * fTransportTimeStep >= this.fTimeStep
                return
%                 fTransportTimeStep = this.fTimeStep / this.fTimeFactor_1;
            end
            
            % Make reaction time constant a multiple of transport time constant
            fReactionTimeStep = fTransportTimeStep / this.fTimeFactor_2;
            % Discretized time domain
            % TO DO: Timefactor 1 is used to reduce the number of
            % iTimePoints while keeping the reaction time step constant
            % (see solve section for followup comment)
            afDiscreteTime = (this.fCurrentSorptionTime : (this.fTimeFactor_1 * fTransportTimeStep) : this.fCurrentSorptionTime + this.fTimeStep);   
            % Number of numerical time grid points
            iTimePoints = length(afDiscreteTime);  
            this.fTimeDifference = this.fTimeStep - (afDiscreteTime(end) - afDiscreteTime(1));        
            
            % Initialize matrices for dispersive transport
            mfMatrix_A = zeros(this.iNumGridPoints);
            mfMatrix_B = zeros(this.iNumGridPoints);
            mfMatrix_Transport_A1 = zeros(this.iNumGridPoints);
            afVektor_Transport_b1 = zeros(this.iNumSubstances, this.iNumGridPoints);
            [mfMatrix_Transport_A1, afVektor_Transport_b1] = this.buildMatrix(fAxialDispersion_D_l, fTransportTimeStep, mfMatrix_A, mfMatrix_B, mfMatrix_Transport_A1, afVektor_Transport_b1);
            
            % Initialize solution matrices
            mfC = zeros(this.iNumSubstances,this.iNumGridPoints,iTimePoints);
            mfQ = zeros(this.iNumSubstances,this.iNumGridPoints,iTimePoints);
            
            % Apply initial conditions
            mfC(:,:,1) = this.mfC_current;
            mfC(:,1,1) = this.afConcentration;
            mfQ(:,:,1) = this.mfQ_current;
            
            mfC_LastToth = this.mfC_current;
            
            % for speed optimization local boolean variables are used to
            % decide if the toth and kinematic constant simplification
            % should be used or not (faster than strcmp, isemtpy or
            % property boolean variables)
            if ~isempty(this.k_l)
                bConst_k_l = true;
            else
                bConst_k_l = false;
            end
            if ~isempty(this.fLimitTothCalculation)
                bLimitToth = true;
            else
                bLimitToth = false;
            end
            if ~strcmp(this.sType, 'MetOx')
                bMetox = false;
            else
                bMetox = true;
            end
            
            if (this.fTimeFactor_1 == 1) && (this.fTimeFactor_2 == 1)
                %----------------------------------------------
                %------------------SOLVE-----------------------
                %----------------------------------------------
                for aiTime_index = 2:iTimePoints

                    %----------------------------------------------
                    %---------------fluid transport----------------
                    %----------------------------------------------

                    % Solve equation system Equation 3.23 from RT BA 13_15
                    mfC(:,:,aiTime_index) = mfC(:,:,aiTime_index-1) * mfMatrix_Transport_A1 + afVektor_Transport_b1;
                    
                    if ~bMetox
                        if bLimitToth
                            mDiff = abs(mfC(:,:,aiTime_index) - mfC_LastToth); 
                            if (max(mDiff(:)) > this.fLimitTothCalculation) || aiTime_index == 2

                                % Calculates the capacity of the filter using the toth equation
                                % saved in the filter table file. The caclulation is then
                                % performeed using a linearized thermodynamic konstant k which,
                                % if multiplied with the current concentration, yields the
                                % current capacity of the filter.
                                mfThermodynConst_K = this.ofilter_table.get_ThermodynConst_K(mfC(:,1:end-1,aiTime_index), this.fSorptionTemperature, this.fRhoSorbent, this.csNames, this.afMolarMass);     %linearized adsorption equilibrium isotherm slope [-]
                                mfC_LastToth = mfC(:,:,aiTime_index);
                                % either gets the saved constant kinematic constant or
                                % calculates it from the equations saved in the filter table
                                if bConst_k_l
                                    mfKineticConst_k_l = this.k_l(:,(1:length(mfThermodynConst_K)));
                                else
                                    mfKineticConst_k_l = this.ofilter_table.get_KineticConst_k_l(mfThermodynConst_K, this.fSorptionTemperature, this.fSorptionPressure, this.fSorptionDensity, this.afConcentration, this.fRhoSorbent, this.fVolumetricFlowRate, this.rVoidFraction, this.csNames, this.afMolarMass);
                                end
                            end
                        else
                            mfThermodynConst_K = this.ofilter_table.get_ThermodynConst_K(mfC(:,1:end-1,aiTime_index), this.fSorptionTemperature, this.fRhoSorbent, this.csNames, this.afMolarMass);     %linearized adsorption equilibrium isotherm slope [-]
                            % either gets the saved constant kinematic constant or
                            % calculates it from the equations saved in the filter table
                            if bConst_k_l
                                mfKineticConst_k_l = this.k_l(:,(1:length(mfThermodynConst_K)));
                            else
                                mfKineticConst_k_l = this.ofilter_table.get_KineticConst_k_l(mfThermodynConst_K, this.fSorptionTemperature, this.fSorptionPressure, this.fSorptionDensity, this.afConcentration, this.fRhoSorbent, this.fVolumetricFlowRate, this.rVoidFraction, this.csNames, this.afMolarMass);
                            end
                        end
                        %---------------------------------------------------------------
                        %-----------------------LDF reaction part-----------------------
                        %---------------------------------------------------------------

                        % Store transportation result values in buffer for later usage
                        mfQ_save = mfQ(:,1:end-1,aiTime_index-1);

                        % Calculate local equilibrium value
                        % Equation 3.42 from RT-BA 2013/15
                        mfQ_equ_local = mfThermodynConst_K .* (mfC(:,1:end-1,aiTime_index) + this.fHelperConstant_a * mfQ_save) ./ (1 + mfThermodynConst_K * this.fHelperConstant_a);

                        % Result of the time step according to LDF
                        % formula (modified equation 3.40 from 
                        % RT-BA 2013/15)
                        mfQ( :, 1:end-1, aiTime_index ) = exp(-mfKineticConst_k_l .* (1 + mfThermodynConst_K * this.fHelperConstant_a) * fReactionTimeStep) .* (mfQ(:, 1:end-1, aiTime_index-1) - mfQ_equ_local) + mfQ_equ_local;

                        % Equation 3-29 from RT-BA 2013/15
                        mfC( :, 1:end-1, aiTime_index ) = this.fHelperConstant_a * (mfQ_save - mfQ( :, 1:end-1, aiTime_index )) + mfC(:,1:end-1,aiTime_index);

                        % Apply bed r.b.c.
                        mfC(:, end, aiTime_index) = mfC(:, end-1, aiTime_index);
                    else
                        % Concentration and loading for MetOx absorption
                        mfC( :, 1:end-1, aiTime_index ) = this.ofilter_table.calculate_C_new(mfC( :, 1:end-1, aiTime_index-1 ), fReactionTimeStep, this.fSorptionTemperature, this.csNames, this.fVolSolid, this.iNumGridPoints, this.afMolarMass);
                        mfQ( :, 1:end-1, aiTime_index ) = mfQ( :, 1:end-1, aiTime_index ) + (mfC(:,:,aiTime_index-1 ) - mfC( :, 1:end-1, aiTime_index ));
                    end
                end
            else 
                %----------------------------------------------
                %------------------SOLVE-----------------------
                %----------------------------------------------
                for aiTime_index = 2:iTimePoints
                    % TO DO: the number of iTimePoints was reduced by
                    % the value of fTimeFactor_1 (for a value of 2 the
                    % number of iTimePoints is 1/2 of the original
                    % value). This was performed to reduce the number
                    % of plotting intervals (see section 4.2.1 from
                    % RT_BA_2013_15). However the way this was implemented
                    % in V-HAB did not result in a limitation of the
                    % plotting variable since previously these two
                    % lines were at this position:
                    %
                    % Read values from previous time step
                    % mfC( :, :, aiTime_index ) = mfC( :, :, aiTime_index-1 );
                    % mfQ( :, :, aiTime_index ) = mfQ( :, :, aiTime_index-1 );
                    %
                    % However these values are set later on anyway,
                    % therefore it does result in a reduction of
                    % simulation time as stated in RT_BA_2013-15 but
                    % instead increases it since an unnecessary
                    % allocation takes place
                    %
                    for iI = 1:this.fTimeFactor_1

                        %----------------------------------------------
                        %---------------fluid transport----------------
                        %----------------------------------------------

                        % Solve equation system
                        if iI == 1
                            mfC( :, :, aiTime_index ) = mfC( :, :, aiTime_index-1 ) * mfMatrix_Transport_A1 + afVektor_Transport_b1;

                            % Store transportation result values in buffer for later usage
                            mfQ_save = mfQ( :, 1:end-1, aiTime_index-1 );
                            mfC_save = mfC( :, 1:end-1, aiTime_index-1 );
                        else
                            mfC( :, :, aiTime_index ) = mfC( :, :, aiTime_index ) * mfMatrix_Transport_A1 + afVektor_Transport_b1;

                            % Store transportation result values in buffer for later usage
                            mfQ_save = mfQ( :, 1:end-1, aiTime_index );
                            mfC_save = mfC( :, 1:end-1, aiTime_index );
                        end

                        %---------------------------------------------------------------
                        %-----------------------LDF reaction part-----------------------
                        %---------------------------------------------------------------

                        for iJ = 1:this.fTimeFactor_2

                            % Concentration and loading for FBA and RCA/Amine absorption
                            if ~bMetox
                                % Update thermodynamic constant
                                if bLimitToth
                                    mDiff = abs(mfC(:,:,aiTime_index) - mfC_LastToth); 
                                    if (max(mDiff(:)) > this.fLimitTothCalculation) || aiTime_index == 2
                                        % Calculates the capacity of the filter using the toth equation
                                        % saved in the filter table file. The caclulation is then
                                        % performeed using a linearized thermodynamic konstant k which,
                                        % if multiplied with the current concentration, yields the
                                        % current capacity of the filter.
                                        mfThermodynConst_K = this.ofilter_table.get_ThermodynConst_K(mfC(:,1:end-1,aiTime_index), this.fSorptionTemperature, this.fRhoSorbent, this.csNames, this.afMolarMass);     %linearized adsorption equilibrium isotherm slope [-]
                                        mfC_LastToth = mfC(:,:,aiTime_index);

                                        % Update kinetic lumped constant                        
                                        % either gets the saved constant kinematic constant or
                                        % calculates it from the equations saved in the filter table
                                        if bConst_k_l
                                            mfKineticConst_k_l = this.k_l(:,(1:length(mfThermodynConst_K)));
                                        else
                                            mfKineticConst_k_l = this.ofilter_table.get_KineticConst_k_l(mfThermodynConst_K, this.fSorptionTemperature, this.fSorptionPressure, this.fSorptionDensity, this.afConcentration, this.fRhoSorbent, this.fVolumetricFlowRate, this.rVoidFraction, this.csNames, this.afMolarMass);
                                        end
                                    end
                                else
                                    mfThermodynConst_K = this.ofilter_table.get_ThermodynConst_K(mfC( :, 1:end-1, aiTime_index ), this.fSorptionTemperature, this.fRhoSorbent, this.csNames, this.afMolarMass);     %linearized adsorption equilibrium isotherm slope [-]

                                    % Update kinetic lumped constant                        
                                    % either gets the saved constant kinematic constant or
                                    % calculates it from the equations saved in the filter table
                                    if bConst_k_l
                                        mfKineticConst_k_l = this.k_l(:,(1:length(mfThermodynConst_K)));
                                    else
                                        mfKineticConst_k_l = this.ofilter_table.get_KineticConst_k_l(mfThermodynConst_K, this.fSorptionTemperature, this.fSorptionPressure, this.fSorptionDensity, this.afConcentration, this.fRhoSorbent, this.fVolumetricFlowRate, this.rVoidFraction, this.csNames, this.afMolarMass);
                                    end
                                end

                                % Calculate local equilibrium value
                                % Equation 3.42 from RT-BA 2013/15
                                mfQ_equ_local = mfThermodynConst_K .* (mfC_save + this.fHelperConstant_a * mfQ_save) ./ (1 + mfThermodynConst_K * this.fHelperConstant_a);

                                % Result of the time step according to LDF
                                % formula (modified equation 3.40 from 
                                % RT-BA 2013/15)
                                if iI == 1 && iJ == 1
                                    mfQ( :, 1:end-1, aiTime_index ) = exp(-mfKineticConst_k_l .* (1 + mfThermodynConst_K * this.fHelperConstant_a) * fReactionTimeStep) .* (mfQ(:, 1:end-1, aiTime_index-1) - mfQ_equ_local) + mfQ_equ_local;
                                else
                                    mfQ( :, 1:end-1, aiTime_index ) = exp(-mfKineticConst_k_l .* (1 + mfThermodynConst_K * this.fHelperConstant_a) * fReactionTimeStep) .* (mfQ(:, 1:end-1, aiTime_index) - mfQ_equ_local) + mfQ_equ_local;
                                end
                                % Equation 3-29 from RT-BA 2013/15
                                mfC( :, 1:end-1, aiTime_index ) = this.fHelperConstant_a * (mfQ_save - mfQ( :, 1:end-1, aiTime_index )) + mfC_save;
                            else
                                % Concentration and loading for MetOx absorption
                                mfC( :, 1:end-1, aiTime_index ) = this.ofilter_table.calculate_C_new(mfC( :, 1:end-1, aiTime_index ), fReactionTimeStep, this.fSorptionTemperature, this.csNames, this.fVolSolid, this.iNumGridPoints, this.afMolarMass);
                                mfQ( :, 1:end-1, aiTime_index ) = mfQ( :, 1:end-1, aiTime_index ) + (mfC_save - mfC( :, 1:end-1, aiTime_index ));
                            end

                        end

                        % Apply bed r.b.c.
                        mfC(:, end, aiTime_index) = mfC(:, end-1, aiTime_index);

                    end
                end
            end
            
            %% Post Processing

            % Save as transfer variable for plotting
            % Loading of the filter
            this.q_plot = mfQ(:, [1,ceil(length(mfQ(1, :, end))/2), end-1],end) / this.fRhoSorbent;   % [mol/kg]
            this.c_plot = mfC(:, [1,ceil(length(mfQ(1, :, end))/2), end-1],end) / this.fRhoSorbent;   % [mol/kg]
            
            % Initialize array for filtered mass
            afLoadedMass_ads = zeros(1, this.iNumSubstances);
            afLoadedMass_des = zeros(1, this.iNumSubstances); 
           
            %%
            % Convert to Loading [kg/m3]
            mfMolarMass = ones(size(mfQ(:, :, end)));
            for iSubstance = 1:length(this.afMolarMass)
                mfMolarMass(iSubstance,:) = mfMolarMass(iSubstance,:).*this.afMolarMass(iSubstance);
            end
            
            mfQ_density = mfQ(:, 1:end-1, end).*mfMolarMass(:, 1:end-1); % [kg/m3]
            
            % mean density time total volume yields total loading:
            afCurrentLoading = mean(mfQ_density ,2) * this.fVolSolid;
            
            % and subtracting the new current loading from the loading
            % already in the filter phase results in the respective mass
            % flows
            afLoadedMassDifference = real(afCurrentLoading) - this.oOut.oPhase.afMass(this.aiPositions)';
            
             %%
            % Sum up loading change in [mol/m3]
            mfQ_mol_change = mfQ(:, :, end) - this.mfQ_current;
            
            % Convert the change to [kg/m3]
            mfQ_density_change = mfQ_mol_change .* mfMolarMass;

            %TODO The following operation ist more elegant, but unfortunately
            % only works with MATLAB 2016a or newer. It can be changed here
            % at a time when most users have updated.
            %mfQ_density_change = mfQ_mol_change .* this.afMolarMass';
            
            % Convert the change to mass in [kg]
            % TO DO: two cells are mentioned as boundary cells but in
            % mfQ_density_change only one cell is neglected? The last
            % entry of mfQ is always 0, that is definityl a boundary cell
            % (that is not used in any calculations btw) but aside from
            % that is the first cell actually a boundary cell? Or is it
            % only a boundary cell for the concentration mfC (where the
            % first cell is required to have the concentration of the inlet
            % flow)
            mfQ_mass_change = mfQ_density_change(:, 1:end-1) * this.fVolSolid / (this.iNumGridPoints-2);   % in [kg]       % -1 (ghost cell) -1 (2 boundary points)
            
            % Sum up filtered mass during the time step
            afLoadedMass = real(sum(mfQ_mass_change, 2));
            
            % the internal calculated absorbed mass and the actually
            % absorbed mass in the V-HAB phase can be different. This
            % difference is balanced with the following calculation. It
            % basically tries to balance out the current difference over 10
            % s to prevent oscillations. Only the DIfference is multiplied
            % with the time step to prevent very small time steps from
            % resulting in extreemly large flow rates.
            afLoadedMass = afLoadedMass + 0.1 * (afLoadedMassDifference*(afDiscreteTime(end) - afDiscreteTime(1)));
            
%%
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

            
            % Debugging break point
%             if (this.oOut.oPhase.afMass(this.oMT.tiN2I.CO2) == 0) && (abs(this.fFlowRate_des) > 1e-6)
%                 keyboard()
%             end
%             
%             if (mod(this.oTimer.fTime, 1000) < 2) && strcmp(this.sName, 'Filter_5A_2_proc')
%                 B = this.mfQ_current(:,2:end-1) .* mfMolarMass;
%                 A = mean(B,2) * this.fVolSolid;
%                 C = this.oOut.oPhase.afMass(this.aiPositions);
%                 keyboard()
%             end

            
            this.fInternalLoading = mean((this.mfQ_current(:,1:end-1) .* mfMolarMass(:, 1:end-1)),2)* this.fVolSolid;
            if strcmp(this.sName, 'Filter_5A_2_proc') || strcmp(this.sName, 'Filter_5A_1_proc')
                this.fInternalLoading = this.fInternalLoading(1); %can only log scalar values, here CO2 loading for 5A and H2o for all others
            else
                this.fInternalLoading = this.fInternalLoading(2); %can only log scalar values, here CO2 loading for 5A and H2o for all others
            end
            
            %% Set the matter properties      
            % Update bed status
            if ~isreal(mfC(:,:,end))
                this.iImaginaryOccCounter = this.iImaginaryOccCounter +1;
            end
            
            this.mfC_current = real(mfC(:, :, end));
            this.mfQ_current = real(mfQ(:, :, end));
            
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
            
            % Debugging break point
            if isnan(this.fFlowRate_des) || isnan(this.fFlowRate_ads) || ~isreal(this.fFlowRate_des) || ~isreal(this.fFlowRate_ads)
                keyboard()
            end
            
            
% TODO: DO WE NEED THAT???
%             % Calculation of the pressure drop through the filter bed
%             fDeltaP = this.ofilter_table.calculate_dp(this.fFilterLength, this.fFluidVelocity, this.rVoidFraction, this.fSorptionTemperature, this.fSorptionDensity);
%             % New pressure at the outlet port
%             fPressureOut = this.oStore.aoPhases(1).toProcsEXME.Inlet.aoFlows.fPressure - fDeltaP;       %[Pa]
%             % Get the flowrate, partial mass and temperature at the outlet
%             fFlowRateOut = this.oStore.aoPhases(1).toProcsEXME.Inlet.aoFlows.fFlowRate - this.fFlowRate_ads - this.fFlowRate_des;    %[kg/s]
%             arPartialMassOut = zeros(1,this.oMT.iSpecies);
%             arPartialMassOut(this.aiPositions) = mfC(:,end,end).*this.afMolarMass' / sum(mfC(:,end,end).*this.afMolarMass');
%             fTempOut = this.oStore.aoPhases(1).toProcsEXME.Inlet.aoFlows.fTemp;                        %[K]
%             
%             % Update the matter properties with the new lower pressure
%             this.oStore.aoPhases(1).toProcsEXME.Outlet.aoFlows.setMatterProperties(fFlowRateOut, arPartialMassOut, fTempOut, fPressureOut);                   
            
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
            
        end
        
        function setNumericalValues(this, iNumGridPoints, fTimeFactor_1, fTimeFactor_2)
            
            % Overwrite the numerical values
            this.iNumGridPoints = iNumGridPoints;
            this.fTimeFactor_1  = fTimeFactor_1;
            this.fTimeFactor_2  = fTimeFactor_2;
              
        end
    end
end
