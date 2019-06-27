function [ afPartialPressures, afPartsPerMillion ] = calculatePartialPressures(this, varargin)
%CALCULATEPARTIALPRESSURES Calculates partial pressures of gas phases and
%flows
%   Calculates the partial pressures for all substances in a gas phase, gas
%   flow or a body of matter in a gaseous state. Therfore input arguments
%   have to be either a matter.phase object, a matter.flow object or matter
%   data formatted and in the order shown below. The function then
%   calculates the amount of each substance in mols, calcualtes the molar
%   ratios for each substance by dividing by the total amount in mols and
%   finally calculates the partial pressures by multiplying the molar
%   rations with the total pressure of the phase or flow. 
%
%   calculatePartialPressures returns
%       afPartialPressures - An array of partial pressures for each
%       substance in Pa

% Case one - just a phase or flow object provided
if length(varargin) == 1
    bIsaMatterPhase = isa(varargin{1}, 'matter.phase');
    bIsaMatterFlow  = isa(varargin{1}, 'matter.flow');
    
    if ~bIsaMatterPhase && ~bIsaMatterFlow
        this.throw('calculatePartialPressures', 'If only one param provided, has to be a matter.phase or matter.flow (derivative)');
    end
    
    
    % initialize attributes from input object
    % Getting the phase type (gas, liquid, solid) depending on the object
    % type, also setting the afMass array. 
    if bIsaMatterPhase
        switch varargin{1}.sType
            case 'gas'
                sPhase = varargin{1}.sType;
                bIsMixture = false;
            case 'mixture'
                sPhase = varargin{1}.sPhaseType;
                bIsMixture = true;
        end
        
        afMass = varargin{1}.afMass;
        
    elseif bIsaMatterFlow
        % Calculating the number of mols for each species
        afMols = varargin{1}.arPartialMass ./ this.afMolarMass;
        % Calculating the total number of mols
        fGasAmount = sum(afMols);

        if fGasAmount == 0
            afPartialPressures = zeros(this.iSubstances,1);
            afPartsPerMillion = zeros(this.iSubstances,1);
            return
        end

        % Calculating the partial amount of each species by mols
        arFractions = afMols ./ fGasAmount;
        % Calculating the partial pressures by multiplying with the
        % total pressure in the phase
        afPartialPressures = arFractions .* varargin{1}.fPressure;
        
        afMass = varargin{1}.arPartialMass;
        try
            afPartsPerMillion = (afMass .* varargin{1}.fMolarMass) ./ (this.afMolarMass .* varargin{1}.fMass) * 1e6;
        catch
            afPartsPerMillion = (afMass .* this.calculateMolarMass(afMass)) ./ (this.afMolarMass .* sum(afMass)) * 1e6;
        end
        return;
    end
    
    fTemperature = varargin{1}.fTemperature;

    if bIsaMatterPhase
        fPressure = varargin{1}.fMass * varargin{1}.fMassToPressure;
    else
        fPressure = varargin{1}.fPressure;
    end
    
    if isempty(fPressure) || isnan(fPressure)
        fPressure = this.Standard.Pressure; % std pressure (Pa)
        fTemperature = this.Standard.Temperature; % std temperature (K)
    end       
    
    if fPressure == 0
        afPartialPressures = zeros(1,length(afMass));
        afPartsPerMillion  = zeros(1,length(afMass));
        return;
    end
    
else
    % Case two - matter data given. Needs to be in the following format and order:
    % phase type (string)
    % substance masses (array of floats)
    % pressure (float)
    
    % PhaseType (solid, liquid or gas)
    sPhase  = varargin{1};
    afMass  = varargin{2};
 	bIsMixture = false;
    
    % If pressure is given use it, otherwise use standard pressure
    if length(varargin) > 2
        fPressure = varargin{3};
    else
        fPressure = this.Standard.Pressure;       % std pressure (Pa)
    end
    
    % If temperature is given use it, otherwise use standard temperature
    if length(varargin) > 3
        fTemperature = varargin{4};
    else
        fTemperature = this.Standard.Temperature;  % std temperature (K)
    end
    
end

% Make sure we have matter in a gaseous state
if ~strcmp(sPhase, 'gas')
    this.throw('calculatePartialPressures', 'Partial pressures can only be calculated for gases!');
end

% Calculating the number of mols for each species
afMols = afMass ./ this.afMolarMass;

% Calculating the total number of mols
fGasAmount = sum(afMols);

% Calculating the partial amount of each species by mols
arFractions = afMols ./ fGasAmount;

% Calculating the partial pressures by multiplying with the
% total pressure in the phase
afPartialPressures = arFractions .* fPressure;

% for cases with partial pressures above the vapor pressure the
% partial pressure has to be limited to the vapor pressure
if bIsMixture
    aiPhases = this.determinePhase(afMass, fTemperature, afPartialPressures);
    miTwoPhaseIndices = find(mod(aiPhases,1));
    for iK = 1:length(miTwoPhaseIndices)
        afPartialPressures(miTwoPhaseIndices(iK)) = this.calculateVaporPressure(fTemperature, this.csSubstances{miTwoPhaseIndices(iK)});
    end
end

% Calculating the concentration in ppm 
try
    afPartsPerMillion = (afMass .* varargin{1}.fMolarMass) ./ (this.afMolarMass .* varargin{1}.fMass) * 1e6;
catch
    afPartsPerMillion = (afMass .* this.calculateMolarMass(afMass)) ./ (this.afMolarMass .* sum(afMass)) * 1e6;
end
end


