classdef Absorber_Algae < matter.procs.p2ps.flow
    %ABSORBEREXAMPLE An example for a p2p processor implementation
    %   The actual logic behind the absorbtion behavior is not based on any
    %   specific physical system. It is just implemented in a way to
    %   demonstrate the use of p2p processors
    
    properties
        % Species to absorb
        sSpecies1;
        sSpecies2;
        sSpecies3;
        
        % Maximum absorb capacity in kg
        fCapacity;
        
        
        % Max absorption rate in kg/s/Pa, partial pressure of the species
        % to absorb
        %NOTE not used yet ...
        fMaxAbsorptionCO2 = 0;
        fMaxAbsorptionNO3 = 0;
        fMaxAbsorptionO2  = 0;
        % Defines which species are extracted
        arExtractPartials;
        fPPCO2;
        fPower;
        fDilution;
        fVolume_FreshWater;
        fMass_Algae;
        fCO2Mass;
        fNuMass;
        fP1 = 0;
        fP2 = 0;
        fP3 = 0;
        fP4 = 0;
        fP5 = 0;
        fP6 = 0;
        fP7 = 0;
        fP8 = 0;
        fP9 = 0;
        fAerationPower;
        fProductivity = 0;
        fX = 0;
        fY = 0;
        fU = 0;
        fVolume = 3*187.2;
        % Ratio of actual loading and maximum load
        rLoad;
        fHarvest;
        fTimerAlgae=0;
        
        fMaxPower;
        fNominalPower;
        fMinPower;
        fFailure;
        fAlgaeFailure=0;
        fTime;
        fStartAlgaeFailure=0;
        fEndAlgaeFailure=0;
        fMassCO2=0;
        fPowerApplicated;
    end
    
    
    methods
        function this = Absorber_Algae(oStore, sName, sPhaseIn, sPhaseOut, sSpecies1, sSpecies2, sSpecies3, fHarvest)
            this@matter.procs.p2ps.flow(oStore, sName, sPhaseIn, sPhaseOut);
            
            
            
            % Species to absorb, max absorption
            this.sSpecies1  = sSpecies1;
            this.sSpecies2  = sSpecies2;
            this.sSpecies3  = sSpecies3;
            
            this.fHarvest = fHarvest;
            
            
            this.fPower = 4600; %Power die vom Algen Reaktor zu Beginn ben?tigt wird
            % The p2p processor can specify which species it wants to
            % extract from the phase. A vector with relative values has to
            % be provided, with the sum of all ratios being 1 (see the
            % matter.phase.arPartialMass vector) ...
            this.arExtractPartials = zeros(1, this.oMT.iSubstances);
            
            % ... in this case using a vector with zeros at all indices
            % except the one holding the partial mass for the species we
            % want to extract - which is set to 1, i.e. only this species
            % is extracted.
            this.arExtractPartials(this.oMT.tiN2I.(this.sSpecies1)) = 1;
            this.arExtractPartials(this.oMT.tiN2I.(this.sSpecies2)) = 1;
            this.arExtractPartials(this.oMT.tiN2I.(this.sSpecies3)) = 1;
            
            this.calculateProductivity();
            
        end
        
        function calculateProductivity(this)
            
            oStore = this.oStore;
            %getting the algae mass
            this.fMass_Algae = oStore.aoPhases(2).fMass;
            % converting into gram to fit the following calculations
            this.fMass_Algae = this.fMass_Algae*1000;
            this.fVolume;
            
            % this.fMass_Algae = this.fMass_Algae*1000;
            this.fDilution = this.fMass_Algae / this.fVolume;
            
            
            
            
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            
            % Power Controller
            
            
            
            
            
            
            this.fMaxPower = 4600;
            this.fNominalPower = 1950;
            this.fMinPower = 1200;
            
            this.fFailure = 0;
            if this.fAlgaeFailure == 1
                if this.fTime >= this.fStartAlgaeFailure && this.fTime <= this.fEndAlgaeFailure
                    this.fFailure = 1;
                end
            end
            
            if this.fFailure == 0
                if this.fPPCO2 >= 100
                    if this.fPower < this.fNominalPower;
                        %if strcmp(obj.sName, 'CAlgae1')
                        disp(['PPCO2 >= 100 & Power Low']);
                        %end
                        this.fPower = this.fNominalPower;
                    end
                    
                elseif this.fPPCO2 <= 60
                    if this.fPower ~= this.fMinPower
                        % if strcmp(obj.sName, 'CAlgae1')
                        disp(['PPCO2 <= 60 & Power Normal or Power high']);
                        %end
                        this.fPower = this.fMinPower;
                    end
                end
                
                if this.fPPCO2 > 120
                    if this.fPower ~= this.fMaxPower
                        %if strcmp(obj.sName, 'CAlgae1')
                        disp(['PPCO2 >= 120 & Power Low or Power Nominal']);
                        %end
                        this.fPower = this.fMaxPower;
                    end
                end
            else
                if this.fPower ~= 0
                    %if strcmp(obj.sName, 'CAlgae1')
                    disp('this.fFailure in Alge Reaktor');
                    %end
                    this.fPower = 0;
                end
            end
            
            
           
            
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %this.fPPCO2=hami.BIO_LSS.subsystems.algae_module.oParent.toStores.crew_module.aoPhases(1).fMass;
            
            fVolume = this.fVolume;
            
            this.fCO2Mass = this.fMassCO2;%oStore.aoPhases(1,1).arPartialMass(11);
            this.fNuMass = 1000000;%oStore.aoPhases(1, 1).arPartialMass(13);
            
            
            if this.fPower < 850         %too little power supply for illumination and aeration
                
                O2used = 10*10^(-6)*1000*32*this.fDilution*fVolume*0.01/60;
                %O2 respiration: 10?mol/mg Chlorophyll///Chlorophyll content of Spirulina 1% equates*0.01
                %Amount of Algae = Dilution*ReactorV///mol converted into gram *32 (O2)
                %per timestep /60 (min)
                
                O2used = O2used/(1000*60);
                
                
                this.fMaxAbsorptionO2 = O2used;
                
                this.fX = 0;
                this.fY = 0;
                this.fU = 1;
                
            elseif this.fPower >= 850    %enough power supply for illumination and aeration
                
                
                %% Productivity Calculation
                fP1 = this.fP1;
                fP2 = this.fP2;
                fP3 = this.fP3;
                fP4 = this.fP4;
                fP5 = this.fP5;
                fP6 = this.fP6;
                fP7 = this.fP7;
                fP8 = this.fP8;
                fP9 = this.fP9;
                
                if this.fDilution > 0 && this.fDilution <= 1.25
                    if this.fPower >= 1700 %[watt]
                        %Illupower5 = 1500; %[watt] equates 900 %[?mol/m?s]
                        this.fAerationPower = 200;
                        %Aerpower5 = 200; %[watt] equates 2.1 %[l/l min]
                        fP5 = 99.79*this.fDilution^(0.8472)*exp(-0.1731*this.fDilution);
                        
                    elseif this.fPower >= 1600 && this.fPower < 1700 %[watt]
                        %Illupower6 = 1500; %[watt] equates 900 %[?mol/m?s]
                        this.fAerationPower = 100;
                        %Aerpower6 = 100; %[watt] equates 0.6 %[l/l min]
                        fP6 = 113*this.fDilution^(1.132)*exp(-0.354*this.fDilution);
                        
                    elseif this.fPower >= 850 && this.fPower < 1600 %[watt]
                        %Illupower9 = 750; %[watt] equates 500 %[?mol/m?s]
                        this.fAerationPower = 100;
                        %Aerpower9 = 100; %[watt] equates 0.6 %[l/l min]
                        fP9 = 69.94*this.fDilution^(0.9015)*exp(-0.3488*this.fDilution);
                    end
                    
                elseif this.fDilution > 1.25 && this.fDilution <= 2.5
                    if this.fPower >= 1700 %[watt]
                        %Illupower5 = 1500; %[watt] equates 900 %[?mol/m?s]
                        this.fAerationPower = 200;
                        %Aerpower5 = 200; %[watt] equates 2.1 %[l/l min]
                        fP5 = 99.79*this.fDilution^(0.8472)*exp(-0.1731*this.fDilution);
                        
                    elseif this.fPower >= 1600 && this.fPower < 1700 %[watt]
                        %Illupower6 = 1500; %[watt] equates 900 %[?mol/m?s]
                        this.fAerationPower = 100;
                        %Aerpower6 = 100; %[watt] equates 0.6 %[l/l min]
                        fP6 = 113*this.fDilution^(1.132)*exp(-0.354*this.fDilution);
                        
                    elseif this.fPower >= 950 && this.fPower < 1600 %[watt]
                        %Illupower8 = 750; %[watt] equates 500 %[?mol/m?s]
                        this.fAerationPower = 200;
                        %Aerpower8 = 200; %[watt] equates 2.1 %[l/l min]
                        fP8 = 67.15*this.fDilution^(1.326)*exp(-0.3816*this.fDilution);
                        
                    elseif this.fPower >= 850 && this.fPower < 950 %[watt]
                        %Illupower9 = 750; %[watt] equates 500 %[?mol/m?s]
                        this.fAerationPower = 100;
                        %Aerpower9 = 100; %[watt] equates 0.6 %[l/l min]
                        fP9 = 69.94*this.fDilution^(0.9015)*exp(-0.3488*this.fDilution);
                    end
                elseif this.fDilution > 2.5 && this.fDilution <= 3.8
                    if this.fPower >= 3100 %[watt]
                        %Illupower3 = 3000; %[watt] equates 1800 %[?mol/m?s]
                        this.fAerationPower = 100;
                        %Aerpower3 = 100; %[watt] equates 0.6 %[l/l min]
                        fP3 = 71.17*this.fDilution^(1.45)*exp(-0.2571*this.fDilution);
                        
                    elseif this.fPower >= 1700 && this.fPower < 3100 %[watt]
                        %Illupower5 = 1500; %[watt] equates 900 %[?mol/m?s]
                        this.fAerationPower = 200;
                        %Aerpower5 = 200; %[watt] equates 2.1 %[l/l min]
                        fP5 = 99.79*this.fDilution^(0.8472)*exp(-0.1731*this.fDilution);
                        
                    elseif this.fPower >= 1600 && this.fPower < 1700 %[watt]
                        %Illupower6 = 1500; %[watt] equates 900 %[?mol/m?s]
                        this.fAerationPower = 100;
                        %Aerpower6 = 100; %[watt] equates 0.6 %[l/l min]
                        fP6 = 113*this.fDilution^(1.132)*exp(-0.354*this.fDilution);
                        
                    elseif this.fPower >= 1150 && this.fPower < 1600 %[watt]
                        %Illupower7 = 750; %[watt] equates 500 %[?mol/m?s]
                        this.fAerationPower = 400;
                        %Aerpower7 = 400; %[watt] equates 4.2 %[l/l min]
                        fP7 = 57.3*this.fDilution^(1.441)*exp(-0.3636*this.fDilution);
                        
                    elseif this.fPower >= 950 && this.fPower < 1150 %[watt]
                        %Illupower8 = 750; %[watt] equates 500 %[?mol/m?s]
                        this.fAerationPower = 200;
                        %Aerpower8 = 200; %[watt] equates 2.1 %[l/l min]
                        fP8 = 67.15*this.fDilution^(1.326)*exp(-0.3816*this.fDilution);
                        
                    elseif this.fPower >= 850 && this.fPower < 950 %[watt]
                        %Illupower9 = 750; %[watt] equates 500 %[?mol/m?s]
                        this.fAerationPower = 100;
                        %Aerpower9 = 100; %[watt] equates 0.6 %[l/l min]
                        fP9 = 69.94*this.fDilution^(0.9015)*exp(-0.3488*this.fDilution);
                    end
                elseif this.fDilution > 3.8 && this.fDilution <= 6.9
                    if this.fPower >= 3200 %[watt]
                        %Illupower2 = 3000; %[watt] equates 1800 %[?mol/m?s]
                        this.fAerationPower = 200;
                        %Aerpower2 = 200; %[watt] equates 2.1 %[l/l min]
                        fP2 = 65.59*this.fDilution^(1.042)*exp(-0.09287*this.fDilution);
                        
                    elseif this.fPower >= 3100 && this.fPower < 3200 %[watt]
                        %Illupower3 = 3000; %[watt] equates 1800 %[?mol/m?s]
                        this.fAerationPower = 100;
                        %Aerpower3 = 100; %[watt] equates 0.6 %[l/l min]
                        fP3 = 71.17*this.fDilution^(1.45)*exp(-0.2571*this.fDilution);
                        
                    elseif this.fPower >= 1900 && this.fPower < 3100 %[watt]
                        %Illupower4 = 1500; %[watt] equates 900 %[?mol/m?s]
                        this.fAerationPower = 400;
                        %Aerpower4 = 400; %[watt] equates 4.2 %[l/l min]
                        fP4 = 75.09*this.fDilution^(0.8996)*exp(-0.1156*this.fDilution);
                        
                    elseif this.fPower >= 1700 && this.fPower < 1900 %[watt]
                        %Illupower5 = 1500; %[watt] equates 900 %[?mol/m?s]
                        this.fAerationPower = 200;
                        %Aerpower5 = 200; %[watt] equates 2.1 %[l/l min]
                        fP5 = 99.79*this.fDilution^(0.8472)*exp(-0.1731*this.fDilution);
                        
                    elseif this.fPower >= 1600 && this.fPower < 1700 %[watt]
                        %Illupower6 = 1500; %[watt] equates 900 %[?mol/m?s]
                        this.fAerationPower = 100;
                        %Aerpower6 = 100; %[watt] equates 0.6 %[l/l min]
                        fP6 = 113*this.fDilution^(1.132)*exp(-0.354*this.fDilution);
                        
                    elseif this.fPower >= 1150 && this.fPower < 1600 %[watt]
                        %Illupower7 = 750; %[watt] equates 500 %[?mol/m?s]
                        this.fAerationPower = 400;
                        %Aerpower7 = 400; %[watt] equates 4.2 %[l/l min]
                        fP7 = 57.3*this.fDilution^(1.441)*exp(-0.3636*this.fDilution);
                        
                    elseif this.fPower >= 950 && this.fPower < 1150 %[watt]
                        %Illupower8 = 750; %[watt] equates 500 %[?mol/m?s]
                        this.fAerationPower = 200;
                        %Aerpower8 = 200; %[watt] equates 2.1 %[l/l min]
                        fP8 = 67.15*this.fDilution^(1.326)*exp(-0.3816*this.fDilution);
                        
                    elseif this.fPower >= 850 && this.fPower < 950 %[watt]
                        %Illupower9 = 750; %[watt] equates 500 %[?mol/m?s]
                        this.fAerationPower = 100;
                        %Aerpower9 = 100; %[watt] equates 0.6 %[l/l min]
                        fP9 = 69.94*this.fDilution^(0.9015)*exp(-0.3488*this.fDilution);
                    end
                elseif this.fDilution > 6.9 && this.fDilution <= 7.4
                    if this.fPower >= 3400 %[watt]
                        %Illupower1 = 3000; %[watt] equates 1800 %[?mol/m?s]
                        this.fAerationPower = 400;
                        %Aerpower1 = 400; %[watt] equates 4.2 %[l/l min]
                        fP1 = 18.26*this.fDilution^(1.812)*exp(-0.123*this.fDilution);
                        
                    elseif this.fPower >= 3200 && this.fPower <3400 %[watt]
                        %Illupower2 = 3000; %[watt] equates 1800 %[?mol/m?s]
                        this.fAerationPower = 200;
                        %Aerpower2 = 200; %[watt] equates 2.1 %[l/l min]
                        fP2 = 65.59*this.fDilution^(1.042)*exp(-0.09287*this.fDilution);
                        
                    elseif this.fPower >= 3100 && this.fPower < 3200 %[watt]
                        %Illupower3 = 3000; %[watt] equates 1800 %[?mol/m?s]
                        this.fAerationPower = 100;
                        %Aerpower3 = 100; %[watt] equates 0.6 %[l/l min]
                        fP3 = 71.17*this.fDilution^(1.45)*exp(-0.2571*this.fDilution);
                        
                    elseif this.fPower >= 1900 && this.fPower < 3100 %[watt]
                        %Illupower4 = 1500; %[watt] equates 900 %[?mol/m?s]
                        this.fAerationPower = 400;
                        %Aerpower4 = 400; %[watt] equates 4.2 %[l/l min]
                        fP4 = 75.09*this.fDilution^(0.8996)*exp(-0.1156*this.fDilution);
                        
                    elseif this.fPower >= 1700 && this.fPower < 1900 %[watt]
                        %Illupower5 = 1500; %[watt] equates 900 %[?mol/m?s]
                        this.fAerationPower = 200;
                        %Aerpower5 = 200; %[watt] equates 2.1 %[l/l min]
                        fP5 = 99.79*this.fDilution^(0.8472)*exp(-0.1731*this.fDilution);
                        
                    elseif this.fPower >= 1600 && this.fPower < 1700 %[watt]
                        %Illupower6 = 1500; %[watt] equates 900 %[?mol/m?s]
                        this.fAerationPower = 100;
                        %Aerpower6 = 100; %[watt] equates 0.6 %[l/l min]
                        fP6 = 113*this.fDilution^(1.132)*exp(-0.354*this.fDilution);
                        
                    elseif this.fPower >= 1150 && this.fPower < 1600 %[watt]
                        %Illupower7 = 750; %[watt] equates 500 %[?mol/m?s]
                        this.fAerationPower = 400;
                        %Aerpower7 = 400; %[watt] equates 4.2 %[l/l min]
                        fP7 = 57.3*this.fDilution^(1.441)*exp(-0.3636*this.fDilution);
                        
                    elseif this.fPower >= 950 && this.fPower < 1150 %[watt]
                        %Illupower8 = 750; %[watt] equates 500 %[?mol/m?s]
                        this.fAerationPower = 200;
                        %Aerpower8 = 200; %[watt] equates 2.1 %[l/l min]
                        fP8 = 67.15*this.fDilution^(1.326)*exp(-0.3816*this.fDilution);
                        
                    elseif this.fPower >= 850 && this.fPower < 950 %[watt]
                        %Illupower9 = 750; %[watt] equates 500 %[?mol/m?s]
                        this.fAerationPower = 100;
                        %Aerpower9 = 100; %[watt] equates 0.6 %[l/l min]
                        fP9 = 69.94*this.fDilution^(0.9015)*exp(-0.3488*this.fDilution);
                    end
                elseif this.fDilution > 7.4 && this.fDilution <= 500
                    if this.fPower >= 3400 %[watt]
                        %Illupower1 = 3000; %[watt] equates 1800 %[?mol/m?s]
                        this.fAerationPower = 400;
                        %Aerpower1 = 400; %[watt] equates 4.2 %[l/l min]
                        fP1 = 18.26*this.fDilution^(1.812)*exp(-0.123*this.fDilution);
                        
                    elseif this.fPower >= 3200 && this.fPower <3400 %[watt]
                        %Illupower2 = 3000; %[watt] equates 1800 %[?mol/m?s]
                        this.fAerationPower = 200;
                        %Aerpower2 = 200; %[watt] equates 2.1 %[l/l min]
                        fP2 = 65.59*this.fDilution^(1.042)*exp(-0.09287*this.fDilution);
                        
                    elseif this.fPower >= 1900 && this.fPower < 3200 %[watt]
                        %Illupower4 = 1500; %[watt] equates 900 %[?mol/m?s]
                        this.fAerationPower = 400;
                        %Aerpower4 = 400; %[watt] equates 4.2 %[l/l min]
                        fP4 = 75.09*this.fDilution^(0.8996)*exp(-0.1156*this.fDilution);
                        
                    elseif this.fPower >= 1700 && this.fPower < 1900 %[watt]
                        %Illupower5 = 1500; %[watt] equates 900 %[?mol/m?s]
                        this.fAerationPower = 200;
                        %Aerpower5 = 200; %[watt] equates 2.1 %[l/l min]
                        fP5 = 99.79*this.fDilution^(0.8472)*exp(-0.1731*this.fDilution);
                        
                    elseif this.fPower >= 1600 && this.fPower < 1700 %[watt]
                        %Illupower6 = 1500; %[watt] equates 900 %[?mol/m?s]
                        this.fAerationPower = 100;
                        %Aerpower6 = 100; %[watt] equates 0.6 %[l/l min]
                        fP6 = 113*this.fDilution^(1.132)*exp(-0.354*this.fDilution);
                        
                    elseif this.fPower >= 1150 && this.fPower < 1600 %[watt]
                        %Illupower7 = 750; %[watt] equates 500 %[?mol/m?s]
                        this.fAerationPower = 400;
                        %Aerpower7 = 400; %[watt] equates 4.2 %[l/l min]
                        fP7 = 57.3*this.fDilution^(1.441)*exp(-0.3636*this.fDilution);
                        
                    elseif this.fPower >= 950 && this.fPower < 1150 %[watt]
                        %Illupower8 = 750; %[watt] equates 500 %[?mol/m?s]
                        this.fAerationPower = 200;
                        %Aerpower8 = 200; %[watt] equates 2.1 %[l/l min]
                        fP8 = 67.15*this.fDilution^(1.326)*exp(-0.3816*this.fDilution);
                        
                    elseif this.fPower >= 850 && this.fPower < 950 %[watt]
                        %Illupower9 = 750; %[watt] equates 500 %[?mol/m?s]
                        this.fAerationPower = 100;
                        %Aerpower9 = 100; %[watt] equates 0.6 %[l/l min]
                        fP9 = 69.94*this.fDilution^(0.9015)*exp(-0.3488*this.fDilution);
                    end
                end
                
                
                
                this.fProductivity = fP1+fP2+fP3+fP4+fP5+fP6+fP7+fP8+fP9;
                
                fP = this.fProductivity;
                fP = fP/(1000*60)*fVolume; %converted from [mg/l/h] into [g/ReactorVolume/min]
                
                
                
                %Stoichiometry (under CO2-limiting conditions): [1]CO2+[0.064]NO3 -> [1.1572]O2+[0.3333]CHON
                Pmol = fP/24.3;                     %Productivity (Algae) converted into mol
                % O2producedmol = Pmol*3.471947195;   %O2 (mol) produced in the reaction
                Nuneedmol = Pmol*0.192019201;       %Nu need (mol) for the reaction
                CO2needmol = Pmol*3.00030003;       %CO2 need (mol) for the reaction
                CO2need = CO2needmol*44;         %CO2 converted into gram
                Nuneed = Nuneedmol*62;
                
                CO2need = CO2need/(1000*60); %kg/s
                Nuneed = Nuneed/(1000*60);      %kg/s
                
                 this.fMaxAbsorptionCO2 = CO2need;
                  this.fMaxAbsorptionNO3 = Nuneed;
                
                
                
                
                
                
