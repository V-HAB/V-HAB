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
% fR_alpha_o, fR_lambda] = HX(oHX, Fluid_1, Fluid_2, fThermal_Cond_Solid)
%
%Where the object oHX containing mHX and sHX_type with the user inputs is
%automatically set in the HX.m file (also see that file for more
%information about which heat exchangers can be calculated and what user
%inputs are required)
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
    fR_alpha_i, fR_alpha_o, fR_lambda] = ...
    HX_main(oHX, Fluid_1, Fluid_2, fThermal_Cond_Solid)

%the source "Waermeuebertragung" Polifke will from now on be defined as [1]

%Please note generally for the convection coeffcient functions: in some of
%these functions a decision wether nondisturbed flow should be assumed or 
%not is necessary. In this programm this has already been set using the
%respective fConfig variables in these cases to use the most probable case.
%So for example in case of a pipe bundle disturbed flow is assumed inside 
%of it because generally a single pipe with a different diameter will lead 
%to the bundle. 
%But if a single pipe was used non disturbed flow is assumed since the pipe
%leading to it will most likely have the same shape and diameter.

%gets the fluid values from the input structs
fMassFlow1              = Fluid_1.Massflow;
fEntry_Temp1            = Fluid_1.Entry_Temperature;
fDyn_Visc_Fluid1        = Fluid_1.Dynamic_Viscosity;
fDensity_Fluid1         = Fluid_1.Density;
fThermal_Cond_Fluid1    = Fluid_1.Thermal_Conductivity;
fC_p_Fluid1             = Fluid_1.Heat_Capacity;

fMassFlow2              = Fluid_2.Massflow;
fEntry_Temp2            = Fluid_2.Entry_Temperature;
fDyn_Visc_Fluid2        = Fluid_2.Dynamic_Viscosity;
fDensity_Fluid2         = Fluid_2.Density;
fThermal_Cond_Fluid2    = Fluid_2.Thermal_Conductivity;
fC_p_Fluid2             = Fluid_2.Heat_Capacity;

%gets the vector mHX with the geometry information from the struct
mHX = oHX.mHX;
sHX_type = oHX.sHX_type;


%%
if strcmpi(sHX_type, 'counter annular passage')
    
    %allocates the entries in the mHX vector from the user entry to the
    %respective variables
    fD_i = mHX(1);
    fD_o = mHX(2);
    fR_i = mHX(3);
    fLength = mHX(4);
    
    %calculates the further needed variables for the heat exchanger from
    %the given values
    
    %flow speed for the fluid within the pipes calculated from the massflow
    %with massflow = volumeflow*rho = fw*fA*frho
    fFlowSpeed_Fluid1 = fMassFlow1/(pi*(fD_i/2)^2*fDensity_Fluid1(1));
    %flow speed of the fluid in the annular passage
    fFlowSpeed_Fluid2 = fMassFlow2/(((pi*(fD_o/2)^2)-(pi*(fD_i/2)^2))*...
                        fDensity_Fluid2(1));
    %heat capacity flow according to [1] page 173 equation (8.1)
    fHeat_Capacity_Flow_1 = abs(fMassFlow1) * fC_p_Fluid1(1);
    fHeat_Capacity_Flow_2 = abs(fMassFlow2) * fC_p_Fluid2(1);
    %Area for the heat exchange
    fArea = pi * fD_i * fLength;
    
    %uses the function for convection in an annular passage to calculate
    %the outer convection coeffcient (for further information view function
    %help)
    falpha_o = convection_annular_passage (fD_i, fD_o, fLength,...
               fFlowSpeed_Fluid2, fDyn_Visc_Fluid2, fDensity_Fluid2,...
               fThermal_Cond_Fluid2, fC_p_Fluid2, 0);
    
    %uses the function for convection in a pipe to calculate the inner
    %convection coeffcient (for further information view function help)
    falpha_pipe = convection_pipe ((2*fR_i), fLength, fFlowSpeed_Fluid1,...
                  fDyn_Visc_Fluid1, fDensity_Fluid1,...
                  fThermal_Cond_Fluid1, fC_p_Fluid1, 1);  
    
    %uses the function for thermal resisitvity to calculate the resistance 
    %from heat conduction (for further information view function help)
    fR_lambda = thermal_resistivity(fThermal_Cond_Solid, 0, fR_i,...
                (fD_i/2), fLength);
   
    %calculates the thermal resistance from convection in the annular gap
    fR_alpha_o = 1/(fArea * falpha_o);
    
    %calculates the thermal resistance from convection in the pipe
    fR_alpha_i = 1/(fArea * falpha_pipe);
    
    %calculates the heat exchange coeffcient fU
    fU = 1/(fArea * (fR_alpha_o + fR_alpha_i + fR_lambda));
    
    %If heat exchanger coefficient U is zero there can be no heat transfer
    %between the two fluids
    if fU == 0
        fOutlet_Temp_1 = fEntry_Temp1;
        fOutlet_Temp_2 = fEntry_Temp2;
    else
    %uses the function for counter flow heat exchangers to calculate the
    %outlet tempratures. Since this function differentiates not between the
    %fluid in the pipes and outside the pipes but between hot and cold a if
    %function is needed to discren which fluid is hotter. (for further
    %information view function help)
        if fEntry_Temp1 > fEntry_Temp2
            [fOutlet_Temp_2, fOutlet_Temp_1] = temperature_counterflow ...
            (fArea, fU, fHeat_Capacity_Flow_2, fHeat_Capacity_Flow_1,...
             fEntry_Temp2, fEntry_Temp1);
        else
            [fOutlet_Temp_1, fOutlet_Temp_2] = temperature_counterflow...
            (fArea, fU, fHeat_Capacity_Flow_1, fHeat_Capacity_Flow_2,...
             fEntry_Temp1, fEntry_Temp2);
        end
    end
    
    %calculation of pressure loss for both fluids:
    fDelta_P_1 = pressure_loss_pipe((2*fR_i), fLength, fFlowSpeed_Fluid1,...
                    fDyn_Visc_Fluid1, fDensity_Fluid1, 0);
    fDelta_P_2 = pressure_loss_pipe((fD_o - fD_i), fLength,...
                    fFlowSpeed_Fluid2, fDyn_Visc_Fluid2,...
                    fDensity_Fluid2, 2, fD_o);

