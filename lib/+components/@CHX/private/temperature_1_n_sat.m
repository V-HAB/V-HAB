%Calculates the outlet temperatures of a shell and tube heat exchanger with 1
%to 8 inner passes.
%Fluid 1 stands for the fluid inside the tubes.
%
%The function uses the following input parameters
%
%mArea                  = column vector with the entries for the area of
%                         each pass
%mU                     = column vector with the entries for the heat 
%                         exchange coefficient in W/m²K for each pass
%fHeat_Capacity_Flow_1  = heat capacity flow of mixed stream in W/K
%fHeat_Capacity_Flow_2	= heat capacity flow of unmixed stream in W/K
%fEntry_Temp_1       	= inlet temperature of fluid 1 in K (inside the pipes)
%fEntry_Temp_2          = inlet temperature of fluid 2 in K
%fConfig                = type of set-up. S = 1 stands for the set up where
%                         the first inner pass is a counterflow pass. S = 2 
%                         stands for the set up where the first inner pass 
%                         is parallel flow
%
%These arguments are used in the function as follows:
%
%[fOutlet_Temp_1, fOutlet_Temp_2] = temperature_1_n_sat(fConfig, mArea,...
%   mU, fHeat_Capacity_Flow_1, fHeat_Capacity_Flow_2, fEntry_Temp_1,...
%   fEntry_Temp_2)
%
%Note that the number of passes is calculated from the number of entries in
%mArea and mU Vector.
%
%Also for more than 8 passes or Number of Transferunits N1 or N2
%higher than 100 the algorithm becomes inaccurate and might not yield
%correct results but calculation is basically possible


function [fOutlet_Temp_1, fOutlet_Temp_2] = temperature_1_n_sat(mArea, mU, fHeat_Capacity_Flow_1, fHeat_Capacity_Flow_2, fEntry_Temp_1, fEntry_Temp_2, fConfig)

%[6] stands for the source "Analytisches Verfahren zur Berechnung 
%Mehrgängiger Rohrbündelwärmeübertrager" Roetzel Wilfried

if size(mArea) ~= size(mU)
    error('the number of areas and heat exchange coefficients have to be equal')
end

%discerns the number of passes from the number of entries of areas
fPasses = length(mArea);

%calculates the total product of area and heat exchanger coefficient
%according to [6] page 17

fUA_total = sum(mU.*mArea);

%Number of Transferunits fluid 1 and fluid 2
fN1 = (fUA_total) / fHeat_Capacity_Flow_1;                          
fN2 = (fUA_total) / fHeat_Capacity_Flow_2;
%Equation from "Wärme- und Stoffübertragung" Baehr side 58 table 1.4

%preallocation of matrices and vectors
mA = zeros (fPasses,fPasses);
mB = zeros (fPasses,fPasses+1);
mepsilon = zeros (fPasses,1);
mK = zeros(fPasses+1,1);
mylambda = sym(zeros(fPasses+1,1));
mZ = zeros(2*fPasses,1);
mD = zeros(2*fPasses, 2*fPasses);


%Definition of Epsilon in each pass according to the 
%equations from [6] page 18
%Epsilon is the relation between the heat transfer capacity of the pass on
%its own to the total transfer capacity

for fi = 1:fPasses
    mepsilon(fi,1) = (mArea(fi) * mU(fi)) / (fUA_total);
end

%checks whether any epsilons for any passes are equal to each other and if
%thats is the cases changes them by adding/subtracting a small delta
for fi = 1:fPasses
    for fk = 1:fPasses
        if mepsilon(fi,1) == mepsilon(fk,1)
            mepsilon(fi,1) = mepsilon(fi,1) - 0.00001 ;
            mepsilon(fk,1) = mepsilon(fk,1) + 0.00001 ;
        end
    end
end

%a second check with different deltas is run to ensure no equals remain
for fi = 1:fPasses
    for fk = 1:fPasses
        if mepsilon(fi,1) == mepsilon(fk,1)
            mepsilon(fi,1) = mepsilon(fi,1) - 0.000001 ;
            mepsilon(fk,1) = mepsilon(fk,1) + 0.000001 ;
        end
    end
end

%%

%Matrix A and B are the matrices which are used to describe the
%differential equation. mB * (1; theta_2; d_theta_2/d_xi;...) = 
%mA * (theta_1,1; theta_1,2;....)
%In there theta_1,1 means the temperature within the first pass etc.

%Definition of matrix A according to [6] page 23 equation (7)
for fi = 1:fPasses
    for fk = 1:fPasses
        mA(fi,fk) = (mepsilon(fk,1)^(fi-1)) * (-1)^(fi*(fk+1));
    end
