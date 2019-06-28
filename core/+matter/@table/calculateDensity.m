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

[fTemperature, arPartialMass, csPhase, aiPhase, aiIndices, afPartialPressures, tbReference, sMatterState, bUseIsobaricData] = getNecessaryParameters(this, varargin{:});

% Check Cases where we do not have to calculate the density
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
    if tbReference.bNone
        fPressure = varargin{4};
        fMolarMass = sum(arPartialMass .* this.afMolarMass);
    else
        fPressure = varargin{1}.fPressure;
        fMolarMass = varargin{1}.fMolarMass;
    end
    if fPressure < 5e5
        fDensity = (fPressure * fMolarMass) / (this.Const.fUniversalGas * fTemperature);
        % We already have what we want, so no need to execute the rest
        % of this function.
        return;
    end
end

fDensity = calculateProperty(this, 'Density', fTemperature, arPartialMass, csPhase, aiPhase, aiIndices, afPartialPressures, bUseIsobaricData);
end

