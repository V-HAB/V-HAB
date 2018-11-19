%Returns the outlet temperatures of a counterflow heat exchanger in K
%
%fArea              = Area of the heat exchanger in m²
%fU                 = heat exchange coefficient W/m²K
%fHeat_Cap_Flow_c   = heat capacity flow of cold stream in W/K
%fHeat_Cap_Flow_h   = heat capacity flow of hot stream in W/K
%fEntry_Temp_c      = inlet temperature of cold fluid in K
%fEntry_Temp_h      = inlet temperature of hot fluid in K
%
%These arguments are used in the function as follows:
%
%[fOutlet_Temp_c, fOutlet_Temp_h] = temperature_counterflow (fArea, fU,...
%         fHeat_Cap_Flow_c, fHeat_Cap_Flow_h, fEntry_Temp_c, fEntry_Temp_h)
%
%Output [fOutlet_Temp_c, fOutlet_Temp_h] in K

function [fOutlet_Temp_c, fOutlet_Temp_h]=temperature_counterflow(fArea,...
      fU, fHeat_Cap_Flow_c, fHeat_Cap_Flow_h, fEntry_Temp_c, fEntry_Temp_h)

%the source "Wärmeübertragung" Polifke will from now on be defined as [1]

%Number of Transfer Units
fNTU = (fU*fArea)/min(fHeat_Cap_Flow_c,fHeat_Cap_Flow_h);                                       
%Equation from [1] page 174 equation (8.4)                                     

%ratio of heat capacity flows
fHeat_Cap_Flow_Ratio = min(fHeat_Cap_Flow_c,fHeat_Cap_Flow_h)/...
                       max(fHeat_Cap_Flow_c,fHeat_Cap_Flow_h);                                 
%Equation from [1] page 174 equation (8.5)

%discerns whether the cold fluid or the hot fluid has the higher heat 
%capacity flow because this decides how the heat capacity flow ratio was 
%calculated an thus decides how the further computation has to be done
if fHeat_Cap_Flow_c < fHeat_Cap_Flow_h
    
    %calculates fTheta_c the dimensionless temperature for the cold 
    %fluid
    fTheta_c = (1-exp(-fNTU*(1-fHeat_Cap_Flow_Ratio)))/...
              (1-fHeat_Cap_Flow_Ratio*exp(-fNTU*(1-fHeat_Cap_Flow_Ratio)));     
    %Equation from [1] page 178 equation (8.15)
    
    %calculates fTheta_h, the dimensionless temperature for the hot 
    %fluid from fTheta_c and fHeat_Cap_Flow_Ratio
    fTheta_h = fHeat_Cap_Flow_Ratio*fTheta_c;                                   
    %Equation from [1] page 176 equation (8.1)

else
    %calculates fTheta_h, the dimensionless temperature for the hot 
    %fluid
    fTheta_h = (1-exp(-fNTU*(1-fHeat_Cap_Flow_Ratio)))/...
              (1-fHeat_Cap_Flow_Ratio*exp(-fNTU*(1-fHeat_Cap_Flow_Ratio)));     
    %Equation from [1] page 178 equation (8.16)converted for theta_h 
    %(see the comment in the book below the function)
    
    %calculates fTheta_c, the dimensionless temperature for the cold
    %fluid from fTheta_h and fHeat_Cap_Flow_Ratio
    fTheta_c = fHeat_Cap_Flow_Ratio*fTheta_h;                                   
    %Equation from [1] page 176 equation (8.1)
end
    
%gains the resulting outlet temperature of the cold fluid from the
%defintion for fTheta_c
fOutlet_Temp_c = fEntry_Temp_c + (fEntry_Temp_h - fEntry_Temp_c)*fTheta_c;                        
%Equation from [1] page 174 equation (8.3)

%gains the resulting outlet temperature of the hot fluid from the
%defintion for fTheta_h
fOutlet_Temp_h = fEntry_Temp_h - (fEntry_Temp_h - fEntry_Temp_c)*fTheta_h;                        
%Equation from [1] page 174 equation (8.2)
end