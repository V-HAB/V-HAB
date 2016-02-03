%Calculates the outlet temperatures of a crossflow heat exchanger with zero
%to n rows of pipes. If pipes are used fluid 1 stands for the fluid inside
%the pipes.
%The function uses the following input parameters
%
%fN_Rows           = Number of pipe rows, for n=0 pure crossflow is assumed
%fArea             = Area of the heat exchanger in m²
%fU                = heat exchange coefficient in W/m²K
%fHeat_Cap_Flow_1  = heat capacity flow of mixed stream in W/K
%fHeat_Cap_Flow_2  = heat capacity flow of unmixed stream in W/K
%fEntry_Temp_1     = inlet temperature of fluid 1 in K (inside the pipes)
%fEntry_Temp_2     = inlet temperature of fluid 2 in K
%
%Additional input required only if more than one pipe row is used:
%
%x0 = broadness of the inlet of fluid 2 in m
%
%These arguments are used in the function as follows:
%
%[fOutlet_Temp_1, fOutlet_Temp_2]=temperature_crossflow (fN_Rows, fArea,...
%     fU, fHeat_Cap_Flow_1, fHeat_Cap_Flow_2, fEntry_Temp_1, fEntry_Temp_2)
%
%With the output [fOutlet_Temp_1, fOutlet_Temp_2] in K

function [fOutlet_Temp_1, fOutlet_Temp_2] = temperature_crossflow ...
          (fN_Rows, fArea, fU, fHeat_Cap_Flow_1, fHeat_Cap_Flow_2,...
          fEntry_Temp_1, fEntry_Temp_2, x0)

%checks whether the input variable for the number of pipe rows is 
%negative and in that case returns an error and aborts the program
if fN_Rows < 0
    error('a negative number for pipe rows is not possible')
end

%%
%definition of generally used variables

%Number of Transferunits fluid 1 and fluid 2
fNTU_1 = (fU*fArea)/fHeat_Cap_Flow_1;                          
fNTU_2 = (fU*fArea)/fHeat_Cap_Flow_2;
%Equation from "Wärme- und Stoffübertragung" Baehr page 58 table 1.4


%%
%pure crossflow (no pipes used)

%the source	“Eine neue Formel für den Wärmedurchgang im Kreuzstrom” from
%W. Nußelt fN_Rows the journal "Technische Mechanik und Thermodynamik"
%pp. 417-422, December 1930 will from now on be identified by [2]

%discerns the input for the number of pipe rows, if it is zero and no pipe
%row is used it is the pure crossflow case
if fN_Rows == 0
    %Number of summands for the series
    fSummands = 10;                                 
    %The number 10 was picked because from this point onward an increase
    %in summands will have no effect on the first 4 decimal places, which
    %means that it has only marginal effects to increase the summands any 
    %further

    %defines two symbolic functions for the dimensionless temperatures
    %over the variables Xi and Eta
    syms yTheta_2(yXi,yEta) yTheta_1(yXi,yEta)

    %preallocation of the vector Phi_n and Variable_1
    yPhi_n = zeros(fSummands,1);
    yVariable_1 = zeros(fSummands,1);

    %calculation of the summands Phi_1 to Phi_s used to solve the integral
    %equation for the temperature field
    for fk = 1:fSummands
    
        %calculates the sum used in the defintion of Phi_n
        yVariable_1(fk,1) = (1/factorial(fk-1))*(fNTU_1^(fk-1))*...
                            (yXi^(fk-1))*exp(-fNTU_1*yXi);
        
        yVariable_2 = sum(yVariable_1);
        %Equation from source [2], equation (19)
        
        %finishes the calculation of the summands and saves them into
        %the vector yPhi_n
        yPhi_n(fk,1) = (1/factorial(fk))*(fNTU_2^fk)*(yEta^fk)*...
                        exp(-fNTU_2*yEta)*(1-yVariable_2);
        %Equation from source [2], equation (19)
    
    end

    %TO DO: could be possible to do this without sym and not for every
    %point in the HX and without using a integral.
    %function definition for the dimensionless temperature of fluid 2
    yTheta_2(yXi, yEta) = exp(-fNTU_2*yEta)+sum(yPhi_n);
    %Equation from source [2], equation (20)

    %function for temperature T2 at any point of the heat exchanger
    yT2 = (yTheta_2 .* (fEntry_Temp_2 - fEntry_Temp_1))+fEntry_Temp_1;
    %Equation from source [2], equation (7)

    %calculation of the average outlet temperature of fluid 2 by 
    %integration of the function for fOutlet_Temp_2 over the outlet
    fOutlet_Temp_2 = int(yT2(yXi,1),yXi,0,1);
    %Equation from source [2], equation (23)

    %conversion of the sym value for the outlet temperature into double
    %value. The value for T2_1 is an average value over the outlet
    fOutlet_Temp_2 = double(fOutlet_Temp_2);
    
    %equation for the average outlet temperature of fluid 1 derived from
    %the heat flow transferred fN_Rows the heat exchanger
    fOutlet_Temp_1 = fEntry_Temp_1 - (fHeat_Cap_Flow_2/fHeat_Cap_Flow_1)*...
                    (fOutlet_Temp_2 - fEntry_Temp_2);
    %Equation from "Wärmeübertragung" Polifke page 176 equation (8.9) 
    

