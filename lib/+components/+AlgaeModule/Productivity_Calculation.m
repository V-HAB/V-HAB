 classdef Productivity_Calculation < vsys

 properties
        fProductivity;
        fPower;
        fDilution;
        fP1 = 0;
        fP2 = 0;
        fP3 = 0;
        fP4 = 0;
        fP5 = 0;
        fP6 = 0;
        fP7 = 0;
        fP8 = 0;
        fP9 = 0;
    end
    
    
  
    methods
        function this = Productivity_Calculation(oParent, sName)
            this@vsys(oParent, sName, 60);

      this.fPower = this.oParent.fPower;
      this.fDilution =  this.oParent.fDilution;
      fP1 = this.fP1;
      fP2 = this.fP2;
      fP3 = this.fP3;
      fP4 = this.fP4;
      fP5 = this.fP5;
      fP6 = this.fP6;
      fP7 = this.fP7;
      fP8 = this.fP8;
      fP9 = this.fP9;
      
        


%% Productivity

            
            if this.fDilution > 0 && this.fDilution <= 1.25
                if this.fPower >= 1700 %[watt]
                    %Illupower5 = 1500; %[watt] equates 900 %[µmol/m²s]
                    oParent.oParent.toChildren.PowerControl.fAerationPower = 200;
                    %Aerpower5 = 200; %[watt] equates 2.1 %[l/l min]
                    fP5 = 99.79*this.fDilution^(0.8472)*exp(-0.1731*this.fDilution);
                    
                elseif this.fPower >= 1600 && this.fPower < 1700 %[watt]
                    %Illupower6 = 1500; %[watt] equates 900 %[µmol/m²s]
                    oParent.oParent.toChildren.PowerControl.fAerationPower = 100;
                    %Aerpower6 = 100; %[watt] equates 0.6 %[l/l min]
                    fP6 = 113*this.fDilution^(1.132)*exp(-0.354*this.fDilution);
                    
                elseif this.fPower >= 850 && this.fPower < 1600 %[watt]
                    %Illupower9 = 750; %[watt] equates 500 %[µmol/m²s]
                    oParent.oParent.toChildren.PowerControl.fAerationPower = 100;
                    %Aerpower9 = 100; %[watt] equates 0.6 %[l/l min]
                    fP9 = 69.94*this.fDilution^(0.9015)*exp(-0.3488*this.fDilution);
                end
                
            elseif this.fDilution > 1.25 && this.fDilution <= 2.5
                if this.fPower >= 1700 %[watt]
                    %Illupower5 = 1500; %[watt] equates 900 %[µmol/m²s]
                    oParent.oParent.toChildren.PowerControl.fAerationPower = 200;
                    %Aerpower5 = 200; %[watt] equates 2.1 %[l/l min]
                    fP5 = 99.79*this.fDilution^(0.8472)*exp(-0.1731*this.fDilution);
                    
                elseif this.fPower >= 1600 && this.fPower < 1700 %[watt]
                    %Illupower6 = 1500; %[watt] equates 900 %[µmol/m²s]
                    oParent.oParent.toChildren.PowerControl.fAerationPower = 100;
                    %Aerpower6 = 100; %[watt] equates 0.6 %[l/l min]
                    fP6 = 113*this.fDilution^(1.132)*exp(-0.354*this.fDilution);
                    
                elseif this.fPower >= 950 && this.fPower < 1600 %[watt]
                    %Illupower8 = 750; %[watt] equates 500 %[µmol/m²s]
                    oParent.oParent.toChildren.PowerControl.fAerationPower = 200;
                    %Aerpower8 = 200; %[watt] equates 2.1 %[l/l min]
                    fP8 = 67.15*this.fDilution^(1.326)*exp(-0.3816*this.fDilution);
                    
                elseif this.fPower >= 850 && this.fPower < 950 %[watt]
                    %Illupower9 = 750; %[watt] equates 500 %[µmol/m²s]
                    oParent.oParent.toChildren.PowerControl.fAerationPower = 100;
                    %Aerpower9 = 100; %[watt] equates 0.6 %[l/l min]
                    fP9 = 69.94*this.fDilution^(0.9015)*exp(-0.3488*this.fDilution);
                end
            elseif this.fDilution > 2.5 && this.fDilution <= 3.8
                if this.fPower >= 3100 %[watt]
                    %Illupower3 = 3000; %[watt] equates 1800 %[µmol/m²s]
                    oParent.oParent.toChildren.PowerControl.fAerationPower = 100;
                    %Aerpower3 = 100; %[watt] equates 0.6 %[l/l min]
                    fP3 = 71.17*this.fDilution^(1.45)*exp(-0.2571*this.fDilution);
                    
                elseif this.fPower >= 1700 && this.fPower < 3100 %[watt]
                    %Illupower5 = 1500; %[watt] equates 900 %[µmol/m²s]
                    oParent.oParent.toChildren.PowerControl.fAerationPower = 200;
                    %Aerpower5 = 200; %[watt] equates 2.1 %[l/l min]
                    fP5 = 99.79*this.fDilution^(0.8472)*exp(-0.1731*this.fDilution);
                    
                elseif this.fPower >= 1600 && this.fPower < 1700 %[watt]
                    %Illupower6 = 1500; %[watt] equates 900 %[µmol/m²s]
                    oParent.oParent.toChildren.PowerControl.fAerationPower = 100;
                    %Aerpower6 = 100; %[watt] equates 0.6 %[l/l min]
                    fP6 = 113*this.fDilution^(1.132)*exp(-0.354*this.fDilution);
                    
                elseif this.fPower >= 1150 && this.fPower < 1600 %[watt]
                    %Illupower7 = 750; %[watt] equates 500 %[µmol/m²s]
                    oParent.oParent.toChildren.PowerControl.fAerationPower = 400;
                    %Aerpower7 = 400; %[watt] equates 4.2 %[l/l min]
                    fP7 = 57.3*this.fDilution^(1.441)*exp(-0.3636*this.fDilution);
                    
                elseif this.fPower >= 950 && this.fPower < 1150 %[watt]
                    %Illupower8 = 750; %[watt] equates 500 %[µmol/m²s]
                    %Aerpower8 = 200; %[watt] equates 2.1 %[l/l min]
                    fP8 = 67.15*this.fDilution^(1.326)*exp(-0.3816*this.fDilution);
                    
                elseif this.fPower >= 850 && this.fPower < 950 %[watt]
                    %Illupower9 = 750; %[watt] equates 500 %[µmol/m²s]
                    oParent.oParent.toChildren.PowerControl.fAerationPower = 100;
                    %Aerpower9 = 100; %[watt] equates 0.6 %[l/l min]
                    fP9 = 69.94*this.fDilution^(0.9015)*exp(-0.3488*this.fDilution);
                end
            elseif this.fDilution > 3.8 && this.fDilution <= 6.9
                if this.fPower >= 3200 %[watt]
                    %Illupower2 = 3000; %[watt] equates 1800 %[µmol/m²s]
                    oParent.oParent.toChildren.PowerControl.fAerationPower = 200;
                    %Aerpower2 = 200; %[watt] equates 2.1 %[l/l min]
                    fP2 = 65.59*this.fDilution^(1.042)*exp(-0.09287*this.fDilution);
                    
                elseif this.fPower >= 3100 && this.fPower < 3200 %[watt]
                    %Illupower3 = 3000; %[watt] equates 1800 %[µmol/m²s]
                    oParent.oParent.toChildren.PowerControl.fAerationPower = 100;
                    %Aerpower3 = 100; %[watt] equates 0.6 %[l/l min]
                    fP3 = 71.17*this.fDilution^(1.45)*exp(-0.2571*this.fDilution);
                    
                elseif this.fPower >= 1900 && this.fPower < 3100 %[watt]
                    %Illupower4 = 1500; %[watt] equates 900 %[µmol/m²s]
                    oParent.oParent.toChildren.PowerControl.fAerationPower = 400;
                    %Aerpower4 = 400; %[watt] equates 4.2 %[l/l min]
                    fP4 = 75.09*this.fDilution^(0.8996)*exp(-0.1156*this.fDilution);
                    
                elseif this.fPower >= 1700 && this.fPower < 1900 %[watt]
                    %Illupower5 = 1500; %[watt] equates 900 %[µmol/m²s]
                    oParent.oParent.toChildren.PowerControl.fAerationPower = 200;
                    %Aerpower5 = 200; %[watt] equates 2.1 %[l/l min]
                    fP5 = 99.79*this.fDilution^(0.8472)*exp(-0.1731*this.fDilution);
                    
                elseif this.fPower >= 1600 && this.fPower < 1700 %[watt]
                    %Illupower6 = 1500; %[watt] equates 900 %[µmol/m²s]
                    oParent.oParent.toChildren.PowerControl.fAerationPower = 100;
                    %Aerpower6 = 100; %[watt] equates 0.6 %[l/l min]
                    fP6 = 113*this.fDilution^(1.132)*exp(-0.354*this.fDilution);
                    
                elseif this.fPower >= 1150 && this.fPower < 1600 %[watt]
                    %Illupower7 = 750; %[watt] equates 500 %[µmol/m²s]
                    oParent.oParent.toChildren.PowerControl.fAerationPower = 400;
                    %Aerpower7 = 400; %[watt] equates 4.2 %[l/l min]
                    fP7 = 57.3*this.fDilution^(1.441)*exp(-0.3636*this.fDilution);
                    
                elseif this.fPower >= 950 && this.fPower < 1150 %[watt]
                    %Illupower8 = 750; %[watt] equates 500 %[µmol/m²s]
                    oParent.oParent.toChildren.PowerControl.fAerationPower = 200;
                    %Aerpower8 = 200; %[watt] equates 2.1 %[l/l min]
                    fP8 = 67.15*this.fDilution^(1.326)*exp(-0.3816*this.fDilution);
                    
                elseif this.fPower >= 850 && this.fPower < 950 %[watt]
                    %Illupower9 = 750; %[watt] equates 500 %[µmol/m²s]
                    oParent.oParent.toChildren.PowerControl.fAerationPower = 100;
                    %Aerpower9 = 100; %[watt] equates 0.6 %[l/l min]
                    fP9 = 69.94*this.fDilution^(0.9015)*exp(-0.3488*this.fDilution);
                end
            elseif this.fDilution > 6.9 && this.fDilution <= 7.4
                if this.fPower >= 3400 %[watt]
                    %Illupower1 = 3000; %[watt] equates 1800 %[µmol/m²s]
                    oParent.oParent.toChildren.PowerControl.fAerationPower = 400;
                    %Aerpower1 = 400; %[watt] equates 4.2 %[l/l min]
                    fP1 = 18.26*this.fDilution^(1.812)*exp(-0.123*this.fDilution);
                    
                elseif this.fPower >= 3200 && this.fPower <3400 %[watt]
                    %Illupower2 = 3000; %[watt] equates 1800 %[µmol/m²s]
                    oParent.oParent.toChildren.PowerControl.fAerationPower = 200;
                    %Aerpower2 = 200; %[watt] equates 2.1 %[l/l min]
                    fP2 = 65.59*this.fDilution^(1.042)*exp(-0.09287*this.fDilution);
                    
                elseif this.fPower >= 3100 && this.fPower < 3200 %[watt]
                    %Illupower3 = 3000; %[watt] equates 1800 %[µmol/m²s]
                    oParent.oParent.toChildren.PowerControl.fAerationPower = 100;
                    %Aerpower3 = 100; %[watt] equates 0.6 %[l/l min]
                    fP3 = 71.17*this.fDilution^(1.45)*exp(-0.2571*this.fDilution);
                    
                elseif this.fPower >= 1900 && this.fPower < 3100 %[watt]
                    %Illupower4 = 1500; %[watt] equates 900 %[µmol/m²s]
                    oParent.oParent.toChildren.PowerControl.fAerationPower = 400;
                    %Aerpower4 = 400; %[watt] equates 4.2 %[l/l min]
                    fP4 = 75.09*this.fDilution^(0.8996)*exp(-0.1156*this.fDilution);
                    
                elseif this.fPower >= 1700 && this.fPower < 1900 %[watt]
                    %Illupower5 = 1500; %[watt] equates 900 %[µmol/m²s]
                    oParent.oParent.toChildren.PowerControl.fAerationPower = 200;
                    %Aerpower5 = 200; %[watt] equates 2.1 %[l/l min]
                    fP5 = 99.79*this.fDilution^(0.8472)*exp(-0.1731*this.fDilution);
                    
                elseif this.fPower >= 1600 && this.fPower < 1700 %[watt]
                    %Illupower6 = 1500; %[watt] equates 900 %[µmol/m²s]
                    oParent.oParent.toChildren.PowerControl.fAerationPower = 100;
                    %Aerpower6 = 100; %[watt] equates 0.6 %[l/l min]
                    fP6 = 113*this.fDilution^(1.132)*exp(-0.354*this.fDilution);
                    
                elseif this.fPower >= 1150 && this.fPower < 1600 %[watt]
                    %Illupower7 = 750; %[watt] equates 500 %[µmol/m²s]
                    oParent.oParent.toChildren.PowerControl.fAerationPower = 400;
                    %Aerpower7 = 400; %[watt] equates 4.2 %[l/l min]
                    fP7 = 57.3*this.fDilution^(1.441)*exp(-0.3636*this.fDilution);
                    
                elseif this.fPower >= 950 && this.fPower < 1150 %[watt]
                    %Illupower8 = 750; %[watt] equates 500 %[µmol/m²s]
                    oParent.oParent.toChildren.PowerControl.fAerationPower = 200;
                    %Aerpower8 = 200; %[watt] equates 2.1 %[l/l min]
                    fP8 = 67.15*this.fDilution^(1.326)*exp(-0.3816*this.fDilution);
                    
                elseif this.fPower >= 850 && this.fPower < 950 %[watt]
                    %Illupower9 = 750; %[watt] equates 500 %[µmol/m²s]
                    oParent.oParent.toChildren.PowerControl.fAerationPower = 100;
                    %Aerpower9 = 100; %[watt] equates 0.6 %[l/l min]
                    fP9 = 69.94*this.fDilution^(0.9015)*exp(-0.3488*this.fDilution);
                end
            elseif this.fDilution > 7.4 && this.fDilution <= 500
                if this.fPower >= 3400 %[watt]
                    %Illupower1 = 3000; %[watt] equates 1800 %[µmol/m²s]
                    oParent.oParent.toChildren.PowerControl.fAerationPower = 400;
                    %Aerpower1 = 400; %[watt] equates 4.2 %[l/l min]
                    fP1 = 18.26*this.fDilution^(1.812)*exp(-0.123*this.fDilution);
                    
                elseif this.fPower >= 3200 && this.fPower <3400 %[watt]
                    %Illupower2 = 3000; %[watt] equates 1800 %[µmol/m²s]
                    oParent.oParent.toChildren.PowerControl.fAerationPower = 200;
                    %Aerpower2 = 200; %[watt] equates 2.1 %[l/l min]
                    fP2 = 65.59*this.fDilution^(1.042)*exp(-0.09287*this.fDilution);
                    
                elseif this.fPower >= 1900 && this.fPower < 3200 %[watt]
                    %Illupower4 = 1500; %[watt] equates 900 %[µmol/m²s]
                    oParent.oParent.toChildren.PowerControl.fAerationPower = 400;
                    %Aerpower4 = 400; %[watt] equates 4.2 %[l/l min]
                    fP4 = 75.09*this.fDilution^(0.8996)*exp(-0.1156*this.fDilution);
                    
                elseif this.fPower >= 1700 && this.fPower < 1900 %[watt]
                    %Illupower5 = 1500; %[watt] equates 900 %[µmol/m²s]
                    oParent.oParent.toChildren.PowerControl.fAerationPower = 200;
                    %Aerpower5 = 200; %[watt] equates 2.1 %[l/l min]
                    fP5 = 99.79*this.fDilution^(0.8472)*exp(-0.1731*this.fDilution);
                    
                elseif this.fPower >= 1600 && this.fPower < 1700 %[watt]
                    %Illupower6 = 1500; %[watt] equates 900 %[µmol/m²s]
                    oParent.oParent.toChildren.PowerControl.fAerationPower = 100;
                    %Aerpower6 = 100; %[watt] equates 0.6 %[l/l min]
                    fP6 = 113*this.fDilution^(1.132)*exp(-0.354*this.fDilution);
                    
                elseif this.fPower >= 1150 && this.fPower < 1600 %[watt]
                    %Illupower7 = 750; %[watt] equates 500 %[µmol/m²s]
                    oParent.oParent.toChildren.PowerControl.fAerationPower = 400;
                    %Aerpower7 = 400; %[watt] equates 4.2 %[l/l min]
                    fP7 = 57.3*this.fDilution^(1.441)*exp(-0.3636*this.fDilution);
                    
                elseif this.fPower >= 950 && this.fPower < 1150 %[watt]
                    %Illupower8 = 750; %[watt] equates 500 %[µmol/m²s]
                    oParent.oParent.toChildren.PowerControl.fAerationPower = 200;
                    %Aerpower8 = 200; %[watt] equates 2.1 %[l/l min]
                    fP8 = 67.15*this.fDilution^(1.326)*exp(-0.3816*this.fDilution);
                    
                elseif this.fPower >= 850 && this.fPower < 950 %[watt]
                    %Illupower9 = 750; %[watt] equates 500 %[µmol/m²s]
                    oParent.oParent.toChildren.PowerControl.fAerationPower = 100;
                    %Aerpower9 = 100; %[watt] equates 0.6 %[l/l min]
                    fP9 = 69.94*this.fDilution^(0.9015)*exp(-0.3488*this.fDilution);
                end
            end
            this.fProductivity = fP1+fP2+fP3+fP4+fP5+fP6+fP7+fP8+fP9;
            
            
            
            this.oParent.toChildren.Productivity.fProductivity = this.fProductivity;
            
            
        end
       
        
        
        
        
end
 end
