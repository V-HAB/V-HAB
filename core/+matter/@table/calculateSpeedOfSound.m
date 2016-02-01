function fSpeedOfSound = calculateSpeedOfSound(this, varargin) %sMatterState, afMasses, fTemperature, fPressure)
    %CALCULATESPECIFICHEATCAPACITY Calculate the specific heat capacity of a mixture
    %    Calculates the specific heat capacity by adding the single
    %    substance capacities weighted with their mass fraction. Can use
    %    either a phase object as input parameter, or the phase type
    %    (sType) and the masses array (afMasses). Optionally, temperature
    %    and pressure can be passed as third and fourth parameters,
    %    respectively.
    %
    % calculateHeatCapacity returns
    %  fSpecificHeatCapacity  - specific, isobaric heat capacity of mix in J/kgK?
    %
    %TODO: deprecate this method in favor of |getSpecificHeatCapacity()|
    %      and |getTotalHeatCapacity()|, which just handle the second case

    iNumArgs = length(varargin); % |iNumArgs == nargin - 1|!?

    % Handle two variants of calling this method: With an object, where the
    % necessary data can be retrieved from, or the data itself.
    if iNumArgs == 1 %nargin < 3
        % First case: Just a phase or flow object is provided.
        %TODO: Delete this part and put it into the corresponding classes
        %      instead (the matter table should not know about other objects).

        oMatterRef = varargin{1};

        % Get data from object: The state of matter (gas, liquid, solid)
        % and |afMasses| array, depending on the object type.
        if isa(oMatterRef, 'matter.phase')
            sMatterState = oMatterRef.sType;
            afMasses     = oMatterRef.afMass;
        elseif isa(oMatterRef, 'matter.procs.p2p')
            sMatterState = oMatterRef.getInEXME().oPhase.sType;
            afMasses     = oMatterRef.arPartialMass * oMatterRef.fFlowRate;
            % Because the flow rate can be negative, we transform the
            % afMasses array into absolutes here. Otherwise the calculated
            % heat capacity will be zero.
            afMasses = abs(afMasses);
        elseif isa(oMatterRef, 'matter.flow')
            sMatterState = oMatterRef.oBranch.getInEXME().oPhase.sType;
            afMasses     = oMatterRef.arPartialMass * oMatterRef.fFlowRate;
            % Because the flow rate can be negative, we transform the
            % afMasses array into absolutes here. Otherwise the calculated
            % heat capacity will be zero.
            afMasses = abs(afMasses);

        else
            this.throw('calculateHeatCapacity', 'Single parameter must be of type |matter.phase| or |matter.flow|.');
        end

        % Get data from object: Temperature and pressure.
        fTemperature = oMatterRef.fTemperature;
        fPressure    = oMatterRef.fPressure;

        if isempty(fPressure) || isnan(fPressure)
            fPressure = this.Standard.Pressure; % std pressure (Pa)
        end

        if isempty(fTemperature) || isnan(fTemperature)
            fTemperature = this.Standard.Temperature; % std temperature (K)
        end
    else
        % Second case: Data is provided directly.

        sMatterState  = varargin{1}; % solid, liquid, or gas
        afMasses      = varargin{2}; % mass per substance (array)
        
        % Get temperature and pressure from arguments, otherwise use
        % standard data.
        if iNumArgs > 2
            fTemperature = varargin{3};
        else
            fTemperature = this.Standard.Temperature; % std temperature (K)
        end
        
        if iNumArgs == 4
            fPressure    = varargin{4};
        else
            fPressure    = this.Standard.Pressure;    % std pressure (Pa)
        end
        
        if iNumArgs > 4
            fDensity   = varargin{4};
        end
    end

    % If no mass is given, the heat capacity is also zero.
    if sum(afMasses) == 0
        fSpeedOfSound = 0;
        return; % Return early.
    end
    
    arPartialMass = afMasses./sum(afMasses);
    
    % Make sure there is no NaN in the mass vector.
    assert(~any(isnan(arPartialMass)), 'Invalid entries in mass vector.');

    
    % Find substances with a mass bigger than zero and count the results.
    % This helps in getting only the needed data from the matter table.
    aiIndices   = find(arPartialMass > 0);
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
        tParameters.sPhaseType = sMatterState;
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

    % Make sure there is no NaN in the specific heat capacity vector.
    assert(~any(isnan(afSpeedOfSound)), 'Invalid entries in specific heat capacity vector.');

    %DEBUG
    assert(isequal(size(afSpeedOfSound), size(arPartialMass(aiIndices)')), 'Vectors must be of same length but one transposed.');

    % Multiply the specific heat capacities with the mass fractions. The
    % result of the matrix multiplication is the specific heat capacity of
    % the mixture.
    fSpeedOfSound = sum(arPartialMass .* afSpeedOfSound);

    % Make sure the heat capacity value is valid.
    assert(~isnan(fSpeedOfSound) && fSpeedOfSound >= 0, ...
        'Invalid speed of sound: %f', fSpeedOfSound);

    % "Most physical systems exhibit a positive heat capacity. However,
    % there are some systems for which the heat capacity is negative. These
    % are inhomogeneous systems which do not meet the strict definition of
    % thermodynamic equilibrium.
    % A more extreme version of this occurs with black holes. According to
    % black hole thermodynamics, the more mass and energy a black hole
    % absorbs, the colder it becomes. In contrast, if it is a net emitter
    % of energy, through Hawking radiation, it will become hotter and
    % hotter until it boils away."
    %     -- http://en.wikipedia.org/wiki/Heat_capacity 
    %        (Retrieved: 2015-05-27 23:48 CEST)
end
