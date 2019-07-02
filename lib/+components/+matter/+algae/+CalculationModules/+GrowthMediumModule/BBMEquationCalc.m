%BBMEQUATIONCALC uses the matlab symbolic toolbox to create the 
%polynomial required to calculate the h+ concentration in the growth
%medium. it uses the equilibrium constants and all involved chemical
%reactions (as functions of known variables) to calculate the polynomial by
%solving the charge balance equation for h+. The coefficicents can then be
%used in the growth medium modules calculation by copying them there. This
%only has to be done if the composition of the growth medium is changed to
%inlcude more substances than the ones listed below. (EDTA, Phosphate, CO2,
%KOH, OH-)

%Charge balance equation
%left_side = H + C_KOH +  C_6 + 2* C_7 + C_OHminusPS + 2*C_1;
%right_side = term_11+ 2*term_12 + 3*term_13 + 4*term_14 + term_3 + 2*term_4 + term_5 + 2*term_6 + 3*term_7 + term_8 + C_AddedAcid; 

%define the function describing the equilibriums that should be rearranged
clear
clc

%concentration of hplus
syms fTargetC_Hplus; 
%equilibrium constants
syms fK_EDTA fK_EDTAminus fK_EDTA2minus fK_EDTA3minus fK_CO2 fK_HCO3 fK_H3PO4 fK_H2PO4 fK_HPO4 fK_w;
% total molality of substances
syms fC_EDTA_ini fC_EDTA_tot fC_Carb_tot fC_H2PO4_ini fC_HPO4_ini fC_Phos_tot fC_KOH_ini fC_OHminusPS fC_AddedAcid fHplusPhotosynthesis;

%define terms that contribute to equation with numerator and denominator
%EDTA to EDTA-
numerator_11 = (fK_EDTA *fC_EDTA_tot*fC_Hplus^3); 
denominator_11= (fC_Hplus^4 + fC_Hplus^3*fK_EDTA + fC_Hplus^2*fK_EDTA*fK_EDTAminus + fC_Hplus*fK_EDTA*fK_EDTAminus*fK_EDTA2minus + fK_EDTA*fK_EDTAminus*fK_EDTA2minus*fK_EDTA3minus);
term_11 = numerator_11 / denominator_11

numerator_12 = (fK_EDTA*fK_EDTAminus *fC_EDTA_tot*fC_Hplus^2); 
denominator_12= (fC_Hplus^4 + fC_Hplus^3*fK_EDTA + fC_Hplus^2*fK_EDTA*fK_EDTAminus + fC_Hplus*fK_EDTA*fK_EDTAminus*fK_EDTA2minus + fK_EDTA*fK_EDTAminus*fK_EDTA2minus*fK_EDTA3minus);
term_12 = numerator_12 / denominator_12

numerator_13 = (fK_EDTA*fK_EDTAminus * fK_EDTA2minus * fC_EDTA_tot*fC_Hplus); 
denominator_13= (fC_Hplus^4 + fC_Hplus^3*fK_EDTA + fC_Hplus^2*fK_EDTA*fK_EDTAminus + fC_Hplus*fK_EDTA*fK_EDTAminus*fK_EDTA2minus + fK_EDTA*fK_EDTAminus*fK_EDTA2minus*fK_EDTA3minus);
term_13 = numerator_13 / denominator_13

numerator_14 = (fK_EDTA*fK_EDTAminus * fK_EDTA2minus *fK_EDTA3minus * fC_EDTA_tot); 
denominator_14= (fC_Hplus^4 + fC_Hplus^3*fK_EDTA + fC_Hplus^2*fK_EDTA*fK_EDTAminus + fC_Hplus*fK_EDTA*fK_EDTAminus*fK_EDTA2minus + fK_EDTA*fK_EDTAminus*fK_EDTA2minus*fK_EDTA3minus);
term_14 = numerator_14 / denominator_14


%CO2+H2O to HCO3-
numerator_3 = fK_CO2 * fC_Carb_tot*fC_Hplus;
denominator_3 = fC_Hplus^2+fK_CO2*fC_Hplus+fK_CO2*fK_HCO3;
term_3 = numerator_3 / denominator_3

%HCO3- to CO3_2-
numerator_4 = fK_HCO3*fK_CO2 * fC_Carb_tot;
denominator_4 = fC_Hplus^2+fK_CO2*fC_Hplus+fK_CO2*fK_HCO3;
term_4 = numerator_4 / denominator_4

%H3PO4 to H2PO4 
numerator_5 = fK_H3PO4*(fC_Phos_tot)*fC_Hplus^2;
denominator_5 = fC_Hplus^3 + fC_Hplus^2*fK_H3PO4 + fC_Hplus*fK_H3PO4*fK_H2PO4 + fK_H3PO4*fK_H2PO4*fK_HPO4;
term_5 = numerator_5 / denominator_5

%H2PO4 (monobasic) to HPO4 (dibasic)
numerator_6 = fK_H2PO4*fK_H3PO4*(fC_Phos_tot)*fC_Hplus;
denominator_6 = fC_Hplus^3 + fC_Hplus^2*fK_H3PO4 + fC_Hplus*fK_H3PO4*fK_H2PO4 + fK_H3PO4*fK_H2PO4*fK_HPO4;
term_6 = numerator_6 / denominator_6

%HPO4 (dibasic) to PO4
numerator_7 = fK_H2PO4*fK_H3PO4*fK_HPO4*(fC_Phos_tot);
denominator_7 = fC_Hplus^3 + fC_Hplus^2*fK_H3PO4 + fC_Hplus*fK_H3PO4*fK_H2PO4 + fK_H3PO4*fK_H2PO4*fK_HPO4;
term_7 = numerator_7 / denominator_7

%autoprotolysis of water
numerator_8 = fK_w;
denominator_8 = fC_Hplus;
term_8 = numerator_8 / denominator_8


%% set up function 

left_side = fC_Hplus + fC_KOH_ini +  fC_H2PO4_ini + 2* fC_HPO4_ini + fC_OHminusPS + fHplusPhotosynthesis + 2*fC_EDTA2minus_ini;

%show right side of function 
right_side = term_11+ 2*term_12 + 3*term_13 + 4*term_14 + term_3 + 2*term_4 + term_5 + 2*term_6 + 3*term_7 + term_8 + fC_AddedAcid; 

right = collect(simplifyFraction(right_side, 'Expand',true),fC_Hplus);
[r_num, r_denom] = numden(right);
%%
%multiply left side with right denominator
left_multiplied = left_side * r_denom;
final = expand(left_multiplied - r_num);
final_collected = collect(final,fC_Hplus)
coefficients = coeffs(final_collected,fC_Hplus);
coef11 = coefficients(1,12)
coef10 = coefficients(1,11)
coef9 = coefficients(1,10)
coef8 = coefficients(1,9)
coef7 = coefficients(1,8)
coef6 = coefficients(1,7)
coef5 = coefficients(1,6)
coef4 = coefficients(1,5)
coef3 = coefficients(1,4)
coef2 = coefficients(1,3)
coef1 = coefficients(1,2)
coef0 = coefficients(1,1)