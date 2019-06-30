function [fCon_Hplus, fCon_OHminus, fPH] = PHCalculator(afCon_Ionplus, afCon_Ionminus, sVolumeUnit,fK_M)
%Function to calculate the pH value in the simulation as is described in
%section 4.2.3.6

% Check the volume unit. If the unit is m^3, transfer it to L.
if sVolumeUnit == 'm3'
    afCon_Ionplus  = afCon_Ionplus./1000;
    afCon_Ionminus = afCon_Ionminus./1000;
end

% Calculate the C_Diff according to the charge conservation in the solution 
fSumCon_Ionplus   =  sum(afCon_Ionplus);
fSumCon_Ionminus  =  sum(afCon_Ionminus);
fCon_Diff         =  fSumCon_Ionminus - fSumCon_Ionplus;

% The ionization constant of water K_W
fK_W = 1e-14;

% Implementation of Eq.(4-33) in the thesis to calculate the H+ concentration
fCon_Hplus = (fCon_Diff + sqrt(fCon_Diff*fCon_Diff + 4 * fK_W ...
              * (1 + fK_M)))/(2 * (1 + fK_M));
                      
% Implementation of Eq.(4-34) in the thesis to calculate the OH-
% concentration and the pH value
fCon_OHminus = fK_W / fCon_Hplus;
fPH = - log10(fCon_Hplus);

end