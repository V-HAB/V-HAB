function [fOutlet_Temp_1, fOutlet_Temp_2, fDelta_P_1, fDelta_P_2] = ...
    plate_fin(oCHX, tCHX_Parameters, Fluid_1, Fluid_2, fThermalConductivitySolid, iIncrementsAir)

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


%calculates the further needed variables for the heat exchanger from the
%given values

% We discretize both direction equally. Increments coolant means that we
% split the coolant flow in this amount of smaller coolant flows (so that
% we basically have x coolant flows in parallel. The same applies for the
% increments of air
iIncrementsCoolant = iIncrementsAir;

%flow speed for the fluids calculated from the massflow with massflow =
%volumeflow*rho = fw*fA*frho
fFlowSpeed_Fluid1 = Fluid_1.fMassflow/(tCHX_Parameters.fHeight_1 * tCHX_Parameters.fBroadness *...
                    Fluid_1.fDensity(1));
fFlowSpeed_Fluid2 = Fluid_2.fMassflow/(tCHX_Parameters.fHeight_2 * tCHX_Parameters.fBroadness *...
                    Fluid_2.fDensity(1));
%heat capacity flow according to [1] page 173 equation (8.1)
fHeat_Capacity_Flow_1 = abs(Fluid_1.fMassflow) * Fluid_1.fSpecificHeatCapacity(1);
fHeat_Capacity_Flow_2 = abs(Fluid_2.fMassflow) * Fluid_2.fSpecificHeatCapacity(1);

% Capacity Flow for the Mix zone. Flow for one complete layer
fHeat_Capacity_Flow_Layers_1 = fHeat_Capacity_Flow_1/tCHX_Parameters.iLayers;
fHeat_Capacity_Flow_Layers_2 = fHeat_Capacity_Flow_2/tCHX_Parameters.iLayers;
%calculates the area of the heat exchanger fArea =
%tCHX_Parameters.fBroadness*tCHX_Parameters.fLength;

fIncrementalLength = tCHX_Parameters.fLength/(iIncrementsAir * tCHX_Parameters.iBaffles+1);
fIncrementalBroadness = tCHX_Parameters.fBroadness/iIncrementsCoolant;
fIncrementalArea = (tCHX_Parameters.fBroadness/iIncrementsAir)*fIncrementalLength;

%uses the function for convection along a plate to calculate the convection
%coeffcients(for further information view function help)
falpha_pipe = functions.calculateHeatTransferCoefficient.convectionPlate(tCHX_Parameters.fLength, fFlowSpeed_Fluid1,...
                Fluid_1.fDynamic_Viscosity, Fluid_1.fDensity,...
                Fluid_1.fThermal_Conductivity, Fluid_1.fSpecificHeatCapacity);
falpha_o = functions.calculateHeatTransferCoefficient.convectionPlate(tCHX_Parameters.fLength, fFlowSpeed_Fluid2,...
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
                (2*tCHX_Parameters.fBroadness+2*tCHX_Parameters.fHeight_2)) , tCHX_Parameters.fLength,...
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
    mOutlet_Temp_1      = nan(iIncrementsAir, iIncrementsCoolant,tCHX_Parameters.iBaffles+1,tCHX_Parameters.iLayers);
    mOutlet_Temp_2      = nan(iIncrementsAir, iIncrementsCoolant,tCHX_Parameters.iBaffles+1,tCHX_Parameters.iLayers);
    mCondensateHeatFlow = nan(iIncrementsAir, iIncrementsCoolant,tCHX_Parameters.iBaffles+1,tCHX_Parameters.iLayers);
    mCondensateFlowRate = zeros(iIncrementsAir, iIncrementsCoolant,tCHX_Parameters.iBaffles+1,tCHX_Parameters.iLayers);
    mHeatFlow           = NaN(iIncrementsAir, iIncrementsCoolant, tCHX_Parameters.iBaffles+1, tCHX_Parameters.iLayers);
    
    tCHX_Parameters.CHX_Type = 'VerticalTube';
    % CHX.CHX_Type = 'HorizontalTube';

    % Toggle calculation mode, whether gasflow influence on Heatflux should
    % be considered
    tCHX_Parameters.GasFlow = true;
    tCHX_Parameters.fMassFlowGas = Fluid_1.fMassflow/(iIncrementsAir*tCHX_Parameters.iLayers);	% Mass flow rate of Watervapor-Air-Mix [kg/s]
    tCHX_Parameters.fMassFlowCoolant = Fluid_2.fMassflow/(iIncrementsCoolant*tCHX_Parameters.iLayers);	% Mass flow rate of coolant [kg/s]

    % TO DO: Make adaptive!
    tCHX_Parameters.Vapor	 = 'H2O';					% Vapor
    tCHX_Parameters.Inertgas = 'Air';					% Inertgas
    tCHX_Parameters.Coolant  = 'H2O';					% Coolant

    tCHX_Parameters.fCellLength                 = tCHX_Parameters.fLength/(iIncrementsCoolant);
    tCHX_Parameters.fCellBroadness              = tCHX_Parameters.fBroadness/iIncrementsAir;
    tCHX_Parameters.fCellArea                   = fIncrementalArea;
    tCHX_Parameters.alpha_coolant               = falpha_o;
    tCHX_Parameters.alpha_gas                   = falpha_pipe;
    tCHX_Parameters.oFlowCoolant                = Fluid_2.oFlow; 
    tCHX_Parameters.fThickness                  = tCHX_Parameters.fThickness;
    tCHX_Parameters.fFinThickness               = tCHX_Parameters.fFinThickness;
    tCHX_Parameters.fThermalConductivitySolid   = fThermalConductivitySolid;
    tCHX_Parameters.fPressureGas                = Fluid_1.oFlow.fPressure;
    tCHX_Parameters.fHydraulicDiameter          = 4*(tCHX_Parameters.fHeight_1 * tCHX_Parameters.fCellBroadness)/(2 * tCHX_Parameters.fHeight_1 + 2 * tCHX_Parameters.fCellBroadness);     % Hydraulic diameter [m]
    tCHX_Parameters.fCharacteristicLength       = tCHX_Parameters.fHydraulicDiameter;

    fInitialWaterFlowPerCell = Fluid_1.oFlow.arPartialMass(oMT.tiN2I.H2O) * tCHX_Parameters.fMassFlowGas;
    fInitialWaterFlowGlobal = fInitialWaterFlowPerCell;

    % Area for mix zone tCHX_Parameters.iBaffles + 1 = number of divided
    % parts. *2 because two parts form the length of the mix zone. 10% of
    % the HX length are mix zone (assumption for now. Will be recalculated
    % when baffle length is use)
    fMixArea = (tCHX_Parameters.fBroadness/(tCHX_Parameters.iBaffles+1))*2*tCHX_Parameters.fLength*0.1; %TODO: add baffle length ...*(tCHX_Parameters.fLength-fBaffleLenght)

    % Global entry temperature. needs a save variable because
    % Fluid_1.fEntry_Temperature/2 are changed insinde the baffles loop
    fEntry_Global1 = Fluid_1.fEntry_Temperature;
    fEntry_Global2 = Fluid_2.fEntry_Temperature;

    % l: in air direction k: in coolant direction

    % new input parameter for the FinConfig function.
    tFinInput.fFinBroadness_1       = tCHX_Parameters.fFinBroadness_1;        % broadness of the channel that is created between fins
    tFinInput.fFinBroadness_2       = tCHX_Parameters.fFinBroadness_2;        
    tFinInput.fIncrementalLenght    = fIncrementalLength;     
    tFinInput.fIncrementalBroadness = fIncrementalBroadness;

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

    mMoleFracVapor = nan(iIncrementsAir, iIncrementsCoolant);

    %% New Calculation with discretization
    % added two more loops for the layer and baffles calculations
    for iLayer = 1:tCHX_Parameters.iLayers
        for iBaffle = 1:(tCHX_Parameters.iBaffles+1)
            for iAirIncrement = 1:iIncrementsAir
                for iCoolantIncrement = 1:iIncrementsCoolant
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
                      
                    %% Actual new calculation
                    %uses the function for crossflow heat exchangers for a
                    %plate heat exchanger and the to calculate the new
                    %outlet temperature of the heat exchanger (with regard
                    %to condensation from the later sections).
                    if iCoolantIncrement == 1 && iAirIncrement == 1
                        % Fluid film of previous cell, that is entering current cell [kg/s]
                        tCHX_Parameters.fMassFlowFilm = 0;
                        % Temperature of incoming gas flow in [K]
                        tCHX_Parameters.fTemperatureGas         = Fluid_1.fEntry_Temperature;
                        % Temperature of incoming cooling flow in [K]
                        tCHX_Parameters.fTemperatureCoolant    	= Fluid_2.fEntry_Temperature;
                        % Molar fraction of the (condensing) vapor in the
                        % overall gas flow
                        tCHX_Parameters.fMolarFractionVapor     = (fInitialWaterFlowPerCell/ oMT.afMolarMass(oMT.tiN2I.H2O)) / (tCHX_Parameters.fMassFlowGas / Fluid_1.oFlow.fMolarMass);

                        tCHX_Parameters.arPartialMassesGas = Fluid_1.oFlow.arPartialMass;

                        tCHX_Parameters = RecalculateMatterProperties(oMT, tCHX_Parameters);

                        % calcualtions are done twice for the upper and
                        % lower side of the layer. Two separate values are
                        % calculated and are summed up in the end

                        %calculations for the upper side of the channel
                        [tOutputs]              = calculateLocalHeatFlow(oCHX, tCHX_Parameters);
                        fHeatFlowUp             = tOutputs.fTotalHeatFlow;
                        fCondensatFlowRateUp    = tOutputs.fCondensateMassFlow ;
                        fHeatFlowCondensateUp   = tOutputs.fHeatFlowCondensate;
                        fHeatFlowGasUp          = tOutputs.fGasHeatFlow;

                        % adjust fin factor for downside as the fin
                        % configuration is different for the upper and
                        % lower side
                        [fFinFlipAir, fFinFlipCoolant]  = FinFlip(tCHX_Parameters,tFinOutput);
                        tCHX_Parameters.iFinAir         = fFinFlipAir;
                        tCHX_Parameters.iFinCoolant     = fFinFlipCoolant;

                        % calculations for the lower side of the channel
                        [tOutputs]              = calculateLocalHeatFlow(oCHX, tCHX_Parameters);
                        fHeatFlowDown           = tOutputs.fTotalHeatFlow;
                        fCondensatFlowRateDown  = tOutputs.fCondensateMassFlow  ;
                        fHeatFlowCondensateDown = tOutputs.fHeatFlowCondensate;
                        fHeatFlowGasDown        = tOutputs.fGasHeatFlow;

                        % summation of the separate values
                        mHeatFlow(iAirIncrement,iCoolantIncrement,iBaffle,iLayer) = fHeatFlowUp + fHeatFlowDown;
                        fHeatFlowGas = fHeatFlowGasUp+fHeatFlowGasDown;

                        mCondensateFlowRate(iAirIncrement,iCoolantIncrement,iBaffle,iLayer) = fCondensatFlowRateUp + fCondensatFlowRateDown;
                        mCondensateHeatFlow(iAirIncrement,iCoolantIncrement,iBaffle,iLayer) = fHeatFlowCondensateUp + fHeatFlowCondensateDown;

                        % new calculation of the outlet temperatures with
                        % the adjusted heat flows
                        mOutlet_Temp_1(iAirIncrement,iCoolantIncrement,iBaffle,iLayer) = Fluid_1.fEntry_Temperature - (fHeatFlowGas / (tCHX_Parameters.fSpecificHeatCapacityGas * tOutputs.fMassFlowGas));
                        mOutlet_Temp_2(iAirIncrement,iCoolantIncrement,iBaffle,iLayer) = Fluid_2.fEntry_Temperature + ((fHeatFlowUp) / (tCHX_Parameters.fMassFlowCoolant * tCHX_Parameters.fSpecificHeatCapacityGas));

                    elseif iAirIncrement == 1
                        % The fresh coolant flow only enters in the first
                        % baffle, and the first air increment, as the air
                        % increments are perpendicular to the flow of the
                        % coolant. However, in the loop of the baffles, we
                        % calculate new fluid entry temperatures for the
                        % coolant based on cross flow CHX with mixing,
                        % therefore, we can use the coolant fluid entry
                        % temperature for each baffle here!

                        % Current condensate flow in [kg/s]
                        fCurrentWaterFlow                   = fInitialWaterFlowPerCell - sum(sum(mCondensateFlowRate(iAirIncrement,:,1:iBaffle,iLayer))); 
                        % Fluid film of previous cell, that is entering current cell in [kg/s]
                        % calculate by calculating the total film mass flow
                        % rate for the current air increment and layer:
                        tCHX_Parameters.fMassFlowFilm       = fInitialWaterFlowPerCell - fCurrentWaterFlow;
                        % Temperature of incoming gas flow in [K]
                        tCHX_Parameters.fTemperatureGas   	= mOutlet_Temp_1(iAirIncrement,iCoolantIncrement-1,iBaffle,iLayer);
                        % Temperature of incoming cooling fluid in [K]
                        tCHX_Parameters.fTemperatureCoolant	= Fluid_2.fEntry_Temperature;
                        % Molar fraction of the (condensing) vapor in the
                        % overall gas flow
                        tCHX_Parameters.fMolarFractionVapor	= (fCurrentWaterFlow/ oMT.afMolarMass(oMT.tiN2I.H2O)) / (tCHX_Parameters.fMassFlowGas / Fluid_1.oFlow.fMolarMass);

                        % Debug option
                        mMoleFracVapor(iAirIncrement,iCoolantIncrement) = tCHX_Parameters.fMolarFractionVapor;
                        
                        tCHX_Parameters.arPartialMassesGas(oMT.tiN2I.H2O) = (fCurrentWaterFlow/fInitialWaterFlowPerCell) * Fluid_1.oFlow.arPartialMass(oMT.tiN2I.H2O);

                        [tOutputs]              = calculateLocalHeatFlow(oCHX, tCHX_Parameters);
                        fHeatFlowUp             = tOutputs.fTotalHeatFlow;
                        fCondensatFlowRateUp    = tOutputs.fCondensateMassFlow;
                        fHeatFlowCondensateUp   = tOutputs.fHeatFlowCondensate;
                        fHeatFlowGasUp          = tOutputs.fGasHeatFlow;

                        % adjust fin factor for downside
                        [fFinFlipAir, fFinFlipCoolant]  = FinFlip(tCHX_Parameters,tFinOutput);
                        tCHX_Parameters.iFinAir         = fFinFlipAir;
                        tCHX_Parameters.iFinCoolant     = fFinFlipCoolant;

                        [tOutputs]              = calculateLocalHeatFlow(oCHX, tCHX_Parameters);
                        fHeatFlowDown           = tOutputs.fTotalHeatFlow;
                        fCondensatFlowRateDown  = tOutputs.fCondensateMassFlow;
                        fHeatFlowCondensateDown = tOutputs.fHeatFlowCondensate;
                        fHeatFlowGasDown        = tOutputs.fGasHeatFlow;

                        mHeatFlow(iAirIncrement,iCoolantIncrement,iBaffle,iLayer) = fHeatFlowUp+fHeatFlowDown;
                        fHeatFlowGas = fHeatFlowGasUp+fHeatFlowGasDown;

                        mCondensateFlowRate(iAirIncrement,iCoolantIncrement,iBaffle,iLayer) = fCondensatFlowRateUp+fCondensatFlowRateDown;
                        mCondensateHeatFlow(iAirIncrement,iCoolantIncrement,iBaffle,iLayer) = fHeatFlowCondensateUp + fHeatFlowCondensateDown;

                        mOutlet_Temp_1(iAirIncrement,iCoolantIncrement,iBaffle,iLayer) = tCHX_Parameters.fTemperatureGas - (fHeatFlowGas / (tCHX_Parameters.fSpecificHeatCapacityGas * tOutputs.fMassFlowGas));
                        mOutlet_Temp_2(iAirIncrement,iCoolantIncrement,iBaffle,iLayer) = Fluid_2.fEntry_Temperature + ((fHeatFlowUp) / (tCHX_Parameters.fMassFlowCoolant * tCHX_Parameters.fSpecificHeatCapacityGas));

                    elseif iCoolantIncrement == 1 && iBaffle == 1
                        % The fresh air flow only enters in the first
                        % baffle, and the first coolant increment, as the
                        % coolant increments are perpendicular to the flow
                        % of the coolant. For the air flow, we cannot
                        % assumed mixing, as air is a single pass (see
                        % "Living together in space: the design and operation
                        % of the life support systems on the International
                        % Space Station", Wieland, Paul O., 1998, page 104,
                        % where it is mentioned that the ISS CHX is based
                        % on spacelab and then refer to:
                        % "Spacelab Phase B study environmental control
                        % system component handbook", Burns, R. A.;
                        % Ignatonis, A. J., 1994, Page 5 for the
                        % information that the CHX is a single air pass CHX
                        
                        % Fluid film of previous cell, that is entering current cell [kg/s]
                        tCHX_Parameters.fMassFlowFilm = 0;
                        % Temperature of incoming gas flow in [K]
                        tCHX_Parameters.fTemperatureGas            = Fluid_1.fEntry_Temperature;

                        if iLayer == 1
                            fInlet_fTemperatureCoolant_up    	= mOutlet_Temp_2(iAirIncrement-1,iCoolantIncrement,iBaffle,iLayer);
                            fInlet_fTemperatureCoolant_down   	= mOutlet_Temp_2(iAirIncrement-1,iCoolantIncrement,iBaffle,iLayer);
                        else
                            fInlet_fTemperatureCoolant_up      	= mOutlet_Temp_2(iAirIncrement-1,iCoolantIncrement,iBaffle,iLayer);			% Temp of cooling fluid [K]
                            fInlet_fTemperatureCoolant_down    	= mOutlet_Temp_2(iAirIncrement-1,iCoolantIncrement,iBaffle,iLayer-1);
                        end
                        % Molar fraction of the (condensing) vapor in the
                        % overall gas flow
                        tCHX_Parameters.fMolarFractionVapor     = (fInitialWaterFlowPerCell/ oMT.afMolarMass(oMT.tiN2I.H2O)) / (tCHX_Parameters.fMassFlowGas / Fluid_1.oFlow.fMolarMass);
                        tCHX_Parameters.arPartialMassesGas      = Fluid_1.oFlow.arPartialMass;                          

                        % Debug option
                        mMoleFracVapor(iAirIncrement,iCoolantIncrement) = tCHX_Parameters.fMolarFractionVapor;
                        % Temperature of incoming cooling fluid in [K]
                        tCHX_Parameters.fTemperatureCoolant = fInlet_fTemperatureCoolant_up;
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
                        [tOutputs]              = calculateLocalHeatFlow(oCHX, tCHX_Parameters);
                        fHeatFlowDown           = tOutputs.fTotalHeatFlow;
                        fCondensatFlowRateDown  = tOutputs.fCondensateMassFlow;
                        fHeatFlowCondensateDown = tOutputs.fHeatFlowCondensate;
                        fHeatFlowGasDown        = tOutputs.fGasHeatFlow;

                        mHeatFlow(iAirIncrement,iCoolantIncrement,iBaffle,iLayer) = fHeatFlowUp+fHeatFlowDown;
                        fHeatFlowGas = fHeatFlowGasUp+fHeatFlowGasDown;

                        mCondensateFlowRate(iAirIncrement,iCoolantIncrement,iBaffle,iLayer) = fCondensatFlowRateUp+fCondensatFlowRateDown;
                        mCondensateHeatFlow(iAirIncrement,iCoolantIncrement,iBaffle,iLayer) = fHeatFlowCondensateUp + fHeatFlowCondensateDown;

                        mOutlet_Temp_1(iAirIncrement,iCoolantIncrement,iBaffle,iLayer) = tCHX_Parameters.fTemperatureGas - (fHeatFlowGas / (tCHX_Parameters.fSpecificHeatCapacityGas * tOutputs.fMassFlowGas));
                        mOutlet_Temp_2(iAirIncrement,iCoolantIncrement,iBaffle,iLayer) = fInlet_fTemperatureCoolant_up + (fHeatFlowUp / (tCHX_Parameters.fMassFlowCoolant * tCHX_Parameters.fSpecificHeatCapacityGas));

                        % new calulation of the water temperatues in the
                        % lower layer
                        if iLayer > 1
                            mOutlet_Temp_2(iAirIncrement,iCoolantIncrement,iBaffle,iLayer-1) = fInlet_fTemperatureCoolant_down + (fHeatFlowDown / (tCHX_Parameters.fMassFlowCoolant * tCHX_Parameters.fSpecificHeatCapacityGas));
                        end

                    elseif iCoolantIncrement == 1
                        % In case the baffle is not the first baffle, we
                        % have to use the air temperatures from the
                        % previous baffle, and the lasst coolant increment
                        % there (as the coolant increments are
                        % perpendicular to the air flow direction!)
                        
                        % Current condensate flow in [kg/s]
                        fCurrentWaterFlow                   = fInitialWaterFlowPerCell - sum(sum(mCondensateFlowRate(iAirIncrement,:,1:iBaffle,iLayer))); 
                        % Fluid film of previous cell, that is entering current cell in [kg/s]
                        % calculate by calculating the total film mass flow
                        % rate for the current air increment and layer:
                        tCHX_Parameters.fMassFlowFilm       = fInitialWaterFlowPerCell - fCurrentWaterFlow;
                        % Temperature of incoming gas flow in [K]
                        tCHX_Parameters.fTemperatureGas       	= mOutlet_Temp_1(iAirIncrement,iIncrementsCoolant,iBaffle-1,iLayer);

                        if iLayer == 1
                            fInlet_fTemperatureCoolant_up    	= mOutlet_Temp_2(iAirIncrement-1,iCoolantIncrement,iBaffle,iLayer);
                            fInlet_fTemperatureCoolant_down   	= mOutlet_Temp_2(iAirIncrement-1,iCoolantIncrement,iBaffle,iLayer);
                        else
                            fInlet_fTemperatureCoolant_up      	= mOutlet_Temp_2(iAirIncrement-1,iCoolantIncrement,iBaffle,iLayer);			% Temp of cooling fluid [K]
                            fInlet_fTemperatureCoolant_down    	= mOutlet_Temp_2(iAirIncrement-1,iCoolantIncrement,iBaffle,iLayer-1);
                        end
                        % Molar fraction of the (condensing) vapor in the
                        % overall gas flow
                        tCHX_Parameters.fMolarFractionVapor     = (fInitialWaterFlowPerCell/ oMT.afMolarMass(oMT.tiN2I.H2O)) / (tCHX_Parameters.fMassFlowGas / Fluid_1.oFlow.fMolarMass);
                        tCHX_Parameters.arPartialMassesGas      = Fluid_1.oFlow.arPartialMass;                          

                        % Debug option
                        mMoleFracVapor(iAirIncrement,iCoolantIncrement) = tCHX_Parameters.fMolarFractionVapor;
                        % Temperature of incoming cooling fluid in [K]
                        tCHX_Parameters.fTemperatureCoolant = fInlet_fTemperatureCoolant_up;
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
                        [tOutputs]              = calculateLocalHeatFlow(oCHX, tCHX_Parameters);
                        fHeatFlowDown           = tOutputs.fTotalHeatFlow;
                        fCondensatFlowRateDown  = tOutputs.fCondensateMassFlow;
                        fHeatFlowCondensateDown = tOutputs.fHeatFlowCondensate;
                        fHeatFlowGasDown        = tOutputs.fGasHeatFlow;

                        mHeatFlow(iAirIncrement,iCoolantIncrement,iBaffle,iLayer) = fHeatFlowUp+fHeatFlowDown;
                        fHeatFlowGas = fHeatFlowGasUp+fHeatFlowGasDown;

                        mCondensateFlowRate(iAirIncrement,iCoolantIncrement,iBaffle,iLayer) = fCondensatFlowRateUp+fCondensatFlowRateDown;
                        mCondensateHeatFlow(iAirIncrement,iCoolantIncrement,iBaffle,iLayer) = fHeatFlowCondensateUp + fHeatFlowCondensateDown;

                        mOutlet_Temp_1(iAirIncrement,iCoolantIncrement,iBaffle,iLayer) = tCHX_Parameters.fTemperatureGas - (fHeatFlowGas / (tCHX_Parameters.fSpecificHeatCapacityGas * tOutputs.fMassFlowGas));
                        mOutlet_Temp_2(iAirIncrement,iCoolantIncrement,iBaffle,iLayer) = fInlet_fTemperatureCoolant_up + (fHeatFlowUp / (tCHX_Parameters.fMassFlowCoolant * tCHX_Parameters.fSpecificHeatCapacityGas));

                        % new calulation of the water temperatues in the
                        % lower layer
                        if iLayer > 1
                            mOutlet_Temp_2(iAirIncrement,iCoolantIncrement,iBaffle,iLayer-1) = fInlet_fTemperatureCoolant_down + (fHeatFlowDown / (tCHX_Parameters.fMassFlowCoolant * tCHX_Parameters.fSpecificHeatCapacityGas));
                        end
                        
                    else

                        fCurrentWaterFlow               = fInitialWaterFlowPerCell - sum(sum(mCondensateFlowRate(iAirIncrement,:,1:iBaffle,iLayer)));
                        tCHX_Parameters.fMassFlowFilm   = fInitialWaterFlowPerCell - fCurrentWaterFlow;					% Fluid film of previous cell, that is entering current cell [kg/s]
                        tCHX_Parameters.fTemperatureGas	= mOutlet_Temp_1(iAirIncrement-1,iCoolantIncrement,iBaffle,iLayer);			% Temp of incoming gasflow [K]
                        if iLayer == 1
                            fInlet_fTemperatureCoolant_up     = mOutlet_Temp_2(iAirIncrement-1,iCoolantIncrement,iBaffle,iLayer);			% Temp of cooling fluid [K]
                            fInlet_fTemperatureCoolant_down   = mOutlet_Temp_2(iAirIncrement-1,iCoolantIncrement,iBaffle,iLayer);
                        else
                            fInlet_fTemperatureCoolant_up     = mOutlet_Temp_2(iAirIncrement-1,iCoolantIncrement,iBaffle,iLayer);
                            fInlet_fTemperatureCoolant_down   = mOutlet_Temp_2(iAirIncrement-1,iCoolantIncrement,iBaffle,iLayer-1);
                        end
                        tCHX_Parameters.fMolarFractionVapor = (fCurrentWaterFlow/ oMT.afMolarMass(oMT.tiN2I.H2O)) / (tCHX_Parameters.fMassFlowGas / Fluid_1.oFlow.fMolarMass); % mol/s mol/s

                        % Debug option
                        mMoleFracVapor(iAirIncrement,iCoolantIncrement) = tCHX_Parameters.fMolarFractionVapor;
                        
                        tCHX_Parameters.arPartialMassesGas(oMT.tiN2I.H2O) = (fCurrentWaterFlow/fInitialWaterFlowPerCell) * Fluid_1.oFlow.arPartialMass(oMT.tiN2I.H2O);

                        tCHX_Parameters.fTemperatureCoolant = fInlet_fTemperatureCoolant_up;

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
                        [tOutputs]              = calculateLocalHeatFlow(oCHX, tCHX_Parameters);
                        fHeatFlowDown           = tOutputs.fTotalHeatFlow;
                        fCondensatFlowRateDown  = tOutputs.fCondensateMassFlow;
                        fHeatFlowCondensateDown = tOutputs.fHeatFlowCondensate;
                        fHeatFlowGasDown        = tOutputs.fGasHeatFlow;

                        mHeatFlow(iAirIncrement,iCoolantIncrement,iBaffle,iLayer) = fHeatFlowUp+fHeatFlowDown;
                        fHeatFlowGas = fHeatFlowGasUp+fHeatFlowGasDown;

                        mCondensateFlowRate(iAirIncrement,iCoolantIncrement,iBaffle,iLayer) = fCondensatFlowRateUp+fCondensatFlowRateDown;
                        mCondensateHeatFlow(iAirIncrement,iCoolantIncrement,iBaffle,iLayer) = fHeatFlowCondensateUp + fHeatFlowCondensateDown;

                        mOutlet_Temp_1(iAirIncrement,iCoolantIncrement,iBaffle,iLayer) = tCHX_Parameters.fTemperatureGas - (fHeatFlowGas / (tCHX_Parameters.fSpecificHeatCapacityGas * tOutputs.fMassFlowGas));
                        mOutlet_Temp_2(iAirIncrement,iCoolantIncrement,iBaffle,iLayer) = fInlet_fTemperatureCoolant_up + (fHeatFlowUp / (tCHX_Parameters.fMassFlowCoolant * tCHX_Parameters.fSpecificHeatCapacityCoolant));

                        if iLayer > 1
                            mOutlet_Temp_2(iAirIncrement,iCoolantIncrement,iBaffle,iLayer-1) = fInlet_fTemperatureCoolant_down + (fHeatFlowDown / (tCHX_Parameters.fMassFlowCoolant * tCHX_Parameters.fSpecificHeatCapacityGas));
                        end

                    end
                    
                    if isnan(mOutlet_Temp_1(iAirIncrement,iCoolantIncrement,iBaffle,iLayer)) || mOutlet_Temp_1(iAirIncrement,iCoolantIncrement,iBaffle,iLayer) < 273

                        keyboard()
                    end
                        
                end
                % reset FinConfig values
                tFinOutput.iFinCounterCoolant  = 1;
                tFinOutput.fOverhangCoolant    = 0;
            end
            tFinOutput.iFinCounterAir = 1;
            tFinOutput.fOverhangAir   = 0;


            % temperature calculation for the mix zone. Only the liquid
            % flow is mixed! We assume here that the mix zone is
            % infinitessimal small and that no heat exchange occurs there.
            Fluid_2.fEntry_Temperature = sum(mOutlet_Temp_2(:,end,iBaffle,iLayer))/size(mOutlet_Temp_2,2);
        end

        % reset inlet variables of the loop for the next layer
        fInitialWaterFlowPerCell = fInitialWaterFlowGlobal;
        Fluid_1.fEntry_Temperature = fEntry_Global1;
        Fluid_2.fEntry_Temperature = fEntry_Global2;

    end
    %% put keyboard or breakpoint here if you want internal values of the CHX
    %  mesh(mOutlet_Temp_1); hold on; mesh(mOutlet_Temp_2);
    %keyboard() calculates the outlet temperatures by averaging the results
    fOutlet_Temp_1 = sum(sum(mOutlet_Temp_1(end,:,tCHX_Parameters.iBaffles+1,:)))/(iIncrementsCoolant*tCHX_Parameters.iLayers);
    fOutlet_Temp_2 = sum(sum(mOutlet_Temp_2(:,end,tCHX_Parameters.iBaffles+1,:)))/(iIncrementsAir*tCHX_Parameters.iLayers);
end

oCHX.fTotalCondensateHeatFlow = sum(sum(sum(sum(mCondensateHeatFlow))));
oCHX.fTotalHeatFlow = sum(sum(sum(sum(mHeatFlow))));

oCHX.afCondensateMassFlow(oCHX.oMT.tiN2I.(tCHX_Parameters.Vapor)) = sum(sum(sum(sum(mCondensateFlowRate))));

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