%%    
elseif strcmpi(sHX_type, 'counter plate')
    %allocates the entries in the mHX vector from the user entry to the
    %respective variables
    fBroadness  = mHX(1);
    fHeight_1  = mHX(2);
    fHeight_2  = mHX(3);
    fLength     = mHX(4);
    fThickness  = mHX(5);
    
    %calculates the further needed variables for the heat exchanger from
    %the given values
    
    %flow speed for the fluids within calculated from the massflow
    %with massflow = volumeflow*rho = fw*fA*frho
    fFlowSpeed_Fluid1 = fMassFlow1/(fHeight_1 * fBroadness *...
                        fDensity_Fluid1(1));
    fFlowSpeed_Fluid2 = fMassFlow2/(fHeight_2 * fBroadness *...
                        fDensity_Fluid2(1));
    %heat capacity flow according to [1] page 173 equation (8.1)
    fHeat_Capacity_Flow_1 = abs(fMassFlow1) * fC_p_Fluid1(1);
    fHeat_Capacity_Flow_2 = fMassFlow2 * fC_p_Fluid2(1);
    %calculates the area of the heat exchange
    fArea = fBroadness*fLength;
    
    %uses the function for convection along a plate to calculate
    %the convection coeffcient for fluid 1 (for further information view 
    %function help)
    falpha_1 = convection_plate (fLength, fFlowSpeed_Fluid1,...
                fDyn_Visc_Fluid1, fDensity_Fluid1, fThermal_Cond_Fluid1,...
                fC_p_Fluid1);

    %uses the function for convection along a plate to calculate
    %the convection coeffcient for fluid 2 (for further information view 
    %function help)
    falpha_2 = convection_plate (fLength, fFlowSpeed_Fluid2,...
                    fDyn_Visc_Fluid2, fDensity_Fluid2,...
                    fThermal_Cond_Fluid2, fC_p_Fluid2);
    
    %uses the function for thermal resisitvity to calculate the resistance 
    %from heat conduction (for further information view function help)    
    fR_lambda = thermal_resistivity(fThermal_Cond_Solid, 2, fArea,...
                    fThickness); 
    
    %calculates the thermal resistance from convection on both sides of the
    %plate
    fR_alpha_1 = 1/(fArea * falpha_1);
    fR_alpha_2 = 1/(fArea * falpha_2);

    %calculates the heat exchange coeffcient fU
    fU = 1/(fArea * (fR_alpha_1 + fR_alpha_2 + fR_lambda));

    %If heat exchanger coefficient U is zero there can be no heat transfer
    %between the two fluids
    if fU == 0
        fOutlet_Temp_1 = fEntry_Temp1;
        fOutlet_Temp_2 = fEntry_Temp2;
    else
    %uses the function for counter flow heat exchangers to calculate the
    %outlet tempratures. Since this function differentiates not between the
    %fluid in the pipes and outside the pipes but between hot and cold a if
    %function is needed to discren which fluid is hotter. (for further
    %information view function help)
        if fEntry_Temp1 > fEntry_Temp2
            [fOutlet_Temp_2, fOutlet_Temp_1] = temperature_counterflow ...
            (fArea, fU, fHeat_Capacity_Flow_2, fHeat_Capacity_Flow_1,...
             fEntry_Temp2, fEntry_Temp1);
        else
            [fOutlet_Temp_1, fOutlet_Temp_2] = temperature_counterflow...
            (fArea, fU, fHeat_Capacity_Flow_1, fHeat_Capacity_Flow_2,...
             fEntry_Temp1, fEntry_Temp2);
        end
    end
    
    %calculation of pressure loss for both fluids:
    fDelta_P_1 = pressure_loss_pipe(((4*fBroadness*fHeight_1)/...
                  (2*fBroadness+2*fHeight_1)) , fLength,...
                  fFlowSpeed_Fluid1, fDyn_Visc_Fluid1, fDensity_Fluid1, 0);
    fDelta_P_2 = pressure_loss_pipe(((4*fBroadness*fHeight_1)/...
                  (2*fBroadness+2*fHeight_2)) , fLength,...
                  fFlowSpeed_Fluid2, fDyn_Visc_Fluid2, fDensity_Fluid2, 1);

%%    
elseif strcmpi(sHX_type, 'counter pipe bundle')

    %allocates the entries in the mHX vector from the user entry to the
    %respective variables
    fD_i    = mHX(1);
    fD_o    = mHX(2);
    fD_Shell    = mHX(3);
    fLength = mHX(4);
    fN_Pipes= mHX(5);
    fs_1    = mHX(6);
    fs_2    = mHX(7);
   
    %checks user input to prevent strange results (like negative areas) in
    %the following code
    if (pi*(fD_Shell/2)^2) < (fN_Pipes*(pi*(fD_o/2)^2))
        error('shell area smaller than sum of pipe areas, check inputs')
    end
    
    %calculates the further needed variables for the heat exchanger from
    %the given values
    
    %flow speed for the fluid calculated from the massflow
    %with massflow = volumeflow*rho = fw*fA*frho
    fFlowSpeed_Fluid1 = fMassFlow1/(fN_Pipes*pi*(fD_i/2)^2 *...
                        fDensity_Fluid1(1));
    fFlowSpeed_Fluid2 = fMassFlow2/(((pi*(fD_Shell/2)^2) -...
                        (fN_Pipes*(pi*(fD_o/2)^2))) * fDensity_Fluid2(1));
    %heat capacity flow according to [1] page 173 equation (8.1)
    fHeat_Capacity_Flow_1 = abs(fMassFlow1) * fC_p_Fluid1(1);
    fHeat_Capacity_Flow_2 = abs(fMassFlow2) * fC_p_Fluid2(1);
    %calculates the area of the heat exchange
    fArea = (fN_Pipes*pi*(fD_i/2)*fLength);
    
    %uses the function for convection inside a pipe to calculate the heat
    %exchange outside the pipe bundle. This is done by calculating the
    %hydraulic diameter of the shell together with the pipes in the bundle
    
    fShell_Area         = pi*(fD_Shell/2)^2;
    fOuter_Bundle_Area  = fN_Pipes*pi*(fD_o/2)^2;
    fOuter_Hydraulic_Diameter = 4*(fShell_Area - fOuter_Bundle_Area)/...
                (pi*fD_Shell + fN_Pipes*pi*fD_o);
    
    falpha_o = convection_pipe(fOuter_Hydraulic_Diameter, fLength,...
                fFlowSpeed_Fluid2, fDyn_Visc_Fluid2, fDensity_Fluid2,...
                fThermal_Cond_Fluid2, fC_p_Fluid2, 0);
    
    %uses the function for convection in a pipe to calculate the inner
    %convection coeffcient (for further information view function help)
    falpha_pipe = convection_pipe (fD_i, fLength, fFlowSpeed_Fluid1,...
                    fDyn_Visc_Fluid1, fDensity_Fluid1,...
                    fThermal_Cond_Fluid1, fC_p_Fluid1, 0);

    %uses the function for thermal resisitvity to calculate the resistance 
    %from heat conduction (for further information view function help)
    fR_lambda = thermal_resistivity(fThermal_Cond_Solid, 0, (fD_i/2),...
                    (fD_o/2), fLength);

    %calculates the thermal resistance from convection outside the pipes
    fR_alpha_i = 1/(fArea * falpha_pipe);

    %calculates the thermal resistance from convection in the pipe
    fR_alpha_o = 1/(fArea * falpha_o);

    %calculates the heat exchange coefficient fU
    fU = 1/(fArea * (fR_alpha_o + fR_alpha_i + fR_lambda));

    %If heat exchange coefficient U is zero there can be no heat transfer
    %between the two fluids
    if fU == 0
        fOutlet_Temp_1 = fEntry_Temp1;
        fOutlet_Temp_2 = fEntry_Temp2;
    else
    %uses the function for counter flow heat exchangers to calculate the
    %outlet temperatures. Since this function differentiates not between    
    %the fluid in the pipes and outside the pipes but between hot and cold 
    %a if function is needed to discern which fluid is hotter. (for further
    %information view function help)  
        if fEntry_Temp1 > fEntry_Temp2
            [fOutlet_Temp_2 , fOutlet_Temp_1] = temperature_counterflow ...
            (fArea, fU, fHeat_Capacity_Flow_2, fHeat_Capacity_Flow_1,...
             fEntry_Temp2, fEntry_Temp1);
        else
            [fOutlet_Temp_1, fOutlet_Temp_2] = temperature_counterflow ...
            (fArea, fU, fHeat_Capacity_Flow_1, fHeat_Capacity_Flow_2,...
             fEntry_Temp1, fEntry_Temp2);
        end
    end

    %calculation of pressure loss for both fluids:
    fDelta_P_1_OverPipe = pressure_loss_pipe(fD_i , fLength,...
                            fFlowSpeed_Fluid1, fDyn_Visc_Fluid1,...
                            fDensity_Fluid1, 0);
    fDelta_P_1_InOut = pressure_loss_InOut_bundle(fD_i, fs_1, fs_2,...
                            fFlowSpeed_Fluid1, fDyn_Visc_Fluid1,...
                            fDensity_Fluid1);
    
    fDelta_P_1 = fDelta_P_1_OverPipe + fDelta_P_1_InOut;
    
    fDelta_P_2 = pressure_loss_pipe(fOuter_Hydraulic_Diameter, fLength,...
                  fFlowSpeed_Fluid2, fDyn_Visc_Fluid2, fDensity_Fluid2, 0);