end

%%
%Definition of Matrix B according to [6] page 24 to 25 equations (8) to
%(10). Matrix B in Matlab is Matrix B* in the source as well as the thesis,
%but since the name B* leads to some problems in Matlab it will be simply
%called B here

%every element of the first column except for the first is zero
mB(1,1) = 1;

mB(1,2) = fN1/fN2;

%generates the sum over the rows of A to be used in the next step
A_sum = sum(mA,2);

%fills the elements above and right of the sum entries of B alternatingly
%with 1 an 1/N1
for fi = 2:fPasses
    for fk = 2:fPasses
        if fi == fk && mod(fi,2) == 0 
            mB(fi,fk) = 1;
        elseif fi == fk && mod(fi,2) ~= 0
            mB(fi,fk) = 1/fN2;
        end
    end
end

%fills the elements to the right of the above mentioned elements 
%alternatingly with 1/N2 and 1/(N1*N2)

for fi = 2:fPasses
    for fk = 2:fPasses
        if fi == fk && mod(fi,2) == 0 
            mB(fi,fk+1) = 1/fN2;
        elseif fi == fk && mod(fi,2) ~= 0
            mB(fi,fk+1) = 1/(fN1*fN2);
        end
    end
end

%fills the remaining positions with the sum entries

for fi = 3:fPasses
    for fk = 2:fPasses
        if fi > fk && fi ~= 1
            mB(fi,fk) = ((1/fN1)^(fk-2)) * (A_sum((fi-(fk-2)),1));
        end
    end
end

%%
%definition of Matrix C according to [6] page 25 equation (12)
%Matrix is gained by transposing the differential equation described in
%line 95 to 96
mC = mA^(-1)*mB;


%%
%definition of the coefficients for the differential equation according to
%[6] page 26 equation (13)

%the differential equation in this case is 
%d^P_theta_2/d_xi^P + K_P * d^(P-1)_theta_2/d_xi^(P-1)+...+
%+K_2 * d_theta_2/d_xi + K_1 * theta_2 = K_0

fSum1_for_K = 0;
fSum2_for_K = 0;

for fi = 1:fPasses  
    for fk = 1:fPasses
        
        fSum1_for_K = fSum1_for_K + (mepsilon(fk,1)^(fPasses+1-fi)) * ...
                        (-1)^((fk+1)*(fPasses+((1-(-1)^fi)/2)));
        
        fSum2_for_K = fSum2_for_K + (mepsilon(fk,1)^(fPasses)) *...
                        mC(fk,fi+1) * (-1)^((fk+1)*(fPasses+1));
    
    end 
end

for fi = 1:fPasses  
    mK(fi,1) = (fN2 * (fN1^(fPasses-fi)) * fSum1_for_K) - ...
                ((fN2 * (fN1^(fPasses-1))) * fSum2_for_K);
end
%the last value for K is 1 according to the differential equation from
%[6] page 27 equation (15) 
%see line 167 to 168 in this code for the differntial equation
mK(end,1) = 1;

%%

%generates a vector mylambda with increasing exponents (starting with zero),
%which will now be used to define the characteristic polynomial of the
%differential equation from line 167 to 168
syms yl
for fi= 1:(fPasses+1)
   mylambda(fi,1) = yl^(fi-1); 
end

%first generates a vector with the entries for the characteristic
%polynomial and then by forming the sum over the elements yields the
%characteristic polynomial

ychar_pol = sum(mK.*mylambda);

%calcuates the zero points of the characteristic polynomial
mm = solve (ychar_pol == 0);

%if a complex number is calculated only the real part is used
mm = double(mm);

for fk = 1:fPasses
    mm(fk,1) = real (mm(fk,1));
end

%checks whether the calculated zero points (or only the real part) fullfills
%the condition to be a zero point

%for k = 1:P
%    if subs(char_pol,m(3,1)) > 10*10-20
%        error('error in zeropoint calculation')
%    end
%end


%%

%Definition of the sum used for K_0 which is later on used for K_0_serpent
%K_0 is inhomogene coeffcient of the differential equation from line 167 to
%168
fSum_for_K_0 = 0;

for fk = 1:fPasses
    fSum_for_K_0 = fSum_for_K_0 + (mepsilon(fk,1)^fPasses) * (-1)^((fPasses+1)*(fk+1));
end

%Definition of additional constant parameters according to [6] page 27
%these parameters simply change the existing ones in a way that the
%sought after temperature is no longer involved in them
K_0_serpent     =   fN2 * (fN1^(fPasses-1)) * fSum_for_K_0;
U_phi_serpent   =  (fN1/fN2) * ((1-(-1)^fPasses)/2);
U_abs_serpent   = -(fN1/fN2);

