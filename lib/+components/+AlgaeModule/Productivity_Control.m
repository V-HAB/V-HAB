 classdef Productivity_Control < vsys

 properties
        fProductivity;
        fPower;
        fDilution;
        fP;
        fVolume;
        fCO2Mass;
        fNuMass;
        fCO2need;
        fNuneed;
    end
    
    
  
    methods
        function this = Productivity_Control(oParent, sName)
            this@vsys(oParent, sName, 60);

      this.fPower = oParent.toChildren.PowerControl.fPower;
      this.fDilution = oParent.toChildren.Harvest.fDilution;
      this.fVolume = this.oParent.toStores.Filter_Algae_Reactor.oGeometry.fVolume;
      
      fVolume = this.fVolume;
      
      this.fCO2Mass = this.oParent.toStores.Filter_Algae_Reactor.aoPhases(1, 1).arPartialMass(10);
      this.fNuMass = this.oParent.toStores.Filter_Algae_Reactor.aoPhases(1, 1).arPartialMass(12);


         if this.fPower < 850         %too little power supply for illumination and aeration
    
                O2used = 10*10^(-6)*1000*32*this.fDilution*fVolume*0.01/60;
                %O2 respiration: 10µmol/mg Chlorophyll///Chlorophyll content of Spirulina 1% equates*0.01
                %Amount of Algae = Dilution*ReactorV///mol converted into gram *32 (O2)
                %per timestep /60 (min)
                
                
                %The light is switched off and algae consume O2
                fP = 0;
         
                
                
            elseif this.fPower >= 850    %enough power supply for illumination and aeration
                oProductivity = hami.BIO_LSS.components.Productivity_Calculation(this, 'Productivity');%Productivity is calculated from the available power and the CellDensity(Dilution)
               
                this.fProductivity = this.toChildren.Productivity.fProductivity;
                
                
                fP = this.fProductivity;
                fP = fP/1000/60*fVolume; %converted from [mg/l/h] into [g/ReactorVolume/min]
                
                this.oParent.toChildren.Algae_Logic.fProductivity = fP;
                
                 %Stoichiometry (under CO2-limiting conditions): [1]CO2+[0.064]NO3 -> [1.1572]O2+[0.3333]CHON
                Pmol = fP/24.33;                     %Productivity (Algae) converted into mol
                % O2producedmol = Pmol*3.471947195;   %O2 (mol) produced in the reaction
                Nuneedmol = Pmol*0.192019201;       %Nu need (mol) for the reaction
                CO2needmol = Pmol*3.00030003;       %CO2 need (mol) for the reaction
                CO2need = CO2needmol*44.01;         %CO2 converted into gram
                Nuneed = Nuneedmol*62.01;           %Nu converted into gram
                % O2produced = O2producedmol*32;  
                
                
                
                
                this.fCO2Mass = this.oParent.toStores.Filter_Algae_Reactor.aoPhases(1, 1).arPartialMass(10);
                
                this.fNuMass = this.oParent.toStores.Filter_Algae_Reactor.aoPhases(1, 1).arPartialMass(12);
                
  
                
                if (this.fCO2Mass >= CO2need) && (this.fNuMass >= Nuneed)       %Enough CO2 and Nu
                    %O2 = O2produced;
                    CO2 = CO2need;
                    Nu = Nuneed;
                    
                    this.fCO2need = CO2need;
                    this.fNuneed = Nuneed;
                    
              %     oParent.toStores.Filter_Algae_Reactor.fMaxAbsorptionCO2 = this.fCO2need;
               %    oParent.toStores.Filter_Algae_Reactor.fMaxAbsorptionNO3 = this.fNuneed;
               %    oParent.toStores.Filter_Algae_Reactor.fMaxAbsorptionO2 = 0;
                    
                elseif (this.fCO2Mass <= CO2need) && (this.fNuMass >= Nuneed)    %Not enough CO2, enough Nu
                    CO2mol = this.fCO2Mass/44.01;           %CO2 converted into mol
                    Nuusedmol = CO2mol*0.064;               %Nu used in the reaction
                    %O2producedmol = CO2mol*1.1572;          %O2 produced in the reaction
                    %Algaeproducedmol = CO2mol*0.3333;       %Algae produced in the reaction
                    Nuused = Nuusedmol*62.01;               %Nu converted into gram
                   % O2 = O2producedmol*32.00;               %O2 converted into gram
                    %Algae = Algaeproducedmol*24.33; 
                    CO2 =  this.fCO2Mass;
                    Nu = Nuused;
                    fP = Algae;
                    
                    this.fCO2need = CO2;
                    this.fNuneed = Nuused;
                    
                    oParent.toStores.Filter_Algae_Reactor.fMaxAbsorptionCO2 = this.fCO2need;
                    oParent.toStores.Filter_Algae_Reactor.fMaxAbsorptionNO3 = this.fNuneed;
                    oParent.toStores.Filter_Algae_Reactor.fMaxAbsorptionO2 = 0;
                    
                elseif (this.fCO2Mass >= CO2need) && (this.fNuMass <= Nuneed)    %Enough CO2, not enough Nu
                    Numol = this.fNuMass/62.01;             %Nu converted into mol
                    CO2usedmol = Numol*15.62;               %CO2 used in the reaction
                    %O2producedmol = Numol*18.07;            %O2 produced in the reaction
                    %Algaeproducedmol = Numol*5.21;          %Algae produced in the reaction
                    CO2used = CO2usedmol*44.01;             %CO2 converted into gram
                    %O2 = O2producedmol*32.00;               %O2 converted into gram
                    %Algae = Algaeproducedmol*24.33; 
                    
                    Nu = this.fNuMass;
                    fP = Algae;
                    
                    this.fCO2need = CO2used;
                    this.fNuneed = Nu;
                   oParent.toStores.Filter_Algae_Reactor.toProcsP2P.filterproc.fMaxAbsorptionCO2 = this.fCO2need;
                    oParent.toStores.Filter_Algae_Reactor.toProcsP2P.filterproc.fMaxAbsorptionNO3 = this.fNuneed;
                    oParent.toStores.Filter_Algae_Reactor.toProcsP2P.filterproc.fMaxAbsorptionO2 = 0;
                    
                elseif (this.fCO2Mass <= CO2need) && (this.fNuMass <= Nuneed)    %Not enough CO2 and Nu
                     CO2used = 0;
                     Nuused = 0;
            
                            if this.fCO2Mass >= 15.63*this.fNuMass
                                %Stoichiometry under NU-limiting conditions: [15.62]CO2+[1]NO3 -> [18.07]O2+[5.21]CHON
                                FlagNu = 1;
                                Numol = this.fNuMass/62.01;             %NO3 converted into mol
                                CO2usedmol = Numol*15.62;               %CO2 used in the reaction
                                %O2producedmol = Numol*18.07;            %O2 produced in the reaction
                                %Algaeproducedmol = Numol*5.21;          %Algae produced in the reaction
                                CO2used = CO2usedmol*44.01;             %CO2 converted into gram
                                %O2 = O2producedmol*32.00;               %O2 converted into gram
                                %Algae = Algaeproducedmol*24.33;         %Algae converted into gram
                            else
                                %Stoichiometry under CO2-limiting conditions: [1]CO2+[0.064]NO3 -> [1.1572]O2+[0.3333]CHON
                                FlagCO2 = 1;
                                CO2mol = this.fCO2Mass/44.01;                 %CO2 converted into mol
                                Nuusedmol = CO2mol*0.064;               %NO3 used in the reaction
                                %O2producedmol = CO2mol*1.1572;          %O2 produced in the reaction
                                %Algaeproducedmol = CO2mol*0.3333;       %Algae produced in the reaction
                                Nuused = Nuusedmol*62.01;               %NO3 converted into gram
                                %O2 = O2producedmol*32.00;               %O2 converted into gram
                                %Algae = Algaeproducedmol*24.33;         %Algae converted into gram
                
                            end
                             
                  if FlagNu ==1
                        CO2 = CO2used;
                        Nu = this.fNuMass;
                  elseif FlagCO2 ==1
                        CO2 = this.fCO2Mass;
                        Nu = Nuused;
                  end
                    oParent.toStores.Filter_Algae_Reactor.toProcsP2P.filterproc.fMaxAbsorptionCO2 = this.fCO2need;
                    oParent.toStores.Filter_Algae_Reactor.toProcsP2P.filterproc.fMaxAbsorptionNO3 = this.fNuneed;
                    oParent.toStores.Filter_Algae_Reactor.toProcsP2P.filterproc.fMaxAbsorptionO2 = 0;
                    
                end
              
           end
        end
    end   
end
 
