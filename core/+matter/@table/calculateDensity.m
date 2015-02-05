function fDensity = calculateDensity(this, varargin)
%CALCULATEDENSITY Calculates the density of the matter in a phase or flow
%   Calculates the density of the matter inside a phase or the matter
%   flowing through the flow object. This is done by adding the single
%   substance densities at the current temperature and pressure and
%   weighing them with their mass fraction. Can use either a phase object
%   as input parameter or the phase type (sType) and the masses array
%   (afMass). Optionally temperature and pressure can be passed as third
%   and fourth parameters, respectively.
%
% calculateDensity returns
%  fDensitiy - density of matter in current state in kg/m^3
% Case one - just a phase object provided
if length(varargin) == 1
    if ~isa(varargin{1}, 'matter.phase') && ~isa(varargin{1}, 'matter.flow')
        this.throw('calculateDensity', 'If only one param provided, has to be a matter.phase or matter.flow (derivative)');
    end
    
    % Getting the phase type (gas, liquid, solid) depending on the object
    % type
    if isa(varargin{1}, 'matter.phase')
        sPhase = varargin{1}.sType;
    elseif isa(varargin{1}, 'matter.flow')
        sPhase = varargin{1}.oBranch.getInEXME().oPhase.sType;
    end
    
    fTemperature = varargin{1}.fTemp;
    fPressure    = varargin{1}.fPressure;
    arPartialMass = varargin{1}.arPartialMass;
    
    % in no mass given also no density possible
    if sum(arPartialMass) == 0;
        fDensity = 0;
        return;
    end
else
    sPhase = varargin{1};
    afMass = varargin{2};
    
    arPartialMass = afMass ./ sum(afMass);
    
    % if no mass given also no density possible
    if sum(afMass) == 0 || sum(isnan(afMass)) == length(afMass)
        fDensity = 0;
        return;
    end
    
    % if additional temperature and pressure given
    if nargin > 2
        fTemperature = varargin{3};
        fPressure    = varargin{4};
    end
end

if isempty(fPressure);    fPressure    = this.Standard.Pressure;    end; % std pressure (Pa)
if isempty(fTemperature); fTemperature = this.Standard.Temperature; end; % std temperature (K)

% Find the indices of all substances that are in the flow
aiIndices = find(arPartialMass > 0);
afRho = zeros(1, length(aiIndices));

for iI = 1:length(aiIndices)
    afRho(iI) = this.findProperty(this.csSubstances{aiIndices(iI)}, 'Density', 'Temperature', fTemperature, 'Pressure', fPressure, sPhase);
end

fDensity = sum(afRho .* arPartialMass(aiIndices));

% If none of the substances has a valid density an error is thrown.
if fDensity < 0 || isnan(fDensity)
    this.throw('calculateDensity','Error in Density calculation!');
end

end

