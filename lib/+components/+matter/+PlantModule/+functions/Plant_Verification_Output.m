function Plant_Verification_Output(oCulture)

    fOxygenProduction = sum(oCulture.mfOxygenProduction);
    fCarbonDioxideUptake =sum(oCulture.mfCarbonDioxideUptake);
    fWaterTranspiration = sum(oCulture.mfWaterTranspiration);
    fTotalBioMass = sum(oCulture.mfTotalBioMass);
    fInedibleMass = sum(oCulture.mfInedibleMass);
    fEdibleMass = sum(oCulture.mfEdibleMass);
%     
%     fInedibleMassDryBasis = sum(oCulture.mfInedibleMassDryBasis);
%     fEdibleMassDryBasis = sum(oCulture.mfEdibleMassDryBasis);
    
    fOxygenProduction = (fOxygenProduction/length(oCulture.mfOxygenProduction))* 24*3600*1000;
    fCarbonDioxideUptake = (fCarbonDioxideUptake/length(oCulture.mfCarbonDioxideUptake))* 24*3600*1000;
    fWaterTranspiration = (fWaterTranspiration/length(oCulture.mfWaterTranspiration))* 24 * 3600;
    fTotalBioMass = (fTotalBioMass/length(oCulture.mfTotalBioMass))* 24*3600*1000;
    fInedibleMass = (fInedibleMass/length(oCulture.mfInedibleMass))* 24*3600*1000;
    fEdibleMass = (fEdibleMass/length(oCulture.mfEdibleMass))* 24*3600*1000;
    
%     fInedibleMassDryBasis = (fInedibleMassDryBasis/length(oCulture.mfInedibleMassDryBasis))* 24*3600*1000;
%     fEdibleMassDryBasis = (fEdibleMassDryBasis/length(oCulture.mfEdibleMassDryBasis))* 24*3600*1000;
    
    fprintf( 'The  mass of produced oxygen is: %f [gramm/m²d] \n', fOxygenProduction);
    fprintf( 'The  mass of consumed carbon dioxide is: %f [gramm/m²d] \n', fCarbonDioxideUptake);
    fprintf( 'The  mass of transpirated water is %f [kg/m²d] \n', fWaterTranspiration);
    fprintf( 'The  mass of produced Total Biomass is %f [gramm/m²d] \n', fTotalBioMass);
    fprintf( 'The  mass of produced Inedible Biomas is %f [gramm/m²d] \n', fInedibleMass);
    fprintf( 'The  mass of produced Edible Biomass is %f [gramm/m²d] \n', fEdibleMass);
%     fprintf( 'The  mass of produced Inedible Biomas on Dry Basis is %f [gramm/m²d] \n', fInedibleMassDryBasis);
%     fprintf( 'The  mass of produced Edible Biomass on Dry Basis is %f [gramm/m²d] \n', fEdibleMassDryBasis);
    
end