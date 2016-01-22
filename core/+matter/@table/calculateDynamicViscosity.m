function fEta = calculateDynamicViscosity(this, varargin)
%CALCULATEDYNAMICVISCOSITY Calculates the dynamic viscosity of the matter in a phase or flow
%   Calculates the dynamic viscosity of the matter inside a phase or the matter
%   flowing through the flow object. This is done by adding the single
%   substance viscosities at the current temperature and pressure and
%   weighing them with their mass fraction. Can use either a phase object
%   as input parameter or the phase type (sType) and the masses array
%   (afMass). Optionally temperature and pressure can be passed as third
%   and fourth parameters, respectively.
%
%   Examples: fEta = calculateDynamicViscosity(oFlow);
%             fEta = calculateDynamicViscosity(oPhase);
%             fEta = calculateDynamicViscosity(sType, afMass, fTemperature, afPartialPressures);
%
% calculateDynamicViscosity returns
%  fEta - dynamic viscosity of matter in current state in kg/ms
% Case one - just a phase object provided

iNumArgs = length(varargin);

if iNumArgs == 1 %nargin < 3
    % First case: Just a phase or flow object is provided.
    %TODO: Delete this part and put it into the corresponding classes
    %      instead (the matter table should not know about other objects).

    oMatterRef = varargin{1};

    % Get data from object: The state of matter (gas, liquid, solid)
    % and |afMasses| array, depending on the object type.
    if isa(oMatterRef, 'matter.phase')
        if oMatterRef.bAdsorber
            sMatterState = 'all';
        else
            sMatterState = oMatterRef.sType;
        end
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
                    afPP = this.calculatePartialPressures(oMatterRef);
                catch
                    afPP = ones(1,this.iSubstances) .* this.Standard.Pressure;
                end
            end
            
        elseif strcmp(oMatterRef.getInEXME().oPhase.sType, 'solid')
            % Solids do not have a partial pressure or even a pressure,
            % therefore the afPP variable which is used to calculate the
            % matter properties is set to the standard pressure to allow
            % the matter table to calculate the values for gases that are
            % adsorbed into solids
            afPP = ones(1,this.iSubstances) .* this.Standard.Pressure;
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
        % Usually within V-HAB the matter state liquid, solid or gas is
        % fix within V-HAB the only exception from this rule is a p2p
        % processor that moves mass from one matter state to another.
        % Since the state cannot be specified for sure in this case the
        % calculation will use all available matter data
        sMatterState = 'all';
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
                    afPP = this.calculatePartialPressures(oMatterRef.getInEXME().oPhase);
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
                        afPP = this.calculatePartialPressures(oMatterRef.oBranch.coExmes{1,1}.oPhase);
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

else
    % Second case: Data is provided directly.
    
    % State can be solid, liquid, or gas
    sMatterState  = varargin{1}; 
    % Mass per substance (array)
    afMasses      = varargin{2};
    % Calculation of partial masses
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
    
    % If there is no temperature given, but pressure, set temperature to
    % standard temperature in [K]
    if isempty(fTemperature); fTemperature = this.Standard.Temperature; end;
end

% If no mass is given the viscosity will be zero, so no need to do the rest
% of the calculation.
if sum(arPartialMass) == 0;
    fEta = 0;
    return;
end

% Find the indices of all substances that are in the flow
aiIndices = find(arPartialMass > 0);
afEta = zeros(1, length(aiIndices));

% Go through all substances that have mass and get the viscosity of each. 
for iI = 1:length(aiIndices)
    % Generating the paramter struct that findProperty() requires.
    tParameters = struct();
    tParameters.sSubstance = this.csSubstances{aiIndices(iI)};
    tParameters.sProperty = 'Dynamic Viscosity';
    tParameters.sFirstDepName = 'Temperature';
    tParameters.fFirstDepValue = fTemperature;
    
    %TODO Add an explanation of what is being done in this if-condition and
    %     why it is being done. 
    if this.ttxMatter.(tParameters.sSubstance).bIndividualFile
        tParameters.sPhaseType = sMatterState;
    else
        if iNumArgs == 1
            tParameters.sPhaseType = oMatterRef.sType;
        else
            tParameters.sPhaseType = varargin{1};
        end
    end
    
    tParameters.sSecondDepName = 'Pressure';
    tParameters.fSecondDepValue = afPP(aiIndices(iI));
    tParameters.bUseIsobaricData = true;
    
    % Now we can call the findProperty() method.
    afEta(iI) = this.findProperty(tParameters);
end

fEta = sum(afEta .* arPartialMass(aiIndices));

% If none of the substances has a valid dynamic viscosity an error is thrown.
if fEta < 0 || isnan(fEta)
    keyboard();
    this.throw('calculateDynamicViscosity','Error in dynamic viscosity calculation!');
    
end

end

