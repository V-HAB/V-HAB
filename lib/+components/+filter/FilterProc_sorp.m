classdef FilterProc_sorp < matter.procs.p2ps.flow
    
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
        
        % Transfer variable for plotting
        q_plot;
        c_plot;
        
        % Logging variable to see how long the update method takes to
        % execute.
        fUpdateDuration;
        
    end
    
   
    
    methods
        
        %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%% Constructor %%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        function [this] = FilterProc_sorp(oStore, sName, sPhaseIn, sPhaseOut, sType)
            this@matter.procs.p2ps.flow(oStore, sName, sPhaseIn, sPhaseOut);
            
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
                    this.ofilter_table = components.filter.FBA_Table;  
                    
                case 'RCA'
                    this.fRhoSorbent   = 636.7;    % SA9-T density [kg/m^3]
                    % Set bed length
                    this.fFilterLength = this.oStore.fx;    % [m]
                    % Load corresponding helper table
                    this.ofilter_table = components.filter.RCA_Table; 
                    
                case 'MetOx'
                    this.fRhoSorbent   = 636.7;    % TODO: Add right value [kg/m^3]
                    % Set bed length
                    this.fFilterLength = this.oStore.fx;    % [m]
                    % Load corresponding helper table
                    this.ofilter_table = components.filter.MetOx_Table;
                    
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
            %%%%%%%%%%%%%%%%%%%%%%%%%%
            
            
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
            
            % Get inflow flow rate
            fFlowRateIn = this.oStore.toPhases.FlowPhase.toProcsEXME.Inlet.oFlow.fFlowRate;
            
            % If there is matter flowing out of the inlet, then we are in
            % some sort of transient phase at the beginning of a simulation
            % or right after a bed switch. To avoid problems later on,
            % we'll just skip this execution and try next time. 
            if fFlowRateIn < 0
                %TODO make this a very low level debugging output once the
                %debug class is implemented
                fprintf('%i\t(%.7fs)\t%s: Skipping adsorption calculation because of negative flow rate.\n', this.oTimer.iTick, this.oTimer.fTime, this.oStore.sName);
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
%             if fFlowRateIn == 0
%                 % If the incoming flow rate is zero, we use the properties
%                 % of the phase from which we adsorb.
%                 % Phase pressure
%                 this.fSorptionPressure    = this.oIn.oPhase.fPressure;
%                 % Phase temperature
%                 this.fSorptionTemperature = this.oIn.oPhase.fTemperature;
% %                 % Phase mass fractions
% %                 arMassFractions           = this.oIn.oPhase.arPartialMass ...
% %                                            (this.oIn.oPhase.arPartialMass > 0);
%                 arMassFractions           = this.oIn.oPhase.arPartialMass(this.aiPositions);
%                 
%                 % Calculating the mol fraction [-]
%                 arMolFractions            = arMassFractions * this.oIn.oPhase.fMolarMass ./ this.afMolarMass;      
%                 % Calculation of phase concentrations in [mol/m^3]
%                 this.afConcentration      = arMolFractions * this.fSorptionPressure / (this.fUnivGasConst_R * this.fSorptionTemperature);                    
%                 % Calculating the density of the phase in [kg/m^3]
%                 this.fSorptionDensity     = this.fSorptionPressure * this.oIn.oPhase.fMolarMass / ...                    
%                                             this.fUnivGasConst_R / this.fSorptionTemperature;
%             else
                % Inlet pressure
                this.fSorptionPressure    = this.oStore.toPhases.FlowPhase.toProcsEXME.Inlet.oFlow.fPressure;
                % Inlet temperature
                this.fSorptionTemperature = this.oStore.aoPhases(1).toProcsEXME.Inlet.oFlow.fTemperature;
%                 % Inlet mass fractions
%                 arMassFractions           = this.oStore.toPhases.FlowPhase.toProcsEXME.Inlet.oFlow.arPartialMass ...
%                                            (this.oStore.toPhases.FlowPhase.toProcsEXME.Inlet.oFlow.arPartialMass > 0);
                arMassFractions           = this.oStore.toPhases.FlowPhase.toProcsEXME.Inlet.oFlow.arPartialMass(this.aiPositions);
                                       
                % Calculating the mol fraction [-]
                arMolFractions            = arMassFractions * this.oStore.toPhases.FlowPhase.toProcsEXME.Inlet.oFlow.fMolarMass ./ this.afMolarMass;
                % Calculation of the incoming concentrations in [mol/m^3]
                this.afConcentration      = arMolFractions * this.fSorptionPressure / (this.fUnivGasConst_R * this.fSorptionTemperature);
                % Calculating the density of the inflowing matter in [kg/m^3]
                this.fSorptionDensity     = (this.fSorptionPressure * this.oStore.toPhases.FlowPhase.toProcsEXME.Inlet.oFlow.fMolarMass) / ...
                                            (this.fUnivGasConst_R * this.fSorptionTemperature);
