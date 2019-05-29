function fSpeedOfSound = calculateSpeedOfSound(this, varargin)
    %calculateSpeedOfSound: Calculate the speed of sound for provided matter
    %    Calculates the speed of sound by adding the single
    %    substance speed of sounds weighted with their mass fraction. Can use
    %    either a phase object as input parameter, or the phase type
    %    (sType) and the masses array (afMasses). Optionally, temperature
    %    and pressure can be passed as third and fourth parameters,
    %    respectively.
    %
    % calculateSpeedOfSound returns
    %  fSpeedOfSound  - speed of sound in m/s
    

[fTemperature, arPartialMass, csPhase, aiPhase, aiIndices, afPartialPressures, ~, ~] = getNecessaryParameters(this, varargin{:});

% here decesion on when other calculations should be used could be placed
% (see calculateDensity function for example)

fSpeedOfSound = calculateProperty(this, 'Speed Of Sound', fTemperature, arPartialMass, csPhase, aiPhase, aiIndices, afPartialPressures);

    
end
