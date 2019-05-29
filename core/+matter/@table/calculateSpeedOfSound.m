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
    
    [fTemperature, arPartialMass, csPhase, aiPhase, aiIndices, ~, ~, ~] = getNecessaryParameters(this, varargin{:});

    % If no mass is given, the heat capacity is also zero.
    if sum(arPartialMass) == 0
        fSpeedOfSound = 0;
        return; % Return early.
    end
    
    arPartialMass = afMasses./sum(afMasses);
    
    % Make sure there is no NaN in the mass vector.
    assert(~any(isnan(arPartialMass)), 'Invalid entries in mass vector.');

    
    % Find substances with a mass bigger than zero and count the results.
    % This helps in getting only the needed data from the matter table.
    iNumIndices = length(aiIndices);

    % Initialize a new array filled with zeros. Then iterate through all
    % indexed substances and get their specific heat capacity.
    afSpeedOfSound = zeros(iNumIndices, 1);
    
    for iI = 1:iNumIndices
        % Creating the input struct for the findProperty() method
        tParameters = struct();
        tParameters.sSubstance = this.csSubstances{aiIndices(iI)};
        tParameters.sProperty = 'Speed Of Sound';
        tParameters.sFirstDepName = 'Temperature';
        tParameters.fFirstDepValue = fTemperature;
        tParameters.sPhaseType = csPhase{aiPhase(aiIndices(iI))};
        if iNumArgs > 4
            tParameters.sSecondDepName = 'Density';
            tParameters.fSecondDepValue = fDensity;
        else
            tParameters.sSecondDepName = 'Pressure';
            tParameters.fSecondDepValue = fPressure;
        end
        tParameters.bUseIsobaricData = true;
        
        afSpeedOfSound(iI) = this.findProperty(tParameters);
    end

    % Make sure there is no NaN in the speed of sound vector.
    assert(~any(isnan(afSpeedOfSound)), 'Invalid entries in specific heat capacity vector.');

    %DEBUG
    assert(isequal(size(afSpeedOfSound), size(arPartialMass(aiIndices)')), 'Vectors must be of same length but one transposed.');

    % Multiply the speed of sound with the mass fractions. The
    % result of the matrix multiplication is the speed of sound of
    % the mixture.
    fSpeedOfSound = sum(arPartialMass(aiIndices)' .* afSpeedOfSound);

    % Make sure the speed of sound value is valid.
    assert(~isnan(fSpeedOfSound) && fSpeedOfSound >= 0, ...
        'Invalid speed of sound: %f', fSpeedOfSound);
end
