function [fpH,afReactionRate] = DiffEquations(afConcentration, tPmr, tpH_Diagram, fK_Metal_Ion)
 %The basic enzyme kinetics in the manipulator "Enzyme Reactions" (the orange block in Fig.4-7)
    
% Concentrations of the external reactants
fCon_CH4N2O    = afConcentration(4);
fCon_NH3       = afConcentration(5);
fCon_NH4OH     = afConcentration(6);
fCon_HNO2      = afConcentration(7);
fCon_HNO3      = afConcentration(8);

% Struct C_inter^A containing the internal reactants in enzyme reaction A
tfCon_A_inter.E       = afConcentration(9);
tfCon_A_inter.ES      = afConcentration(10);
tfCon_A_inter.I       = afConcentration(11);
tfCon_A_inter.EI      = afConcentration(12);
tfCon_A_inter.ESI     = afConcentration(13);
tfCon_A_inter.EP      = afConcentration(14);
tfCon_A_inter.EPI     = afConcentration(15);

% Struct C_inter^B containing the internal reactants in enzyme reaction B
tfCon_B_inter.E       = afConcentration(16);
tfCon_B_inter.ES1      = afConcentration(17);
tfCon_B_inter.I       = afConcentration(18);
tfCon_B_inter.EI      = afConcentration(19);
tfCon_B_inter.ESI1     = afConcentration(20);
tfCon_B_inter.EP      = afConcentration(21);
tfCon_B_inter.EPI     = afConcentration(22);
tfCon_B_inter.ES2      = afConcentration(30-7);
tfCon_B_inter.ESI2      = afConcentration(31-7);

% Struct C_inter^C containing the internal reactants in enzyme reaction C
tfCon_C_inter.E       = afConcentration(23+2);
tfCon_C_inter.ES      = afConcentration(24+2);
tfCon_C_inter.I       = afConcentration(25+2);
tfCon_C_inter.EI      = afConcentration(26+2);
tfCon_C_inter.ESI     = afConcentration(27+2);
tfCon_C_inter.EP      = afConcentration(28+2);
tfCon_C_inter.EPI     = afConcentration(29+2);


% Calculation of the pH value with the function "PHCalculator.m" which is
% described in section 4.2.3.6 in the thesis. 
[fCon_Hplus, fCon_OHminus, fpH] = components.matter.CROP.tools.PHCalculator([afConcentration(6) afConcentration(17) afConcentration(20)], ...
    [afConcentration(7)  afConcentration(21)  afConcentration(22)  afConcentration(26)  afConcentration(29)...
    afConcentration(8)  afConcentration(30)  afConcentration(31)], 'l',fK_Metal_Ion);

% Add the effect of the pH value to the rate constants which is
% described in section 4.2.3.8 in the thesis with the function
% "Reaction_Factor_pH.m"
tPmr = components.matter.CROP.tools.Reaction_Factor_pH(tPmr, tpH_Diagram, fpH);

% Reaction rate vectors of reaction A, B, C, D (v^A, v^B, v^C, v^D in the thesis)
% Reaction rate vectors of reaction A (v^A)
afFluxA(1)  =  tPmr.A.a.fk_f * tfCon_A_inter.E  * fCon_CH4N2O   -     tPmr.A.a.fk_r * tfCon_A_inter.ES;
afFluxA(3)  =  tPmr.A.c.fk_f * tfCon_A_inter.E  * tfCon_A_inter.I  -  tPmr.A.c.fk_r * tfCon_A_inter.EI;
afFluxA(5)  =  tPmr.A.e.fk_f * tfCon_A_inter.EI * fCon_CH4N2O   -     tPmr.A.e.fk_r * tfCon_A_inter.ESI;
afFluxA(2)  =  tPmr.A.b.fk_f * tfCon_A_inter.ES                 -     tPmr.A.b.fk_r * tfCon_A_inter.EP;
afFluxA(7)  =  tPmr.A.g.fk_f * tfCon_A_inter.EP                 -     tPmr.A.g.fk_r * tfCon_A_inter.E   * fCon_NH3 * fCon_NH3;     %![NH3]^2
afFluxA(4)  =  tPmr.A.d.fk_f * tfCon_A_inter.ES * tfCon_A_inter.I  -  tPmr.A.d.fk_r * tfCon_A_inter.ESI;
afFluxA(6)  =  tPmr.A.f.fk_f * tfCon_A_inter.ESI                -     tPmr.A.f.fk_r * tfCon_A_inter.EPI;
afFluxA(8)  =  tPmr.A.h.fk_f * tfCon_A_inter.EPI                -     tPmr.A.h.fk_r * tfCon_A_inter.EI  * fCon_NH3 * fCon_NH3;   %![NH3]^2

