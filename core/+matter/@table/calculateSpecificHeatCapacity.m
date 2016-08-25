function fSpecificHeatCapacity = calculateSpecificHeatCapacity(this, varargin) %sMatterState, afMasses, fTemperature, fPressure)
%CALCULATESPECIFICHEATCAPACITY Calculate the specific heat capacity of a mixture
%    Calculates the specific heat capacity by adding the single substance
%    capacities weighted with their mass fraction. Can use either a phase
%    object as input parameter, or the phase type (sType) and the masses
%    array (afMasses). Optionally, temperature and pressure can be passed
%    as third and fourth parameters,
%    respectively.
%
%   Examples: fSpecificHeatCapacity = calculateSpecificHeatCapacity(oFlow);
%             fSpecificHeatCapacity = calculateSpecificHeatCapacity(oPhase);
%             fSpecificHeatCapacity = calculateSpecificHeatCapacity(sType, afMass, fTemperature, afPartialPressures);
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
        arPartialMass = oMatterRef.arPartialMass;
        
        
        % From "Berechnung von Phasengleichgewichten" Ralf Dohrn, page 147:
        % "Wie bei einem idealen Gas finden in einer Mischung idealer Gase
        % keine Wechselwirkungen zwischen den Molekülen statt. Jede
        % Komponente in der Mischung verhält sich so, als nähme sie als
        % ideales Gas allein das gesamte Volumen V bei der Temperatur T
        % ein; sie übt den Partialdruck Pi = YiP aus, der sich in diesem
        % Fall nach dem idealen Gasgesetz berechnet."
        if strcmp(sMatterState, 'gas')
            afPP = oMatterRef.afPP;
            if isempty(afPP)
                try
                    [ afPP, ~ ] = this.calculatePartialPressures(oMatterRef);
                catch
                    afPP = ones(1,this.iSubstances) .* this.Standard.Pressure;
                end
            end
        elseif strcmp(oMatterRef.sType, 'solid')
            % Solids do not have a partial pressure or even a pressure,
            % therefore the afPP variable which is used to calculate the
            % matter properties is set to the standard pressure to allow
            % the matter table to calculate the values for gases that are
            % adsorbed into solids
            afPP = ones(1,this.iSubstances) .* this.Standard.Pressure;
        elseif strcmp(oMatterRef.sType, 'mixture')
            % for mixtures the actual matter type is set by the user and
            % also differs for each substance. The partial pressure for a gas
            % mixture phase (e.g. gas that contains solids) has to be
            % calculated the same way as for a gas phase except for the
            % substances that are solid
            
            if isempty(oMatterRef.sPhaseType)
                afPP = ones(1,this.iSubstances) .* this.Standard.Pressure;
                aiPhase = this.determinePhase(oMatterRef.afMass, oMatterRef.fTemperature, this.Standard.Pressure);
            else
                aiPhase = this.determinePhase(oMatterRef.afMass, oMatterRef.fTemperature, oMatterRef.fPressure);
                if strcmp(oMatterRef.sPhaseType, 'gas')
                    afMassGas = zeros(1,this.iSubstances);
                    afMassGas(aiPhase == 3) = oMatterRef.afMass(aiPhase == 3);
                    afPP = this.calculatePartialPressures('gas',afMassGas, oMatterRef.fPressure);
                    afPP(aiPhase ~= 3) = oMatterRef.fPressure;
                else
                    afPP = ones(1,this.iSubstances) .* oMatterRef.fPressure;
                end
            end
            
        else
            % The problem is that liquids (and solids) in V-HAB do not have
            % a partial pressure variable and they cannot be view as ideal
            % gases since the assumption that the molecule do not interact
            % with each other does not hold true for liquids. For example
            % if you have a liquid mixture of 50% water and 50% ethanol
            % then you cannot just take half the total pressure/density for
            % either substance to calculate any matter properties. For
            % example if you'd take a partial density the density of water
            % would be around 500 kg/m² and the matter table would tell you
            % that water is not liquid at that density. Instead for liquids
            % the overall pressure is used as partial pressure for every
            % substance
            try
                afPP = ones(1,this.iSubstances) .* oMatterRef.fPressure;
            catch
                afPP = ones(1,this.iSubstances) .* this.Standard.Pressure;
            end
        end
        
    elseif isa(oMatterRef, 'matter.procs.p2p')
        sMatterState = oMatterRef.sType;
        arPartialMass = oMatterRef.arPartialMass;
        
        % From "Berechnung von Phasengleichgewichten" Ralf Dohrn, page 147:
        % "Wie bei einem idealen Gas finden in einer Mischung idealer Gase
        % keine Wechselwirkungen zwischen den Molekülen statt. Jede
        % Komponente in der Mischung verhält sich so, als nähme sie als
        % ideales Gas allein das gesamte Volumen V bei der Temperatur T
        % ein; sie übt den Partialdruck Pi = YiP aus, der sich in diesem
        % Fall nach dem idealen Gasgesetz berechnet."
        if strcmp(oMatterRef.getInEXME().oPhase.sType, 'gas')
            afPP = oMatterRef.getInEXME().oPhase.afPP;
            if isempty(afPP)
                try
                    [ afPP, ~ ] = this.calculatePartialPressures(oMatterRef.getInEXME().oPhase);
                catch
                    afPP = ones(1,this.iSubstances) .* this.Standard.Pressure;
                end
            end
        else
            try
                if ~isnan(oMatterRef.getInEXME().oPhase.fPressure)
                    afPP = ones(1,this.iSubstances) .* oMatterRef.getInEXME().oPhase.fPressure;
                else
                    afPP = ones(1,this.iSubstances) .* this.Standard.Pressure;
                end
            catch
                afPP = ones(1,this.iSubstances) .* this.Standard.Pressure;
            end
        end
    elseif isa(oMatterRef, 'matter.flow')
        sMatterState = oMatterRef.oBranch.getInEXME().oPhase.sType;
        arPartialMass = oMatterRef.arPartialMass;
        
        % From "Berechnung von Phasengleichgewichten" Ralf Dohrn, page 147:
        % "Wie bei einem idealen Gas finden in einer Mischung idealer Gase
        % keine Wechselwirkungen zwischen den Molekülen statt. Jede
        % Komponente in der Mischung verhält sich so, als nähme sie als
        % ideales Gas allein das gesamte Volumen V bei der Temperatur T
        % ein; sie übt den Partialdruck Pi = YiP aus, der sich in diesem
        % Fall nach dem idealen Gasgesetz berechnet."
        if strcmp(sMatterState, 'gas')
            if oMatterRef.fFlowRate >= 0
                afPP = oMatterRef.oBranch.coExmes{1,1}.oPhase.afPP;
                if isempty(afPP)
                    try
                        [ afPP, ~ ] = this.calculatePartialPressures(oMatterRef.oBranch.coExmes{1,1}.oPhase);
                    catch
                        afPP = ones(1,this.iSubstances) .* this.Standard.Pressure;
                    end
                end
            else
                afPP = oMatterRef.oBranch.coExmes{1,2}.oPhase.afPP;
            end
        else
            try
                if oMatterRef.fFlowRate >= 0
                    afPP = ones(1,this.iSubstances) .* oMatterRef.oBranch.coExmes{1,1}.oPhase.fPressure;
                else
                    afPP = ones(1,this.iSubstances) .* oMatterRef.oBranch.coExmes{1,2}.oPhase.fPressure;
                end
            catch
                afPP = ones(1,this.iSubstances) .* this.Standard.Pressure;
            end
        end
        
    else
        this.throw('calculateHeatCapacity', 'Single parameter must be of type |matter.phase| or |matter.flow|.');
    end
    
    % Get data from object: Temperature and pressure.
    fTemperature = oMatterRef.fTemperature;
    
    if isempty(fTemperature) || isnan(fTemperature)
        fTemperature = this.Standard.Temperature; % std temperature (K)
    end
    
    bUseIsobaricData   = true;
    