%%
elseif strcmpi(sHX_type, 'parallel annular passage')
    
    %allocates the entries in the mHX vector from the user entry to the
    %respective variables
    fD_i = mHX(1);
    fD_o = mHX(2);
    fR_i = mHX(3);
    fLength = mHX(4);
    
    %calculates the further needed variables for the heat exchanger from
    %the given values
    
    %flow speed for the fluids calculated from the massflow
    %with massflow = volumeflow*rho = fw*fA*frho
    fFlowSpeed_Fluid1 = fMassFlow1/(pi*(fD_i/2)^2*fDensity_Fluid1(1));
    fFlowSpeed_Fluid2 = fMassFlow2/(((pi*(fD_o/2)^2)-(pi*(fD_i/2)^2))*...
                        fDensity_Fluid2(1));
    %heat capacity flow according to [1] page 173 equation (8.1)
    fHeat_Capacity_Flow_1 = abs(fMassFlow1) * fC_p_Fluid1(1);
    fHeat_Capacity_Flow_2 = abs(fMassFlow2) * fC_p_Fluid2(1);
    %calculates the area of the heat exchange
    fArea = pi * fD_i * fLength;
    
    %uses the function for convection in an annular passage to calculate
    %the outer convection coeffcient (for further information view function
    %help)
    falpha_o = convection_annular_passage (fD_i, fD_o, fLength,...
                fFlowSpeed_Fluid2, fDyn_Visc_Fluid2, fDensity_Fluid2,...
                fThermal_Cond_Fluid2, fC_p_Fluid2, 0);
 
    %uses the function for convection in a pipe to calculate the inner
    %convection coeffcient (for further information view function help)
    falpha_pipe = convection_pipe (2*fR_i, fLength, fFlowSpeed_Fluid1,...
                    fDyn_Visc_Fluid1, fDensity_Fluid1,...
                    fThermal_Cond_Fluid1, fC_p_Fluid1, 1);

    %uses the function for thermal resisitvity to calculate the resistance 
    %from heat conduction (for further information view function help)
    fR_lambda = thermal_resistivity(fThermal_Cond_Solid, 0, fR_i,...
                    (fD_i/2), fLength);

    %calculates the thermal resistance from convection in the annular gap
    fR_alpha_i = 1/(fArea * falpha_pipe);

    %calculates the thermal resistance from convection in the pipe
    fR_alpha_o = 1/(fArea * falpha_o);

    %calculates the heat exchange coeffcient fU
    fU = 1/(fArea * (fR_alpha_o + fR_alpha_i + fR_lambda));

    %If heat exchange coefficient U is zero there can be no heat transfer
    %between the two fluids
    if fU == 0
        fOutlet_Temp_1 = fEntry_Temp1;
        fOutlet_Temp_2 = fEntry_Temp2;
    else
    %uses the function for parallel flow heat exchangers to calculate the
    %outlet tempratures. Since this function differentiates not between the
    %fluid in the pipes and outside the pipes but between hot and cold a if
    %function is needed to discren which fluid is hotter.(for further
    %information view function help)
        if fEntry_Temp1 > fEntry_Temp2
            [fOutlet_Temp_2, fOutlet_Temp_1] = temperature_parallelflow...
            (fArea, fU, fHeat_Capacity_Flow_2, fHeat_Capacity_Flow_1,...
             fEntry_Temp2, fEntry_Temp1);
        else
            [fOutlet_Temp_1, fOutlet_Temp_2] = temperature_parallelflow...
            (fArea, fU, fHeat_Capacity_Flow_1, fHeat_Capacity_Flow_2,...
             fEntry_Temp1, fEntry_Temp2);
        end
    end

    %calculation of pressure loss for both fluids:
    fDelta_P_1 = pressure_loss_pipe((2*fR_i), fLength,...
                    fFlowSpeed_Fluid1, fDyn_Visc_Fluid1,...
                    fDensity_Fluid1, 0);
    fDelta_P_2 = pressure_loss_pipe((fD_o - fD_i), fLength,...
                    fFlowSpeed_Fluid2, fDyn_Visc_Fluid2,...
                    fDensity_Fluid2, 2, fD_o);
  
