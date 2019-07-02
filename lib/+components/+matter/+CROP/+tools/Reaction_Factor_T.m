function tPmr = Reaction_Factor_T(tPmr, fT)
%Function to add the temperature effect to the enzyme kinetics as is described in section 4.2.3.7 in the thesis

% Denature temperature 
fTdenature = 40;

% Reference temperature
fTref = 25;

% Calculate the temperature effect factor k_T
if fT > fTdenature
    rTemp_Factor=(2^(-(fT - fTref)/10));
else
    rTemp_Factor=(2^((fT - fTref)/10));
end

% Add the temperature effect factors to the rate constants
for i = ['A' 'B' 'C']
    for j = ['a' 'b' 'c' 'd' 'e' 'f' 'g' 'h']
        tPmr.(i).(j).fk_f  = rTemp_Factor * tPmr.(i).(j).fk_f ;
        tPmr.(i).(j).fk_r  = rTemp_Factor * tPmr.(i).(j).fk_r ;
    end
end

tPmr.D.fk_f = rTemp_Factor * tPmr.D.fk_f;
tPmr.D.fk_r = rTemp_Factor * tPmr.D.fk_r;

end