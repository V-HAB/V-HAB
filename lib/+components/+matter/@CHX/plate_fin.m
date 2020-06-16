function [fOutlet_Temp_1, fOutlet_Temp_2, fDelta_P_1, fDelta_P_2] = ...
    plate_fin(oCHX, tCHX_Parameters, Fluid_1, Fluid_2, fThermalConductivitySolid, miIncrements)

% Function used to calculate the outlet temperatures and pressure drop of a
% plate and fin cross counter flow heat exchanger with a single air pass
% (fluid 1) and iBaffles+1 coolant passes as it is used in the Common Cabin
% Air Assembly of the ISS. Please view:
% "Living together in space: the design and operation of the life support
% systems on the International Space Station", Wieland, Paul O., 1998, page
% 104 for an description of the CHX used in the CCAA
%
% The CHX uses multiple layers and each layer uses the following
% discretization (vertical arrows indicate coolant flow direction):
%
% iBaffle       1       2       3      4
%
%                       Baffle 2                    iAir
%           |               |               |       6
%           |       |       |       |       |       5
% Air Flow  |       |   ^   |       |   ^   |       4
% ------->  |       |   |   |       |   |   |       3
%           |       |       |       |       |       2
%           |       |               |       |       1
%                Baffle 1       Baffle 3
%
% iCoolant    1,2,3   1,2,3   1,2,3    1,2,3
%
% The Air flow is discretices into iIncrements flow, which are seperated by
% the fins over the whole course of the CHX (it does not necessary have to
% use the samne amount of increments as there are fins in the CHX), the
% iIncrementsAir parameter is therefore perpendicular to the air flow
% direction. The coolant flow is seperated into increments for each baffle
% section (there is always one more flow section than there are baffles,
% the iBaffle is for a baffle flow section). Every time the coolant passes
% from one baffle section to the next, the coolant temperature is mixed
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
%as the wall temperature T_w. These should be saved in the struct values as
%vectors with the first entry beeing the material value for T_m and the
%second value for T_w
%
%Together alle the inputs are used in the function as follows:
%
%[fOutlet_Temp_1, fOutlet_Temp_2, fDelta_P_1, fDelta_P_2 fR_alpha_i,...
% fR_alpha_o, fR_lambda] = HX(oCHX, Fluid_1, Fluid_2, fThermal_Cond_Solid)
%
%Where the object oCHX containing mHX and sHX_type with the user inputs is
%automatically set in the HX.m file (also see that file for more
%information about which heat exchangers can be calculated and what user
%inputs are required)
%
%with the outputs: fOutlet_Temp_1 = temperature after HX for fluid within
%the pipes (if there
%                 are pipes) in K
%fOutlet_Temp_2 = temperature after HX for sheath fluid (fluid outside
%                 pipes if there are pipes) in K
%fDelta_P_1  = pressure loss of fluid 1 in N/m² fDelta_P_2  = pressure loss
%of fluid 2 in N/m² fR_alpha_i  = thermal resistivity from convection on
%the inner side in W/K fR_alpha_o  = thermal resistivity from convection on
%the inner side in W/K fR_lambda   = thermal resistivity from conduction in
%W/K

%the source "Wärmeübertragung" Polifke will from now on be defined as [1]

%Please note generally for the convection coeffcient functions: in some of
%these functions a decision wether nondisturbed flow should be assumed or
%not is necessary. In this programm this has already been set using the
%respective fConfig variables in these cases to use the most probable case.
%So for example in case of a pipe bundle disturbed flow is assumed inside
%of it because generally a single pipe with a different diameter will lead
%to the bundle. But if a single pipe was used non disturbed flow is assumed
%since the pipe leading to it will most likely have the same shape and
%diameter.

iIncrementsAir      = miIncrements(1);
iIncrementsCoolant  = miIncrements(2);

%calculates the further needed variables for the heat exchanger from the
%given values

%flow speed for the fluids calculated from the massflow with massflow =
%volumeflow*rho = fw*fA*frho
fFlowSpeed_Fluid1 = Fluid_1.fMassflow/(tCHX_Parameters.fHeight_1 * tCHX_Parameters.fBroadness *  tCHX_Parameters.iLayers    * Fluid_1.fDensity(1));
fFlowSpeed_Fluid2 = Fluid_2.fMassflow/(tCHX_Parameters.fHeight_2 * tCHX_Parameters.fBroadness * (tCHX_Parameters.iLayers+1) * Fluid_2.fDensity(1));
                
