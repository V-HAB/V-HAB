function fVaporPressure = calculateVaporPressure(~, fTemperature, sSubstance)
%The vapor pressure over temperature is required for the 
%calculation of condensation in the heat exchanger. The values and
%equation are taken from http://webbook.nist.gov for every sustance and the
%vapor pressure returned in case the substance is liquid for any pressure
%is 0 and if it is a gas for any pressure it is inf.
    
%first it is necessary to decide for which substance the vapor pressure
%should be calculated

tfAntoineParameters = struct();

% Antoine parameters for CH4
tfAntoineParameters.CH4.Range(1).mfLimits = [90.99, 189.99];
tfAntoineParameters.CH4.Range(1).fA = 3.9895;
tfAntoineParameters.CH4.Range(1).fB = 443.028;
tfAntoineParameters.CH4.Range(1).fC = -0.49;

% Antoine parameters for H2
tfAntoineParameters.H2.Range(1).mfLimits = [21.01, 32.27];
tfAntoineParameters.H2.Range(1).fA = 3.54314;
tfAntoineParameters.H2.Range(1).fB = 99.395;
tfAntoineParameters.H2.Range(1).fC = 7.726;

% Antoine parameters for O2
tfAntoineParameters.O2.Range(1).mfLimits = [54.36, 154.33];
tfAntoineParameters.O2.Range(1).fA = 3.9523;
tfAntoineParameters.O2.Range(1).fB = 340.024;
tfAntoineParameters.O2.Range(1).fC = -4.144;

% Antoine parameters for H2O
tfAntoineParameters.H2O.Range(1).mfLimits = [255.9, 379];
tfAntoineParameters.H2O.Range(1).fA = 4.6543;
tfAntoineParameters.H2O.Range(1).fB = 1435.264;
tfAntoineParameters.H2O.Range(1).fC = -64.848;

tfAntoineParameters.H2O.Range(2).mfLimits = [379, 573];
tfAntoineParameters.H2O.Range(2).fA = 3.55959;
tfAntoineParameters.H2O.Range(2).fB = 643.748;
tfAntoineParameters.H2O.Range(2).fC = -198.043;

% Antoine parameters for CO2
tfAntoineParameters.CO2.Range(1).mfLimits = [154.26, 195.89];
tfAntoineParameters.CO2.Range(1).fA = 6.81228;
tfAntoineParameters.CO2.Range(1).fB = 1301.679;
tfAntoineParameters.CO2.Range(1).fC = -3.494;

% Antoine parameters for NH3
tfAntoineParameters.NH3.Range(1).mfLimits = [164, 239.6];
tfAntoineParameters.NH3.Range(1).fA = 3.18757;
tfAntoineParameters.NH3.Range(1).fB = 596.713;
tfAntoineParameters.NH3.Range(1).fC = -80.78;

tfAntoineParameters.NH3.Range(2).mfLimits = [239.6, 371.5];
tfAntoineParameters.NH3.Range(2).fA = 4.86886;
tfAntoineParameters.NH3.Range(2).fB = 1113.928;
tfAntoineParameters.NH3.Range(2).fC = -10.409;

% Antoine parameters for CO
tfAntoineParameters.CO.Range(1).mfLimits = [81.63];

% Antoine parameters for N2
tfAntoineParameters.N2.Range(1).mfLimits = [63.14, 126];
tfAntoineParameters.N2.Range(1).fA = 3.7362;
tfAntoineParameters.N2.Range(1).fB = 264.651;
tfAntoineParameters.N2.Range(1).fC = -6.788;

% Antoine parameters for Ar
tfAntoineParameters.Ar.Range(1).mfLimits = [83.78, 150.72];
tfAntoineParameters.Ar.Range(1).fA = 3.29555;
tfAntoineParameters.Ar.Range(1).fB = 215.24;
tfAntoineParameters.Ar.Range(1).fC = -22.233;


for iRange = 1:length(tfAntoineParameters.(sSubstance))
    
    mfLimits = [tfAntoineParameters.(sSubstance).Range(:).mfLimits];
    
    if fTemperature < mfLimits(1)
        % For temperature below the limits the substance is liquid and the
        % vapor pressure is 0. This is represented by the following antoine
        % parameters
        fA = 0;
        fB = inf;
        fC = 0;
        
    elseif fTemperature > mfLimits(end)
        % For temperature above the limits the substance is gaseous and the
        % vapor pressure is inf. This is represented by the following antoine
        % parameters
        fA = inf;
        fB = 0;
        fC = 0;
        
    elseif (fTemperature >= tfAntoineParameters.(sSubstance).Range(iRange).mfLimits(1)) &&...
            (fTemperature <= tfAntoineParameters.(sSubstance).Range(iRange).mfLimits(2))
        % In between the limits the respective antoine parameters from the
        % NIST chemistry webbook for the respective substance are used
        fA = tfAntoineParameters.(sSubstance).Range(iRange).fA;
        fB = tfAntoineParameters.(sSubstance).Range(iRange).fB;
        fC = tfAntoineParameters.(sSubstance).Range(iRange).fC;
    end
    
end

% Antoine Equation
fVaporPressure = (10^(fA -(fB/(fTemperature+fC))))*10^5; 

end

