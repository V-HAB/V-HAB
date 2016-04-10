function fDensity = calculateDensity(this, varargin)
%CALCULATEDENSITY Calculates the density of the matter in a phase or flow
%   Calculates the density of the matter inside a phase or the matter
%   flowing through the flow object. This is done by adding the single
%   substance densities at the current temperature and pressure and
%   weighing them with their mass fraction. Can use either a phase object
%   as input parameter or the phase type (sType) and the masses array
%   (afMass). Optionally temperature and partial pressures can be passed as
%   third and fourth parameters, respectively.
%
% calculateDensity returns
%  fDensitiy - density of matter in current state in kg/m^3
% Case one - just a phase or flow object provided
if length(varargin) == 1
    if ~isa(varargin{1}, 'matter.phase') && ~isa(varargin{1}, 'matter.flow')
        this.throw('calculateDensity', 'If only one param provided, has to be a matter.phase or matter.flow (derivative)');
    end
    
    % initialize attributes from input object
    % Getting the phase type (gas, liquid, solid) depending on the object
    % type
    if isa(varargin{1}, 'matter.phase')
        sMatterState = varargin{1}.sType;         
    elseif isa(varargin{1}, 'matter.flow')
        sMatterState = varargin{1}.oBranch.getInEXME().oPhase.sType;
    end
    
    fTemperature = varargin{1}.fTemperature;
    
    if any(strcmp(sMatterState, {'gas', 'liquid'}))
        % matter.flow - can we use the ideal gas law?
        %TODO matter.table.setUseSimpleEquationsIfSufficientlyValid()!
        if varargin{1}.fPressure < 5e5
            fDensity = (varargin{1}.fPressure * varargin{1}.fMolarMass) / (matter.table.Const.fUniversalGas * varargin{1}.fTemperature);
            return;
        end
        
        
        afPartialPressures = this.calculatePartialPressures(varargin{1});
    else
        if isa(varargin{1}, 'matter.phase')
            fDensity = varargin{1}.fMass / varargin{1}.fVolume;
            return;
        else
            this.throw('calculateDensity', 'The calculation of solid flow densities has not yet been implemented.')
        end
    end
    
    if isempty(fTemperature) || isnan(fTemperature)
        fTemperature = this.Standard.Temperature; % std temperature (K)
    end
    
    arPartialMass = varargin{1}.arPartialMass;
    
    % in no mass given also no density possible
    if sum(arPartialMass) == 0;
        fDensity = 0;
        return;
    end
    
else
    sMatterState = varargin{1};
    afMass       = varargin{2};
    
    arPartialMass = afMass ./ sum(afMass);
    
    % if no mass given also no density possible
    if sum(afMass) == 0 || sum(isnan(afMass)) == length(afMass)
        fDensity = 0;
        return;
    end
    
    % if additional temperature and pressure given
    if nargin > 3
        fTemperature = varargin{3};
    else
        fTemperature = this.Standard.Temperature; % std temperature (K)
    end
    
    % Assume if vector with length > 1 -> partials, else total pressure
    if nargin > 4 && ~isempty(varargin{4}) && isvector(varargin{4}) && length(varargin{4}) > 1
        afPartialPressures = varargin{4};
    else
        fPressure = this.Standard.Pressure;
        
        if nargin > 4 && ~isempty(varargin{4}) && isvector(varargin{4}) && isscalar(varargin{4})
            fPressure = varargin{4};
        end
        
        if any(strcmp(sMatterState, {'gas', 'liquid'}))
            afPartialPressures = this.calculatePartialPressures(sMatterState, afMass, fPressure);
        else
            afPartialPressures = ones(1, this.iSubstances) * this.Standard.Pressure;
        end
    end
    
end

% Find the indices of all substances that are in the flow
aiIndices = find(arPartialMass > 0);

% Go through all substances that have mass and get the density of each. 
afRho = zeros(1, length(aiIndices));

for iI = 1:length(aiIndices)
    tParameters = struct();
    tParameters.sSubstance = this.csSubstances{aiIndices(iI)};
    tParameters.sProperty = 'Density';
    tParameters.sFirstDepName = 'Temperature';
    tParameters.fFirstDepValue = fTemperature;
    tParameters.sPhaseType = sMatterState;
    tParameters.sSecondDepName = 'Pressure';
    tParameters.fSecondDepValue = afPartialPressures(aiIndices(iI));
    
    %TODO should that just be true for e.g. pipe flows?
    tParameters.bUseIsobaricData = true;
    
    afRho(iI) = this.findProperty(tParameters);
end

% Sum up the densities multiplied by the partial masses to get the overall density.
fDensity = sum(afRho .* arPartialMass(aiIndices));

% If none of the substances has a valid density an error is thrown.
if fDensity < 0 || isnan(fDensity)
    this.throw('calculateDensity','Error in Density calculation!');
end

end

