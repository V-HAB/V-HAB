function afResolvedMass = resolveCompoundMass(this, afMass, arCompoundMass)
%% resolveCompoundMass
% This function is used to resolve compound masses into their components
% and provide an afMass Vector which only contains base matter
if any(afMass(this.abCompound))
    afResolvedMass = afMass' .* arCompoundMass;
    afResolvedMass = sum(afResolvedMass, 1);
    % Since the arCompoundMass entries for non compound masses are all 0 we
    % have to add these masses to the resolved mass again!
    afResolvedMass(1, ~this.abCompound) = afResolvedMass(1, ~this.abCompound) + afMass(1, ~this.abCompound);
else
    afResolvedMass = afMass;
end
end