% Reaction rate of reaction D (v^D)
fFluxD    =  tPmr.D.fk_f   * fCon_NH3                  -     tPmr.D.fk_r   * fCon_NH4OH * fCon_OHminus;

% Reaction rate vectors of reaction B (v^B)
afFluxB(1)  =  tPmr.B.a.fk_f * tfCon_B_inter.E  * fCon_NH4OH      -    tPmr.B.a.fk_r * tfCon_B_inter.ES1;                % *** NH4OH to NH3, back
afFluxB(3)  =  tPmr.B.c.fk_f * tfCon_B_inter.E  * tfCon_B_inter.I -    tPmr.B.c.fk_r * tfCon_B_inter.EI;
afFluxB(5)  =  tPmr.B.e.fk_f * tfCon_B_inter.EI * fCon_NH4OH      -    tPmr.B.e.fk_r * tfCon_B_inter.ESI1;               % *** NH4OH to NH3, back
afFluxB(2)  =  tPmr.B.b.fk_f * tfCon_B_inter.ES1                  -    tPmr.B.b.fk_r * tfCon_B_inter.EP  * fCon_Hplus^2;  % ! added the influence of H+
afFluxB(7)  =  tPmr.B.g.fk_f * tfCon_B_inter.EP                   -    tPmr.B.g.fk_r * tfCon_B_inter.E   * fCon_HNO2;
afFluxB(4)  =  tPmr.B.d.fk_f * tfCon_B_inter.ES1 * tfCon_B_inter.I -   tPmr.B.d.fk_r * tfCon_B_inter.ESI1;
afFluxB(6)  =  tPmr.B.f.fk_f * tfCon_B_inter.ESI1                -     tPmr.B.f.fk_r * tfCon_B_inter.EPI * fCon_Hplus^2;  % ! added the influence of H+
afFluxB(8)  =  tPmr.B.h.fk_f * tfCon_B_inter.EPI                -      tPmr.B.h.fk_r * tfCon_B_inter.EI  * fCon_HNO2;

afFluxB(9)  =  tPmr.B.a.fk_f * tfCon_B_inter.E  * fCon_NH4OH    -      tPmr.B.a.fk_r * tfCon_B_inter.ES2;                % *** NH4OH to NH3, back
afFluxB(10) =  tPmr.B.e.fk_f * tfCon_B_inter.EI * fCon_NH4OH    -      tPmr.B.e.fk_r * tfCon_B_inter.ESI2;               % *** NH4OH to NH3, back
afFluxB(11) =  tPmr.B.b.fk_f * tfCon_B_inter.ES2                 -     tPmr.B.b.fk_r * tfCon_B_inter.EP  * fCon_Hplus^2;  % ! added the influence of H+
afFluxB(12) =  tPmr.B.d.fk_f * tfCon_B_inter.ES2 * tfCon_B_inter.I  -  tPmr.B.d.fk_r * tfCon_B_inter.ESI2;
afFluxB(13) =  tPmr.B.f.fk_f * tfCon_B_inter.ESI2                -     tPmr.B.f.fk_r * tfCon_B_inter.EPI * fCon_Hplus^2;  % ! added the influence of H+


% Reaction rate vectors of reaction C (v^C)
afFluxC(1)  =  tPmr.C.a.fk_f * tfCon_C_inter.E  * fCon_HNO2     -     tPmr.C.a.fk_r * tfCon_C_inter.ES;
afFluxC(3)  =  tPmr.C.c.fk_f * tfCon_C_inter.E  * tfCon_C_inter.I  -  tPmr.C.c.fk_r * tfCon_C_inter.EI;
afFluxC(5)  =  tPmr.C.e.fk_f * tfCon_C_inter.EI * fCon_HNO2     -     tPmr.C.e.fk_r * tfCon_C_inter.ESI;
afFluxC(2)  =  tPmr.C.b.fk_f * tfCon_C_inter.ES                 -     tPmr.C.b.fk_r * tfCon_C_inter.EP; 
afFluxC(7)  =  tPmr.C.g.fk_f * tfCon_C_inter.EP                 -     tPmr.C.g.fk_r * tfCon_C_inter.E   * fCon_HNO3;
afFluxC(4)  =  tPmr.C.d.fk_f * tfCon_C_inter.ES * tfCon_C_inter.I  -  tPmr.C.d.fk_r * tfCon_C_inter.ESI;
afFluxC(6)  =  tPmr.C.f.fk_f * tfCon_C_inter.ESI                -     tPmr.C.f.fk_r * tfCon_C_inter.EPI;
afFluxC(8)  =  tPmr.C.h.fk_f * tfCon_C_inter.EPI                -     tPmr.C.h.fk_r * tfCon_C_inter.EI  * fCon_HNO3;

