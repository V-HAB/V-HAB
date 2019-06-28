function fPressure = calculatePressure(this, varargin) %sMatterState, afMasses, fTemperature, fPressure)
% TO DO: Add description, also give partial pressures as output?

iNumArgs = length(varargin); % |iNumArgs == nargin - 1|!?

% Handle two variants of calling this method: With an object, where the
% necessary data can be retrieved from, or the data itself.
if iNumArgs == 1 %nargin < 3
    % First case: Just a phase or flow object is provided.
    oMatterRef = varargin{1};
    
    % Get data from object: The state of matter (gas, liquid, solid)
    % and |afMasses| array, depending on the object type.
    if isa(oMatterRef, 'matter.phase')
        
        sMatterState = oMatterRef.sType;
        arPartialMass = oMatterRef.arPartialMass;
        oPhase = oMatterRef;
        afMass = oPhase.afMass;
        fCurrentPressure = oPhase.fPressure;
        
    elseif isa(oMatterRef, 'matter.procs.p2p')
        sMatterState = oMatterRef.sType;
        arPartialMass = oMatterRef.arPartialMass;
        oPhase = oMatterRef.getInEXME().oPhase;
        afMass = oPhase.afMass;
        fCurrentPressure = oPhase.fPressure;
        
    elseif isa(oMatterRef, 'matter.flow')
        sMatterState = oMatterRef.oBranch.getInEXME().oPhase.sType;
        arPartialMass = oMatterRef.arPartialMass;
        if oMatterRef.fFlowRate >= 0
            oPhase = oMatterRef.oBranch.coExmes{1,1}.oPhase;
        else
            oPhase = oMatterRef.oBranch.coExmes{2,1}.oPhase;
        end
        afMass = oPhase.afMass;
        fCurrentPressure = oPhase.fPressure;
    else
        this.throw('calculateHeatCapacity', 'Single parameter must be of type |matter.phase| or |matter.flow|.');
    end
    
    % Get data from object: Temperature and pressure.
    fTemperature = oMatterRef.fTemperature;
    fDensity = oMatterRef.fDensity;
    if isempty(fTemperature) || isnan(fTemperature)
        fTemperature = this.Standard.Temperature; % std temperature (K)
    end
    
    bUseIsobaricData   = true;
    
else
    % Second case: Data is provided directly.
    
    sMatterState  = varargin{1}; % solid, liquid, or gas
    afMass      = varargin{2}; % mass per substance (array)
    arPartialMass = afMass./(sum(afMass));
    
    % Get temperature and pressure from arguments, otherwise use
    % standard data.
    if iNumArgs > 2
        fTemperature = varargin{3};
    else
        % Standard temperature in [K]
        fTemperature = this.Standard.Temperature;
    end
    
    if iNumArgs > 3
        fDensity    = varargin{4};
    else
        % Standard pressure in [Pa]
        fDensity = this.Standard.Density;
    end
    if iNumArgs > 4
        fCurrentPressure    = varargin{5};
    else
        % Standard pressure in [Pa]
        fCurrentPressure = this.Standard.Pressure;
    end
    
    if iNumArgs > 5
        bUseIsobaricData   = varargin{6};
    else
        bUseIsobaricData   = true;
    end
    
    % If there is no temperature given, but pressure, set temperature to
    % standard temperature in [K]
    if isempty(fTemperature); fTemperature = this.Standard.Temperature; end
end

% If no mass is given the heat capacity will be zero, so no need to do the
% rest of the calculation.
if sum(arPartialMass) == 0
    fPressure = 0;
    return;
end

% Find substances with a mass bigger than zero and count the results.
% This helps in getting only the needed data from the matter table.
aiIndices   = find(arPartialMass > 0);

% TO DO: write determinePhase function to work with the density as well as
% the pressure and replace the fCurrentPressure property in this function
% with the density

csPhase = {'solid';'liquid';'gas';'supercritical'};

% One of the most important parts to correctly calculate the pressure is to
% use the correct partial densities.
switch sMatterState
    case 'solid'
        
        error('In V-HAB solids do not have a pressure')
    case 'liquid'
        % TO DO: replace with correct mixture calculations
        afPartialDensity = arPartialMass.*fDensity;
        aiPhase = ones(1,this.iSubstances) .* 2;

    case 'gas'
        % gases behave as if each component of the gas mixture is alone in
        % the total gas volume and therefore the partial density is the
        % mass ratio times the total density.
        afPartialDensity = arPartialMass.*fDensity;
        aiPhase = ones(1,this.iSubstances) .* 3;
            
    case 'mixture'
        afPartialDensity = arPartialMass.*fDensity;
        aiPhase = this.determinePhase(afMass, fTemperature, ones(1,this.iSubstances) .* fCurrentPressure);
end

iNumIndices = length(aiIndices);

% Initialize a new array filled with zeros. Then iterate through all
% indexed substances and get their specific heat capacity.
afPP = zeros(iNumIndices, 1);

for iI = 1:iNumIndices
    % Creating the input struct for the findProperty() method
    tParameters = struct();
    tParameters.sSubstance = this.csSubstances{aiIndices(iI)};
    if this.ttxMatter.(tParameters.sSubstance).bIndividualFile
        tParameters.sProperty = 'Pressure';
        tParameters.sFirstDepName = 'Temperature';
        tParameters.fFirstDepValue = fTemperature;
        tParameters.sPhaseType = csPhase{aiPhase(aiIndices(iI))};
        tParameters.sSecondDepName = 'Density';
        tParameters.fSecondDepValue = afPartialDensity(aiIndices(iI));
        tParameters.bUseIsobaricData = bUseIsobaricData;

        % Now we can call the findProperty() method.
        afPP(iI) = this.findProperty(tParameters);
    else
        afPP(iI) = this.Standard.Pressure;
    end
end


% Make sure there is no NaN in the specific heat capacity vector.
if any(isnan(afPP))
   error('Invalid entries in partial pressure vector.');
end

% Make sure no negative partial pressure were calculated
if any(afPP < 0)
    error('Invalid entries in partial pressure vector.');
end

%DEBUG
if ~isequal(size(afPP), size(arPartialMass(aiIndices)'))
    error('Vectors must be of same length but one transposed.');
end

% Multiply the specific heat capacities with the mass fractions. The
% result of the matrix multiplication is the specific heat capacity of
% the mixture.
fPressure = sum(afPP);

% Make sure the heat capacity value is valid.
if isnan(fPressure) && fTemperature >= 0
    error('Invalid pressure: %f', fTemperature);
end

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
