%Function used to calculate the outlet temperatures and pressure drop of a
%heat exchanger. (It is also possible to return the thermal resistances)
%
%fluid 1 is always the fluid within the inner pipe(s), if there are pipes.
%
%additional to the inputs explained in the file HX. there are inputs which
%shouldn't be made by a user but come from the V-HAB environment. Every 
%input except for flambda_solid is needed for both fluids which makes a 
%total of 13 flow and material parameters:
%
%The Values for both fluids are required as a struct with the following
%fields filled with the respecitve value for the respective fluid:
%'Massflow' , 'Entry_Temperature' , 'Dynamic_Viscosity' , 'Density' ,
%'Thermal_Conductivity' , 'Heat_Capacity'
%
%for temperature dependant calculations the material values for the fluids
%are required for the average temperature between in and outlet T_m as well
%as the wall temperature T_w.
%These should be saved in the struct values as vectors with the first
%entry beeing the material value for T_m and the second value for T_w
%
%Together alle the inputs are used in the function as follows:
%
%[fOutlet_Temp_1, fOutlet_Temp_2, fDelta_P_1, fDelta_P_2 fR_alpha_i,...
% fR_alpha_o, fR_lambda] = HX(tHX_Parameters, Fluid_1, Fluid_2, fThermalConductivitySolid)
%
%Where the struct tHX_Parameters contains the geometric information from
%the heat exchanger as defined in the parent HX object
%
%with the outputs:
%fOutlet_Temp_1 = temperature after HX for fluid within the pipes (if there
%                 are pipes) in K
%fOutlet_Temp_2 = temperature after HX for sheath fluid (fluid outside
%                 pipes if there are pipes) in K
%fDelta_P_1  = pressure loss of fluid 1 in N/m2
%fDelta_P_2  = pressure loss of fluid 2 in N/m2
%fR_alpha_i  = thermal resistivity from convection on the inner side in W/K
%fR_alpha_o  = thermal resistivity from convection on the inner side in W/K
%fR_lambda   = thermal resistivity from conduction in W/K
function [fOutlet_Temp_1, fOutlet_Temp_2, fDelta_P_1, fDelta_P_2,...
    fR_alpha_i, fR_alpha_o, fR_lambda] = AnnularPassage(~, tHX_Parameters, Fluid_1, Fluid_2, fThermalConductivitySolid)
    
    %calculates the further needed variables for the heat exchanger from
    %the given values
    
    %flow speed for the fluid within the pipes calculated from the massflow
    %with massflow = volumeflow*rho = fw*fA*frho
    fFlowSpeed_Fluid1 = Fluid_1.fMassflow/(pi*(tHX_Parameters.fInnerDiameter/2)^2*Fluid_1.fDensity(1));
    %flow speed of the fluid in the annular passage
    fFlowSpeed_Fluid2 = Fluid_2.fMassflow/(((pi*(tHX_Parameters.fOuterDiameter/2)^2)-(pi*(tHX_Parameters.fInnerDiameter/2)^2))*...
                        Fluid_2.fDensity(1));
    %heat capacity flow according to [1] page 173 equation (8.1)
    fHeat_Capacity_Flow_1 = abs(Fluid_1.fMassflow) * Fluid_1.fSpecificHeatCapacity(1);
    fHeat_Capacity_Flow_2 = abs(Fluid_2.fMassflow) * Fluid_2.fSpecificHeatCapacity(1);
    %Area for the heat exchange
    fArea = pi * tHX_Parameters.fInnerDiameter * tHX_Parameters.fLength;
    
    %uses the function for convection in an annular passage to calculate
    %the outer convection coeffcient (for further information view function
    %help)
    falpha_o = functions.calculateHeatTransferCoefficient.convectionAnnularPassage (tHX_Parameters.fInnerDiameter, tHX_Parameters.fOuterDiameter, tHX_Parameters.fLength,...
               fFlowSpeed_Fluid2, Fluid_2.fDynamicViscosity, Fluid_2.fDensity,...
               Fluid_2.fThermalConductivity, Fluid_2.fSpecificHeatCapacity, 0);
    
    %uses the function for convection in a pipe to calculate the inner
    %convection coeffcient (for further information view function help)
    falpha_pipe = functions.calculateHeatTransferCoefficient.convectionPipe ((2*tHX_Parameters.fInternalRadius), tHX_Parameters.fLength, fFlowSpeed_Fluid1,...
                  Fluid_1.fDynamicViscosity, Fluid_1.fDensity,...
                  Fluid_1.fThermalConductivity, Fluid_1.fSpecificHeatCapacity, 1);  
    
    %uses the function for thermal resisitvity to calculate the resistance 
    %from heat conduction (for further information view function help)
    fR_lambda = functions.calculateHeatTransferCoefficient.conductionResistance(fThermalConductivitySolid, 0, tHX_Parameters.fInternalRadius,...
                (tHX_Parameters.fInnerDiameter/2), tHX_Parameters.fLength);
   
    %calculates the thermal resistance from convection in the annular gap
    fR_alpha_o = 1/(fArea * falpha_o);
    
    %calculates the thermal resistance from convection in the pipe
    fR_alpha_i = 1/(fArea * falpha_pipe);
    
    %calculates the heat exchange coeffcient fU
    fU = 1/(fArea * (fR_alpha_o + fR_alpha_i + fR_lambda));
    
    %If heat exchanger coefficient U is zero there can be no heat transfer
    %between the two fluids
    if fU == 0
        fOutlet_Temp_1 = Fluid_1.fEntryTemperature;
        fOutlet_Temp_2 = Fluid_2.fEntryTemperature;
    else
    %uses the function for counter flow heat exchangers to calculate the
    %outlet tempratures. Since this function differentiates not between the
    %fluid in the pipes and outside the pipes but between hot and cold a if
    %function is needed to discren which fluid is hotter. (for further
    %information view function help)
        if tHX_Parameters.bParallelFlow
            hHandle = str2func('temperature_parallelflow');
        else
            hHandle = str2func('temperature_counterflow');
        end
        
        if Fluid_1.fEntryTemperature > Fluid_2.fEntryTemperature
            [fOutlet_Temp_2, fOutlet_Temp_1] =  hHandle(fArea, fU, fHeat_Capacity_Flow_2, fHeat_Capacity_Flow_1,...
             Fluid_2.fEntryTemperature, Fluid_1.fEntryTemperature);
        else
            [fOutlet_Temp_1, fOutlet_Temp_2] = hHandle(fArea, fU, fHeat_Capacity_Flow_1, fHeat_Capacity_Flow_2,...
             Fluid_1.fEntryTemperature, Fluid_2.fEntryTemperature);
        end
    end
    
    %calculation of pressure loss for both fluids:
    fDelta_P_1 = functions.calculateDeltaPressure.Pipe((2*tHX_Parameters.fInternalRadius), tHX_Parameters.fLength, fFlowSpeed_Fluid1,...
                    Fluid_1.fDynamicViscosity, Fluid_1.fDensity, 0);
    fDelta_P_2 = functions.calculateDeltaPressure.Pipe((tHX_Parameters.fOuterDiameter - tHX_Parameters.fInnerDiameter), tHX_Parameters.fLength,...
                    fFlowSpeed_Fluid2, Fluid_2.fDynamicViscosity,...
                    Fluid_2.fDensity, 2, tHX_Parameters.fOuterDiameter);
end