%%
elseif strcmpi(sHX_type, 'parallel plate')
    
    %allocates the entries in the mHX vector from the user entry to the
    %respective variables
    fBroadness  = mHX(1);
    fHeight_1  = mHX(2);
    fHeight_2  = mHX(3);
    fLength     = mHX(4);
    fThickness  = mHX(5);
    
    %calculates the further needed variables for the heat exchanger from
    %the given values
    
    %flow speed for the fluids calculated from the massflow
    %with massflow = volumeflow*rho = fw*fA*frho
    fFlowSpeed_Fluid1 = fMassFlow1/(fHeight_1 * fBroadness *...
                        fDensity_Fluid1(1));
    fFlowSpeed_Fluid2 = fMassFlow2/(fHeight_2 * fBroadness *...
                        fDensity_Fluid2(1));
    %heat capacity flow according to [1] page 173 equation (8.1)
    fHeat_Capacity_Flow_1 = abs(fMassFlow1) * fC_p_Fluid1(1);
    fHeat_Capacity_Flow_2 = abs(fMassFlow2) * fC_p_Fluid2(1);
    %calculates the area of the heat exchange
    fArea = fBroadness*fLength;
    
    %uses the function for convection along a plate to calculate the 
    %convection coeffcients (for further information view function help)
    falpha_o = convection_plate (fLength, fFlowSpeed_Fluid1,...
                fDyn_Visc_Fluid1, fDensity_Fluid1, fThermal_Cond_Fluid1,...
                fC_p_Fluid1);
    falpha_pipe = convection_plate (fLength, fFlowSpeed_Fluid2,...
                    fDyn_Visc_Fluid2, fDensity_Fluid2,...
                    fThermal_Cond_Fluid2, fC_p_Fluid2);
  
    %uses the function for thermal resisitvity to calculate the resistance 
    %from heat conduction (for further information view function help)    
    fR_lambda = thermal_resistivity(fThermal_Cond_Solid, 2, fArea,...
                    fThickness);
   
    %calculates the thermal resistance from convection on both sides of the
    %plate
    fR_alpha_i = 1/(fArea * falpha_pipe);
    fR_alpha_o = 1/(fArea * falpha_o);
    
    %calculates the heat exchange coeffcient fU
    fU = 1/(fArea * (fR_alpha_o + fR_alpha_i + fR_lambda));

    %If heat exchange coefficient U is zero there can be no heat transfer
    %between the two fluids
    if fU == 0
        fOutlet_Temp_1 = fEntry_Temp1;
        fOutlet_Temp_2 = fEntry_Temp2;
    else
    %uses the function for parallel flow heat exchangers to calculate the
    %outlet tempratures. Since this function differentiates not between the
    %fluid in the pipes and outside the pipes but between hot and cold a if
    %function is needed to discren which fluid is hotter. (for further
    %information view function help)
        if fEntry_Temp1 > fEntry_Temp2
            [fOutlet_Temp_2, fOutlet_Temp_1] = temperature_parallelflow...
            (fArea, fU, fHeat_Capacity_Flow_2, fHeat_Capacity_Flow_1,...
             fEntry_Temp2, fEntry_Temp1);
        else
            [fOutlet_Temp_1, fOutlet_Temp_2] = temperature_parallelflow...
            (fArea, fU, fHeat_Capacity_Flow_1, fHeat_Capacity_Flow_2,...
             fEntry_Temp1, fEntry_Temp2);
        end
    end
    
    %calculation of pressure loss for both fluids:
    fDelta_P_1 = pressure_loss_pipe(((4*fBroadness*fHeight_1)/...
                  (2*fBroadness+2*fHeight_1)), fLength,...
                  fFlowSpeed_Fluid1, fDyn_Visc_Fluid1, fDensity_Fluid1, 0);
    fDelta_P_2 = pressure_loss_pipe(((4*fBroadness*fHeight_1)/...
                  (2*fBroadness+2*fHeight_2)) , fLength,...
                  fFlowSpeed_Fluid2, fDyn_Visc_Fluid2, fDensity_Fluid2, 1);
    
%%
elseif strcmpi(sHX_type, 'parallel pipe bundle')
    
    %allocates the entries in the mHX vector from the user entry to the
    %respective variables
    fD_i        = mHX(1);
    fD_o        = mHX(2);
    fD_Shell    = mHX(3);
    fLength     = mHX(4);
    fN_Pipes    = mHX(5);
    fs_1        = mHX(6);
    fs_2        = mHX(7);
  
    %calculates the further needed variables for the heat exchanger from
    %the given values
    
    if (pi*(fD_Shell/2)^2) < (fN_Pipes*(pi*(fD_o/2)^2))
        error('shell area smaller than sum of pipe areas, cheack inputs')
    end
    
    %flow speed for the fluids calculated from the massflow
    %with massflow = volumeflow*rho = fw*fA*frho
    fFlowSpeed_Fluid1 = fMassFlow1/(fN_Pipes*pi*(fD_i/2)^2 *...
                        fDensity_Fluid1(1));
    fFlowSpeed_Fluid2 = fMassFlow2/(((pi*(fD_Shell/2)^2) -...
                        (fN_Pipes*(pi*(fD_o/2)^2))) * fDensity_Fluid2(1));
    %heat capacity flow according to [1] page 173 equation (8.1)
    fHeat_Capacity_Flow_1 = abs(fMassFlow1) * fC_p_Fluid1(1);
    fHeat_Capacity_Flow_2 = abs(fMassFlow2) * fC_p_Fluid2(1);
    %calculates the area of the heat exchange
    fArea = (fN_Pipes*pi*(fD_i/2)*fLength);

    %uses the function for convection inside a pipe to calculate the heat
    %exchange outside the pipe bundle. This is done by calculating the
    %hydraulic diameter of the shell together with the pipes in the bundle
    
    fShell_Area         = pi*(fD_Shell/2)^2;
    fOuter_Bundle_Area  = fN_Pipes*pi*(fD_o/2)^2;
    fOuter_Hydraulic_Diameter = 4*(fShell_Area - fOuter_Bundle_Area)/...
                (pi*fD_Shell + fN_Pipes*pi*fD_o);
    
    falpha_o = convection_pipe(fOuter_Hydraulic_Diameter, fLength,...
                fFlowSpeed_Fluid2, fDyn_Visc_Fluid2, fDensity_Fluid2,...
                fThermal_Cond_Fluid2, fC_p_Fluid2, 0);
    
    %uses the function for convection in a pipe to calculate the inner
    %convection coeffcient (for further information view function help)
    falpha_pipe = convection_pipe (fD_i, fLength, fFlowSpeed_Fluid1,...
                    fDyn_Visc_Fluid1, fDensity_Fluid1,...
                    fThermal_Cond_Fluid1, fC_p_Fluid1, 0);
  
    %uses the function for thermal resisitvity to calculate the resistance 
    %from heat conduction (for further information view function help)
    fR_lambda = thermal_resistivity(fThermal_Cond_Solid, 0, (fD_i/2),...
                    (fD_o/2), fLength);
   
    %calculates the thermal resistance from convection outside the pipes
    fR_alpha_o = 1/(fArea * falpha_o);
   
    %calculates the thermal resistance from convection in the pipe
   	fR_alpha_i = 1/(fArea * falpha_pipe);

    %calculates the heat exchange coeffcient fU
    fU = 1/(fArea * (fR_alpha_o + fR_alpha_i + fR_lambda));
    
    %If heat exchange coefficient U is zero there can be no heat transfer
    %between the two fluids
    if fU == 0
        fOutlet_Temp_1 = fEntry_Temp1;
        fOutlet_Temp_2 = fEntry_Temp2;
    else
    %uses the function for parallel flow heat exchangers to calculate the
    %outlet tempratures. Since this function differentiates not between the
    %fluid in the pipes and outside the pipes but between hot and cold a if
    %function is needed to discren which fluid is hotter. (for further
    %information view function help)  
        if fEntry_Temp1 > fEntry_Temp2
            [fOutlet_Temp_2, fOutlet_Temp_1] = temperature_parallelflow...
            (fArea, fU, fHeat_Capacity_Flow_2, fHeat_Capacity_Flow_1,...
             fEntry_Temp2, fEntry_Temp1);
        else
            [fOutlet_Temp_1, fOutlet_Temp_2] = temperature_parallelflow...
            (fArea, fU, fHeat_Capacity_Flow_1, fHeat_Capacity_Flow_2,...
             fEntry_Temp1, fEntry_Temp2);
        end
    end
    
    %calculation of pressure loss for both fluids:
    fDelta_P_1_OverPipe = pressure_loss_pipe(fD_i , fLength,...
                            fFlowSpeed_Fluid1, fDyn_Visc_Fluid1,...
                            fDensity_Fluid1, 0);
    fDelta_P_1_InOut = pressure_loss_InOut_bundle(fD_i, fs_1, fs_2,...
                     fFlowSpeed_Fluid1, fDyn_Visc_Fluid1, fDensity_Fluid1);
    
    fDelta_P_1 = fDelta_P_1_OverPipe + fDelta_P_1_InOut;
    
    fDelta_P_2 = pressure_loss_pipe(fOuter_Hydraulic_Diameter, fLength,...
                  fFlowSpeed_Fluid2, fDyn_Visc_Fluid2, fDensity_Fluid2, 0);

