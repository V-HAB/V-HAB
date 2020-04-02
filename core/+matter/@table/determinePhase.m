function [miPhase, csPossiblePhase] = determinePhase(this, sSubstance, fTemperature, fPressure)

% TO DO: Write description!

% Temperature is index X,1 in mfData
% Pressure is index X,2 in mfData
% Phase Type indicator is X,3 in mfData

% 1 = solid
% 2 = liquid
% 3 = gas
% 4 = supercritical
csPhase = {'Solid';'Liquid';'Gas';'Supercritical'};

if isnumeric(sSubstance)
    % it is also possible to use the determine phase function on a whole
    % afMass vector and get back a vector of equal length that contains the
    % phase indicator for each substance
    csSubstances = this.csSubstances(sSubstance ~= 0);
    
    if any(sSubstance(this.abCompound))
        error('resolve compound masses using the resolveCompoundMass function of the matter table before using the determine phase function!')
    end
    
    miPhase = zeros(1,this.iSubstances);
    for k = 1:length(csSubstances)
        [miPhase(this.tiN2I.(csSubstances{k})), ~] = determinePhaseForSubstance(this, csSubstances{k}, fTemperature, fPressure(this.tiN2I.(csSubstances{k})));
    end
    
    try
        csPossiblePhase = csPhase(unique(miPhase(miPhase~=0)));
    catch
        csPossiblePhase = 'PhaseChanging';
    end
else
[miPhase, csPossiblePhase] = determinePhaseForSubstance(this, sSubstance, fTemperature, fPressure);
end
end


function [miPhase, csPossiblePhase] = determinePhaseForSubstance(this, sSubstance, fTemperature, fPressure)

% The Phase indicator numbers translate to the phases as:
% 1 = solid
% 2 = liquid
% 3 = gas
% 4 = supercritical
csPhase = {'Solid';'Liquid';'Gas';'Supercritical'};

if ~this.ttxMatter.(sSubstance).bIndividualFile
    % no actual matter data is available --> the phase struct is used to
    % determine which phase the substance can be in
    % TO DO: add warning
    csPossiblePhase = fieldnames(this.ttxMatter.(sSubstance).ttxPhases);
    for k = 1:length(csPossiblePhase)
        csPossiblePhase{k} = strrep(csPossiblePhase{k},'t','');
    end
    miPhase = find(strcmp(csPhase, csPossiblePhase{1}));
    
    return
end
    
if ~isfield(this.ttxMatter.(sSubstance).tIsobaricData, 'tPhaseIdentification')
    
    % at first a mfData matrix that contains the data for all possible phases
    % has to be constructed
    miLength = zeros(4,1);

    for iPhase = 1:4
        tfTemperature.(csPhase{iPhase}) = this.ttxMatter.(sSubstance).tIsobaricData.(['t',csPhase{iPhase}]).mfData(:,1);
        tfPressure.(csPhase{iPhase})    = this.ttxMatter.(sSubstance).tIsobaricData.(['t',csPhase{iPhase}]).mfData(:,2);

        miLength(iPhase) = length(tfTemperature.(csPhase{iPhase})); 
    end

    mfData = [tfTemperature.Solid, tfPressure.Solid, ones(miLength(1),1);...
              tfTemperature.Liquid, tfPressure.Liquid, 2.*ones(miLength(2),1);...
              tfTemperature.Gas, tfPressure.Gas, 3.*ones(miLength(3),1);...
              tfTemperature.Supercritical, tfPressure.Supercritical, 4.*ones(miLength(4),1)];


    % Now we remove all rows that contain NaN values
    mfData(any(isnan(mfData), 2), :) = [];

    % Only unique values are needed (also scatteredInterpolant would give out a warning in that case)
    mfData = unique(mfData,'rows');
    % Sometimes there are also multiple values for
    % the same combination of dependencies. Here we
    % get rid of those too.
    [ ~, aIndices ] = unique(mfData(:, [1 2]), 'rows');
    mfData = mfData(aIndices, :);

    % interpolate linear with no extrapolation
    %CHECK Does it make sense not to extrapolate?
    hInterpolation = scatteredInterpolant(mfData(:,1),mfData(:,2),mfData(:,3),'linear','none');

    this.ttxMatter.(sSubstance).tIsobaricData.tPhaseIdentification.tInterpolation = hInterpolation;
    this.ttxMatter.(sSubstance).tIsobaricData.tPhaseIdentification.bInterpolation = true;
    
    this.ttxMatter.(sSubstance).tIsobaricData.tPhaseIdentification.ttExtremes.tTemperature.Min = min(mfData(:,1));
    this.ttxMatter.(sSubstance).tIsobaricData.tPhaseIdentification.ttExtremes.tTemperature.Max = max(mfData(:,1));
    
    this.ttxMatter.(sSubstance).tIsobaricData.tPhaseIdentification.ttExtremes.tPressure.Min = min(mfData(:,2));
    this.ttxMatter.(sSubstance).tIsobaricData.tPhaseIdentification.ttExtremes.tPressure.Max = max(mfData(:,2));
end

if fTemperature < this.ttxMatter.(sSubstance).tIsobaricData.tPhaseIdentification.ttExtremes.tTemperature.Min
    fTemperature = this.ttxMatter.(sSubstance).tIsobaricData.tPhaseIdentification.ttExtremes.tTemperature.Min;
    % TO DO:Add warning that matter data was not sufficient
elseif fTemperature > this.ttxMatter.(sSubstance).tIsobaricData.tPhaseIdentification.ttExtremes.tTemperature.Max
    fTemperature = this.ttxMatter.(sSubstance).tIsobaricData.tPhaseIdentification.ttExtremes.tTemperature.Max;
    % TO DO:Add warning that matter data was not sufficient
end

if fPressure < this.ttxMatter.(sSubstance).tIsobaricData.tPhaseIdentification.ttExtremes.tPressure.Min
    fPressure = this.ttxMatter.(sSubstance).tIsobaricData.tPhaseIdentification.ttExtremes.tPressure.Min;
    % TO DO:Add warning that matter data was not sufficient
elseif fPressure > this.ttxMatter.(sSubstance).tIsobaricData.tPhaseIdentification.ttExtremes.tPressure.Max
    fPressure = this.ttxMatter.(sSubstance).tIsobaricData.tPhaseIdentification.ttExtremes.tPressure.Max;
    % TO DO:Add warning that matter data was not sufficient
end

fPhase = this.ttxMatter.(sSubstance).tIsobaricData.tPhaseIdentification.tInterpolation(fTemperature, fPressure);
% if the value is just not integer afer the sixt digit it can be considered
% to be a numerical error and even if a phase change was detected the favor
% is so much towards one phase that no phase change would occur
fPhase = round(fPhase,6);

% TO DO: at triple point this calculation will give the result that a phase
% change occurs but only between two different phases!

csPossiblePhase = csPhase(floor(fPhase):ceil(fPhase));
miPhase = fPhase;
% if mod(fPhase,0) ~= 0
%     keyboard()
% end
end
