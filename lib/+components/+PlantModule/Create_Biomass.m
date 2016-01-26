classdef Create_Biomass < matter.manips.substance.flow
    
    % Short description:
    %  This manipulator creates biomass and handles the gas production and
    %  the gas consumption caused by the plants.
    %  The Plants-phase of the PlantCultivationStore is treated.
    
    properties %(SetAccess = protected, GetAccess = public)
        
        %properties regarding plant growth handling
        tPlantData;
        fCCulture;
        fFields;
        fState;
        fPlant;
        
        
        %reference time tranformed to minutes (total simulation time since start)
        fTimeInMinutes;
        
        oParent;
        
        %array for handling harvest amounts sourcing in different grown cultures
        afPartials=0;
        afPartials2=0;
        
        %growth conditions
        fWaterAvailable;
        fPressureAtmosphere;
        fRelativeHumidityLight;
        fRelativeHumidityDark;
        fPPF;
        fCO2ppm             = 1300;
        fCO2ppm_Measured    = 1300;
        fH;
        fTemperatureLight;
        fTemperatureDark;
        
        %biomass growth shares
        fINEDIBLE_CGR_d;
        fINEDIBLE_CGR_f;
        fED_CGR_d;
        fED_CGR_f;
        
        %gas/water exchange rates
        fO2Exchange = 0;
        fCO2Exchange = 0;
        fH2OExchange = 0;
        fWaterNeed = 0;
        
        %variable for update check
        fLastUpdate = 0;
        
        
        %properties regarding logging of gas and water exchanges
        fO2_sum = 0;
        afO2_sum_out;
        fO2_sum_total = 0;
        fO2Exchange_out = 0;
        
        fCO2_sum = 0;
        afCO2_sum_out;
        fCO2_sum_total = 0;
        fCO2Exchange_out = 0;
        
        fH2O_trans_sum = 0;
        afH2O_trans_sum_out;
        fH2O_trans_sum_total = 0;
        fH2OExchange_out = 0;
        
        fH2O_consum_sum = 0;
        afH2O_consum_sum_out;
        fH2O_consum_sum_total = 0;
        fWaterNeed_out = 0;
        
        
        
    end
    
    
    methods
        function this = Create_Biomass(oParent, sName, oPhase, tPlantData, tPlantParameters, fTemperatureLight, fTemperatureDark, fRelativeHumidityLight, fRelativeHumidityDark, fPressureAtmosphere, fCO2ppm, fPPF, fH, fWaterAvailable)
            this@matter.manips.substance.flow(sName, oPhase);
            
            %Referencing sources for plant basic growth parameters
            this.fPlant = tPlantParameters;
            this.tPlantData = tPlantData.PlantEng;
            this.fCCulture.sName='Plants';
            
            
            %Names of Cultures in loaded growth setup "PlantEng"
            this.fFields = fieldnames(this.tPlantData);
            
            
            global bUseGlobalPlantConditions
            
            %assigning parent object
            this.oParent = oParent;
            
            %assigning growth parameters
            this.fWaterAvailable    = fWaterAvailable;          % [kg]
            this.fPressureAtmosphere             = fPressureAtmosphere;                   % [Pa]
            this.fRelativeHumidityLight            = fRelativeHumidityLight;                  % [-]
            this.fRelativeHumidityDark          = fRelativeHumidityDark;                % [-]
            this.fH                 = fH;                       % [hourds/day]
            this.fTemperatureLight        = fTemperatureLight;              % [°C]
            this.fTemperatureDark         = fTemperatureDark;               % [°C]
            
            
            
            %transforming and assigning reference growth times to minutes
            for i=1:size(this.fPlant,2)
                this.fPlant(i).tM_nominal=this.fPlant(i).tM_nominal*24*60;  % [min]
                this.fPlant(i).tQ=this.fPlant(i).tQ*24*60;                  % [min]
                this.fPlant(i).tE=this.fPlant(i).tE*24*60;                  % [min]
            end
            
            
            
            %For each entry in "PlantEng" (= number of entries in "this.fFields") ...
            % ... assign the following parameters in the fCCulture struct
            for x=1:length(this.fFields)
                this.fCCulture.plants{x, 1}.state=eval(['this.tPlantData.' this.fFields{x} '.EngData']);
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                
                % Factor to transform specific day-based values minute-based values
                this.fCCulture.plants{x, 1}.FactorDaysToMinutes         = 60*24;        % [min/d]
                
                % Factor to transform specific hourly based rates (from Calculate_PlantGrowthParameters)
                % to rates basing on seconds
                this.fCCulture.plants{x, 1}.FactorHourlyRatesToSeconds  = 1 /(60*60);   % [s/h]
                
                
                
                
                % Assigning of harvest time in minutes
                this.fCCulture.plants{x, 1}.state.harv_time     =   ...
                    this.fCCulture.plants{x, 1}.state.harv_time * this.fCCulture.plants{x, 1}.FactorDaysToMinutes;
                
                
                
                %Assigning growth conditions, depending und simulation settings in "PlantModule"-system
                if bUseGlobalPlantConditions == 1 % Global growth conditions are used
                    this.fPPF       = fPPF;         % [µmol/m^2/s]
                    this.fCO2ppm    = fCO2ppm;   % [µmol/mol]
                    %Assigning CO2 and PPF value to the corresponding culture state
                    this.fCCulture.plants{x, 1}.state.CO2 = this.fCO2ppm;
                    this.fCCulture.plants{x, 1}.state.PPF = this.fPPF;
                    
                else % Specific growth conditions for each single culture are used
                    
                    %Assigning CO2, PPF, H value from the corresponding culture state
                    this.fPPF       = this.fCCulture.plants{x, 1}.state.PPF;    % [µmol/m^2/s]
                    this.fCO2ppm    = this.fCCulture.plants{x, 1}.state.CO2;    % [µmol/mol]
                    this.fH         = this.fCCulture.plants{x, 1}.state.H;      % [hours/day]
                end
                
                
                
                
                if isempty(this.fCCulture.plants{x, 1}.state.H)
                    %Usage of plant specific H value
                    this.fCCulture.plants{x, 1}.state.H = this.fPlant(this.fCCulture.plants{x, 1}.state.plant_type).H0;
                end
                
                
                
                
                %assinging all initial growth process to the considered plant's state - default settings
                this.fCCulture.plants{x, 1}.state.internaltime          = 0;
                this.fCCulture.plants{x, 1}.state.internalGeneration    = 1;
                this.fCCulture.plants{x, 1}.state.emerge_time = this.fCCulture.plants{x, 1}.state.emerge_time*this.fCCulture.plants{x, 1}.FactorDaysToMinutes;
                this.fCCulture.plants{x, 1}.state.TCB                   = 0;
                this.fCCulture.plants{x, 1}.state.TEB                   = 0;
                this.fCCulture.plants{x, 1}.state.O2_exchange           = 0;
                this.fCCulture.plants{x, 1}.state.CO2_exchange          = 0;
                this.fCCulture.plants{x, 1}.state.water_exchange        = 0;
                this.fCCulture.plants{x, 1}.state.CUE_24                = 0;
                this.fCCulture.plants{x, 1}.state.A                     = 0;
                this.fCCulture.plants{x, 1}.state.P_net                 = 0;
                this.fCCulture.plants{x, 1}.state.CQY                   = 0;
                this.fCCulture.plants{x, 1}.state.CO2_assimilation_fct  = 1;
                this.fCCulture.plants{x, 1}.state.t_without_H2O         = 0;
                
                %test
                this.fCCulture.plants{x, 1}.state.TCB_CGR_test          = 0;
                
                
                %Harvest variables
                this.fCCulture.plants{x, 1}.state.time_since_planting   = 0;
                this.fCCulture.plants{x, 1}.state.CultureNumber         = x;
                
                this.fCCulture.plants{x, 1}.INEDIBLE_CGR_d              = 0;
                this.fCCulture.plants{x, 1}.INEDIBLE_CGR_f              = 0;
                this.fCCulture.plants{x, 1}.ED_CGR_d                    = 0;
                this.fCCulture.plants{x, 1}.ED_CGR_f                    = 0;
                
                this.fCCulture.plants{x, 1}.O2_sum_out                  = 0;
                this.fCCulture.plants{x, 1}.CO2_sum_out                 = 0;
                this.fCCulture.plants{x, 1}.H2O_trans_sum_out           = 0;
                this.fCCulture.plants{x, 1}.H2O_consum_sum_out          = 0;
                
                
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                
                % Assigning plant_type of currently considered culture
                % (variable x)  to its state
                this.fCCulture.PlantType(x) = this.fCCulture.plants{x, 1}.state.plant_type;
                
                % Assigning the current culture's name to
                %  ...fCCculture{x,1}
                this.fCCulture.CultureInfo{x} = this.fFields{x};
                
                % Loading plant all parameters of the corresponding culture (variable x)
                %  from the PlantParameter-function
                %  into ...fCCulture.plants{x,1}.plant
                this.fCCulture.plants{x, 1}.plant=this.fPlant(this.fCCulture.PlantType(x));
                
                
            end %End of fCCulture assignment
            
            % Initializing some logging arrays
            this.afO2_sum_out         = zeros(1, length(this.fCCulture.plants));
            this.afCO2_sum_out        = zeros(1, length(this.fCCulture.plants));
            this.afH2O_trans_sum_out  = zeros(1, length(this.fCCulture.plants));
            this.afH2O_consum_sum_out = zeros(1, length(this.fCCulture.plants));
            
            
            
        end
        
        
        
        
        
        
        function update(this)
            
            if this.oTimer.iTick == 0 || this.oTimer.fTime <= 60
                return;
            end
            
            % Leaves update call when Update has already been done for
            % considered time
            if this.fLastUpdate == this.oParent.oTimer.fTime;
                return;
            end
            
            
            
            % The update only will be conducted every minute!
            % Necessary for proper "integration"
            if mod(this.oTimer.fTime, 60)~= 0;
                return;
            end
            
            
            %Array with a row for each matter available in matter table.
            % 80 columns for 80 possible plant cultures that could
            % contribute biomass at the same harvest time
            this.afPartials2 = zeros(this.oPhase.oMT.iSubstances, 80);
            %Target array for summated matter over all plant cultures (set up in PlantEng)
            % Matter is summated for each matter particular (-> columns)
            this.afPartials = zeros(1, this.oPhase.oMT.iSubstances);
            
            % Reference of position number inside matter table for requested matter
            tiN2I      = this.oPhase.oMT.tiN2I;
            
            
            
            
            %Transforming time from seconds to minutes
            this.fTimeInMinutes = this.oParent.oTimer.fTime / 60; % [min]
            
            
            global bUseGlobalPlantConditions
            
            
            
            for iI = 1:size(this.fCCulture.plants, 1)
                
                
                %Updating current CO2ppm and PPF Greenhouse conditions
                % (with corresponding simulation settings)
                
                
                if bUseGlobalPlantConditions == 1
                    this.fPPF       = this.oParent.fPPF;                            %PPF of parent System
                    this.fCO2ppm    = this.oParent.fCO2ppm;                         %CO2 PPM of parent system; Either 'predefined' or 'live LSS' value
                else
                    this.fPPF       = this.fCCulture.plants{iI, 1}.state.PPF;        %Use PPF from plant setup
                    this.fCO2ppm    = this.fCCulture.plants{iI, 1}.state.CO2;        %Use CO2 PPM from plant setup
                    this.fH         = this.fCCulture.plants{iI, 1}.state.H;          %Use H (photoperiod per day) value from plant setup
                end
                
                
                %Call of function, processing the plant growth
                %%%%%%%%%%%%%
                % -Output Parameters-
                [this.fCCulture.plants{iI, 1},          ...     % State of cultures
                    this.fINEDIBLE_CGR_d,               ...     % Inedible harvest mass dry             [kg]
                    this.fINEDIBLE_CGR_f,               ...     % Inedible harvest mass fluid           [kg]
                    this.fED_CGR_d,                     ...     % Edible harvest mass dry               [kg]
                    this.fED_CGR_f,                     ...     % Edible harvest mass fluid             [kg]
                    this.fO2Exchange,                  ...     % Oxygen exchange rate                  [kg/s]
                    this.fCO2Exchange ,                ...     % Carbon dioxide exchange rate          [kg/s]
                    this.fH2OExchange,               ...     % Water exchange rate (transpiration)   [kg/s]
                    this.fWaterNeed,                    ...     % Water consumption rate                [kg/s]
                    this.fO2_sum,                       ...     % Cumulated oxygen production           [kg]
                    this.fCO2_sum,                      ...     % Cumulated carbon dioxide consumption  [kg]
                    this.fH2O_trans_sum,                ...     % Cumulated water transpiration         [kg]
                    this.fH2O_consum_sum]               ...     % Cumulated water consumption           [kg]
                    = components.PlantModule.Process_PlantGrowthParameters(  ... % Path to function
                    ... % -Input Parameters-
                    this.fCCulture.plants{iI, 1},    ...     % State of cultures
                    this.fTimeInMinutes,            ...     % Time in minutes                       [min]
                    this.fWaterAvailable,           ...     % Water mass available                  [kg]
                    this.fPressureAtmosphere,                    ...     % Pressure                              [Pa]
                    this.fRelativeHumidityLight,                   ...     % Relative humidity day                 [-]
                    this.fRelativeHumidityDark,                 ...     % Relative humidity night               [-]
                    this.fPPF,                      ...     % Photosynthetic photon flux            [µmol/m^2/s]
                    this.fCO2ppm,                   ...     % CO2 level                             [µmol/mol]
                    this.fCO2ppm_Measured,          ...     % CO2 level in LSS                      [µmol/mol]
                    this.fH,                        ...     % Photoperiod per day                   [h/d]
                    this.fTemperatureLight,               ...     % Mean air temperature                  [°C]
                    this.fTemperatureDark);                       % Mean air temperature                  [°C]
                %%%%%%%%%%%%%%
                
                
                %assinging calculated growth rates to the considered culture (i)
                this.fCO2Exchange_out(iI)    = this.fCO2Exchange;
                this.fO2Exchange_out(iI)     = this.fO2Exchange;
                
                this.afO2_sum_out(iI)         = this.fO2_sum;
                this.afCO2_sum_out(iI)        = this.fCO2_sum;
                this.afH2O_trans_sum_out(iI)  = this.fH2O_trans_sum;
                this.afH2O_consum_sum_out(iI) = this.fH2O_consum_sum;
                
                this.fH2OExchange_out(iI)  = this.fH2OExchange;
                this.fWaterNeed_out(iI)       = this.fWaterNeed;
                
                
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                
                %at harvest time: harvested biomass components are assigned considering grown plant type
                switch this.fCCulture.PlantType(iI)
                    case 1 %'drybean'
                        this.afPartials2(tiN2I.DrybeanEdibleFluid, iI)       = (this.fED_CGR_f);
                        this.afPartials2(tiN2I.DrybeanInedibleFluid, iI)     = (this.fINEDIBLE_CGR_f);
                        this.afPartials2(tiN2I.DrybeanEdibleDry, iI)         = (this.fED_CGR_d);
                        this.afPartials2(tiN2I.DrybeanInedibleDry, iI)       = (this.fINEDIBLE_CGR_d);
                        
                    case 2 %'lettuce'
                        this.afPartials2(tiN2I.LettuceEdibleFluid, iI)       = (this.fED_CGR_f);
                        this.afPartials2(tiN2I.LettuceInedibleFluid, iI)     = (this.fINEDIBLE_CGR_f);
                        this.afPartials2(tiN2I.LettuceEdibleDry, iI)         = (this.fED_CGR_d);
                        this.afPartials2(tiN2I.LettuceInedibleDry, iI)       = (this.fINEDIBLE_CGR_d);
                        
                    case 3 %'peanut'
                        this.afPartials2(tiN2I.PeanutEdibleFluid, iI)        = (this.fED_CGR_f);
                        this.afPartials2(tiN2I.PeanutInedibleFluid, iI)      = (this.fINEDIBLE_CGR_f);
                        this.afPartials2(tiN2I.PeanutEdibleDry, iI)          = (this.fED_CGR_d);
                        this.afPartials2(tiN2I.PeanutInedibleDry, iI)        = (this.fINEDIBLE_CGR_d);
                        
                    case 4 %'rice'
                        this.afPartials2(tiN2I.RiceEdibleFluid, iI)          = (this.fED_CGR_f);
                        this.afPartials2(tiN2I.RiceInedibleFluid, iI)        = (this.fINEDIBLE_CGR_f);
                        this.afPartials2(tiN2I.RiceEdibleDry, iI)            = (this.fED_CGR_d);
                        this.afPartials2(tiN2I.RiceInedibleDry, iI)          = (this.fINEDIBLE_CGR_d);
                        
                    case 5 %'soybean'
                        this.afPartials2(tiN2I.SoybeanEdibleFluid, iI)       = (this.fED_CGR_f);
                        this.afPartials2(tiN2I.SoybeanInedibleFluid, iI)     = (this.fINEDIBLE_CGR_f);
                        this.afPartials2(tiN2I.SoybeanEdibleDry, iI)         = (this.fED_CGR_d);
                        this.afPartials2(tiN2I.SoybeanInedibleDry, iI)       = (this.fINEDIBLE_CGR_d);
                        
                    case 6 %'sweetpotato'
                        this.afPartials2(tiN2I.SweetpotatoEdibleFluid, iI)   = (this.fED_CGR_f);
                        this.afPartials2(tiN2I.SweetpotatoInedibleFluid, iI) = (this.fINEDIBLE_CGR_f);
                        this.afPartials2(tiN2I.SweetpotatoEdibleDry, iI)     = (this.fED_CGR_d);
                        this.afPartials2(tiN2I.SweetpotatoInedibleDry, iI)   = (this.fINEDIBLE_CGR_d);
                        
                    case 7 %'tomato'
                        this.afPartials2(tiN2I.TomatoEdibleFluid, iI)        = (this.fED_CGR_f);
                        this.afPartials2(tiN2I.TomatoInedibleFluid, iI)      = (this.fINEDIBLE_CGR_f);
                        this.afPartials2(tiN2I.TomatoEdibleDry, iI)          = (this.fED_CGR_d);
                        this.afPartials2(tiN2I.TomatoInedibleDry, iI)        = (this.fINEDIBLE_CGR_d);
                        
                    case 8 %'wheat'
                        this.afPartials2(tiN2I.WheatEdibleFluid, iI)         = (this.fED_CGR_f);
                        this.afPartials2(tiN2I.WheatInedibleFluid, iI)       = (this.fINEDIBLE_CGR_f);
                        this.afPartials2(tiN2I.WheatEdibleDry, iI)           = (this.fED_CGR_d);
                        this.afPartials2(tiN2I.WheatInedibleDry, iI)         = (this.fINEDIBLE_CGR_d);
                        
                    case 9 %'whitepotato'
                        this.afPartials2(tiN2I.WhitepotatoEdibleFluid, iI)   = (this.fED_CGR_f);
                        this.afPartials2(tiN2I.WhitepotatoInedibleFluid, iI) = (this.fINEDIBLE_CGR_f);
                        this.afPartials2(tiN2I.WhitepotatoEdibleDry, iI)     = (this.fED_CGR_d);
                        this.afPartials2(tiN2I.WhitepotatoInedibleDry, iI)   = (this.fINEDIBLE_CGR_d);
                end;
            end;
            
            %Summation of the single conbritutions by different plant cultures (set up in PlantEng),
            % harvested at the same time.
            % 'drybean'
            this.afPartials(1, tiN2I.DrybeanEdibleFluid)        = sum(this.afPartials2(tiN2I.DrybeanEdibleFluid,:));
            this.afPartials(1, tiN2I.DrybeanInedibleFluid)      = sum(this.afPartials2(tiN2I.DrybeanInedibleFluid,:));
            this.afPartials(1, tiN2I.DrybeanEdibleDry)          = sum(this.afPartials2(tiN2I.DrybeanEdibleDry,:));
            this.afPartials(1, tiN2I.DrybeanInedibleDry)        = sum(this.afPartials2(tiN2I.DrybeanInedibleDry,:));
            
            % 'lettuce'
            this.afPartials(1, tiN2I.LettuceEdibleFluid)        = sum(this.afPartials2(tiN2I.LettuceEdibleFluid,:));
            this.afPartials(1, tiN2I.LettuceInedibleFluid)      = sum(this.afPartials2(tiN2I.LettuceInedibleFluid,:));
            this.afPartials(1, tiN2I.LettuceEdibleDry)          = sum(this.afPartials2(tiN2I.LettuceEdibleDry,:));
            this.afPartials(1, tiN2I.LettuceInedibleDry)        = sum(this.afPartials2(tiN2I.LettuceInedibleDry,:));
            
            % 'peanut'
            this.afPartials(1, tiN2I.PeanutEdibleFluid)         = sum(this.afPartials2(tiN2I.PeanutEdibleFluid,:));
            this.afPartials(1, tiN2I.PeanutInedibleFluid)       = sum(this.afPartials2(tiN2I.PeanutInedibleFluid,:));
            this.afPartials(1, tiN2I.PeanutEdibleDry)           = sum(this.afPartials2(tiN2I.PeanutEdibleDry,:));
            this.afPartials(1, tiN2I.PeanutInedibleDry)         = sum(this.afPartials2(tiN2I.PeanutInedibleDry,:));
            %'rice'
            this.afPartials(1, tiN2I.RiceEdibleFluid)           = sum(this.afPartials2(tiN2I.RiceEdibleFluid,:));
            this.afPartials(1, tiN2I.RiceInedibleFluid)         = sum(this.afPartials2(tiN2I.RiceInedibleFluid,:));
            this.afPartials(1, tiN2I.RiceEdibleDry)             = sum(this.afPartials2(tiN2I.RiceEdibleDry,:));
            this.afPartials(1, tiN2I.RiceInedibleDry)           = sum(this.afPartials2(tiN2I.RiceInedibleDry,:));
            %'soybean'
            this.afPartials(1, tiN2I.SoybeanEdibleFluid)        = sum(this.afPartials2(tiN2I.SoybeanEdibleFluid,:));
            this.afPartials(1, tiN2I.SoybeanInedibleFluid)      = sum(this.afPartials2(tiN2I.SoybeanInedibleFluid,:));
            this.afPartials(1, tiN2I.SoybeanEdibleDry)          = sum(this.afPartials2(tiN2I.SoybeanEdibleDry,:));
            this.afPartials(1, tiN2I.SoybeanInedibleDry)        = sum(this.afPartials2(tiN2I.SoybeanInedibleDry,:));
            %'sweetpotato'
            this.afPartials(1, tiN2I.SweetpotatoEdibleFluid)    = sum(this.afPartials2(tiN2I.SweetpotatoEdibleFluid,:));
            this.afPartials(1, tiN2I.SweetpotatoInedibleFluid)  = sum(this.afPartials2(tiN2I.SweetpotatoInedibleFluid,:));
            this.afPartials(1, tiN2I.SweetpotatoEdibleDry)      = sum(this.afPartials2(tiN2I.SweetpotatoEdibleDry,:));
            this.afPartials(1, tiN2I.SweetpotatoInedibleDry)    = sum(this.afPartials2(tiN2I.SweetpotatoInedibleDry,:));
            %'tomato'
            this.afPartials(1, tiN2I.TomatoEdibleFluid)         = sum(this.afPartials2(tiN2I.TomatoEdibleFluid,:));
            this.afPartials(1, tiN2I.TomatoInedibleFluid)       = sum(this.afPartials2(tiN2I.TomatoInedibleFluid,:));
            this.afPartials(1, tiN2I.TomatoEdibleDry)           = sum(this.afPartials2(tiN2I.TomatoEdibleDry,:));
            this.afPartials(1, tiN2I.TomatoInedibleDry)         = sum(this.afPartials2(tiN2I.TomatoInedibleDry,:));
            %'wheat'
            this.afPartials(1, tiN2I.WheatEdibleFluid)          = sum(this.afPartials2(tiN2I.WheatEdibleFluid,:));
            this.afPartials(1, tiN2I.WheatInedibleFluid)        = sum(this.afPartials2(tiN2I.WheatInedibleFluid,:));
            this.afPartials(1, tiN2I.WheatEdibleDry)            = sum(this.afPartials2(tiN2I.WheatEdibleDry,:));
            this.afPartials(1, tiN2I.WheatInedibleDry)          = sum(this.afPartials2(tiN2I.WheatInedibleDry,:));
            %'whitepotato'
            this.afPartials(1, tiN2I.WhitepotatoEdibleFluid)    = sum(this.afPartials2(tiN2I.WhitepotatoEdibleFluid,:));
            this.afPartials(1, tiN2I.WhitepotatoInedibleFluid)  = sum(this.afPartials2(tiN2I.WhitepotatoInedibleFluid,:));
            this.afPartials(1, tiN2I.WhitepotatoEdibleDry)      = sum(this.afPartials2(tiN2I.WhitepotatoEdibleDry,:));
            this.afPartials(1, tiN2I.WhitepotatoInedibleDry)    = sum(this.afPartials2(tiN2I.WhitepotatoInedibleDry,:));
            
            
            
            %Logged gas exchanges
            %   "Integrated" total values of corresponding exchanges
            %   computed according to specific flowrates
            this.fO2_sum_total          = sum(this.afO2_sum_out);            %[kg]
            this.fCO2_sum_total         = sum(this.afCO2_sum_out);           %[kg]
            this.fH2O_trans_sum_total   = sum(this.afH2O_trans_sum_out);     %[kg]
            this.fH2O_consum_sum_total  = sum(this.afH2O_consum_sum_out);    %[kg]
            
            %Total gas exchange
            % Summation over all single contrubitions from
            % active plant cultures (PlantEng)
            this.fCO2Exchange          = sum(this.fCO2Exchange_out);      % [kg/s]
            this.fO2Exchange           = sum(this.fO2Exchange_out);       % [kg/s]
            this.fH2OExchange        = sum(this.fH2OExchange_out);    % [kg/s]
            this.fWaterNeed             = sum(this.fWaterNeed_out);         % [kg/s]
            
            %Get an array with the all mass available in current phase
            % (Plants-phase), separated for each single matter
            afFRs                       = this.getTotalFlowRates();
            
            %Setting the amounts of gas destructed and created every minute
            % They need to be in kg, because the manipulator is set to
            % total mass transformation (third parameter "true", below)
            % The manipulator should operate every minute, so the time base
            % is [kg/(min)]
            if ~(afFRs(tiN2I.CO2)==0 || afFRs(tiN2I.H2O)==0)
                this.afPartials(1, tiN2I.CO2)   = -this.fCO2Exchange * 60 / 4;                        % [kg]
                this.afPartials(1, tiN2I.O2)    = +this.fO2Exchange  * 60 / 4;                        % [kg]
                this.afPartials(1, tiN2I.H2O)   = (this.fH2OExchange - this.fWaterNeed) * 60 / 4;   % [kg]
            end;
            
            fTimeStep = this.oParent.oTimer.fTime - this.fLastUpdate;
            
            afPartialFlows = this.afPartials ./ fTimeStep;
            
            %Setting control variable for call frequency check
            this.fLastUpdate = this.oParent.oTimer.fTime;
            
            
            update@matter.manips.substance.flow(this, afPartialFlows);
        end
    end
    
end