%calculates the area of the heat exchanger fArea =
%tCHX_Parameters.fBroadness*tCHX_Parameters.fLength;

fIncrementalLength      = tCHX_Parameters.fLength       /(iIncrementsCoolant * (tCHX_Parameters.iBaffles+1));
fIncrementalBroadness   = tCHX_Parameters.fBroadness    /iIncrementsAir;
fIncrementalArea        = fIncrementalLength * fIncrementalBroadness;

%uses the function for convection along a plate to calculate the convection
%coeffcients(for further information view function help)
falpha_pipe = functions.calculateHeatTransferCoefficient.convectionPlate(tCHX_Parameters.fLength, fFlowSpeed_Fluid1,...
                Fluid_1.fDynamic_Viscosity, Fluid_1.fDensity,...
                Fluid_1.fThermal_Conductivity, Fluid_1.fSpecificHeatCapacity);
falpha_o = functions.calculateHeatTransferCoefficient.convectionPlate(tCHX_Parameters.fBroadness, fFlowSpeed_Fluid2,...
                Fluid_2.fDynamic_Viscosity, Fluid_2.fDensity,...
                Fluid_2.fThermal_Conductivity, Fluid_2.fSpecificHeatCapacity);

%uses the function for thermal resisitvity to calculate the resistance from
%heat conduction (for further information view function help)
fR_lambda_Incremental = functions.calculateHeatTransferCoefficient.conductionResistance(fThermalConductivitySolid, 2, fIncrementalArea,...
                tCHX_Parameters.fThickness, fIncrementalLength);

%calculation of pressure loss for both fluids:
fDelta_P_1 = functions.calculateDeltaPressure.Pipe(((4*tCHX_Parameters.fBroadness*tCHX_Parameters.fHeight_1)/...
                (2*tCHX_Parameters.fBroadness+2*tCHX_Parameters.fHeight_1)) , tCHX_Parameters.fLength,...
                fFlowSpeed_Fluid1, Fluid_1.fDynamic_Viscosity,...
                Fluid_1.fDensity, 0);
fDelta_P_2 = functions.calculateDeltaPressure.Pipe(((4*tCHX_Parameters.fBroadness*tCHX_Parameters.fHeight_1)/...
                (2*tCHX_Parameters.fBroadness+2*tCHX_Parameters.fHeight_2)) , (tCHX_Parameters.iBaffles+1) * tCHX_Parameters.fBroadness,...
                fFlowSpeed_Fluid2, Fluid_2.fDynamic_Viscosity,...
                Fluid_2.fDensity, 1);

%calculates the thermal resistance from convection in the pipes
fR_alpha_i_Incremental = 1/(fIncrementalArea * falpha_pipe);

%calculates the thermal resistance from convection outside the pipes
fR_alpha_o_Incremental = 1/(fIncrementalArea * falpha_o);

%calculates the heat exchange coefficient
fIncrementalU = 1/(fIncrementalArea * (fR_alpha_o_Incremental + fR_alpha_i_Incremental + fR_lambda_Incremental));

%% New Code for Condensating Heat Exchanger
%
%In order to calculate the condensation in the heat exchanger it is
%necessary to get the temperature in the heat exchanger at different
%locations. This is achieved by splitting the heat exchanger into several
%smaller heat exchangers and calculating their respective outlet
%temperatures.
if ~isfield(oCHX.txCHX_Parameters, 'mOutlet_Temp_2')
    % In case this is the first time the CHX is calculate, we do not yet
    % have a good estimation for the coolant temperatures. Therefore we
    % initialize the coolant to have the same temperature everywhere and no
    % condensation occuring
    oCHX.txCHX_Parameters.mOutlet_Temp_2        = ones(iIncrementsAir, iIncrementsCoolant,tCHX_Parameters.iBaffles+1,tCHX_Parameters.iLayers+1) * Fluid_2.fEntry_Temperature; 
    oCHX.txCHX_Parameters.mOutlet_Temp_1        = ones(iIncrementsAir, iIncrementsCoolant,tCHX_Parameters.iBaffles+1,tCHX_Parameters.iLayers) * Fluid_1.fEntry_Temperature; 
    oCHX.txCHX_Parameters.mCondensateFlowRate   = zeros(iIncrementsAir, iIncrementsCoolant,tCHX_Parameters.iBaffles+1,tCHX_Parameters.iLayers); 
end