%                 if (this.fCO2Mass >= CO2need) && (this.fNuMass >= Nuneed)       %Enough CO2 and Nu
%                     %O2 = O2produced;
%                     CO2 = CO2need;
%                     Nu = Nuneed;
%                     %disp('Enough CO2 and Nu');
%                     this.fMaxAbsorptionCO2 = CO2need;
%                     this.fMaxAbsorptionNO3 = Nuneed;
%                     % disp('enough all');
%                     Z = CO2need + Nuneed;
%                     
%                     this.fX = CO2need/Z;
%                     this.fY = Nuneed/Z;
%                     this.fU = 0;
%                     
%                     
%                 elseif (this.fCO2Mass <= CO2need) && (this.fNuMass >= Nuneed)    %Not enough CO2, enough Nu
%                     CO2mol = this.fCO2Mass/44.01;           %CO2 converted into mol
%                     Nuusedmol = CO2mol*0.064;               %Nu used in the reaction
%                     %O2producedmol = CO2mol*1.1572;          %O2 produced in the reaction
%                     %Algaeproducedmol = CO2mol*0.3333;       %Algae produced in the reaction
%                     Nuused = Nuusedmol*62.01;               %Nu converted into gram
%                     % O2 = O2producedmol*32.00;               %O2 converted into gram
%                     %Algae = Algaeproducedmol*24.33;
%                     CO2 =  this.fCO2Mass/(1000*60);
%                     Nuused = Nuused/(1000*60);
%                     
%                     %disp('Not enough CO2, enough Nu');
%                     this.fMaxAbsorptionCO2 = CO2;
%                     this.fMaxAbsorptionNO3 = Nuused;
%                     
%                     Z = CO2 + Nuused;
%                     if Z == 0
%                         this.fX = 0;
%                         this.fY = 0;
%                     else
%                         this.fX = CO2/Z;
%                         this.fY = Nuused/Z;
%                         this.fU = 0;
%                     end
%                     
%                     
%                 elseif (this.fCO2Mass >= CO2need) && (this.fNuMass <= Nuneed)    %Enough CO2, not enough Nu
%                     Numol = this.fNuMass/62.01;             %Nu converted into mol
%                     CO2usedmol = Numol*15.62;               %CO2 used in the reaction
%                     %O2producedmol = Numol*18.07;            %O2 produced in the reaction
%                     %Algaeproducedmol = Numol*5.21;          %Algae produced in the reaction
%                     CO2used = CO2usedmol*44.01;             %CO2 converted into gram
%                     %O2 = O2producedmol*32.00;               %O2 converted into gram
%                     %Algae = Algaeproducedmol*24.33;
%                     CO2used = CO2used/(1000*60);
%                     Nu = this.fNuMass/(1000*60);
%                     
%                     %disp('Enough CO2, not enough Nu');
%                     this.fMaxAbsorptionCO2 = CO2used;
%                     this.fMaxAbsorptionNO3 = Nu;
%                     
%                     Z = CO2used + Nu;
%                     
%                     if Z == 0
%                         this.fX = 0;
%                         this.fY = 0;
%                     else
%                         this.fX = CO2used/Z;
%                         this.fY = Nu/Z;
%                         this.fU = 0;
%                     end
%                     
%                 elseif (this.fCO2Mass <= CO2need) && (this.fNuMass <= Nuneed)    %Not enough CO2 and Nu
%                     CO2used = 0;
%                     Nuused = 0;
%                     % disp('Not enough CO2 and Nu');
%                     if this.fCO2Mass >= 15.63*this.fNuMass
%                         %Stoichiometry under NU-limiting conditions: [15.62]CO2+[1]NO3 -> [18.07]O2+[5.21]CHON
%                         FlagNu = 1;
%                         Numol = this.fNuMass/62.01;             %NO3 converted into mol
%                         CO2usedmol = Numol*15.62;               %CO2 used in the reaction
%                         %O2producedmol = Numol*18.07;            %O2 produced in the reaction
%                         %Algaeproducedmol = Numol*5.21;          %Algae produced in the reaction
%                         CO2used = CO2usedmol*44.01;             %CO2 converted into gram
%                         %O2 = O2producedmol*32.00;               %O2 converted into gram
%                         %Algae = Algaeproducedmol*24.33;         %Algae converted into gram
%                     else
%                         %Stoichiometry under CO2-limiting conditions: [1]CO2+[0.064]NO3 -> [1.1572]O2+[0.3333]CHON
%                         FlagCO2 = 1;
%                         CO2mol = this.fCO2Mass/44.01;                 %CO2 converted into mol
%                         Nuusedmol = CO2mol*0.064;               %NO3 used in the reaction
%                         %O2producedmol = CO2mol*1.1572;          %O2 produced in the reaction
%                         %Algaeproducedmol = CO2mol*0.3333;       %Algae produced in the reaction
%                         Nuused = Nuusedmol*62.01;               %NO3 converted into gram
%                         %O2 = O2producedmol*32.00;               %O2 converted into gram
%                         %Algae = Algaeproducedmol*24.33;         %Algae converted into gram
%                         
%                     end
%                     
%                     if FlagNu == 1
%                         CO2 = CO2used;
%                         Nu = this.fNuMass
%                         CO2used = CO2used/(1000*60);
%                         this.fNuMass = this.fNuMass/(1000*60);
%                         this.fMaxAbsorptionCO2 = CO2used;
%                         this.fMaxAbsorptionNO3 = this.fNuMass;
%                         
%                         Z = CO2used + this.fNuMass;
%                         if Z == 0
%                             this.fX = 0;
%                             this.fY = 0;
%                         else
%                             this.fX = CO2used/Z;
%                             this.fY = this.fNuMass/Z;
%                             this.fU = 0;
%                         end
%                         
%                     elseif FlagCO2 == 1
%                         CO2 = this.fCO2Mass;
%                         Nu = Nuused;
%                         this.fCO2Mass = this.fCO2Mass/(1000*60);
%                         Nuused = Nuused/(1000*60);
%                         this.fMaxAbsorptionCO2 = this.fCO2Mass;
%                         this.fMaxAbsorptionNO3 = Nuused;
%                         
%                         Z = this.fCO2Mass + Nuused;
%                         
%                         if Z == 0
%                             this.fX = 0;
%                             this.fY = 0;
%                         else
%                             this.fX = this.fCO2Mass/Z;
%                             this.fY = Nuused/Z;
%                             this.fU = 0;
%                         end
%                     end
%                     
%                     
                 end
             
            
            this.arExtractPartials(this.oMT.tiN2I.(this.sSpecies1)) = CO2need/(CO2need+Nuneed);%1*this.fX;
            this.arExtractPartials(this.oMT.tiN2I.(this.sSpecies2)) = Nuneed/(CO2need+Nuneed);%1*this.fY;
            this.arExtractPartials(this.oMT.tiN2I.(this.sSpecies3)) = 0; %1*this.fU;
            
            %setting the partial ratios of the absorbed species
            
            
        end
        
        function update(this)
            % Called whenever a flow rate changes. The two EXMES (oIn/oOut)
            % have an oPhase attribute that allows us to get the phases on
            % the left/right side.
            % Here, the oIn is always the air phase, the oOut is the solid
            % absorber phase.
            
            
            % calculates the new productivity
            % everytime the update function is called
            this.calculateProductivity();
            
            
            
            % setting the partial flowrates to be the amount of CO2 O2 NO3
            % that is needed per second
            
            %afFlowRate = 0;
            
            afFlowRate(1) = this.fMaxAbsorptionCO2;
            afFlowRate(2) = this.fMaxAbsorptionNO3;
            %afFlowRate(3) = this.fMaxAbsorptionO2;
            % Nothing flows in, so nothing absorbed ...
            %             if isempty(afFlowRate)
            %                 this.setMatterProperties(0, this.arExtractPartials);
            %
            %                 return;
            %             end
            
            % the flowrate of the p2p is the sum of the partial flowrates
            % since only the specified species flow here
            
            fFlowRate = sum(afFlowRate);
            
            
            
            this.setMatterProperties(fFlowRate, this.arExtractPartials);
        end
    end
end


