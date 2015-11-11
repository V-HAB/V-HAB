function fLambda = calculateThermalConductivity(this, varargin)
%CALCULATECONDUCTIVITY Calculates the conductivity of the matter in a phase or flow
%   Calculates the conductivity of the matter inside a phase or the matter
%   flowing through the flow object. This is done by adding the single
%   substance conductivity at the current temperature and pressure and
%   weighing them with their mass fraction. Can use either a phase object
%   as input parameter or the phase type (sType) and the masses array
%   (afMass). Optionally temperature and pressure can be passed as third
%   and fourth parameters, respectively.
%
% calculateConductivity returns
%  fLambda - conductivity of matter in current state in W/mK
% Case one - just a phase object provided
if length(varargin) == 1
    if ~isa(varargin{1}, 'matter.phase') && ~isa(varargin{1}, 'matter.flow')
        this.throw('calculateConductivity', 'If only one param provided, has to be a matter.phase or matter.flow (derivative)');
    end
    
    % Getting the phase type (gas, liquid, solid) depending on the object
    % type
    if isa(varargin{1}, 'matter.phase')
        sPhase = varargin{1}.sType;
    elseif isa(varargin{1}, 'matter.flow')
        sPhase = varargin{1}.oBranch.getInEXME().oPhase.sType;
    end
    
    fTemperature = varargin{1}.fTemperature;
    fPressure    = varargin{1}.fPressure;
    arPartialMass = varargin{1}.arPartialMass;
    
    % in no mass given also no conductivity possible
    if sum(arPartialMass) == 0;
        fLambda = 0;
        return;
    end
else
    sPhase = varargin{1};
    afMass = varargin{2};
    
    arPartialMass = afMass ./ sum(afMass);
    
    % if no mass given also no conductivity possible
    if sum(afMass) == 0 || sum(isnan(afMass)) == length(afMass)
        fLambda = 0;
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
afLambda = zeros(1, length(aiIndices));

for iI = 1:length(aiIndices)
    tParameters = struct();
    tParameters.sSubstance = this.csSubstances{aiIndices(iI)};
    tParameters.sProperty = 'Thermal Conductivity';
    tParameters.sFirstDepName = 'Temperature';
    tParameters.fFirstDepValue = fTemperature;
    tParameters.sPhaseType = sPhase;
    tParameters.sSecondDepName = 'Pressure';
    tParameters.fSecondDepValue = fPressure;
    tParameters.bUseIsobaricData = false;
    
    afLambda(iI) = this.findProperty(tParameters);
end

fLambda = sum(afLambda .* arPartialMass(aiIndices));

% If none of the substances has a valid dynamic viscosity an error is thrown.
if fLambda < 0 || isnan(fLambda)
    keyboard();
    this.throw('calculateConductivity','Error in conductivity calculation!');
    
end

end

