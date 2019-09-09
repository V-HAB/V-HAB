function afResolvedMass = resolveCompoundMass(this, afMass, arCompoundMass)
%% resolveCompoundMass
% This function is used to resolve compound masses into their components
% and provide an afMass Vector which only contains base matter
if any(afMass(this.abCompound))
    afResolvedMass = afMass' .* arCompoundMass;
    afResolvedMass = sum(afResolvedMass, 1);
else
    afResolvedMass = afMass;
end
end
