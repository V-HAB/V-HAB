function [ CO2ppm ] = Calc_CO2_ppm( oPhase )
    %PPM_CO2 Calculates the ppm level of CO2 of input Phase
    
    % Mass of CO2 in considered phase
    fMassCO2 = oPhase.afMass(oPhase.oMT.tiN2I.CO2); %[kg]
    % Total gas mass in considered phase
    fTotalGasMass = oPhase.fMass; %[kg]
    % Molar mass CO2
    fMolarMassCO2 = oPhase.oMT.afMolarMass(oPhase.oMT.tiN2I.CO2); %[kg/mol]
    % Molar mass of phase
    fMolarMassPhase = oPhase.fMolarMass; %[kg/mol]
    
    %Calculating ppm of CO2
    CO2ppm = (fMassCO2 * fMolarMassPhase) / (fTotalGasMass * fMolarMassCO2) * 1000000; %[-]
    
end

