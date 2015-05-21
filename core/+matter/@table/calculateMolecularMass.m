function fMolecularMass = calculateMolecularMass(this, afMass)
    %CALCULATEMOLECULARMASS Calculate total molar mass from partial masses
    %   This function takes a vector of masses (its elements are the masses
    %   of each substance in the examined mixture; the order of elements
    %   must comply with the order of substances in the matter table) and
    %   calculates the total molar mass of the mixture using the molar mass
    %   of each substance from the matter table. 
    %   
    %   Using the ideal gas law, it holds: 
    %   
    %       p = m * R_m * T / ( V * M ) = R_m * T / V * m / M        [A]
    %   
    %       p = ?(p[i]) = ?( m[i] * R_m / M[i] * T / V )
    %                   = R_m * T / V * ?( m[i] / M[i] )             [B]
    %   
    %   Since [A] equals [B]: 
    %   
    %       R_m * T / V * m / M = R_m * T / V * ?( m[i] / M[i] )
    %                     m / M = ?( m[i] / M[i] )
    %   
    %                    ===> M = m / ?( m[i] / M[i] )
    %   
    %   Or simpler, using the definition of the molar mass |M = m / n|: 
    %   
    %       n[i] = m[i] / M[i]
    %   
    %       n = ?( n[i] ) = ?( m[i] / M[i] )
    %   
    %       ===> M = m / ?( m[i] / M[i] )
    %   
    %   Here, the sum (total amount of substance) is calculated with the
    %   matrix product of the mass vector |afMass| and the inverse of the
    %   elements of the molar mass vector |this.afMolMass| transformed. 
    % 
    % 
    % calculateMolecularMass returns
    %   fMolecularMass  - molecular mass of mix, g/mol
    % 
    % 
    %TODO:
    %   - Rename to |calculateMolarMass| since "molecular mass" means
    %     something different.
    %   - Use |this.afMolarMass| to return [kg/mol] rather than [g/mol].

fMass = sum(afMass);

if fMass == 0
    fMolecularMass = 0;
    return;
end

fMolecularMass = fMass / (afMass * (1 ./ this.afMolMass)');

%TODO Replace with this line once transition to molar mass in kg/mol is complete
%fMolecularMass = fMass / (afMass * (1 ./ this.afMolarMass)');
end