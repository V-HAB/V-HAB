function [ afPartialPressures ] = calculatePartialPressures(this, varargin)
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
        sPhase = varargin{1}.sType;
        afMass = varargin{1}.afMass;
        
    elseif bIsaMatterFlow
        %afPartialPressures = varargin{1}.getPartialPressures();
        afPartialPressures = varargin{1}.afPartialPressure;
        return;
    end
    
    fPressure = varargin{1}.fPressure;
    
    if isempty(fPressure) || isnan(fPressure)
        fPressure = this.Standard.Pressure; % std pressure (Pa)
    end       
    
    if fPressure == 0
        afPartialPressures = zeros(1,length(afMass));
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
    
    % If pressure is given use it, otherwise use standard pressure
    if nargin > 2
        fPressure = varargin{3};
    else
        fPressure = this.Standard.Pressure;       % std pressure (Pa)
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

end


