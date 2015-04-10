function [fDensity] = LiquidDensity(fTemperature, fPressure, fFixDensity, fFixTemperature, fMolMass, ...
    fCriticalTemperature, fCriticalPressure, fBoilingPressure, fBoilingTemperature)

    %reduced temperature
    fFixReducedTemperature = fFixTemperature/fCriticalTemperature;

    %reduced normal boiling point temperature
    fReducedBoilingTemperature = fBoilingTemperature/fCriticalTemperature;
    %reduced normal boiling point pressure
    fReducedBoilingPressure = fBoilingPressure/fCriticalPressure;

    %calculation of the parameters needed for the characterisitc molar volume
    nu_r_0_Fix = 1 - 1.52816*(1-fFixReducedTemperature)^(1/3) + 1.43907*(1-fFixReducedTemperature)^(2/3) - 0.81446*(1-fFixReducedTemperature) + 0.190454*(1-fFixReducedTemperature)^(4/3);
    nu_r_delta_Fix = (-0.296123 + 0.386914*fFixReducedTemperature - 0.0427258*fFixReducedTemperature^2 - 0.0480645*fFixReducedTemperature^3)/(fFixReducedTemperature-1.00001);

    %acentric factor
    fAcentricFactor = (log(fReducedBoilingPressure) - 5.92714 + (6.09648/fReducedBoilingTemperature) + 1.28862*log(fReducedBoilingTemperature) - 0.169347*fReducedBoilingTemperature^6)/(15.2518 - (15.6875/fReducedBoilingTemperature) - 13.4721*log(fReducedBoilingTemperature) + 0.43577*fReducedBoilingTemperature^6);

    %chracteristic molar volume in l/mol
    fCharacteristicMolarVolume = (fMolMass/fFixDensity)/(nu_r_0_Fix*(1 - fAcentricFactor*nu_r_delta_Fix));

    %general Gas Constant
    fR = 8314; % (dm³ Pa)/(mol K)
    
    %reduced temperature
    fReducedTemperature = fTemperature/fCriticalTemperature;
    
    %reduced pressure
    fReducedPressure = fPressure/fCriticalPressure;

    %required parameters for the reduced pressure
    fAlpha = 35 - 36/(fReducedTemperature) - 96.736*log10(fReducedTemperature) + fReducedTemperature^6;
    fBeta  = log10(fReducedTemperature) + 0.03721754*fAlpha;
    p_r_0  = 5.8031817*log10(fReducedTemperature) + 0.07608141 * fAlpha;
    p_r_1  = 4.86601*fBeta;
    %reduced vapor pressure
    fReducedSaturationPressure    = 10^(p_r_0 + fAcentricFactor*p_r_1);

    %molar co-volume which is the molar volume for infinite (very high)
    %pressure
    fMolarCoVolume = ((7.9019*10^-2) - ((2.8431*10^-2)*fAcentricFactor))*(fR*fCriticalTemperature)/fCriticalPressure;

    %calculation of the parameters needed for the molar saturation volume
    nu_r_0 = 1 - 1.52816*(1-fReducedTemperature)^(1/3) + 1.43907*(1-fReducedTemperature)^(2/3) - 0.81446*(1-fReducedTemperature) + 0.190454*(1-fReducedTemperature)^(4/3);
    nu_r_delta = (-0.296123 + 0.386914*fReducedTemperature - 0.0427258*fReducedTemperature^2 - 0.0480645*fReducedTemperature^3)/(fReducedTemperature-1.00001);

    %molar saturation volume in l/mol
    fMolarSaturationVolume = nu_r_0*fCharacteristicMolarVolume*(1-fAcentricFactor*nu_r_delta);

    fJ = (1.3168*10^-3) + (3.4448*10^-2)*(1-fReducedTemperature)^(1/3) + (5.4131*10^-2)*...
         (1-fReducedTemperature)^(2/3);

    %molar volume in l/mol
    fMolarVolume = ((fMolarCoVolume - fMolarSaturationVolume)*(5.5526-2.7659*...
        fAcentricFactor)*((fJ + (9.6840*10^-2)*(fReducedPressure-fReducedSaturationPressure)+...
        (8.6761*10^-2)*(fReducedPressure-fReducedSaturationPressure)^3)/(48.8756*(1-fReducedTemperature)...
        + 0.7185*(fReducedPressure-fReducedSaturationPressure)+(3.4031*10^-5)*(fReducedPressure-...
        fReducedSaturationPressure)^3)))+fMolarSaturationVolume;

    fDensity = fMolMass/fMolarVolume;

end