%%    
elseif strcmpi(sHX_type, 'cross')
    
    %allocates the entry for the number of pipe rows to decide how the 
    %programm should proceed    
    fN_Rows = mHX(1);
    %if the number of rows is larger than 0 it means that pipes were used
    %and the entries from mHX can be allocated as follows
    if fN_Rows > 0
        fN_Pipes    = mHX(2);
        fD_i        = mHX(3);
        fD_o        = mHX(4);
        fLength     = mHX(5);
        fs_1        = mHX(6); 
        fs_2        = mHX(7);
        fConfig     = mHX(8);
        if length(mHX) == 9
            fs_3    = mHX(9); 
        end
        %calculates the further needed variables for the heat exchanger
        %from the given values
        
        %flow speed for the fluids calculated from the massflow
        %with massflow = volumeflow*rho = fw*fA*frho        
        fFlowSpeed_Fluid1 = fMassFlow1/(fN_Pipes*pi*(fD_i/2)^2 *...
                            fDensity_Fluid1(1));
        fFlowSpeed_Fluid2 = fMassFlow2/(((fs_1 - fD_i)* fLength *...
                            (fN_Pipes/fN_Rows)) * fDensity_Fluid2(1));
        %heat capacity flow according to [1] page 173 equation (8.1)
        fHeat_Capacity_Flow_1 = abs(fMassFlow1) * fC_p_Fluid1(1);
        fHeat_Capacity_Flow_2 = abs(fMassFlow2) * fC_p_Fluid2(1);
        %calculates the area of the heat exchange
        fArea = (fN_Pipes*(pi*(fD_i/2)^2));               
        
        %calculation of pressure loss for both fluids:
        fDelta_P_1_OverPipe = pressure_loss_pipe(fD_i , fLength,...
                                fFlowSpeed_Fluid1, fDyn_Visc_Fluid1,...
                                fDensity_Fluid1, 0);
        fDelta_P_1_InOut = pressure_loss_InOut_bundle(fD_i, fs_1, fs_2,...
                                fFlowSpeed_Fluid1, fDyn_Visc_Fluid1,...
                                fDensity_Fluid1);
    
        fDelta_P_1 = fDelta_P_1_OverPipe + fDelta_P_1_InOut;
        
        %for the pressure loss in the pipe bundle it is only differenitated
        %between aligend and shiffted configuration and not also between
        %partially shiffted
        if fConfig == 0
            fDelta_P_2 = pressure_loss_pipe_bundle(fD_o, fs_1, fs_2,...
                           fN_Rows, fFlowSpeed_Fluid2, fDyn_Visc_Fluid2,...
                           fDensity_Fluid2, 0); 
        elseif fConfig == 1 || fConfig == 2
            fDelta_P_2 = pressure_loss_pipe_bundle(fD_o, fs_1, fs_2,...
                           fN_Rows, fFlowSpeed_Fluid2, fDyn_Visc_Fluid2,...
                           fDensity_Fluid2, 1);
        else
            error('wrong input for fConfig')
        end
    end
  
    %for fN_Rows = 0 no pipes were used => plate heat exchanger
    if fN_Rows == 0
        
        %allocates the entries in the mHX vector from the user entry to the
        %respective variables if a plate heat exchanger is used
        fBroadness  = mHX(2);
        fHeight_1   = mHX(3);
        fHeight_2   = mHX(4);
        fLength     = mHX(5);
        fThickness  = mHX(6);
    
        %calculates the further needed variables for the heat exchanger 
        %from the given values
        
        %flow speed for the fluids calculated from the massflow
        %with massflow = volumeflow*rho = fw*fA*frho        
        fFlowSpeed_Fluid1 = fMassFlow1/(fHeight_1 * fBroadness *...
                            fDensity_Fluid1(1));
        fFlowSpeed_Fluid2 = fMassFlow2/(fHeight_2 * fBroadness *...
                            fDensity_Fluid2(1));
        %heat capacity flow according to [1] page 173 equation (8.1)
        fHeat_Capacity_Flow_1 = abs(fMassFlow1) * fC_p_Fluid1(1);
        fHeat_Capacity_Flow_2 = abs(fMassFlow2) * fC_p_Fluid2(1);
        %calculates the area of the heat exchange
        fArea = fBroadness*fLength;
        
        %uses the function for convection along a plate to calculate the 
        %convection coeffcients(for further information view function help)
        falpha_o = convection_plate(fLength, fFlowSpeed_Fluid1,...
                        fDyn_Visc_Fluid1, fDensity_Fluid1,...
                        fThermal_Cond_Fluid1, fC_p_Fluid1);
        falpha_pipe = convection_plate(fLength, fFlowSpeed_Fluid2,...
                        fDyn_Visc_Fluid2, fDensity_Fluid2,...
                        fThermal_Cond_Fluid2, fC_p_Fluid2);
 
        %uses the function for thermal resisitvity to calculate the 
        %resistance from heat conduction (for further information view
        %function help)    
        fR_lambda = thermal_resistivity(fThermal_Cond_Solid, 2, fArea,...
                        fThickness, fLength);

        %calculation of pressure loss for both fluids:
        fDelta_P_1 = pressure_loss_pipe(((4*fBroadness*fHeight_1)/...
                        (2*fBroadness+2*fHeight_1)) , fLength,...
                        fFlowSpeed_Fluid1, fDyn_Visc_Fluid1,...
                        fDensity_Fluid1, 0);
        fDelta_P_2 = pressure_loss_pipe(((4*fBroadness*fHeight_1)/...
                        (2*fBroadness+2*fHeight_2)) , fLength,...
                        fFlowSpeed_Fluid2, fDyn_Visc_Fluid2,...
                        fDensity_Fluid2, 1);
        
    %for fN_Rows = 1 a single pipe row was used 
    elseif fN_Rows == 1
        %uses the function for convection at one row of pipes to calculate
        %the outer convection coeffcient (for further information view
        %function help)
        falpha_o = convection_one_pipe_row(fD_o,fs_1, fFlowSpeed_Fluid2,...
            fDyn_Visc_Fluid2, fDensity_Fluid2, fThermal_Cond_Fluid2,...
            fC_p_Fluid2);
        
        %uses the function for convection in a pipe to calculate the inner
        %convection coeffcient (for further information view function help)
        falpha_pipe = convection_pipe (fD_i, fLength, fFlowSpeed_Fluid1,...
                        fDyn_Visc_Fluid1, fDensity_Fluid1,...
                        fThermal_Cond_Fluid1, fC_p_Fluid1, 0);
    
        %uses the function for thermal resisitvity to calculate the resis-
        %tance from conduction (for further information view function help)
        fR_lambda = thermal_resistivity(fThermal_Cond_Solid,0, (fD_i/2),...
                        (fD_o/2), fLength);
   
    %for fN_Rows > 1 multiple pipe rows
    elseif fN_Rows > 1
        %uses the function for convection at multiple pipe rows to
        %calculate the outer convection coeffcient (for further 
        %information view function help)
        
        %partially shiffted configuration
        if fConfig == 2
            falpha_o = convection_multiple_pipe_row (fD_o, fs_1, fs_2,...
                        fFlowSpeed_Fluid2, fDyn_Visc_Fluid2,...
                        fDensity_Fluid2, fThermal_Cond_Fluid2,...
                        fC_p_Fluid2, fConfig, fs_3);
        %aligend or shiffted configuration
        elseif fConfig == 1 || fConfig == 0
            falpha_o = convection_multiple_pipe_row (fD_o, fs_1, fs_2,...
                        fFlowSpeed_Fluid2, fDyn_Visc_Fluid2,...
                        fDensity_Fluid2, fThermal_Cond_Fluid2,...
                        fC_p_Fluid2, fConfig);
        else
            error('wrong input for fConfig')
        end
        
        %uses the function for convection in a pipe to calculate the inner
        %convection coeffcient (for further information view function help)
        falpha_pipe = convection_pipe (fD_i, fLength, fFlowSpeed_Fluid1,...
                        fDyn_Visc_Fluid1, fDensity_Fluid1,...
                        fThermal_Cond_Fluid1, fC_p_Fluid1, 0);
   
        %uses the function for thermal resisitvity to calculate the resis-
        %tance from conduction (for further information view function help)
        fR_lambda = thermal_resistivity(fThermal_Cond_Solid,0, (fD_i/2),... 
                        (fD_o/2), fLength);
   
    else 
        error('no negative input for the number of pipe rows allowed')
    end

    %calculates the thermal resistance from convection in the pipes
    fR_alpha_i = 1/(fArea * falpha_pipe);
    
    %calculates the thermal resistance from convection outside the pipes
    fR_alpha_o = 1/(fArea * falpha_o);
    
    %calculates the heat exchange coefficient
    fU = 1/(fArea * (fR_alpha_o + fR_alpha_i + fR_lambda));
    
    %If heat exchange coefficient U is zero there can be no heat transfer
    %between the two fluids
    if fU == 0
        fOutlet_Temp_1 = fEntry_Temp1;
        fOutlet_Temp_2 = fEntry_Temp2;
    else
        %uses the function for crossflow heat exchangers to calculate the
        %outlet temperatures
        if fN_Rows >= 1
            [fOutlet_Temp_1, fOutlet_Temp_2] = temperature_crossflow...
            (fN_Rows ,fArea, fU, fHeat_Capacity_Flow_1, ...
             fHeat_Capacity_Flow_2, fEntry_Temp1, fEntry_Temp2, fLength); 
        else
            [fOutlet_Temp_1, fOutlet_Temp_2] = temperature_crossflow...
            (fN_Rows ,fArea, fU, fHeat_Capacity_Flow_1, ...
             fHeat_Capacity_Flow_2, fEntry_Temp1, fEntry_Temp2);
        end
    end
    
