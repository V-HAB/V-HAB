function fDewPoint = convertHumidityToDewpoint(this, varargin)
% this function converts a relative humidity value (0 to 1) into dewpoint [K]
%
% The function can be provided with a gas phase as input parameter in which
% case it will automatically take the required parameters from the object.
% Alternativly it can be provided with the following input parameters in
% that order:
%
% rRelativeHumidity     Relative Humidity between 0 and 1 [-]
% fTemperature          Temperature of the gas for which the dewpoint shall
%                       be calculated in [K]
%
% Note, if you want to convert a dew point into a humidity use the
% calculateVaporPressure function for the dew point temperature (and H2O),
% to calculate the current partial pressure of H2O and then calculate the
% vapor pressure for the actual temperature (to get the current vapor
% pressure of Water). By then dividing the partial pressure and the vapor
% pressure you obtain the humidity:
% rRelHumidity = oMT.calculateVaporPressure(fDewPoint, 'H2O') / oMT.calculateVaporPressure(fTemperature, 'H2O');
% Since the dew point is not a value used in Matlab no function for this is
% provided, however this explanation was included since dewpoints are often
% used in literature

if length(varargin) == 1
    oPhase = varargin{1};
    fTemperature      = oPhase.fTemperature;
    fPartialPressure  = oPhase.afPP(this.tiN2I.H2O);
else
    rRelativeHumidity = varargin{1};
    fTemperature  = varargin{2};
    
    fPartialPressure = rRelativeHumidity * this.calculateVaporPressure(fTemperature, 'H2O');
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
    
% In the following cases the dewpoint cannot be calculated because the
% temperature is outside of the limits for the available antoine equations.
% However if the temperature is below the limits the substance is liquid
% and the dewpoint can be seen as 0 K. If the temperature is above the
% limit the substance is gaseous and the dewpoint can be seen as infinite
elseif fTemperature < 255.9
    fA = inf;
    fB = 0;
    fC = 0;
elseif fTemperature >= 573
    fA = 0;
    fB = inf;
    fC = 0;
end
% Antoine Equation solved for the temperature
fDewPoint = fB/(fA - log10(fPartialPressure/(1e5))) - fC;
end

 