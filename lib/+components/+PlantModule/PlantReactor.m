classdef PlantReactor < matter.manips.partial
    %SOMEABSORBEREXAMPLE Summary of this class goes here
    %   Detailed explanation goes here
    
    properties %(SetAccess = protected, GetAccess = public)
        fPlantEng;
        fCCulture;
        fFields;
        fState;
        fPlant;
        fTimeConstant;
        fTimeFact;
        fSimulationTimestep;
        fCO2;
        fPPF;
        fIsCO2global;
        fIsPPFglobal;
        
        fINEDIBLE_CGR_d;
        fINEDIBLE_CGR_f;
        fED_CGR_d;
        fED_CGR_f;
        fCO2PartialPressure;
        fCO2ppm;
        fRelHumidity;
        fWaterAvailable;
        fCrewModulePressure;
        fO2_exchange;
        fCO2_exchange;
        fwater_exchange;
        fWaterOverall=10000;
        fWaterNeed;
        fTimeReq;
        fTimeAvailability;
        plant_model;
        fTick;
        fED_CGR_out;
        fCGR_out;
        fCO2_exchange_out;
        fO2_exchange_out;
        fwater_exchange_out;
        fWaterNeed_out;
       
        
    end
    
    
    methods
        function this = PlantReactor(sName, oPhase, fPlantEng, fPlant,fWaterAvailable,fRelHumidity,fCO2PartialPressure,fCrewModulePressure,fTick)
            this@matter.manips.partial(sName, oPhase);
            this.fPlant=fPlant;
            this.fPlantEng=fPlantEng.PlantEng;
            this.fCCulture.sName='MichesPflanzen';
            this.fCCulture.Module=1;
            this.fFields=fieldnames(this.fPlantEng);
            this.fCCulture.Power = 0;
            this.fTick=fTick;
            this.fWaterAvailable=fWaterAvailable;
            this.fRelHumidity=fRelHumidity;
            this.fCO2PartialPressure=fCO2PartialPressure;
            this.fCrewModulePressure=fCrewModulePressure;
            this.fTimeAvailability = 1;
            
            this.fSimulationTimestep=2;% timestep (0 = day, 1 = hour, 2 = minute)
            this.fCO2=1200;   %C02 concentration (in ppm)
            this.fPPF=1400;    %light intenxity (in PPF)
            this.fIsCO2global=0;  % 1--> same C02 concentration for all plants
            % 0--> peculiar C02 concentration for each plant
            this.fIsPPFglobal=0;  % 1--> same light itensity for all plants
            % 0--> peculiar light itensity for each plant
             for i=1:size(this.fPlant,2)
                    this.fPlant(i).tM_nominal=this.fPlant(i).tM_nominal*24;
                    this.fPlant(i).tQ=this.fPlant(i).tQ*24;
                    this.fPlant(i).tE=this.fPlant(i).tE*24;
                end
            
            for x=1:length(this.fFields)
                this.fCCulture.plants{x, 1}.state=eval(['this.fPlantEng.' this.fFields{x} '.EngData']);
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                
                
                if this.fSimulationTimestep==0
                    this.fCCulture.plants{x, 1}.time_constant=1;
                else if this.fSimulationTimestep==1
                        this.fCCulture.plants{x, 1}.time_constant=24;
                    else
                        this.fCCulture.plants{x, 1}.time_constant=60*24;
                    end
                end
                
                %this.fCCulture.plants{x, 1}.time_constant=1;
               
                
                %this.fCCulture.plants{x, 1}=PlantInit('Wheat',this.fCCulture.plants,this.fCCulture.plants{x, 1}.state);
                
                if isempty(this.fCCulture.plants{x, 1}.state.harv_time)
                    this.fCCulture.plants{x, 1}.state.harv_time=this.fPlant.tM_nominal;
                else
                    this.fCCulture.plants{x, 1}.state.harv_time=this.fCCulture.plants{x, 1}.state.harv_time*this.fCCulture.plants{x, 1}.time_constant;
                end
                
                if this.fIsCO2global==0
                    if isempty(this.fCCulture.plants{x, 1}.state.C02)
                        this.fCCulture.plants{x, 1}.state.C02=this.fPlant.C02_ref(2);
                    end
                else
                    this.fCCulture.plants{x, 1}.state.C02=CO2;
                end
                
                if this.fIsPPFglobal==0
                    if isempty(this.fCCulture.plants{x, 1}.state.PPF)
                        this.fCCulture.plants{x, 1}.state.PPF=this.fPlant.PPF_ref(2);
                    end
                else
                    this.fCCulture.plants{x, 1}.state.PPF=PPF;
                end
                
                if isempty(this.fCCulture.plants{x, 1}.state.H)
                    this.fCCulture.plants{x, 1}.state.H=this.fPlant.H0;
                end
                
                
                if this.fCCulture.plants{x, 1}.time_constant == 1
                    this.fCCulture.plants{x, 1}.time_fact = 0;
                elseif this.fCCulture.plants{x, 1}.time_constant == 24
                    this.fCCulture.plants{x, 1}.time_fact = 1;
                elseif this.fCCulture.plants{x, 1}.time_constant == (24*60)
                    this.fCCulture.plants{x, 1}.time_fact = 60;
                end
                
                this.fCCulture.plants{x, 1}.state.internaltime=0;
                this.fCCulture.plants{x, 1}.state.internalGeneration=1;
                this.fCCulture.plants{x, 1}.state.InitEmerg_time = this.fCCulture.plants{x, 1}.state.emerg_time*this.fCCulture.plants{x, 1}.time_constant  + ((2*this.fCCulture.plants{x, 1}.time_fact)*this.fCCulture.plants{x, 1}.state.extension);
                this.fCCulture.plants{x, 1}.state.emerg_time=this.fCCulture.plants{x, 1}.state.emerg_time*this.fCCulture.plants{x, 1}.time_constant + ((2*this.fCCulture.plants{x, 1}.time_fact)*this.fCCulture.plants{x, 1}.state.extension);
                this.fCCulture.plants{x, 1}.state.TCB=0;
                this.fCCulture.plants{x, 1}.state.TEB=0;
                this.fCCulture.plants{x, 1}.state.O2_exchange=0;
                this.fCCulture.plants{x, 1}.state.CO2_exchange=0;
                this.fCCulture.plants{x, 1}.state.water_exchange=0;
                this.fCCulture.plants{x, 1}.state.CUE_24=0;
                this.fCCulture.plants{x, 1}.state.A=0;
                this.fCCulture.plants{x, 1}.state.P_net=0;
                this.fCCulture.plants{x, 1}.state.CGR=0;
                this.fCCulture.plants{x, 1}.state.CQY=0;
                this.fCCulture.plants{x, 1}.state.CO2_assimilation_fct = 1;
                this.fCCulture.plants{x, 1}.state.t_without_H2O = 0;
                this.fCCulture.plants{x, 1}.state.AddGen = 0;
                
                this.fCCulture.plants{x, 1}.INEDIBLE_CGR_d = 0;
                this.fCCulture.plants{x, 1}.INEDIBLE_CGR_f = 0;
                this.fCCulture.plants{x, 1}.ED_CGR_d = 0;
                this.fCCulture.plants{x, 1}.ED_CGR_f = 0;
                
                %plants = Plants(plant(state.plant_type), state, this.fCCulture.plants{x, 1}.time_constant, CO2, PPF, isCO2global, isPPFglobal);
                
                
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                this.fCCulture.PlantType(x) = this.fCCulture.plants{x, 1}.state.plant_type;
                this.fCCulture.CultureInfo{x} = this.fFields{x};
                this.fCCulture.plants{x, 1}.plant=this.fPlant(this.fCCulture.PlantType(x));
                
                this.fCCulture.Power = this.fCCulture.Power + this.fCCulture.plants{x, 1}.state.PPF*this.fCCulture.plants{x, 1}.state.extension;
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                this.fCO2ppm = 15*this.fCO2PartialPressure;
                
                % this.fCCulture.plants{x, 1}=this.fPlant;
            end
            
        end
        
        function update(this)
            % splits up the components taken from the flowphase inside of
            % the algae phase so the algae grow and produce O2
            arPartials = zeros(1, this.oPhase.oMT.iSubstances);
            afMolMass  = this.oPhase.oMT.afMolMass;
            tiN2I      = this.oPhase.oMT.tiN2I;
            this.fCO2ppm = 15*this.fCO2PartialPressure;
            
            for i = 1:size(this.fCCulture.plants, 1)
                %%%%%%%%%%%%%
                [this.fCCulture.plants{i, 1},this.fINEDIBLE_CGR_d,this.fINEDIBLE_CGR_f,...
                    this.fED_CGR_d,this.fED_CGR_f,this.fO2_exchange,this.fCO2_exchange,...
                    this.fwater_exchange,this.fWaterOverall,this.fWaterNeed,this.fTimeReq] ...
                    = components.PlantModule.plant_model(this.fCCulture.plants{i, 1},...
                    this.fTick,this.fCrewModulePressure,this.fRelHumidity,...
                    this.fWaterAvailable,this.fTimeAvailability, this.fCO2ppm);
                %%%%%%%%%%%%%%
                this.fED_CGR_out(i) = this.fED_CGR_d;
                this.fCGR_out(i) = this.fINEDIBLE_CGR_d + this.fED_CGR_d;
                this.fCO2_exchange_out(i) = this.fCO2_exchange;
                this.fO2_exchange_out(i) = this.fO2_exchange;
                
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %                 %Plant Failure Second Part of Two
                %                 if CCulture.PLANTFAILURE == 1
                %                     if global_tick >= Start && global_tick <= End
                %                         WaterNeed = 0;
                %                     end
                %                 end
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                this.fwater_exchange_out(i) = this.fwater_exchange;
                this.fWaterNeed_out(i) = this.fWaterNeed;
                
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                switch this.fCCulture.PlantType(i)
                    case 1 %'drybean'
                        arPartials(tiN2I.DrybeanEdibleFluid)=(this.fED_CGR_f-this.fED_CGR_d)/1000;
                        arPartials(tiN2I.DrybeanInedibleFluid)=(this.fINEDIBLE_CGR_f-this.fINEDIBLE_CGR_d)/1000;
                        arPartials(tiN2I.DrybeanEdibleDry)=(this.fED_CGR_d)/1000;
                        arPartials(tiN2I.DrybeanInedibleFluid)=(this.fINEDIBLE_CGR_d)/1000;
                        
                        
                        
                        
                    case 2 %'lettuce'
                        
                        
                        arPartials(tiN2I.LettuceEdibleFluid)=(this.fED_CGR_f-this.fED_CGR_d)/1000;
                        arPartials(tiN2I.LettuceInedibleFluid)=(this.fINEDIBLE_CGR_f-this.fINEDIBLE_CGR_d)/1000;
                        arPartials(tiN2I.LettuceEdibleDry)=(this.fED_CGR_d)/1000;
                        arPartials(tiN2I.LettuceInedibleFluid)=(this.fINEDIBLE_CGR_d)/1000;
                        
                    case 3 %'peanut'
                        arPartials(tiN2I.PeanutEdibleFluid)=(this.fED_CGR_f-this.fED_CGR_d)/1000;
                        arPartials(tiN2I.PeanutInedibleFluid)=(this.fINEDIBLE_CGR_f-this.fINEDIBLE_CGR_d)/1000;
                        arPartials(tiN2I.PeanutEdibleDry)=(this.fED_CGR_d)/1000;
                        arPartials(tiN2I.PeanutInedibleFluid)=(this.fINEDIBLE_CGR_d)/1000;
                        
                    case 4 %'rice'
                        arPartials(tiN2I.RiceEdibleFluid)=(this.fED_CGR_f-this.fED_CGR_d)/1000;
                        arPartials(tiN2I.RiceInedibleFluid)=(this.fINEDIBLE_CGR_f-this.fINEDIBLE_CGR_d)/1000;
                        arPartials(tiN2I.RiceEdibleDry)=(this.fED_CGR_d)/1000;
                        arPartials(tiN2I.RiceInedibleFluid)=(this.fINEDIBLE_CGR_d)/1000;
                        
                    case 5 %'soybean'
                        arPartials(tiN2I.SoybeanEdibleFluid)=(this.fED_CGR_f-this.fED_CGR_d)/1000;
                        arPartials(tiN2I.SoybeanInedibleFluid)=(this.fINEDIBLE_CGR_f-this.fINEDIBLE_CGR_d)/1000;
                        arPartials(tiN2I.SoybeanEdibleDry)=(this.fED_CGR_d)/1000;
                        arPartials(tiN2I.SoybeanInedibleFluid)=(this.fINEDIBLE_CGR_d)/1000;
                        
                    case 6 %'sweetpotato'
                        arPartials(tiN2I.SweetpotatoEdibleFluid)=(this.fED_CGR_f-this.fED_CGR_d)/1000;
                        arPartials(tiN2I.SweetpotatoInedibleFluid)=(this.fINEDIBLE_CGR_f-this.fINEDIBLE_CGR_d)/1000;
                        arPartials(tiN2I.SweetpotatoEdibleDry)=(this.fED_CGR_d)/1000;
                        arPartials(tiN2I.SweetpotatoInedibleFluid)=(this.fINEDIBLE_CGR_d)/1000;
                        
                    case 7 %'tomato'
                        arPartials(tiN2I.TomatoEdibleFluid)=(this.fED_CGR_f-this.fED_CGR_d)/1000;
                        arPartials(tiN2I.TomatoInedibleFluid)=(this.fINEDIBLE_CGR_f-this.fINEDIBLE_CGR_d)/1000;
                        arPartials(tiN2I.TomatoEdibleDry)=(this.fED_CGR_d)/1000;
                        arPartials(tiN2I.TomatoInedibleFluid)=(this.fINEDIBLE_CGR_d)/1000;
                        
                    case 8 %'wheat'
                        arPartials(tiN2I.WheatEdibleFluid)=(this.fED_CGR_f-this.fED_CGR_d)/1000;
                        arPartials(tiN2I.WheatInedibleFluid)=(this.fINEDIBLE_CGR_f-this.fINEDIBLE_CGR_d)/1000;
                        arPartials(tiN2I.WheatEdibleDry)=(this.fED_CGR_d)/1000;
                        arPartials(tiN2I.WheatInedibleDry)=(this.fINEDIBLE_CGR_d)/1000;
                    
                        
                    case 9 %'whitepotato'
                        arPartials(tiN2I.WhitepotatoEdibleFluid)=(this.fED_CGR_f-this.fED_CGR_d)/1000;
                        arPartials(tiN2I.WhitepotatoInedibleFluid)=(this.fINEDIBLE_CGR_f-this.fINEDIBLE_CGR_d)/1000;
                        arPartials(tiN2I.WhitepotatoEdibleDry)=(this.fED_CGR_d)/1000;
                        arPartials(tiN2I.WhitepotatoInedibleFluid)=(this.fINEDIBLE_CGR_d)/1000;
                end;
            end;
            
             afFRs      = this.getTotalFlowRates();
            this.fCO2_exchange = sum(this.fCO2_exchange_out)/60000; %kg
            this.fO2_exchange = sum(this.fO2_exchange_out)/60000; %kg
            this.fwater_exchange = sum(this.fwater_exchange_out)/60; %kg
            this.fWaterNeed = sum(this.fWaterNeed_out)/60; %kg
            
            if afFRs(tiN2I.CO2)==0 || afFRs(tiN2I.H2O)==0
            else    
            arPartials(tiN2I.CO2)=-this.fCO2_exchange;
            arPartials(tiN2I.O2)=+this.fO2_exchange;
            arPartials(tiN2I.H2O)=this.fwater_exchange-this.fWaterNeed;
            end;
            %             afFRs2      = this.getTotalFlowRates();
                        
            %
            
            %             %
            %             %             fCO2 = afFRs(tiN2I.CO2);
            %             %             fC   = fCO2 *afMolMass(tiN2I.C)  / afMolMass(tiN2I.CO2);
            %             %             fO21  = fCO2 *afMolMass(tiN2I.O2) / afMolMass(tiN2I.CO2);
            %             %             fNO3 = afFRs(tiN2I.NO3);
            %             %             fN   = fNO3 * afMolMass(tiN2I.N)  / afMolMass(tiN2I.NO3);
            %             %             fO3  = fNO3 * afMolMass(tiN2I.O3) / afMolMass(tiN2I.NO3);
            %             %             fO2  = fO3  * afMolMass(tiN2I.O2) / afMolMass(tiN2I.O3);
            %             %fO   = fO2  * afMolMass(tiN2I.O)  / afMolMass(tiN2I.O2);
            %             %
            %             arPartials(tiN2I.Food) = (afFRs(tiN2I.C)+afFRs(tiN2I.O)+afFRs(tiN2I.O2)+afFRs(tiN2I.N)+afFRs(tiN2I.H));
            %             arPartials(tiN2I.C)   = -afFRs(tiN2I.C);
            %             arPartials(tiN2I.O)  = -afFRs(tiN2I.O);
            %             arPartials(tiN2I.N)   = -afFRs(tiN2I.N);
            %             arPartials(tiN2I.H)  = -afFRs(tiN2I.H);
            %             arPartials(tiN2I.O2)  = -afFRs(tiN2I.O2);
            %
            
            
            
            update@matter.manips.partial(this, arPartials, true);
        end
    end
    
end