function fSaturationVaporPressure = calculateWaterSaturationVaporPressure( ~ , fTemperature )
%CALCULATESATURATIONVAPORPRESSURE Calculates the saturation vapor pressure
%of water above a flat surface of water.
%   This formula uses the newest parameters for the Magnus correlation
%   between gas temperature and saturation vapor pressure. The values are
%   taken from the following publication:
%   Oleg A. Alduchov and Robert E. Eskridge, 1996: Improved Magnus Form
%   Approximation of Saturation Vapor Pressure. J. Appl. Meteor., 35,
%   601?609. DOI: 10.1175/1520-0450(1996)035<0601:IMFAOS>2.0.CO;2

fSaturationVaporPressure = 610.94 * exp((17.625 * (fTemperature - 273.15)) / (243.04 + fTemperature - 273.15));

end

