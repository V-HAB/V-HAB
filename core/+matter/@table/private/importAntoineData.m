function importAntoineData(this)
%IMPORTANTOINEDATA Imports data for the Antoine equation for vapor pressure
%   This function manipulates the ttxMatter property of the matter table
%   class and adds properties to several substances that are required in
%   the Antoine equation to calculate the vapor pressure. 

% First we take a look at the properties of the constant data class
% 'AntoineData'. There is a single property for each absorber substance.
csSubstances = properties('matter.data.AntoineData');

% Counting the number of absorbers we have
iNumberOfSubstances = length(csSubstances);

% Now we loop through each of the substances and add the data to the
% ttxMatter struct.
for iSubstance = 1:iNumberOfSubstances
    this.ttxMatter.(csSubstances{iSubstance}).cxAntoineParameters = matter.data.AntoineData.(csSubstances{iSubstance});
end

end