else
    % Second case: Data is provided directly.
    
    sMatterState  = varargin{1}; % solid, liquid, or gas
    afMasses      = varargin{2}; % mass per substance (array)
    arPartialMass = afMasses./(sum(afMasses));
    
    % Get temperature and pressure from arguments, otherwise use
    % standard data.
    if iNumArgs > 2
        fTemperature = varargin{3};
    else
        % Standard temperature in [K]
        fTemperature = this.Standard.Temperature;
    end
    
    if iNumArgs > 3
        afPP    = varargin{4};
    else
        % Standard pressure in [Pa]
        afPP = ones(this.iSubstances) .* this.Standard.Pressure;
    end
    
    if iNumArgs > 4
        bUseIsobaricData   = varargin{5};
    else
        bUseIsobaricData   = true;
    end
    
    % If there is no temperature given, but pressure, set temperature to
    % standard temperature in [K]
    if isempty(fTemperature); fTemperature = this.Standard.Temperature; end;
end

% If no mass is given the heat capacity will be zero, so no need to do the
% rest of the calculation.
if sum(arPartialMass) == 0
    fSpecificHeatCapacity = 0;
    return;
end

% Make sure there is no NaN in the mass vector.
assert(~any(isnan(arPartialMass)), 'Invalid entries in mass vector.');

% Find substances with a mass bigger than zero and count the results.
% This helps in getting only the needed data from the matter table.
aiIndices   = find(arPartialMass > 0);
iNumIndices = length(aiIndices);

% Initialize a new array filled with zeros. Then iterate through all
% indexed substances and get their specific heat capacity.
afCp = zeros(iNumIndices, 1);

csPhase = {'solid';'liquid';'gas';'supercritical'};
tiP2N.solid = 1;
tiP2N.liquid = 2;
tiP2N.gas = 3;
tiP2N.supercritical = 4;
if ~strcmp(sMatterState, 'mixture')
    aiPhase = tiP2N.(sMatterState)*ones(1,this.iSubstances);
end

for iI = 1:iNumIndices
    % Creating the input struct for the findProperty() method
    tParameters = struct();
    tParameters.sSubstance = this.csSubstances{aiIndices(iI)};
    tParameters.sProperty = 'Heat Capacity';
    tParameters.sFirstDepName = 'Temperature';
    tParameters.fFirstDepValue = fTemperature;
    tParameters.sPhaseType = csPhase{aiPhase(aiIndices(iI))};
    tParameters.sSecondDepName = 'Pressure';
    tParameters.fSecondDepValue = afPP(aiIndices(iI));
    tParameters.bUseIsobaricData = bUseIsobaricData;
    
    % Now we can call the findProperty() method.
    afCp(iI) = this.findProperty(tParameters);
end

% Make sure there is no NaN in the specific heat capacity vector.
assert(~any(isnan(afCp)), 'Invalid entries in specific heat capacity vector.');

%DEBUG
assert(isequal(size(afCp), size(arPartialMass(aiIndices)')), 'Vectors must be of same length but one transposed.');

% Multiply the specific heat capacities with the mass fractions. The
% result of the matrix multiplication is the specific heat capacity of
% the mixture.
fSpecificHeatCapacity = arPartialMass(aiIndices) * afCp;

% Make sure the heat capacity value is valid.
assert(~isnan(fSpecificHeatCapacity) && fSpecificHeatCapacity >= 0, ...
    'Invalid heat capacity: %f', fSpecificHeatCapacity);

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