%%
elseif strcmpi(sHX_type, '1 n sat')
    
    %allocates the entries in the mHX vector from the user entry to the
    %respective variables
    
    %length of the passes
    fLength = mHX(1,1);
    fD_Shell = mHX(1,2);
    
    %from this point on entries are column vectors
    mD_i = mHX(:,3);
    mD_o = mHX(:,4);
    mN_Pipes_Pass = mHX(:,5);
  
    %calculates the further needed variables for the heat exchanger from
    %the given values
    
    %number of passes
    fP = size(mHX);
    fP = fP(1,1);
    
    fs_1 = 0;
    
    for k = 1:fP
        fOuter_Pipe_Area = mN_Pipes_Pass(k)*pi*(mD_o(k)/2)^2;
    
        fCircumfence = mN_Pipes_Pass(k)*pi*mD_o(k);
        
        %here a simple assumption is made for the average distance values 
        %between the pipes since they are only used in the pressure loss
        %calculation
        fs_1 = fs_1 + (mD_o(k)/2)+0.005;  
    end
    
    fs_1 = fs_1/fP;
    fs_2 = fs_1;
    
    %calculates the outer hydraulic diameter for the sheath current
    fOuter_Hydraulic_Diameter = 4*((pi*(fD_Shell/2)^2) - ...
                        fOuter_Pipe_Area)/(pi*fD_Shell + fCircumfence);
        
  
    %preallocation of vectors
    mArea_hx_pass = zeros(fP,1);
    mw_fluid1 = zeros(fP,1);
    fArea_pipes = 0;
    
    for k = 1:fP
        %calculates the Area for the heat exchange in each pass
        mArea_hx_pass(k,1) = pi * (mD_i(k,1)/2)^2 * mN_Pipes_Pass(k,1)* fLength;
        %calculates the flowspeed for the fluid within the pipes for each
        %pass
        mw_fluid1(k,1) = fMassFlow1/(mN_Pipes_Pass(k,1)*pi*...
                         (mD_i(k,1)/2)^2 * fDensity_Fluid1(1));
        %calculates the total Area of all pipes which obstructs the flow in
        %the shell
        fArea_pipes =fArea_pipes+(mN_Pipes_Pass(k,1)*(pi*(mD_o(k,1)/2)^2));
    end

    if pi*(fD_Shell/2)^2 - fArea_pipes < 0
        error('area of shell smaller than combined area of pipes')
    end
    %calculates the flow speed for the sheath current
    fFlowSpeed_Fluid2 = fMassFlow2/((pi*(fD_Shell/2)^2 - fArea_pipes) *...
                        fDensity_Fluid2(1));
   
    %heat capacity flow according to [1] page 173 equation (8.1)
    fHeat_Capacity_Flow_1 = abs(fMassFlow1) * fC_p_Fluid1(1);
    fHeat_Capacity_Flow_2 = abs(fMassFlow2) * fC_p_Fluid2(1);

    if (fHeat_Capacity_Flow_1 == 0) || (fHeat_Capacity_Flow_2 == 0)
        fOutlet_Temp_1 = fEntry_Temp1;
        fOutlet_Temp_2 = fEntry_Temp2;
    else
        %preallocation of vectors
        mD_Hydraulic_Pass = zeros(fP,1);
        malpha_o = zeros(fP,1);
        malpha_i = zeros(fP,1);
        fR_lambda = zeros(fP,1);
        fR_alpha_o = zeros(fP,1);
        fR_alpha_i = zeros(fP,1);
        mU = zeros(fP,1);

        for k = 1:fP
            %calculates the convection coefficient outside the pipes for each
            %pass
            mD_Hydraulic_Pass(k) = (pi*(fD_Shell/2)^2 - mN_Pipes_Pass(k,1)*pi*...
                                   (mD_o(k,1)/2)^2/(pi*fD_Shell +...
                                    mN_Pipes_Pass(k,1)*pi*mD_o(k,1)));
            malpha_o(k,1) = convection_pipe(mD_Hydraulic_Pass(k), fLength,...
                            fFlowSpeed_Fluid2, fDyn_Visc_Fluid2,...
                            fDensity_Fluid2, fThermal_Cond_Fluid2,...
                            fC_p_Fluid2, 0);

            %calculates the convection coeffcient inside the pipes for each
            %pass
            malpha_i(k,1) = convection_pipe (mD_i(k,1), fLength,...
                            mw_fluid1(k,1), fDyn_Visc_Fluid1,...
                            fDensity_Fluid1, fThermal_Cond_Fluid1,...
                            fC_p_Fluid1, 0);

            %calculates the thermal resistance from conduction for each pass
            %please note that the data type should be m for a matrix/vector,
            %but because of error in value return when this value is named
            %differently it is called fR_lambda
            fR_lambda(k,1) = thermal_resistivity(fThermal_Cond_Solid, 0,...
                                mD_i(k,1), mD_o(k,1), fLength);

            %calculates the thermal resistances from convection for each pass
            %please note that the data type should be m for a matrix/vector,
            %but because of error in value return when this value is named
            %differently it is called fR_alpha_i/o
            fR_alpha_i(k,1) = 1/(mArea_hx_pass(k,1) * malpha_i(k,1));
            fR_alpha_o(k,1) = 1/(mArea_hx_pass(k,1) * malpha_o(k,1));

            %calculates the heat exchange coefficient for each pass
            mU(k,1) = 1/(mArea_hx_pass(k,1) * (fR_alpha_o(k,1) +...
                        fR_alpha_i(k,1) + fR_lambda(k,1)));
        end

        %uses the function for 1,n shell and tube heat exchangers to calculate
        %the outlet temperatures
        [fOutlet_Temp_1, fOutlet_Temp_2] = temperature_1_n_sat...
        (mArea_hx_pass, mU, fHeat_Capacity_Flow_1, fHeat_Capacity_Flow_2,...
         fEntry_Temp1, fEntry_Temp2,0);
  
    end
    %calculation of pressure loss for both fluids:
    fDelta_P_1_OverPipe = 0;
    fDelta_P_1_InOut = 0;
    for k = 1:fP
        fDelta_P_1_OverPipe = fDelta_P_1_OverPipe + pressure_loss_pipe(mD_i(k) , fLength, mw_fluid1(k), fDyn_Visc_Fluid1, fDensity_Fluid1, 0);
    
        fDelta_P_1_InOut = fDelta_P_1_InOut + pressure_loss_InOut_bundle(mD_i(k), fs_1, fs_2, mw_fluid1(k), fDyn_Visc_Fluid1, fDensity_Fluid1);
    
    end
    
    fDelta_P_1 = fDelta_P_1_OverPipe + fDelta_P_1_InOut;
    
    %this heat exchanger does not use any baffles. This means the pressure
    %loss can be calculated with the pressure loss over a pipe using the
    %hydraulic diameter between shell and outer pipe diameters
    
    fDelta_P_2 = pressure_loss_pipe(fOuter_Hydraulic_Diameter, fLength,...
                  fFlowSpeed_Fluid2, fDyn_Visc_Fluid2, fDensity_Fluid2, 0);
    
