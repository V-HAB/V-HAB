function [ fVolume ] = getSolidVolume(oMT, tfMasses, fTemperature)
%calculates the volume of a solid phase with the given tf masses struct
%   since no volume can be set for solid phases this function can be used
%   to calculate the solid volume beforehand and implement it in the store
%   definition to achieve a fitting overal store volume with defineable
%   gas/liquid volumes

% gets the names of the substances used in this solid
csSubstances = fieldnames(tfMasses);

% creates the afMass variable
afMass = zeros(1,oMT.iSubstances);
for iSubstance = 1:length(csSubstances)
    
    iIndex = oMT.tiN2I.(csSubstances{iSubstance});
    
    afMass(iIndex) = tfMasses.(csSubstances{iSubstance});
    
end
% calculates the density
fDensity = oMT.calculateDensity('solid',afMass,fTemperature);

% The volume is the mass divided with the density
fVolume = sum(afMass)/fDensity;

end

