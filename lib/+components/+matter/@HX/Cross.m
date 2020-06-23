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
    fR_alpha_i, fR_alpha_o, fR_lambda] = Cross(~, tHX_Parameters, Fluid_1, Fluid_2, fThermalConductivitySolid)
    
    %if the number of rows is larger than 0 it means that pipes were used
    %and the entries from mHX can be allocated as follows
    if tHX_Parameters.iNumberOfRows > 0
        %calculates the further needed variables for the heat exchanger
        %from the given values
        
        %flow speed for the fluids calculated from the massflow
        %with massflow = volumeflow*rho = fw*fA*frho        
        fFlowSpeed_Fluid1 = Fluid_1.fMassflow/(tHX_Parameters.iNumberOfPipes*pi*(tHX_Parameters.fInnerDiameter/2)^2 *...
                            Fluid_1.fDensity(1));
        fFlowSpeed_Fluid2 = Fluid_2.fMassflow/(((tHX_Parameters.fPerpendicularSpacing - tHX_Parameters.fInnerDiameter)* tHX_Parameters.fLength *...
                            (tHX_Parameters.iNumberOfPipes/tHX_Parameters.iNumberOfRows)) * Fluid_2.fDensity(1));
        %heat capacity flow according to [1] page 173 equation (8.1)
        fHeat_Capacity_Flow_1 = abs(Fluid_1.fMassflow) * Fluid_1.fSpecificHeatCapacity(1);
        fHeat_Capacity_Flow_2 = abs(Fluid_2.fMassflow) * Fluid_2.fSpecificHeatCapacity(1);
        %calculates the area of the heat exchange
        fArea = (tHX_Parameters.iNumberOfPipes*(pi*(tHX_Parameters.fInnerDiameter/2)^2));               
        
        %calculation of pressure loss for both fluids:
        fDelta_P_1_OverPipe = functions.calculateDeltaPressure.Pipe(tHX_Parameters.fInnerDiameter , tHX_Parameters.fLength,...
                                fFlowSpeed_Fluid1, Fluid_1.fDynamicViscosity,...
                                Fluid_1.fDensity, 0);
        fDelta_P_1_InOut = functions.calculateDeltaPressure.PipeBundleInletOutlet(tHX_Parameters.fInnerDiameter, tHX_Parameters.fPerpendicularSpacing, tHX_Parameters.fParallelSpacing,...
                                fFlowSpeed_Fluid1, Fluid_1.fDynamicViscosity,...
                                Fluid_1.fDensity);
    
        fDelta_P_1 = fDelta_P_1_OverPipe + fDelta_P_1_InOut;
        
        %for the pressure loss in the pipe bundle it is only differenitated
        %between aligend and shiffted configuration and not also between
        %partially shiffted
        if tHX_Parameters.iConfiguration == 0
            fDelta_P_2 = functions.calculateDeltaPressure.PipeBundle(tHX_Parameters.fOuterDiameter, tHX_Parameters.fPerpendicularSpacing, tHX_Parameters.fParallelSpacing,...
                           tHX_Parameters.iNumberOfRows, fFlowSpeed_Fluid2, Fluid_2.fDynamicViscosity,...
                           Fluid_2.fDensity, 0); 
        elseif tHX_Parameters.iConfiguration == 1 || tHX_Parameters.iConfiguration == 2
            fDelta_P_2 = functions.calculateDeltaPressure.PipeBundle(tHX_Parameters.fOuterDiameter, tHX_Parameters.fPerpendicularSpacing, tHX_Parameters.fParallelSpacing,...
                           tHX_Parameters.iNumberOfRows, fFlowSpeed_Fluid2, Fluid_2.fDynamicViscosity,...
                           Fluid_2.fDensity, 1);
        else
            error('wrong input for tHX_Parameters.iConfiguration')
        end
    end
  
    %for tHX_Parameters.iNumberOfRows = 0 no pipes were used => plate heat exchanger
    if tHX_Parameters.iNumberOfRows == 0
        %calculates the further needed variables for the heat exchanger 
        %from the given values
        
        %flow speed for the fluids calculated from the massflow
        %with massflow = volumeflow*rho = fw*fA*frho        
        fFlowSpeed_Fluid1 = Fluid_1.fMassflow/(tHX_Parameters.fHeight_1 * tHX_Parameters.fBroadness *...
                            Fluid_1.fDensity(1));
        fFlowSpeed_Fluid2 = Fluid_2.fMassflow/(tHX_Parameters.fHeight_2 * tHX_Parameters.fBroadness *...
                            Fluid_2.fDensity(1));
        %heat capacity flow according to [1] page 173 equation (8.1)
        fHeat_Capacity_Flow_1 = abs(Fluid_1.fMassflow) * Fluid_1.fSpecificHeatCapacity(1);
        fHeat_Capacity_Flow_2 = abs(Fluid_2.fMassflow) * Fluid_2.fSpecificHeatCapacity(1);
        %calculates the area of the heat exchange
        fArea = tHX_Parameters.fBroadness*tHX_Parameters.fLength;
        
        %uses the function for convection along a plate to calculate the 
        %convection coeffcients(for further information view function help)
        falpha_o = functions.calculateHeatTransferCoefficient.convectionPlate(tHX_Parameters.fLength, fFlowSpeed_Fluid1,...
                        Fluid_1.fDynamicViscosity, Fluid_1.fDensity,...
                        Fluid_1.fThermalConductivity, Fluid_1.fSpecificHeatCapacity);
        falpha_pipe = functions.calculateHeatTransferCoefficient.convectionPlate(tHX_Parameters.fLength, fFlowSpeed_Fluid2,...
                        Fluid_2.fDynamicViscosity, Fluid_2.fDensity,...
                        Fluid_2.fThermalConductivity, Fluid_2.fSpecificHeatCapacity);
 
        %uses the function for thermal resisitvity to calculate the 
        %resistance from heat conduction (for further information view
        %function help)    
        fR_lambda = functions.calculateHeatTransferCoefficient.conductionResistance(fThermalConductivitySolid, 2, fArea,...
                        tHX_Parameters.fThickness, tHX_Parameters.fLength);

        %calculation of pressure loss for both fluids:
        fDelta_P_1 = functions.calculateDeltaPressure.Pipe(((4*tHX_Parameters.fBroadness*tHX_Parameters.fHeight_1)/...
                        (2*tHX_Parameters.fBroadness+2*tHX_Parameters.fHeight_1)) , tHX_Parameters.fLength,...
                        fFlowSpeed_Fluid1, Fluid_1.fDynamicViscosity,...
                        Fluid_1.fDensity, 0);
        fDelta_P_2 = functions.calculateDeltaPressure.Pipe(((4*tHX_Parameters.fBroadness*tHX_Parameters.fHeight_1)/...
                        (2*tHX_Parameters.fBroadness+2*tHX_Parameters.fHeight_2)) , tHX_Parameters.fLength,...
                        fFlowSpeed_Fluid2, Fluid_2.fDynamicViscosity,...
                        Fluid_2.fDensity, 1);
        
    %for tHX_Parameters.iNumberOfRows = 1 a single pipe row was used 
    elseif tHX_Parameters.iNumberOfRows == 1
        %uses the function for convection at one row of pipes to calculate
        %the outer convection coeffcient (for further information view
        %function help)
        falpha_o = functions.calculateHeatTransferCoefficient.convectionOnePipeRow(tHX_Parameters.fOuterDiameter,tHX_Parameters.fPerpendicularSpacing, fFlowSpeed_Fluid2,...
            Fluid_2.fDynamicViscosity, Fluid_2.fDensity, Fluid_2.fThermalConductivity,...
            Fluid_2.fSpecificHeatCapacity);
        
        %uses the function for convection in a pipe to calculate the inner
        %convection coeffcient (for further information view function help)
        falpha_pipe = functions.calculateHeatTransferCoefficient.convectionPipe (tHX_Parameters.fInnerDiameter, tHX_Parameters.fLength, fFlowSpeed_Fluid1,...
                        Fluid_1.fDynamicViscosity, Fluid_1.fDensity,...
                        Fluid_1.fThermalConductivity, Fluid_1.fSpecificHeatCapacity, 0);
    
        %uses the function for thermal resisitvity to calculate the resis-
        %tance from conduction (for further information view function help)
        fR_lambda = functions.calculateHeatTransferCoefficient.conductionResistance(fThermalConductivitySolid,0, (tHX_Parameters.fInnerDiameter/2),...
                        (tHX_Parameters.fOuterDiameter/2), tHX_Parameters.fLength);
   
    %for tHX_Parameters.iNumberOfRows > 1 multiple pipe rows
    elseif tHX_Parameters.iNumberOfRows > 1
        %uses the function for convection at multiple pipe rows to
        %calculate the outer convection coeffcient (for further 
        %information view function help)
        
        %partially shiffted configuration
        if tHX_Parameters.iConfiguration == 2
            falpha_o = functions.calculateHeatTransferCoefficient.convectionMultiplePipeRow (tHX_Parameters.fOuterDiameter, tHX_Parameters.fPerpendicularSpacing, tHX_Parameters.fParallelSpacing,...
                        fFlowSpeed_Fluid2, Fluid_2.fDynamicViscosity,...
                        Fluid_2.fDensity, Fluid_2.fThermalConductivity,...
                        Fluid_2.fSpecificHeatCapacity, tHX_Parameters.iConfiguration, tHX_Parameters.fPipeRowOffset);
        %aligend or shiffted configuration
        elseif tHX_Parameters.iConfiguration == 1 || tHX_Parameters.iConfiguration == 0
            falpha_o = functions.calculateHeatTransferCoefficient.convectionMultiplePipeRow (tHX_Parameters.fOuterDiameter, tHX_Parameters.fPerpendicularSpacing, tHX_Parameters.fParallelSpacing,...
                        fFlowSpeed_Fluid2, Fluid_2.fDynamicViscosity,...
                        Fluid_2.fDensity, Fluid_2.fThermalConductivity,...
                        Fluid_2.fSpecificHeatCapacity, tHX_Parameters.iConfiguration);
        else
            error('wrong input for tHX_Parameters.iConfiguration')
        end
        
        %uses the function for convection in a pipe to calculate the inner
        %convection coeffcient (for further information view function help)
        falpha_pipe = functions.calculateHeatTransferCoefficient.convectionPipe (tHX_Parameters.fInnerDiameter, tHX_Parameters.fLength, fFlowSpeed_Fluid1,...
                        Fluid_1.fDynamicViscosity, Fluid_1.fDensity,...
                        Fluid_1.fThermalConductivity, Fluid_1.fSpecificHeatCapacity, 0);
   
        %uses the function for thermal resisitvity to calculate the resis-
        %tance from conduction (for further information view function help)
        fR_lambda = functions.calculateHeatTransferCoefficient.conductionResistance(fThermalConductivitySolid,0, (tHX_Parameters.fInnerDiameter/2),... 
                        (tHX_Parameters.fOuterDiameter/2), tHX_Parameters.fLength);
   
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
        fOutlet_Temp_1 = Fluid_1.fEntryTemperature;
        fOutlet_Temp_2 = Fluid_2.fEntryTemperature;
    else
        %uses the function for crossflow heat exchangers to calculate the
        %outlet temperatures
        if tHX_Parameters.iNumberOfRows >= 1
            [fOutlet_Temp_1, fOutlet_Temp_2] = functions.HX.temperature_crossflow...
            (tHX_Parameters.iNumberOfRows ,fArea, fU, fHeat_Capacity_Flow_1, ...
             fHeat_Capacity_Flow_2, Fluid_1.fEntryTemperature, Fluid_2.fEntryTemperature, tHX_Parameters.fLength); 
        else
            [fOutlet_Temp_1, fOutlet_Temp_2] = functions.HX.temperature_crossflow...
            (tHX_Parameters.iNumberOfRows ,fArea, fU, fHeat_Capacity_Flow_1, ...
             fHeat_Capacity_Flow_2, Fluid_1.fEntryTemperature, Fluid_2.fEntryTemperature);
        end
    end
end