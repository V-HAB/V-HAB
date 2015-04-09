function fMolecularMass = calculateMolecularMass(this, afMass)
%CALCULATEMOLECULARMASS Summary of this function goes here
    % Calculates the total molecular masses for a provided mass
    % vector based on the matter table. Can be used by phase, flow
    % and others to update their value.
    %
    % calculateMolecularMass returns
    %   fMolecularMass  - molecular mass of mix, g/mol

fMass = sum(afMass);

if fMass == 0
    fMolecularMass = 0;
    return;
end

fMolecularMass = afMass ./ fMass * this.afMolMass';

%TODO Replace with this line once transition to molar mass in kg/mol is complete
%fMolecularMass = afMass ./ fMass * this.afMolarMass';
end