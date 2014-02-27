function [ cParams, sDefaultPhase ] = water(~, fVolume, fTemperature, fPressure)
%helper to create a water phase
%
% Parameters:
%   fVolume         - Volume in SI m3
%   fTemperature    - Temperature in K - default 293.15 K
%   rRH             - Relative humidity - ratio (default 0, max 1)
%   fPressure       - Pressure in Pa - default 29647 Pa

% Values from @matter.table
% fRm         = 8.314472;
% fMolMassH2O = 18;
% fMolMassO2  = 32;
% fMolMassCO2 = 44;
% fMolMassN2  = 28;

% Check input arguments, set default
%TODO for fTemp, rRH, fPress -> key/value pairs?
if nargin < 3, fTemperature = 293.15; end;
%if nargin < 4, rRH          = 0;      end;
if nargin < 4, fPressure    = 28300; end;


%%Density calculation for water

%TO DO make dependant on matter table
%density at one fixed datapoint
fFixDensity = 998.21;        %g/dm³
%temperature for the fixed datapoint
fFixTemperature = 293.15;           %K
%Molar Mass of the compound
fMolMassH2O = 18.01528;       %g/mol
%critical temperature
fCriticalTemperature = 647.096;         %K
%critical pressure
fCriticalPressure = 220.64*10^5;      %N/m² = Pa

%boiling point normal pressure
fBoilingPressure = 1.01325*10^5;      %N/m² = Pa
%normal boiling point temperature
fBoilingTemperature = 373.124;      %K

fDensity = solver.matter.fdm_liquid.functions.LiquidDensity(fTemperature, fPressure, fFixDensity, fFixTemperature, fMolMassH2O, ...
    fCriticalTemperature, fCriticalPressure, fBoilingPressure, fBoilingTemperature);

%%


fMass = fDensity*fVolume;

% Matter composition
tfMass = struct(...
    'H2O', fMass ...
);



%TO DO: Check was only taken from N2Atmosphere
% Create cParams for a whole matter.phases.liquid standard phase. If user does
% not want to use all of them, can just use
% matter.phases.liquid(oMT.create('air'){1:2}, ...)
cParams = { tfMass fVolume fTemperature fPressure};


% Default class - required for automatic construction of phase. Helper re-
% turns the default phase that could be constructed with this set of params
sDefaultPhase = 'matter.phases.liquid';



end