%             end
            
            % In some cases (manual solver in combination with an empty
            % phase at one end to which this p2p processor is connected)
            % the pressure here can be zero. It should only be zero for one
            % timestep, so we'll just skip this one.
            if this.fSorptionPressure <= 0 
                %TODO make this a very low level debugging output once the
                %debug class is implemented
                fprintf('%i\t(%.7fs)\t%s: Skipping adsorption calculation because of zero or negative pressure.\n', this.oTimer.iTick, this.oTimer.fTime, this.oStore.sName);
                return;
            end

            % Convert flow rate into [m^3/s]
            this.fVolumetricFlowRate = fFlowRateIn / this.fSorptionDensity;       % [m^3/s]

            % Calculate flow velocity
            this.fFluidVelocity = this.fVolumetricFlowRate / (this.fVolFlow / this.fFilterLength);      % [m/s]

            % Get dispersion coefficient
            fAxialDispersion_D_l = this.ofilter_table.get_AxialDispersion_D_L(this.fFluidVelocity, this.fSorptionTemperature, this.fSorptionPressure, this.afConcentration, this.csNames, this.afMolarMass);
           
            % Calculate helper constant for concentration switch sorbent <-> sorptive
            fHelperConstant_a = (1 - this.rVoidFraction) / this.rVoidFraction;        % [-]
            
            % Initialize time domain
            % Numerical time grid spacing (dispersive transport stability)
            afInnerTimeStep(1) = this.fDeltaX^2 / (this.fFluidVelocity * this.fDeltaX + 2 * fAxialDispersion_D_l);
            % BUT: calculated time step needs to be smaller than current vhab time step
            
            if this.fTimeFactor_1 * afInnerTimeStep(1) >= this.fTimeStep
                %TODO Turn this into a very low level debug output once the
                %debug class is implemented
                %fprintf('%i\t(%f)\t%s: Skipping because inner time step is larger than external timestep.\n', this.oTimer.iTick, this.oTimer.fTime, this.oStore.sName);
                return;
            end
            
            % Make reaction time constant a multiple of transport time constant
            afInnerTimeStep(2) = afInnerTimeStep(1) / this.fTimeFactor_2;
            % Discretized time domain
            afDiscreteTime = (this.fCurrentSorptionTime : (this.fTimeFactor_1 * afInnerTimeStep(1)) : this.fCurrentSorptionTime + this.fTimeStep);   
            % Number of numerical time grid points
            iTimePoints = length(afDiscreteTime);  
            this.fTimeDifference = this.fTimeStep - (afDiscreteTime(end) - afDiscreteTime(1));        
            
            % Initialize matrices for dispersive transport
            mfMatrix_A = zeros(this.iNumGridPoints);
            mfMatrix_B = zeros(this.iNumGridPoints);
            mfMatrix_Transport_A1 = zeros(this.iNumGridPoints);
            afVektor_Transport_b1 = zeros(this.iNumSubstances, this.iNumGridPoints);
            [mfMatrix_Transport_A1, afVektor_Transport_b1] = this.buildMatrix(fAxialDispersion_D_l, afInnerTimeStep(1), mfMatrix_A, mfMatrix_B, mfMatrix_Transport_A1, afVektor_Transport_b1);
            
            % Initialize solution matrices
            mfC = zeros(this.iNumSubstances,this.iNumGridPoints,iTimePoints);
            mfQ = zeros(this.iNumSubstances,this.iNumGridPoints,iTimePoints);
            
            % Apply initial conditions
            mfC(:,:,1) = this.mfC_current;
            mfC(:,1,1) = this.afConcentration;
            mfQ(:,:,1) = this.mfQ_current;
            
            %----------------------------------------------
            %------------------SOLVE-----------------------
            %----------------------------------------------
            for aiTime_index = 2:iTimePoints
                
                % Read values from previous time step
                mfC(:,:,aiTime_index) = mfC(:,:,aiTime_index-1);
                mfQ(:,:,aiTime_index) = mfQ(:,:,aiTime_index-1);
                
                for iI = 1:this.fTimeFactor_1
                    
                    %----------------------------------------------
                    %---------------fluid transport----------------
                    %----------------------------------------------
                    
                    % Solve equation system
                    mfC(:,:,aiTime_index) = mfC(:,:,aiTime_index) * mfMatrix_Transport_A1 + afVektor_Transport_b1;
                    
                    %---------------------------------------------------------------
                    %-----------------------LDF reaction part-----------------------
                    %---------------------------------------------------------------
                    
                    % Store transportation result values in buffer for later usage
                    mfQ_save = mfQ(:,1:end-1,aiTime_index);
                    mfC_save = mfC(:,1:end-1,aiTime_index);
                    
                    for iJ = 1:this.fTimeFactor_2
                        % Concentration and loading for adsorption
                        if strcmp(this.sType, 'RCA') || strcmp(this.sType, 'FBA')
                            % Update thermodynamic constant
                            mfThermodynConst_K = this.ofilter_table.get_ThermodynConst_K(mfC(:,1:end-1,aiTime_index), this.fSorptionTemperature, this.fRhoSorbent, this.csNames, this.afMolarMass);     %linearized adsorption equilibrium isotherm slope [-]
                            
                            % Update kinetic lumped constant
                            mfKineticConst_k_l = this.ofilter_table.get_KineticConst_k_l(mfThermodynConst_K, this.fSorptionTemperature, this.fSorptionPressure, this.fSorptionDensity, this.afConcentration, this.fRhoSorbent, this.fVolumetricFlowRate, this.rVoidFraction, this.csNames, this.afMolarMass);
                            
                            % Calculate local equilibrium value
                            mfQ_equ = mfThermodynConst_K .* (mfC_save + fHelperConstant_a * mfQ_save) ./ (1 + mfThermodynConst_K * fHelperConstant_a);
                            
                            % Result of the time step according to LDF formula
                            mfQ(:,1:end-1,aiTime_index) = exp(-mfKineticConst_k_l .* (1 + mfThermodynConst_K * fHelperConstant_a) * afInnerTimeStep(2)) .* (mfQ(:, 1:end-1, aiTime_index) - mfQ_equ) + mfQ_equ;
                            mfC(:,1:end-1,aiTime_index) = fHelperConstant_a * (mfQ_save - mfQ(:, 1:end-1, aiTime_index)) + mfC_save;
                            
                        % Concentration and loading for MetOx absorption
                        elseif strcmp(this.sType, 'MetOx')
                            mfC(:,1:end-1,aiTime_index) = this.ofilter_table.calculate_C_new(mfC(:,1:end-1,aiTime_index), afInnerTimeStep(2), this.fSorptionTemperature, this.csNames, this.fVolSolid, this.iNumGridPoints, this.afMolarMass);
                            mfQ(:,1:end-1,aiTime_index) = mfQ(:, 1:end-1, aiTime_index) + (mfC_save - mfC(:, 1:end-1, aiTime_index));
                        end
                        
                    end
                    
                    % Apply bed r.b.c.
                    mfC(:, end, aiTime_index) = mfC(:, end-1, aiTime_index);
                    
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
            
            % Sum up loading change in [mol/m3]
            mfQ_mol_change = mfQ(:, :, end) - this.mfQ_current;
            
            % Convert the change to [kg/m3]
            mfQ_density_change = mfQ_mol_change .* this.afMolarMass';
            
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
            this.mfQ_current = mfQ(:, :, end);
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
         
        
        function [mfMatrix_Transport_A1, afVektor_Transport_b1] = buildMatrix(this, fAxialDispersion_D_l, afInnerTimeStep, mfMatrix_A,mfMatrix_B, mfMatrix_Transport_A1, afVektor_Transport_b1)
            % Build an advection diffusion massbalance matrix
            % Extended Upwind scheme
            fNumericDispersion_D_num = this.fFluidVelocity / 2 * (this.fDeltaX - this.fFluidVelocity * afInnerTimeStep);
            fEntry_a = afInnerTimeStep * this.fFluidVelocity / this.fDeltaX;
            fEntry_b = afInnerTimeStep * (fAxialDispersion_D_l - fNumericDispersion_D_num) / this.fDeltaX^2;
            
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
