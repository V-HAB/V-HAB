function fDewPoint = convertHumidityToDewpoint(oMT, varargin)
% this function can be given a gas phase as input parameter (oMT is
% automatically supplied, because it is a matter table function) or the
% relative humidity and temperature to convert the humidity into the dew
% point (only works for water)
%
% Note, if you want to convert a dew point into a humidity use the
% calculateVaporPressure function for the dew point temperature (and H2O),
% to calculate the current partial pressure of H2O and then calculate the
% vapor pressure for the actual temperature (to get the current vapor
% pressure of Water). By then dividing the partial pressure and the vapor
% pressure you obtain the humidity:
% rRelHumidity = oMT.calculateVaporPressure(fDewPoint, 'H2O') / oMT.calculateVaporPressure(fTemperature, 'H2O');

if length(varargin) == 1
    oPhase = varargin{1};
    fTemperature      = oPhase.fTemperature;
    fPartialPressure  = oPhase.afPP(oPhase.oMT.tiN2I.H2O);
else
    rRelativeHumidity = varargin{1};
    fTemperature  = varargin{2};
    
    fPartialPressure = rRelativeHumidity * oMT.calculateVaporPressure(fTemperature, 'H2O');
end
% Values for antoine equation from nist chemistry webbook
if fTemperature >= 255.9 && fTemperature < 379
    %parameters for the vapor pressure calculation
    fA = 4.6543;
    fB = 1435.264;
    fC = -64.848;
elseif fTemperature >= 379 && fTemperature < 573
    %parameters for the vapor pressure calculation
    fA = 3.55959;
    fB = 643.748;
    fC = -198.043;
end
% Antoine Equation solved for the temperature
fDewPoint = fB/(fA - log10(fPartialPressure/(1e5))) - fC;
end

 