%Vector mZ and matrix MD are now used to solve the whole task with the
%equation:
%mD * (M_1; ... ; M_P; theta_1,1''; ... ; theta_1,(P-1)''; Phi_1) =
% = mZ
%M_1 to M_P in this vector are the integration constants needed to solve
%the differential equation from line 167 to 168. theta_1,1'' etc are the
%temperatures at the end of each pass, which are the inlet temperatures of
%the next pass and Phi_1 finally contains the sought after temperature with
%the definition of Phi_1 beeing Phi_1 = (T_1'' - T_1')/(T_2' - T_1')

%Definition of vector mZ according to [6] page 28

mZ(1,1) = 1 - ((K_0_serpent * U_abs_serpent) / mK(1,1));
mZ(2,1) = mZ(1,1);

for fi = 1:(fPasses-1)
    
    %calculates the sum from 1 to k which is used for each element of Z
    for fk = 1:fPasses
        mZ( (2*fi+1) ,1) = mZ( (2*fi+1) ,1) + (mepsilon(fk,1)^fi) * (-1)^((fi+1)*(fk+1));
    end
    
    %switches signs because the equation for the elements of Z starts with
    %a negativ sign
    mZ( (2*fi+1) ,1) = - mZ( (2*fi+1) ,1);
    
    %according to the definition these elements are equal
    mZ( (2*(fi+1)) ,1) = mZ( (2*fi+1) ,1);
    
end

%%
%Definition of Matrix mD according to [6] page 28 to 29
for j = 1:fPasses
    mD(1,j) = 1;
end

for fi = 2:(2*fPasses)
    %fills the elements of mD for i = 3,5,... and j = 1 to P
    if mod(fi,2) ~= 0         
        for j = 1:fPasses
            for fk = 3:((fi+3)/2)
                mD(fi,j) = mD(fi,j) + mB(((fi+1)/2),fk) * (mm(j,1)^(fk-2));
            end
        end
        
    %fills the elements of mD for i = 2,4,... and j = 1 to P    
    else
        for j = 1:fPasses
            mD(fi,j) = mD(fi-1,j) * exp(mm(j,1));
        end
    end
    
end

%fills the elements mD((2*i-1),j) and mD((2*i),j) for i = 1 to P and j =
%(P+1) to (2*P-1)
for fi = 1:fPasses
    for j = (fPasses+1):((2*fPasses)-1)
        mD( (2*fi-1) ,j) = -((1-(-1)^(j-fPasses))/2) * ...
            (mepsilon((j-fPasses),1)^(fi-1) + (((-1)^fi) * ...
             mepsilon((j-fPasses+1),1)^(fi-1)));
        
        mD( (2*fi) ,j) = -((1-(-1)^(j-fPasses+1))/2) * ((((-1)^fi) * ...
            mepsilon((j-fPasses),1)^(fi-1)) + ...
            mepsilon((j-fPasses+1),1)^(fi-1));
    end
end

mD(1,(2*fPasses)) = (K_0_serpent * U_phi_serpent) / mK(1,1);

mD(2,(2*fPasses)) = 1 + ((K_0_serpent * U_phi_serpent) / mK(1,1));

for fi = 2:fPasses
    mD( (2*fi-1) , (2*fPasses) ) = -((1-(-1)^fPasses)/2) * (fN1/fN2) * ...
                                    (mepsilon(fPasses,1)^(fi-1));
    
    mD( (2*fi) , (2*fPasses) ) = mZ((2*fi),1) - ((-1)^fi) * ...
        ((1+(-1)^fPasses)/2) * (fN1/fN2) * (mepsilon(fPasses,1)^(fi-1));
end

%%
%solving the linear system of equations according to [6] page 28 equation
%(16)

%the vector mSolution contains the following values:
%for i = 1:P => mSolution(i,1)= M_i with M_i as the integration constants
%for i = (P+1):(2*P-1) => theta'' 1,(i-P)
%for i = 2*P => Phi_1

%this means the last entry contains information about the outlet 
%temperature for fluid 1

mSolution = mD\mZ;

fOutlet_Temp_1 = (mSolution(2*fPasses)*(fEntry_Temp_2 - ...
                    fEntry_Temp_1)) + fEntry_Temp_1;

fOutlet_Temp_2 = -(fHeat_Capacity_Flow_1/fHeat_Capacity_Flow_2) * ...
                  (fOutlet_Temp_1 - fEntry_Temp_1) + fEntry_Temp_2;

end