%%
%crossflow with up to n rows of pipes
%Fluid 1 is the fluid which flows inside the pipes while fluid 2 flows
%outside of them

%the source "Thermische Auslegung von Kreuzstromwärmeübertragern" 
%from Schedwill will from now on be identified as [5]

%discerns the input for the number of pipe rows, if it is bigger than one
%up to n pipe rows are used and it is the n pipe rows crossflow case
else
    
    %definition of the constant parameter epsilon used to calculate the
    %outlet temperature of fluid 2
    %This parameter simply combines values to make calculation easier
    %afterwards, it doesn't have a physical significance
    fepsilon = ((fNTU_1*fN_Rows)/(fNTU_2*x0))*(1-exp(-fNTU_2/fN_Rows));  
    %Equation from [5] page 73 equation (4.118)
    
    %preallocation of the values used to calculate the sums used in 
    %the equation for the outlet temperature of fluid 2
    yVariable_1 = zeros((fN_Rows-1),1);
    yVariable_2 = zeros(fN_Rows,1);
    yVariable_3 = zeros(fN_Rows,1);
    
    %definition of the equation for the average outlet temperature of 
    %fluid 2 according to [5] page 78 equation 4.151
    
    %since the equation contains sums from r to m, m to p and p to (n-1)
    %three for loops are necessary
    for fp = 1:(fN_Rows-1)
        
        for fm = 0:fp
           
            for fr = 0:fm
               
                %calculates the first sum from r=0 to m by computing each 
                %element and saving it into the vector yVariable_3. 
                %Afterwards the sum can be calculated using the sum() 
                %command over yVariable_3
                yVariable_3((fr+1),1) = ((fepsilon*x0)^fr)/factorial(fr);
                
            end
            
            %calculates the second sum from m=0 to p which contains the
            %first sum saved in yVariable_3
            yVariable_2((fm+1),1) = factorial(fp)/(factorial(fm)*...
                factorial(fp-fm))*((1-exp(-fNTU_2/fN_Rows))^fm)*...
                exp(-(fp-fm)*fNTU_2/fN_Rows)*sum(yVariable_3);
            
        end
        
        %saves each Variable_2 which is calculated for every p into the 
        %vector Variable_1 to calculate the third sum from p=1 to (n-1)
        yVariable_1(fp,1) = yVariable_2;
        
    end
    
    %calculates the outlet temperature of fluid 2 using the sum over
    %yVariable_3
    fOutlet_Temp_2 = fEntry_Temp_2 + (fEntry_Temp_1 - fEntry_Temp_2)*...
        (fHeat_Cap_Flow_1/(fN_Rows*fHeat_Cap_Flow_2))*...
        (fN_Rows-(1+sum(yVariable_1))*exp(-fepsilon*x0));
    %Equation from [5] page 78 equation 4.151
    
    %equation for the average outlet temperature of fluid 1 derived from
    %the heat flow transferred fN_Rows the heat exchanger
    fOutlet_Temp_1 =fEntry_Temp_1 - (fHeat_Cap_Flow_2/fHeat_Cap_Flow_1)*...
                    (fOutlet_Temp_2 - fEntry_Temp_2);
    %Equation from "Wärmeübertragung" Polifke page 176 equation (8.9)
    if isnan(fOutlet_Temp_1) ||  isnan(fOutlet_Temp_2)
        keyboard()
    end
    
    
end
end