mCondensateHeatFlow = zeros(iIncrementsAir, iIncrementsCoolant, tCHX_Parameters.iBaffles+1, tCHX_Parameters.iLayers);
mHeatFlow           = zeros(iIncrementsAir, iIncrementsCoolant, tCHX_Parameters.iBaffles+1, tCHX_Parameters.iLayers);
%If heat exchange coefficient U is zero there can be no heat transfer
%between the two fluids
if fIncrementalU == 0
    fOutlet_Temp_1 = Fluid_1.fEntry_Temperature;
    fOutlet_Temp_2 = Fluid_2.fEntry_Temperature;
    
    oCHX.afCondensateMassFlow = zeros(1, this.oMT.iSubstances);
else
    %have to split the heat exchanger for multiple pipe rows into several
    %HX with one pipe row. And also the pipes have to be splitted into
    %increments in their length.
    
    % For easier access we get the matter table object
    oMT = Fluid_1.oFlow.oMT;
    
    % preallocation of variables matrices increased to four dimensions.
    mOutlet_Temp_1      = oCHX.txCHX_Parameters.mOutlet_Temp_1;
    mOutlet_Temp_2      = oCHX.txCHX_Parameters.mOutlet_Temp_2;
    mCondensateHeatFlow = nan(iIncrementsAir, iIncrementsCoolant,tCHX_Parameters.iBaffles+1,tCHX_Parameters.iLayers);
    mCondensateFlowRate = oCHX.txCHX_Parameters.mCondensateFlowRate;
    mHeatFlow           = NaN(iIncrementsAir, iIncrementsCoolant, tCHX_Parameters.iBaffles+1, tCHX_Parameters.iLayers);
    mHeatFlowUp         = NaN(iIncrementsAir, iIncrementsCoolant, tCHX_Parameters.iBaffles+1, tCHX_Parameters.iLayers);
    mHeatFlowDown       = NaN(iIncrementsAir, iIncrementsCoolant, tCHX_Parameters.iBaffles+1, tCHX_Parameters.iLayers);
    mMassFlowFilmOut    = NaN(iIncrementsAir, iIncrementsCoolant, tCHX_Parameters.iBaffles+1, tCHX_Parameters.iLayers);
    
    tCHX_Parameters.CHX_Type = 'VerticalTube';
    % CHX.CHX_Type = 'HorizontalTube';

    % Toggle calculation mode, whether gasflow influence on Heatflux should
    % be considered
    tCHX_Parameters.GasFlow = true;
    tCHX_Parameters.fMassFlowGas        = Fluid_1.fMassflow/(iIncrementsAir*tCHX_Parameters.iLayers);	% Mass flow rate of Watervapor-Air-Mix [kg/s]
    % As stated in "Living together in space: the design and operation of
    % the life support systems on the International Space Station",
    % Wieland, Paul O., 1998, page 104, the CHX has one more coolant than
    % air layer, which makes sense because then all coolant layers can use
    % the full coolant contact area
    tCHX_Parameters.fMassFlowCoolant    = Fluid_2.fMassflow/(iIncrementsCoolant * (tCHX_Parameters.iLayers + 1));	% Mass flow rate of coolant [kg/s]

    % TO DO: Make adaptive!
    tCHX_Parameters.Vapor	 = 'H2O';					% Vapor
    tCHX_Parameters.Inertgas = 'Air';					% Inertgas
    tCHX_Parameters.Coolant  = 'H2O';					% Coolant

    tCHX_Parameters.fCellLength                 = fIncrementalLength;
    tCHX_Parameters.fCellBroadness              = fIncrementalBroadness;
    tCHX_Parameters.fCellArea                   = fIncrementalArea;
    tCHX_Parameters.alpha_coolant               = falpha_o;
    tCHX_Parameters.alpha_gas                   = falpha_pipe;
    tCHX_Parameters.oFlowCoolant                = Fluid_2.oFlow; 
    tCHX_Parameters.fThickness                  = tCHX_Parameters.fThickness;
    tCHX_Parameters.fFinThickness               = tCHX_Parameters.fFinThickness;
    tCHX_Parameters.fThermalConductivitySolid   = fThermalConductivitySolid;
    tCHX_Parameters.fPressureGas                = Fluid_1.oFlow.fPressure;
    tCHX_Parameters.fHydraulicDiameter          = 4*(tCHX_Parameters.fHeight_1 * tCHX_Parameters.fFinBroadness_1)/(2 * tCHX_Parameters.fHeight_1 + 2 * tCHX_Parameters.fFinBroadness_1);     % Hydraulic diameter [m]
    tCHX_Parameters.fCharacteristicLength       = tCHX_Parameters.fHydraulicDiameter;
    tCHX_Parameters.arPartialMassesGas          = Fluid_1.oFlow.arPartialMass;

    fInitialWaterFlowPerCell = Fluid_1.oFlow.arPartialMass(oMT.tiN2I.H2O) * tCHX_Parameters.fMassFlowGas;
    
    fOutlet_Temp_1 = sum(sum(mOutlet_Temp_1(:,iIncrementsCoolant,tCHX_Parameters.iBaffles+1,:))) / (iIncrementsAir * tCHX_Parameters.iLayers);
    fOutlet_Temp_2 = sum(sum(mOutlet_Temp_2(1,:,1,:))) / (iIncrementsCoolant * (tCHX_Parameters.iLayers + 1));
    fCondensateFlow = 0;

    % new input parameter for the FinConfig function.
    tFinInput.fFinBroadness_1       = tCHX_Parameters.fFinBroadness_1;        % broadness of the channel that is created between fins
    tFinInput.fFinBroadness_2       = tCHX_Parameters.fFinBroadness_2;        
    tFinInput.fIncrementalLenght    = fIncrementalLength;     
    tFinInput.fIncrementalBroadness = fIncrementalBroadness;

    mMoleFracVapor = nan(iIncrementsAir, iIncrementsCoolant);

    fTemperatureGasLastMatterProps     = 0;
    fTemperatureCoolantLastMatterProps = 0;
    
    iCounter = 0;
    fError = inf;
    mfError = nan(500,1);
    % Since the plate fin CHX in the CCAA uses cross counter flow
    % configuration, we do not know the correct temperature values to use
    % initially. Therefore, an iterative calculation is required to
    % calculate it
    while fError > 1e-2 && iCounter < 50
        
        iCounter = iCounter + 1;
        
        % initialization of variables for the FinConfig calculation. Detailes
        % explanaition of the calculation in the MA2018-10 by Fabian Lübbert
        % Appendix B
        tFinOutput.fOverhangAir        = 0;                      
        tFinOutput.fOverhangCoolant    = 0;
        tFinOutput.fFinOverhangAir     = 0;
        tFinOutput.fFinOverhangCoolant = 0;
        tFinOutput.iCellCounterAir     = 1;
        tFinOutput.iCellCounterCoolant = 1;
        tFinOutput.iFinCounterAir      = 1;
        tFinOutput.iFinCounterCoolant  = 1;
        
        
        %% New Calculation with discretization
        % added two more loops for the layer and baffles calculations
        for iBaffle = (tCHX_Parameters.iBaffles+1):-1:1
            if mod(iBaffle, 2) ~= 0
                miAirLoop = iIncrementsAir:-1:1;
            else
                miAirLoop = 1:iIncrementsAir;
            end
            for iAirIncrement = miAirLoop
                for iCoolantIncrement = 1:iIncrementsCoolant
                    for iLayer = 1:3
                        % checks if the fin for the actual cell is high or low
                        % (high means additional resistance)
                        tFinOutput = FinConfig(iAirIncrement, iCoolantIncrement, tFinOutput, tFinInput);

                        iFinResistance = tFinOutput.iFinStateCoolant + tFinOutput.iFinStateAir*2;

                        %iFinResistance = 0; %Debug value
                        % FinFactor adapt the Fin value if the cell is split
                        % between two fins
                        if iFinResistance == 0
                            tCHX_Parameters.iFinCoolant = 0;
                            tCHX_Parameters.iFinAir     = 0;
                        elseif iFinResistance == 1
                            tCHX_Parameters.iFinCoolant = 1*tFinOutput.fFinFactorCoolant;
                            tCHX_Parameters.iFinAir     = 0;
                        elseif iFinResistance == 2
                            tCHX_Parameters.iFinCoolant = 0;
                            tCHX_Parameters.iFinAir     = 1*tFinOutput.fFinFactorAir;
                        else
                            tCHX_Parameters.iFinCoolant = 1*tFinOutput.fFinFactorCoolant;
                            tCHX_Parameters.iFinAir     = 1*tFinOutput.fFinFactorAir;
                        end

                        % Current condensate flow in [kg/s]
                        fCurrentWaterFlow = fInitialWaterFlowPerCell;
                        if iBaffle > 1
                            % this calculation regards the condensate
                            % flow from the previous baffles, if we are
                            % not in the first baffle:
                            fCurrentWaterFlow	= fCurrentWaterFlow - sum(sum(mCondensateFlowRate(iAirIncrement,:,1:iBaffle-1,iLayer))); 
                        end
                        if iCoolantIncrement > 1
                            % In the above calculation only the
                            % condensate flow from the previous baffles
                            % is considered, here we consider the
                            % condensate flow from this baffle section
                            % as well:
                            fCurrentWaterFlow   = fCurrentWaterFlow - sum(mCondensateFlowRate(iAirIncrement,1:iCoolantIncrement-1,iBaffle,iLayer));
                        end
                        
                        % Fluid film of previous cell, that is entering current cell in [kg/s]
                        % calculate by calculating the total film mass flow
                        % rate for the current air increment and layer:
                        tCHX_Parameters.fMassFlowFilm       = fInitialWaterFlowPerCell - fCurrentWaterFlow;

                        % Temperature of incoming gas flow in [K]
                        if iCoolantIncrement == 1 && iBaffle == 1
                            % If we are in the first coolant increment and
                            % first baffle section we use the entry
                            % temperature of the air
                            tCHX_Parameters.fTemperatureGas   	= Fluid_1.fEntry_Temperature;
                        elseif iCoolantIncrement == 1 && iBaffle > 1
                            % In case this is the first coolant increment
                            % but not the first baffle section, we have to
                            % get the air temperature from the previous
                            % baffle calculation:
                            tCHX_Parameters.fTemperatureGas   	= mOutlet_Temp_1(iAirIncrement,iIncrementsCoolant,iBaffle-1,iLayer);
                        else
                            % In all other cases, we can get the gas entry
                            % temperature from the previous coolant
                            % increment of this baffle section
                            tCHX_Parameters.fTemperatureGas   	= mOutlet_Temp_1(iAirIncrement,iCoolantIncrement-1,iBaffle,iLayer);
                        end

                        % Temperature of incoming cooling fluid in [K]
                        if (iAirIncrement == iIncrementsAir && mod(iBaffle, 2) ~= 0) || (iAirIncrement == 1 && mod(iBaffle, 2) == 0)
                            % this case covers the transition from one
                            % baffle section to the next. In this case we
                            % have to calculate the mixture temperature
                            % from the previous baffle section, unless this
                            % is the last baffle section, in which case we
                            % use the entry temperature of the fluid:
                            if iBaffle == tCHX_Parameters.iBaffles+1
                                fInlet_fTemperatureCoolant_up	= Fluid_2.fEntry_Temperature;
                                fInlet_fTemperatureCoolant_down = Fluid_2.fEntry_Temperature;
                            else
                                % temperature calculation for the mix zone.
                                % Only the liquid flow is mixed! We assume
                                % here that the mix zone is infinitessimal
                                % small and that no heat exchange occurs
                                % there. Since we have the same fluid that
                                % is mixing and the fluid the temperature
                                % differences are small, we assume it all
                                % has the same specific heat capacity and
                                % therefore can just average the
                                % temperatures
                                fInlet_fTemperatureCoolant_up	= sum(mOutlet_Temp_2(iAirIncrement,:,iBaffle+1,iLayer + 1)) / iIncrementsCoolant;
                                fInlet_fTemperatureCoolant_down = sum(mOutlet_Temp_2(iAirIncrement,:,iBaffle+1,iLayer))     / iIncrementsCoolant;
                            end

                        elseif mod(iBaffle, 2) ~= 0
                            % For uneven baffle section the coolant
                            % flow passes from air increment 6 to air
                            % increment 1. Therefore, if we are in an
                            % unevern baffle section and not at the
                            % last air increment, we use the outlet
                            % temperature of the air increment one
                            % higher
                            fInlet_fTemperatureCoolant_up	= mOutlet_Temp_2(iAirIncrement+1,iCoolantIncrement,iBaffle,iLayer + 1);
                            fInlet_fTemperatureCoolant_down = mOutlet_Temp_2(iAirIncrement+1,iCoolantIncrement,iBaffle,iLayer);
                        else
                            % The only remaining case are even numbered
                            % baffle sections, where the coolant flow passes
                            % from air increment 1 to 6
                            fInlet_fTemperatureCoolant_up	= mOutlet_Temp_2(iAirIncrement-1,iCoolantIncrement,iBaffle,iLayer + 1);
                            fInlet_fTemperatureCoolant_down = mOutlet_Temp_2(iAirIncrement-1,iCoolantIncrement,iBaffle,iLayer);
                        end

                        % Molar fraction of the (condensing) vapor in the
                        % overall gas flow
                        tCHX_Parameters.fMolarFractionVapor	= (fCurrentWaterFlow/ oMT.afMolarMass(oMT.tiN2I.H2O)) / (tCHX_Parameters.fMassFlowGas / Fluid_1.oFlow.fMolarMass);
                        tCHX_Parameters.fMolarMassGas = Fluid_1.oFlow.fMolarMass;
                        % Debug option
                        mMoleFracVapor(iAirIncrement,iCoolantIncrement) = tCHX_Parameters.fMolarFractionVapor;

                        tCHX_Parameters.arPartialMassesGas(oMT.tiN2I.H2O) = (fCurrentWaterFlow/fInitialWaterFlowPerCell) * Fluid_1.oFlow.arPartialMass(oMT.tiN2I.H2O);

                        tCHX_Parameters.fTemperatureCoolant = fInlet_fTemperatureCoolant_up;
                        
                        if abs(fTemperatureGasLastMatterProps - tCHX_Parameters.fTemperatureGas) > 2
                            tCHX_Parameters = RecalculateMatterProperties(oMT, tCHX_Parameters, 1);
                            fTemperatureGasLastMatterProps     = tCHX_Parameters.fTemperatureGas;
                        end
                        if abs(fTemperatureCoolantLastMatterProps - tCHX_Parameters.fTemperatureCoolant) > 2
                            tCHX_Parameters = RecalculateMatterProperties(oMT, tCHX_Parameters, 2);
                            fTemperatureCoolantLastMatterProps = tCHX_Parameters.fTemperatureCoolant;
                        end
                        
                        [tOutputs]              = calculateLocalHeatFlow(oCHX, tCHX_Parameters);
                        fHeatFlowUp             = tOutputs.fTotalHeatFlow;
                        fCondensatFlowRateUp    = tOutputs.fCondensateMassFlow;
                        fHeatFlowCondensateUp   = tOutputs.fHeatFlowCondensate;
                        fHeatFlowGasUp          = tOutputs.fGasHeatFlow;

                        % adjust fin factor for downside
                        [fFinFlipAir, fFinFlipCoolant]  = FinFlip(tCHX_Parameters,tFinOutput);
                        tCHX_Parameters.iFinAir         = fFinFlipAir;
                        tCHX_Parameters.iFinCoolant     = fFinFlipCoolant;
                        tCHX_Parameters.fTemperatureCoolant = fInlet_fTemperatureCoolant_down;

                        fCurrentWaterFlow = fCurrentWaterFlow - fCondensatFlowRateUp;
                        if fCurrentWaterFlow < 0
                            fCurrentWaterFlow = 0;
                        end
                        tCHX_Parameters.arPartialMassesGas(oMT.tiN2I.H2O) = (fCurrentWaterFlow/fInitialWaterFlowPerCell) * Fluid_1.oFlow.arPartialMass(oMT.tiN2I.H2O);
                        tCHX_Parameters.fMolarFractionVapor	= (fCurrentWaterFlow/ oMT.afMolarMass(oMT.tiN2I.H2O)) / (tCHX_Parameters.fMassFlowGas / Fluid_1.oFlow.fMolarMass);
                        
                        [tOutputs]              = calculateLocalHeatFlow(oCHX, tCHX_Parameters);
                        fHeatFlowDown           = tOutputs.fTotalHeatFlow;
                        fCondensatFlowRateDown  = tOutputs.fCondensateMassFlow;
                        fHeatFlowCondensateDown = tOutputs.fHeatFlowCondensate;
                        fHeatFlowGasDown        = tOutputs.fGasHeatFlow;

                        mHeatFlow(iAirIncrement,iCoolantIncrement,iBaffle,iLayer)       = fHeatFlowUp + fHeatFlowDown;
                        mHeatFlowUp(iAirIncrement,iCoolantIncrement,iBaffle,iLayer)     = fHeatFlowUp;
                        mHeatFlowDown(iAirIncrement,iCoolantIncrement,iBaffle,iLayer) 	= fHeatFlowDown;
                        
                        fHeatFlowGas = fHeatFlowGasUp + fHeatFlowGasDown;

                        mCondensateFlowRate(iAirIncrement,iCoolantIncrement,iBaffle,iLayer) = fCondensatFlowRateUp  + fCondensatFlowRateDown;
                        mCondensateHeatFlow(iAirIncrement,iCoolantIncrement,iBaffle,iLayer) = fHeatFlowCondensateUp + fHeatFlowCondensateDown;

                        mMassFlowFilmOut(iAirIncrement,iCoolantIncrement,iBaffle,iLayer)    = tCHX_Parameters.fMassFlowFilm - mCondensateFlowRate(iAirIncrement,iCoolantIncrement,iBaffle,iLayer);
                        
                        mOutlet_Temp_1(iAirIncrement,iCoolantIncrement,iBaffle,iLayer)      = tCHX_Parameters.fTemperatureGas	- (fHeatFlowGas     / (tOutputs.fMassFlowGas            * tCHX_Parameters.fSpecificHeatCapacityGas));
                       
                        if iLayer ~= 1
                            mOutlet_Temp_2(iAirIncrement,iCoolantIncrement,iBaffle,iLayer)	= mOutlet_Temp_2(iAirIncrement,iCoolantIncrement,iBaffle,iLayer) 	+ (fHeatFlowDown    / (tCHX_Parameters.fMassFlowCoolant * tCHX_Parameters.fSpecificHeatCapacityCoolant));
                        else
                            mOutlet_Temp_2(iAirIncrement,iCoolantIncrement,iBaffle,iLayer)	= fInlet_fTemperatureCoolant_down 	+ (fHeatFlowDown    / (tCHX_Parameters.fMassFlowCoolant * tCHX_Parameters.fSpecificHeatCapacityCoolant));
                        end
                        mOutlet_Temp_2(iAirIncrement,iCoolantIncrement,iBaffle,iLayer+1)    = fInlet_fTemperatureCoolant_up     + (fHeatFlowUp      / (tCHX_Parameters.fMassFlowCoolant * tCHX_Parameters.fSpecificHeatCapacityCoolant));
                        
                        % Here we have to use the outlet temperature of
                        % this cell, as in the previous layer calculation
                        % we calculated an outlet temperature with only
                        % have of the flow. The only exception for this is
                        % the first layer
                    end
                    % reset FinConfig values
                    tFinOutput.iFinCounterCoolant  = 1;
                    tFinOutput.fOverhangCoolant    = 0;
                end
                tFinOutput.iFinCounterAir = 1;
                tFinOutput.fOverhangAir   = 0;
            end
        end
        
        mOutlet_Temp_2(:,:,:,tCHX_Parameters.iLayers+1)    = mOutlet_Temp_2(:,:,:,2+1);
        for iLayer = 3:tCHX_Parameters.iLayers
            mCondensateFlowRate(:,:,:,iLayer)   = mCondensateFlowRate(:,:,:,2);
            mCondensateHeatFlow(:,:,:,iLayer)   = mCondensateHeatFlow(:,:,:,2);
            mHeatFlow(:,:,:,iLayer)             = mHeatFlow(:,:,:,2);
            mMassFlowFilmOut(:,:,:,iLayer)      = mMassFlowFilmOut(:,:,:,2);
            mOutlet_Temp_1(:,:,:,iLayer)        = mOutlet_Temp_1(:,:,:,2);
            mOutlet_Temp_2(:,:,:,iLayer)        = mOutlet_Temp_2(:,:,:,2);
        end
        
        fPreviousOutletTemp1 = fOutlet_Temp_1;
        fPreviousOutletTemp2 = fOutlet_Temp_2;
        fPreviousCondensateFlow = fCondensateFlow;
        
        fOutlet_Temp_1 = sum(sum(mOutlet_Temp_1(:,iIncrementsCoolant,tCHX_Parameters.iBaffles+1,:))) / (iIncrementsAir * tCHX_Parameters.iLayers);
        fOutlet_Temp_2 = sum(sum(mOutlet_Temp_2(1,:,1,:))) / (iIncrementsCoolant * (tCHX_Parameters.iLayers + 1));
        fCondensateFlow = sum(sum(sum(sum(mCondensateFlowRate))));
        
        fError = max([abs(fOutlet_Temp_1 - fPreviousOutletTemp1), abs(fOutlet_Temp_2 - fPreviousOutletTemp2), abs(fCondensateFlow - fPreviousCondensateFlow) * 3600]);
        mfError(iCounter) = fError;
    end
