function [ CO2ppm ] = Calc_CO2_ppm_( oPhase )
%PPM_CO2 Summary of this function goes here
%   Detailed explanation goes here
    %Calculates the ppm level of CO2 of input Phase
    
    %Partial Mass of CO2 in considered phase
        mCO2=oPhase.afMass(oPhase.oMT.tiN2I.CO2); %[kg]
    %Total gas mass in considered phase
        mges=oPhase.fMass; %[kg]
    %Molecular mass CO2
        MCO2=44; %[g/mol]
    %Total molescular mass of CO2
        Mges=oPhase.fMolMass; %[g/mol]
    
    %Calculating ppm of CO2
        CO2ppm=(mCO2*Mges)/(MCO2*mges)*1000000; %[]


end

