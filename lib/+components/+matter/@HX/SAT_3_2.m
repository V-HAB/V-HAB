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
    fR_alpha_i, fR_alpha_o, fR_lambda] = SAT_3_2(~, tHX_Parameters, Fluid_1, Fluid_2, fThermalConductivitySolid)
    
    
    
    %Area of the window 
    fArea_Win = (tHX_Parameters.fShellDiameter/2)^2 *acos(1-(tHX_Parameters.fBaffleHeight/(tHX_Parameters.fShellDiameter/2)))...
                 - sqrt(tHX_Parameters.fBaffleHeight*tHX_Parameters.fShellDiameter-tHX_Parameters.fBaffleHeight^2)*...
                 (tHX_Parameters.fShellDiameter-tHX_Parameters.fBaffleHeight);
    
    %assumptions for user inputs that were specified as unknown (x)
    if (tHX_Parameters.fInnerDiameter == 'x') && (tHX_Parameters.fOuterDiameter ~= 'x')
        tHX_Parameters.fInnerDiameter = tHX_Parameters.fOuterDiameter - 0.001;
    elseif tHX_Parameters.fOuterDiameter == 'x' && (tHX_Parameters.fInnerDiameter ~= 'x')
        tHX_Parameters.fOuterDiameter = tHX_Parameters.fInnerDiameter + 0.001;
    elseif (tHX_Parameters.fInnerDiameter == 'x') && (tHX_Parameters.fOuterDiameter == 'x')
        error('at least one of the inputs tHX_Parameters.fInnerDiameter or tHX_Parameters.fOuterDiameter is required')
    end
    if tHX_Parameters.fBaffleDiameter == 'x'
        tHX_Parameters.fBaffleDiameter = tHX_Parameters.fShellDiameter - (0.01*tHX_Parameters.fShellDiameter);
    end
    if tHX_Parameters.fBatchDiameter == 'x'
        tHX_Parameters.fBatchDiameter = tHX_Parameters.fShellDiameter - (0.015*tHX_Parameters.fShellDiameter);
    end
    if tHX_Parameters.fHoleDiameter == 'x'
        tHX_Parameters.fHoleDiameter = tHX_Parameters.fOuterDiameter + 0.0005;
    end
    %assumes a value for the pipes in the window zone from an area 
    %relation and the total number of pipes
    if tHX_Parameters.iNumberOfPipesInWindow == 'x'
        tHX_Parameters.iNumberOfPipesInWindow = tHX_Parameters.iNumberOfPipes * (fArea_Win/(pi*(tHX_Parameters.fShellDiameter/2)^2));
    end
    %assumes a value for the flow resists in the end zone from an area 
    %relation and the flow resists in the transverse zone and rounding it
    %to the higher next integer
    if tHX_Parameters.iNumberOfResistancesEndZone == 'x'
        tHX_Parameters.iNumberOfResistancesEndZone = ceil(tHX_Parameters.iNumberOfResistances/((pi*(tHX_Parameters.fShellDiameter/2)^2)...
                              -fArea_Win)*(pi*(tHX_Parameters.fShellDiameter/2)^2));
    end
    %assumes a value for the number of pipes at the diameter by discerning
    %how many pipes have room within the diameter with a half centimeter
    %spacing between the outer pipes and the diameter and rounds that
    %number to the lower next integer
    if tHX_Parameters.iNumberOfPipes_Diam == 'x'
        tHX_Parameters.iNumberOfPipes_Diam = floor((tHX_Parameters.fShellDiameter+0.01+tHX_Parameters.fPerpendicularSpacing)/(tHX_Parameters.fOuterDiameter+tHX_Parameters.fPerpendicularSpacing));
    end
    
    %calculates the further needed variables for the heat exchanger from
    %the given values
    if ((pi*(tHX_Parameters.fShellDiameter/2)^2) - (tHX_Parameters.iNumberOfPipes*(pi*(tHX_Parameters.fOuterDiameter/2)^2))) < 0
        error('the shell diameter is smaller than the combined area of he pipes')       
    end
    %flow speed for the fluid within the pipes calculated from the massflow
    %with massflow = volumeflow*rho = fw*fA*frho
    %the number of pipes is halfed because of 2 inner passes
    fFlowSpeed_Fluid1 = Fluid_1.fMassflow/((tHX_Parameters.iNumberOfPipes/2)*pi*(tHX_Parameters.fInnerDiameter/2)^2 *...
                        Fluid_1.fDensity(1));
    fFlowSpeed_Fluid2 = Fluid_2.fMassflow/(((pi*(tHX_Parameters.fShellDiameter/2)^2) - (tHX_Parameters.iNumberOfPipes*...
                        (pi*(tHX_Parameters.fOuterDiameter/2)^2))) * Fluid_2.fDensity(1));
    %heat capacity flow according to [1] page 173 equation (8.1)
    fHeat_Capacity_Flow_1 = abs(Fluid_1.fMassflow) * Fluid_1.fSpecificHeatCapacity(1);
    fHeat_Capacity_Flow_2 = abs(Fluid_2.fMassflow) * Fluid_2.fSpecificHeatCapacity(1);
    %calculates the area for the heat exchange
    fArea = (tHX_Parameters.iNumberOfPipes*(pi*(tHX_Parameters.fInnerDiameter/2)^2));
    
    %Distance between baffles and end of heat exchanger
    fS_e = tHX_Parameters.fLength-tHX_Parameters.fBaffleDistance;
    
    %simplification for the number of rows, calculated from the number of
    %pipes in the transverse zone
    %number of rows in the transverse zone between baffles
    tHX_Parameters.iNumberOfPipes_Trans = (tHX_Parameters.iNumberOfPipes-(2*tHX_Parameters.iNumberOfPipesInWindow));
    fN_Rows_Trans = tHX_Parameters.iNumberOfPipes_Trans/(tHX_Parameters.iNumberOfPipes_Diam/1.5);
    %number of baffles
    fN_Baffles = 2;
    
    %calculates the convection coeffcient on the outer side of the pipes
    %using the function for the sheath current of a shell and tube heat
    %exchanger (for further info view the help of the function) 
    %partially shiffted configuration with one additional input for the
    %shiffting length tHX_Parameters.fPipeRowOffset
    if length(mHX)==21
        falpha_sheath = functions.calculateHeatTransferCoefficient.functions.calculateHeatTransferCoefficient.convectionSheathCurrent (tHX_Parameters.fOuterDiameter, tHX_Parameters.fBaffleDiameter,...
                            tHX_Parameters.fBatchDiameter, tHX_Parameters.fHoleDiameter, tHX_Parameters.fShellDiameter, tHX_Parameters.fPerpendicularSpacing, tHX_Parameters.fParallelSpacing,...
                            tHX_Parameters.iNumberOfPipes, tHX_Parameters.iNumberOfPipesInWindow, tHX_Parameters.iNumberOfResistances,...
                            tHX_Parameters.iNumberOfSealings , tHX_Parameters.iNumberOfPipes_Diam, tHX_Parameters.fBaffleDistance,...
                            tHX_Parameters.fBaffleHeight, fFlowSpeed_Fluid2,...
                            Fluid_2.fDynamicViscosity, Fluid_2.fDensity,...
                            Fluid_2.fThermalConductivity, Fluid_2.fSpecificHeatCapacity, tHX_Parameters.iConfiguration,...
                            tHX_Parameters.fPipeRowOffset);
    %shiffted or aligend configuration
    elseif length(mHX)==20
        falpha_sheath = functions.calculateHeatTransferCoefficient.functions.calculateHeatTransferCoefficient.convectionSheathCurrent (tHX_Parameters.fOuterDiameter, tHX_Parameters.fBaffleDiameter,...
            tHX_Parameters.fBatchDiameter, tHX_Parameters.fHoleDiameter, tHX_Parameters.fShellDiameter, tHX_Parameters.fPerpendicularSpacing, tHX_Parameters.fParallelSpacing, tHX_Parameters.iNumberOfPipes,...
            tHX_Parameters.iNumberOfPipesInWindow, tHX_Parameters.iNumberOfResistances, tHX_Parameters.iNumberOfSealings , tHX_Parameters.iNumberOfPipes_Diam,...
            tHX_Parameters.fBaffleDistance, tHX_Parameters.fBaffleHeight, fFlowSpeed_Fluid2,...
            Fluid_2.fDynamicViscosity, Fluid_2.fDensity, Fluid_2.fThermalConductivity,...
            Fluid_2.fSpecificHeatCapacity, tHX_Parameters.iConfiguration);
    else
        error('wrong input for tHX_Parameters.iConfiguration')
    end
    %calculates the thermal resistance resulting from convection in the
    %sheath current
    fR_alpha_o = 1/(fArea * falpha_sheath);
    
    %calculates the convection coeffcient on the inner side of the pipes
    %using the function for a simple pipe (for further info view the help 
    %of the function)
    falpha_pipe = functions.calculateHeatTransferCoefficient.convectionPipe (tHX_Parameters.fInnerDiameter, tHX_Parameters.fLength, fFlowSpeed_Fluid1,...
                    Fluid_1.fDynamicViscosity, Fluid_1.fDensity,...
                    Fluid_1.fThermalConductivity, Fluid_1.fSpecificHeatCapacity, 0);

    %calculates the thermal resistance resulting from convection in the
    %pipes
    fR_alpha_i = 1/(fArea * falpha_pipe);
    
    %calculates the thermal resitivity for further info view the help 
    %of the function
    fR_lambda = functions.calculateHeatTransferCoefficient.conductionResistance(fThermalConductivitySolid, 0, (tHX_Parameters.fInnerDiameter/2),...
                    (tHX_Parameters.fOuterDiameter/2), tHX_Parameters.fLength);

    %calculates the heat exchange coeffcient fU
    fU = 1/(fArea * (fR_alpha_o + fR_alpha_i + fR_lambda));
    
    %uses the function for the 3,2 shell and tube heat exchanger to
    %calculate the outlet temperatures (view help of the function for
    %further information)
    if fU == 0
        fOutlet_Temp_1 = Fluid_1.fEntryTemperature; 
        fOutlet_Temp_2 = Fluid_2.fEntryTemperature;
    else
        [fOutlet_Temp_1, fOutlet_Temp_2] = functions.HX.temperature_3_2_sat(fArea, fU,...
                        fHeat_Capacity_Flow_1, fHeat_Capacity_Flow_2,...
                        Fluid_1.fEntryTemperature, Fluid_2.fEntryTemperature);
    end

    fDelta_P_1_OverPipe = functions.calculateDeltaPressure.Pipe(tHX_Parameters.fInnerDiameter , tHX_Parameters.fLength,...
                            fFlowSpeed_Fluid1, Fluid_1.fDynamicViscosity,...
                            Fluid_1.fDensity, 0);
    fDelta_P_1_InOut = functions.calculateDeltaPressure.PipeBundleInletOutlet(tHX_Parameters.fInnerDiameter, tHX_Parameters.fPerpendicularSpacing, tHX_Parameters.fParallelSpacing,...
                            fFlowSpeed_Fluid1, Fluid_1.fDynamicViscosity,...
                            Fluid_1.fDensity);
    
    fDelta_P_1 = fDelta_P_1_OverPipe + fDelta_P_1_InOut;
    
    if tHX_Parameters.iConfiguration == 2
        tHX_Parameters.iConfiguration_press_loss = 1;
    else
        tHX_Parameters.iConfiguration_press_loss = tHX_Parameters.iConfiguration;
    end
    
    fDelta_P_2 = functions.calculateDeltaPressure.SheathCurrent(tHX_Parameters.fOuterDiameter, tHX_Parameters.fShellDiameter, tHX_Parameters.fBaffleDiameter,...
    tHX_Parameters.fBatchDiameter, tHX_Parameters.fHoleDiameter, tHX_Parameters.fInnerDiameterInterface, tHX_Parameters.fBaffleDistance, fS_e, tHX_Parameters.fBaffleHeight,...
    tHX_Parameters.fLengthInterfaceFitting, tHX_Parameters.fPerpendicularSpacing, tHX_Parameters.fParallelSpacing, tHX_Parameters.iNumberOfPipes, fN_Rows_Trans, tHX_Parameters.iNumberOfPipes_Diam,...
    tHX_Parameters.iNumberOfPipesInWindow, tHX_Parameters.iNumberOfSealings, fN_Baffles, tHX_Parameters.iNumberOfResistances,...
    tHX_Parameters.iNumberOfResistancesEndZone, Fluid_2.fDynamicViscosity, Fluid_2.fDensity, Fluid_2.fMassflow,...
    tHX_Parameters.iConfiguration_press_loss);
end