%%
elseif strcmpi(sHX_type, '3 2 sat')

    %allocates the entries of the mHX vector to the respective variables 
    fD_i                = mHX{1};
    fLength             = mHX{2};
    fD_o                = mHX{3};
    fD_Baffle           = mHX{4};
    fD_Batch            = mHX{5};
    fD_Hole             = mHX{6};
    fD_Shell            = mHX{7};
    fD_Int              = mHX{8};
    fLength_Int         = mHX{9};
    fs_1                = mHX{10};
    fs_2                = mHX{11};
    fN_Pipes            = mHX{12};
    fN_Pipes_Win        = mHX{13};
    fN_Flow_Resist      = mHX{14};
    fN_Flow_Resist_end  = mHX{15};
    fN_Sealings         = mHX{16};
    fN_Pipes_Diam       = mHX{17};
    fDist_Baffles       = mHX{18};
    fHeight_Baffle     = mHX{19};
    fConfig             = mHX{20};
    if length(mHX)==21
        fs_3            = mHX{21};
    end
    
    %Area of the window 
    fArea_Win = (fD_Shell/2)^2 *acos(1-(fHeight_Baffle/(fD_Shell/2)))...
                 - sqrt(fHeight_Baffle*fD_Shell-fHeight_Baffle^2)*...
                 (fD_Shell-fHeight_Baffle);
    
    %assumptions for user inputs that were specified as unknown (x)
    if (fD_i == 'x') && (fD_o ~= 'x')
        fD_i = fD_o - 0.001;
    elseif fD_o == 'x' && (fD_i ~= 'x')
        fD_o = fD_i + 0.001;
    elseif (fD_i == 'x') && (fD_o == 'x')
        error('at least one of the inputs fD_i or fD_o is required')
    end
    if fD_Baffle == 'x'
        fD_Baffle = fD_Shell - (0.01*fD_Shell);
    end
    if fD_Batch == 'x'
        fD_Batch = fD_Shell - (0.015*fD_Shell);
    end
    if fD_Hole == 'x'
        fD_Hole = fD_o + 0.0005;
    end
    %assumes a value for the pipes in the window zone from an area 
    %relation and the total number of pipes
    if fN_Pipes_Win == 'x'
        fN_Pipes_Win = fN_Pipes * (fArea_Win/(pi*(fD_Shell/2)^2));
    end
    %assumes a value for the flow resists in the end zone from an area 
    %relation and the flow resists in the transverse zone and rounding it
    %to the higher next integer
    if fN_Flow_Resist_end == 'x'
        fN_Flow_Resist_end = ceil(fN_Flow_Resist/((pi*(fD_Shell/2)^2)...
                              -fArea_Win)*(pi*(fD_Shell/2)^2));
    end
    %assumes a value for the number of pipes at the diameter by discerning
    %how many pipes have room within the diameter with a half centimeter
    %spacing between the outer pipes and the diameter and rounds that
    %number to the lower next integer
    if fN_Pipes_Diam == 'x'
        fN_Pipes_Diam = floor((fD_Shell+0.01+fs_1)/(fD_o+fs_1));
    end
    
    %calculates the further needed variables for the heat exchanger from
    %the given values
    if ((pi*(fD_Shell/2)^2) - (fN_Pipes*(pi*(fD_o/2)^2))) < 0
        error('the shell diameter is smaller than the combined area of he pipes')       
    end
    %flow speed for the fluid within the pipes calculated from the massflow
    %with massflow = volumeflow*rho = fw*fA*frho
    %the number of pipes is halfed because of 2 inner passes
    fFlowSpeed_Fluid1 = fMassFlow1/((fN_Pipes/2)*pi*(fD_i/2)^2 *...
                        fDensity_Fluid1(1));
    fFlowSpeed_Fluid2 = fMassFlow2/(((pi*(fD_Shell/2)^2) - (fN_Pipes*...
                        (pi*(fD_o/2)^2))) * fDensity_Fluid2(1));
    %heat capacity flow according to [1] page 173 equation (8.1)
    fHeat_Capacity_Flow_1 = abs(fMassFlow1) * fC_p_Fluid1(1);
    fHeat_Capacity_Flow_2 = abs(fMassFlow2) * fC_p_Fluid2(1);
    %calculates the area for the heat exchange
    fArea = (fN_Pipes*(pi*(fD_i/2)^2));
    
    %Distance between baffles and end of heat exchanger
    fS_e = fLength-fDist_Baffles;
    
    %simplification for the number of rows, calculated from the number of
    %pipes in the transverse zone
    %number of rows in the transverse zone between baffles
    fN_Pipes_Trans = (fN_Pipes-(2*fN_Pipes_Win));
    fN_Rows_Trans = fN_Pipes_Trans/(fN_Pipes_Diam/1.5);
    %number of baffles
    fN_Baffles = 2;
    
    %calculates the convection coeffcient on the outer side of the pipes
    %using the function for the sheath current of a shell and tube heat
    %exchanger (for further info view the help of the function) 
    %partially shiffted configuration with one additional input for the
    %shiffting length fs_3
    if length(mHX)==21
        falpha_sheath = convection_sheath_current (fD_o, fD_Baffle,...
                            fD_Batch, fD_Hole, fD_Shell, fs_1, fs_2,...
                            fN_Pipes, fN_Pipes_Win, fN_Flow_Resist,...
                            fN_Sealings , fN_Pipes_Diam, fDist_Baffles,...
                            fHeight_Baffle, fFlowSpeed_Fluid2,...
                            fDyn_Visc_Fluid2, fDensity_Fluid2,...
                            fThermal_Cond_Fluid2, fC_p_Fluid2, fConfig,...
                            fs_3);
    %shiffted or aligend configuration
    elseif length(mHX)==20
        falpha_sheath = convection_sheath_current (fD_o, fD_Baffle,...
            fD_Batch, fD_Hole, fD_Shell, fs_1, fs_2, fN_Pipes,...
            fN_Pipes_Win, fN_Flow_Resist, fN_Sealings , fN_Pipes_Diam,...
            fDist_Baffles, fHeight_Baffle, fFlowSpeed_Fluid2,...
            fDyn_Visc_Fluid2, fDensity_Fluid2, fThermal_Cond_Fluid2,...
            fC_p_Fluid2, fConfig);
    else
        error('wrong input for fConfig')
    end
    %calculates the thermal resistance resulting from convection in the
    %sheath current
    fR_alpha_o = 1/(fArea * falpha_sheath);
    
    %calculates the convection coeffcient on the inner side of the pipes
    %using the function for a simple pipe (for further info view the help 
    %of the function)
    falpha_pipe = convection_pipe (fD_i, fLength, fFlowSpeed_Fluid1,...
                    fDyn_Visc_Fluid1, fDensity_Fluid1,...
                    fThermal_Cond_Fluid1, fC_p_Fluid1, 0);

    %calculates the thermal resistance resulting from convection in the
    %pipes
    fR_alpha_i = 1/(fArea * falpha_pipe);
    
    %calculates the thermal resitivity for further info view the help 
    %of the function
    fR_lambda = thermal_resistivity(fThermal_Cond_Solid, 0, (fD_i/2),...
                    (fD_o/2), fLength);

    %calculates the heat exchange coeffcient fU
    fU = 1/(fArea * (fR_alpha_o + fR_alpha_i + fR_lambda));
    
    %uses the function for the 3,2 shell and tube heat exchanger to
    %calculate the outlet temperatures (view help of the function for
    %further information)
    if fU == 0
        fOutlet_Temp_1 = fEntry_Temp1; 
        fOutlet_Temp_2 = fEntry_Temp2;
    else
        [fOutlet_Temp_1, fOutlet_Temp_2] =temperature_3_2_sat(fArea, fU,...
                        fHeat_Capacity_Flow_1, fHeat_Capacity_Flow_2,...
                        fEntry_Temp1, fEntry_Temp2);
    end

    fDelta_P_1_OverPipe = pressure_loss_pipe(fD_i , fLength,...
                            fFlowSpeed_Fluid1, fDyn_Visc_Fluid1,...
                            fDensity_Fluid1, 0);
    fDelta_P_1_InOut = pressure_loss_InOut_bundle(fD_i, fs_1, fs_2,...
                            fFlowSpeed_Fluid1, fDyn_Visc_Fluid1,...
                            fDensity_Fluid1);
    
    fDelta_P_1 = fDelta_P_1_OverPipe + fDelta_P_1_InOut;
    
    if fConfig == 2
        fconfig_press_loss = 1;
    else
        fconfig_press_loss = fConfig;
    end
    
    fDelta_P_2 = pressure_loss_sheath_current(fD_o, fD_Shell, fD_Baffle,...
    fD_Batch, fD_Hole, fD_Int, fDist_Baffles, fS_e, fHeight_Baffle,...
    fLength_Int, fs_1, fs_2, fN_Pipes, fN_Rows_Trans, fN_Pipes_Diam,...
    fN_Pipes_Win, fN_Sealings, fN_Baffles, fN_Flow_Resist,...
    fN_Flow_Resist_end, fDyn_Visc_Fluid2, fDensity_Fluid2, fMassFlow2,...
    fconfig_press_loss);
else
    error('unkown input for the heat exchanger type')
end

end