% Integration of the reaction rate vectors
afFlux_total = [afFluxA afFluxB afFluxC fFluxD]';

% *********************************************************************


% Internal matrix K_inter^A which represents the relationship between the 
% reaction rates of the enzyme-related reactants in reaction A and the vector v^A
tmK_inter.A = ...
    [-1 0 -1 0 0 0 1 0;...
    1 -1 0 -1 0 0 0 0;...
    0 0 -1 -1 0 0 0 0;...
    0 0 1 0 -1 0 0 1;...
    0 0 0 1 1 -1 0 0;...
    0 1 0 0 0 0 -1 0;...
    0 0 0 0 0 1 0 -1];

% Internal matrix K_inter^B which represents the relationship between the 
% reaction rates of the enzyme-related reactants in reaction B and the vector v^B
tmK_inter.B = ...
    [-1 0 -1 0 0 0 1 0 -1 0 0 0 0;...
    1 -1 0 -1 0 0 0 0 0 0 0 0 0;...
    0 0 -1 -1 0 0 0 0 0 0 0 -1 0;...
    0 0 1 0 -1 0 0 1 0 -1 0 0 0;...
    0 0 0 1 1 -1 0 0 0 0 0 0 0;...
    0 1 0 0 0 0 -1 0 0 0 1 0 0;...
    0 0 0 0 0 1 0 -1 0 0 0 0 1;...
    0 0 0 0 0 0 0 0 1 0 -1 -1 0;...
    0 0 0 0 0 0 0 0 0 1 0 1 -1];

% Internal matrix K_inter^C which represents the relationship between the 
% reaction rates of the enzyme-related reactants in reaction C and the vector v^C
tmK_inter.C = tmK_inter.A;

% External matrix K_exter^A which represents the relationship between the 
% reaction rates of the external reactants and the vector v^A
tmK_exter.A = ...
    [0 -1 0 0 0 -1 0 0;...
    0 1 0 0 0 1 0 0;...
    0 0 0 0 0 0 0 0;...
    -1 0 0 0 -1 0 0 0;...
    0 0 0 0 0 0 2 2;...
    0 0 0 0 0 0 0 0;...
    0 0 0 0 0 0 0 0;...
    0 0 0 0 0 0 0 0];

% External matrix K_exter^B which represents the relationship between the 
% reaction rates of the external reactants and the vector v^B
tmK_exter.B = ...
    [0 2 0 0 0 2 0 0 0 0 1 0 1;...
    0 0 0 0 0 0 0 0 0 0 0 0 0;...
    0 -1.5 0 0 0 -1.5 0 0 0 0 -1.5 0 -1.5;...
    0 0 0 0 0 0 0 0 0 0 0 0 0;...
    0 0 0 0 0 0 0 0 -1 -1 0 0 0;...
    -1 0 0 0 -1 0 0 0 0 0 0 0 0;...
    0 0 0 0 0 0 1 1 0 0 0 0 0;...
    0 0 0 0 0 0 0 0 0 0 0 0 0];

% External matrix K_exter^C which represents the relationship between the 
% reaction rates of the external reactants and the vector v^C
tmK_exter.C = ...
    [0 0 0 0 0 0 0 0;...
    0 0 0 0 0 0 0 0;...
    0 -0.5 0 0 0 -0.5 0 0;...
    0 0 0 0 0 0 0 0;...
    0 0 0 0 0 0 0 0;...
    0 0 0 0 0 0 0 0;...
    -1 0 0 0 -1 0 0 0;...
    0 0 0 0 0 0 1 1];

% External matrix K_exter^D which represents the relationship between the 
% reaction rates of the external reactants and v^D
tmK_exter.D = [-1 0 0 0 -1 1 0 0]';

% Integration of the above matrices into a matrix K_tot as is described in
% section 4.2.3.5 in the thesis.
mK_total = [tmK_exter.A tmK_exter.B tmK_exter.C tmK_exter.D;...
    tmK_inter.A zeros(7,22);...
    zeros(9,8) tmK_inter.B zeros(9,9);...
    zeros(7,21) tmK_inter.C zeros(7,1)];

% Calculation of the reaction rate vector of all reactants as is described
% in Eq.(4-23) in section 4.2.3.5 in the thesis.
afReactionRate = mK_total * afFlux_total;

end