end

oCHX.fTotalCondensateHeatFlow = sum(sum(sum(sum(mCondensateHeatFlow))));
oCHX.fTotalHeatFlow = sum(sum(sum(sum(mHeatFlow))));

% Outcomment this code and run it to get the data formatted into 2D for
% each layer, which makes plotting easier. Note that the coolant flow
% follows the baffles!
% iLayer = 2;
% mOutletTemp1_2D         = zeros(iIncrementsAir, iIncrementsCoolant *tCHX_Parameters.iBaffles+1);
% mOutletTemp2_2D         = zeros(iIncrementsAir, iIncrementsCoolant *tCHX_Parameters.iBaffles+1);
% mCondensateFlowRate_2D  = zeros(iIncrementsAir, iIncrementsCoolant *tCHX_Parameters.iBaffles+1);
% mMassFlowFilmOut_2D     = zeros(iIncrementsAir, iIncrementsCoolant *tCHX_Parameters.iBaffles+1);
% for iAir = 1:iIncrementsAir
%     for iCoolant = 1:iIncrementsCoolant
%         for iBaffle = 1:tCHX_Parameters.iBaffles+1
%             
%             iCoolBaff = (iBaffle - 1) * iIncrementsCoolant + iCoolant;
%             mOutletTemp1_2D(iAir, iCoolBaff)        = mOutlet_Temp_1(iAir, iCoolant, iBaffle, iLayer);
%             mOutletTemp2_2D(iAir, iCoolBaff)        = mOutlet_Temp_2(iAir, iCoolant, iBaffle, iLayer);
%             mCondensateFlowRate_2D(iAir, iCoolBaff) = mCondensateFlowRate(iAir, iCoolant, iBaffle, iLayer);
%             mMassFlowFilmOut_2D(iAir, iCoolBaff)    = mMassFlowFilmOut(iAir, iCoolant, iBaffle, iLayer);
%         end
%     end
% end
% fHeatFlow           = sum(sum(sum(sum(mHeatFlow))));
% fCondensateFlow     = sum(sum(sum(sum(mCondensateFlowRate))));
% fHeatFlowAir        = (Fluid_1.fEntry_Temperature - fOutlet_Temp_1) * tCHX_Parameters.fSpecificHeatCapacityGas      * Fluid_1.fMassflow;
% fHeatFlowCoolant    = (Fluid_2.fEntry_Temperature - fOutlet_Temp_2) * tCHX_Parameters.fSpecificHeatCapacityCoolant  * Fluid_2.fMassflow;
% fHeatFlowCondensate = oCHX.mPhaseChangeEnthalpy(oCHX.oMT.tiN2I.H2O) * fCondensateFlow;
% 
% 
% fPressureH2O = Fluid_1.oFlow.afPartialPressure(oCHX.oMT.tiN2I.H2O);
% fVaporPressure =  oCHX.hVaporPressureInterpolation(Fluid_2.fEntry_Temperature);
% fMaximumCondensateFlow = (fPressureH2O - fVaporPressure) * (Fluid_1.fMassflow / tCHX_Parameters.fDensityGas) / (Fluid_2.fEntry_Temperature * oCHX.oMT.Const.fUniversalGas / oCHX.oMT.afMolarMass(oCHX.oMT.tiN2I.H2O));
%     
% fWaterFlowInitial   =  Fluid_1.oFlow.arPartialMass(oCHX.oMT.tiN2I.H2O) * Fluid_1.fMassflow;
% fWaterFlowRemaining =  fWaterFlowInitial - fCondensateFlow;

oCHX.afCondensateMassFlow(oCHX.oMT.tiN2I.(tCHX_Parameters.Vapor)) = sum(sum(sum(sum(mCondensateFlowRate))));

% We store the calculate coolant flows, to use them as the initialization
% parameter for the next calculation of the CHX
oCHX.txCHX_Parameters.mOutlet_Temp_1 = mOutlet_Temp_1;
oCHX.txCHX_Parameters.mOutlet_Temp_2 = mOutlet_Temp_2;
oCHX.txCHX_Parameters.mCondensateFlowRate = mCondensateFlowRate;

% If you encounter any of these keyboards the CHX calculation went wrong at
% some point
if isnan(fOutlet_Temp_1) || isnan(fOutlet_Temp_2)
    keyboard()
elseif isinf(fOutlet_Temp_1) || isinf(fOutlet_Temp_2)
    keyboard()
elseif (0>fOutlet_Temp_1) || (0>fOutlet_Temp_2)
    keyboard()
end
end