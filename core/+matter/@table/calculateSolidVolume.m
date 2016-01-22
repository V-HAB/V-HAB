function [ fVolume ] = calculateSolidVolume(this, tfMasses, fTemperature, bAdsorber)
%calculates the volume of a solid phase with the given tf masses struct
%   since no volume can be set for solid phases this function can be used
%   to calculate the solid volume beforehand and implement it in the store
%   definition to achieve a fitting overal store volume with defineable
%   gas/liquid volumes

if nargin < 4
    bAdsorber = false;
end

% gets the names of the substances used in this solid
csSubstances = fieldnames(tfMasses);

% creates the afMass variable
afMass = zeros(1,this.iSubstances);
for iSubstance = 1:length(csSubstances)
    
    iIndex = this.tiN2I.(csSubstances{iSubstance});
    
    afMass(iIndex) = tfMasses.(csSubstances{iSubstance});
    
end
% calculates the density
if bAdsorber
                        
    aiIndices   = find(afMass > 0);
    iNumIndices = length(aiIndices);
    
    iAdsorber = find(afMass == max(afMass));
    if length(iAdsorber) > 1
        error('two substances within the adsorber phase have the exact same mass so it is not possible to determine which should be the main substance')
    end
    sAdsorberSubstance = this.csSubstances{iAdsorber};
                    
    % Initialize a new array filled with zeros. Then iterate through all
    % indexed substances and get their specific heat capacity.
    afRho = zeros(this.iSubstances, 1);
    arPartialMass = afMass./(sum(afMass));
    
    for iI = 1:iNumIndices
        afRho(aiIndices(iI)) = this.ttxMatter.(this.csSubstances{aiIndices(iI)}).fStandardDensity;
    end

    % now the dynamic heat capacity for the main
    % adsorber material is calculated and the standard
    % value for just this substance is overwritten with
    % the dynamic value
    tParameters = struct();
    tParameters.sSubstance = sAdsorberSubstance;
    tParameters.sProperty = 'Density';
    tParameters.sFirstDepName = 'Temperature';
    tParameters.fFirstDepValue = fTemperature;
    tParameters.sPhaseType = 'solid';
    tParameters.sSecondDepName = 'Pressure';
    tParameters.fSecondDepValue = this.Standard.Pressure;
    tParameters.bUseIsobaricData = true;

    % Now we can call the findProperty() method.
    afRho(this.tiN2I.(sAdsorberSubstance)) = this.findProperty(tParameters);

    % Multiply the specific heat capacities with the mass fractions. The
    % result of the matrix multiplication is the specific heat capacity of
    % the mixture.
    fDensity = sum(arPartialMass * afRho);
    
else
    fDensity = this.calculateDensity('solid',afMass,fTemperature);
end

% The volume is the mass divided with the density
fVolume = sum(afMass)/fDensity;

end

