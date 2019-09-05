function afResolvedMass = resolveCompoundMass(this, afMass, tfCompoundMass)
%% resolveCompoundMass
% This function is used to resolve compound masses into their components
% and provide an afMass Vector which only contains base matter
if any(afMass(this.abCompound))
    afResolvedMass = afMass;
    csCompounds = fieldnames(tfCompoundMass);
    for iCompound = 1:length(csCompounds)
        afResolvedMass = afResolvedMass + tfCompoundMass.(csCompounds{iCompound});
    end
    afResolvedMass(this.abCompound) = 0;
else
    afResolvedMass = afMass;
end
end
