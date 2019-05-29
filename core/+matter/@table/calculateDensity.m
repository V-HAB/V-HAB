function fDensity = calculateDensity(this, varargin)
%CALCULATEDENSITY Calculates the density of the matter in a phase or flow
%   Calculates the density of the matter inside a phase or the matter
%   flowing through the flow object. This is done by adding the single
%   substance densities at the current temperature and pressure and
%   weighing them with their mass fraction. Can use either a phase object
%   (afMass). Optionally temperature and partial pressures can be passed as
%   as input parameter or the phase type (sType) and the masses array
%   third and fourth parameters, respectively.
%
%   Examples: fDensity = calculateDensity(oFlow);
%             fDensity = calculateDensity(oPhase);
%             fDensity = calculateDensity(sType, xfMass, fTemperature, afPartialPressures);
%
% calculateDensity returns
%  fDensitiy - density of matter in current state in kg/m^3

[fTemperature, arPartialMass, csPhase, aiPhase, aiIndices, afPartialPressures, tbReference, sMatterState] = getNecessaryParameters(this, varargin{:});

% Check Cases where we do not have to calculate the density
if sum(arPartialMass) == 0
    fDensity = 0;
    return
end

if tbReference.bFlow
    % If the flowrate is 0 use density of phase
    if varargin{1}.fFlowRate == 0
        oPhase = varargin{1}.oBranch.getInEXME().oPhase;
        fDensity = oPhase.fDensity;
        if isempty(fDensity)
            fDensity = oPhase.fMass / oPhase.fVolume;
        end
        return
    end
end

% If the matter state is gaseous and the pressure is not too high, 
% we can use the idal gas law. This makes the calculation a lot
% faster, since we can avoid the multiple findProperty() calls in
% this function.
if strcmp(sMatterState, 'gas')
    if varargin{1}.fPressure < 5e5
        fDensity = (varargin{1}.fPressure * varargin{1}.fMolarMass) / (this.Const.fUniversalGas * varargin{1}.fTemperature);
        % We already have what we want, so no need to execute the rest
        % of this function.
        return;
    end
end

% Go through all substances that have mass and get the density of each. 
afRho = zeros(1, length(aiIndices));

for iI = 1:length(aiIndices)
    % Generating the paramter struct that findProperty() requires.
    tParameters = struct();
    tParameters.sSubstance = this.csSubstances{aiIndices(iI)};
    tParameters.sProperty = 'Density';
    tParameters.sFirstDepName = 'Temperature';
    tParameters.fFirstDepValue = fTemperature;
    tParameters.sPhaseType = csPhase{aiPhase(aiIndices(iI))};
    tParameters.sSecondDepName = 'Pressure';
    tParameters.fSecondDepValue = afPartialPressures(aiIndices(iI));
    tParameters.bUseIsobaricData = true;
    
    % Now we can call the findProperty() method.
    afRho(iI) = this.findProperty(tParameters);
end

% Sum up the densities multiplied by the partial masses to get the overall density.
if strcmp(sMatterState, 'gas')
    % for gases the density is calculated for the partial pressure of each
    % substance, and therefore is the partial density of the substance. The
    % overal density therefore must be calculated as the sum of each
    % partial density
    fDensity = sum(afRho);
else
    fDensity = sum(afRho .* arPartialMass(aiIndices));
end

% If none of the substances has a valid density an error is thrown.
if fDensity < 0 || isnan(fDensity)
    this.throw('calculateDensity','Error in Density calculation!');
end

end

