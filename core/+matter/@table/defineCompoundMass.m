function defineCompoundMass(this, oCaller, sCompoundName, trBaseComposition, bEdibleSubstance)
%% defineCompoundMass
% Defines a new mass type for which no data is present in the
% MatterData.csv. Instead the defined compound mass is made up of a basic
% composition of substances and these are used to calculate the matter
% properties of the compound
bError = true;
if isa(oCaller, 'simulation.infrastructure')
    if isempty(fieldnames(oCaller.oSimulationContainer.toChildren))
        % we only allow this if nothing is defined yet!
        bError = false;
    end
elseif isa(oCaller, 'matter.table')
    % while this allows abuse because the user could provide the matter
    % table object as input to define compound masses during the
    % simulation, that amounts to intentional abuse.
    bError = false;
end

if bError
    error('Defining a compound mass is only possible within the matter table (not by the user) or the setup (location for user defined compound masses). This is necessary to prevent inconsistencies in the length of afMass vectors etc.')
end

if isfield(this.ttxMatter, sCompoundName) && ~this.abCompound(this.tiN2I.(sCompoundName))
    error(['The entry ', sCompoundName,' already exists in the matter table, you cannot add a compound mass under the same name as an existing base mass'])
end

csComposition = fieldnames(trBaseComposition);
rTotalRatio = 0;
for iField = 1:length(csComposition)
    rTotalRatio = rTotalRatio + trBaseComposition.(csComposition{iField});
end

% allow errors in the composition of less than 0.1 %
if abs(rTotalRatio - 1) > 1e-3
     error(['The compound mass ', sCompoundName,' was defined with a base ratio that does not sum up to one!'])
end

if rTotalRatio ~= 1
    for iField = 1:length(csComposition)
        trBaseComposition.(csComposition{iField}) = trBaseComposition.(csComposition{iField}) / rTotalRatio;
    end
end

% First we increment the total number of substances
this.iSubstances = this.iSubstances+1;

% Write new substancename into the cellarray
this.csSubstances{this.iSubstances} = sCompoundName;

% Add index of new substance to name to index struct
this.tiN2I.(sCompoundName) = this.iSubstances;

% Get list of substance indices.
this.csI2N = fieldnames(this.tiN2I);

this.tsS2N.sCompoundName = sCompoundName;
this.tsN2S.sCompoundName = sCompoundName;

this.abAbsorber(this.iSubstances) = false;

this.abCompound(this.iSubstances) = true;

if nargin > 4
    this.abEdibleSubstances(this.iSubstances) = bEdibleSubstance;
else
    this.abEdibleSubstances(this.iSubstances) = false;
end

this.ttxMatter.(sCompoundName).trBaseComposition    = trBaseComposition;
this.ttxMatter.(sCompoundName).bIndividualFile      = false;
this.ttxMatter.(sCompoundName).sName                = sCompoundName;

arBaseComposition = zeros(1,this.iSubstances);
for iField = 1:length(csComposition)
    arBaseComposition(this.tiN2I.(csComposition{iField})) = trBaseComposition.(csComposition{iField});
end

% this.ttxMatter.(sCompoundName).arBaseComposition   = arBaseComposition;
this.ttxMatter.(sCompoundName).csComposition        = csComposition;

this.afMolarMass(this.iSubstances) = 0;
this.afMolarMass(this.iSubstances) = sum(this.afMolarMass .* arBaseComposition);

% For the nutritional energy we assume that is 0 even for foods that
% consist of multiple parts. These must be split up before calculating
% their energy content, to ensure it is correct!
this.afNutritionalEnergy(this.iSubstances) = 0;
% Charge is also set to 0, if it contains charged substances, this is
% detected when resolving the compound
this.aiCharge(this.iSubstances) = 0;
this.afDissociationConstant(this.iSubstances) = 0;

% Absorbers store a vector with the same length as the number of substances
% in the matter table for the adsorption enthalpy. To ensure consistency we
% also have to add the new substance to these vectors
for iAbsorber = 1:sum(this.abAbsorber)
    miAbsorberIndex = find(this.abAbsorber);
    this.ttxMatter.(this.csSubstances{miAbsorberIndex(iAbsorber)}).tAbsorberParameters.mfAbsorptionEnthalpy(this.iSubstances) = 0;
    this.ttxMatter.(this.csSubstances{miAbsorberIndex(iAbsorber)}).tAbsorberParameters.tToth.mf_A0(this.iSubstances) = 0;
    this.ttxMatter.(this.csSubstances{miAbsorberIndex(iAbsorber)}).tAbsorberParameters.tToth.mf_B0(this.iSubstances) = 0;
    this.ttxMatter.(this.csSubstances{miAbsorberIndex(iAbsorber)}).tAbsorberParameters.tToth.mf_E(this.iSubstances)  = 0;
    this.ttxMatter.(this.csSubstances{miAbsorberIndex(iAbsorber)}).tAbsorberParameters.tToth.mf_T0(this.iSubstances) = 0;
    this.ttxMatter.(this.csSubstances{miAbsorberIndex(iAbsorber)}).tAbsorberParameters.tToth.mf_C0(this.iSubstances) = 0;
end
end
