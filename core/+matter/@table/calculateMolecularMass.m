function fMolarMass = calculateMolecularMass(this, afMasses)
    %CALCULATEMOLECULARMASS Calculate total molar mass from partial masses
    %   This function takes a vector of masses (its elements are the masses
    %   of each substance in the examined mixture; the order of elements
    %   must comply with the order of substances in the matter table) and
    %   calculates the total molar mass of the mixture using the molar mass
    %   of each substance from the matter table.
    %   
    %   Using the definition of the molar mass |M = m / n|:
    %   
    %       n[i] = m[i] / M[i]
    %       
    %       n = SUM( n[i] ) = SUM( m[i] / M[i] )
    %       
    %       ===> M = m / SUM( m[i] / M[i] )
    %   
    %   Here, the sum (total amount of substance) is calculated with the
    %   matrix product of the mass vector |afMasses| and the inverse of the
    %   elements of the molar mass vector |this.afMolarMass| transformed.
    %   
    %   
    % calculateMolecularMass returns
    %   fMolarMass  - molar mass of mix, kg/mol
    %
    %TODO:
    %   - Rename to |calculateMolarMass| since "molecular mass" means
    %     something different.

fTotalMass = sum(afMasses);

if fTotalMass == 0
    fMolarMass = 0;
    return;
end

fMolarMass = fTotalMass / (afMasses * (1 ./ this.afMolarMass)');

end
