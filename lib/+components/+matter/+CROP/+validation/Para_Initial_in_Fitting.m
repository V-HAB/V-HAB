function [ afPmr_Estimate_Initial ] = Para_Initial_in_Fitting()
%This function is used to set initial parameter set in each data series for data fitting.

% The sequences of the parameters are described in section 4.3.3 in the thesis
afPmr_Estimate_Initial = zeros(98,1);

afPmr_Estimate_Initial(1) = 0.05;
afPmr_Estimate_Initial(2) = 1;
afPmr_Estimate_Initial(3) = 0.05;
afPmr_Estimate_Initial(4) = 1;
afPmr_Estimate_Initial(5) = 0.0001;
afPmr_Estimate_Initial(6) = 0.0003;
afPmr_Estimate_Initial(7) = 0.0003;
afPmr_Estimate_Initial(8) = 0.0005;

afPmr_Estimate_Initial(1+8) = 0.05;
afPmr_Estimate_Initial(2+8) = 1;
afPmr_Estimate_Initial(3+8) = 0.05;
afPmr_Estimate_Initial(4+8) = 1;
afPmr_Estimate_Initial(5+8) = 0.0001;
afPmr_Estimate_Initial(6+8) = 0.0003;
afPmr_Estimate_Initial(7+8) = 0.0003;
afPmr_Estimate_Initial(8+8) = 0.0005;

afPmr_Estimate_Initial(1+16) = 0.05;
afPmr_Estimate_Initial(2+16) = 1;
afPmr_Estimate_Initial(3+16) = 0.05;
afPmr_Estimate_Initial(4+16) = 1;
afPmr_Estimate_Initial(5+16) = 0.0001;
afPmr_Estimate_Initial(6+16) = 0.0003;
afPmr_Estimate_Initial(7+16) = 0.0003;
afPmr_Estimate_Initial(8+16) = 0.0005;

afPmr_Estimate_Initial(25) = 0.005;
afPmr_Estimate_Initial(26) = 0.1;
for i = 0:5
    afPmr_Estimate_Initial(26+1+12*i) = 0.1;
    afPmr_Estimate_Initial(26+2+12*i) = 0;
    afPmr_Estimate_Initial(26+3+12*i) = 0;
    afPmr_Estimate_Initial(26+4+12*i) = 0;
    afPmr_Estimate_Initial(26+5+12*i) = 0;
    afPmr_Estimate_Initial(26+6+12*i) = 0.1;
    afPmr_Estimate_Initial(26+7+12*i) = 0.1;
    afPmr_Estimate_Initial(26+8+12*i) = 0.1;
    afPmr_Estimate_Initial(26+9+12*i) = 0.01;
    afPmr_Estimate_Initial(26+10+12*i) = 0.01;
    afPmr_Estimate_Initial(26+11+12*i) = 0.01;
    afPmr_Estimate_Initial(26+12+12*i) = 0;
end

