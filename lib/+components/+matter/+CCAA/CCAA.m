classdef CCAA < vsys
    
    
    %% Common Cabin Air Assembly (CCAA)
    %
    % The CCAA is used onboard the ISS to control the humidity and
    % temperature within the ISS. For humidity control a condensing heat
    % exchanger is used to remove excess humidity from the ISS. The
    % temperature control is achiev through a normal heat exchanger which
    % is not modelled at the moment.
    
    properties (SetAccess = protected, GetAccess = public)
        %Variable to decide wether the CCAA is active or not. Used for the
        %Case study to make it easier to switch them on or off
        bActive = true;
        
        % To emulate protoflight test data the option to set specific
        % values for the TCCV angle and coolant/gas flows as implemented
        tFixValues;
        bUseFixValues;
        
        bKickValveAktivated = 0;            % Variable used to execute the kick valve
        fKickValveAktivatedTime = 0;        % Variable used to execute the kick valve
        
        mfCHXAirFlow;                       % Table used to calculate the flow rates of the ARS valve
        fTCCV_Angle = 40;                   % opening angle of the TCCV valve, set inititally to the medium value (min is 9° max is 84°)
        
        % allowed coolant flow is between 600 and 1230 lb/hr See "Living
        % together in space: the design and operation of the life support
        % systems on the International Space Station", Wieland, Paul O.,
        % 1998, page 104 Note that the coolant flow is provided with 1230
        % lb/hr for the lab and hab and 600 lb/hr for the Node 2 and AL
        fCoolantFlowRate = 0.0755987283; % 600 lb/hr
        
        % The CHX data is given for 50 to 450 cfm so the CCAA
        % should have at least 450 cfm of inlet flow that can enter
        % the CHX. And 450 cfm are 0.2124 m^3/s
        % cfm = cubic feet per minute
        fVolumetricFlowRate = 0.2;
            
        % relative humidity in the connected module
        rRelHumidity = 0.45;
        
        % Property to save the interpolation for the CHX air flow based on
        % the angle value
        Interpolation;
        
        % Porperty to save the interpolation for the CHX effectiveness
        interpolateEffectiveness;
        
        % subsystem name for the asccociated CDRA
        sCDRA;
        
        % According to "International Space Station Carbon Dioxide Removal
        % Assembly Testing" 00ICES-234 James C. Knox (2000) the minmal flow
        % rate for CDRA to remove enough CO2 is 41 kg/hr. The nominal flow
        % through CDRA is supposed to be 42.7 kg/hr.
        fCDRA_FlowRate = 1.187e-2;
        
        % Object for the phase of the module where the CCAA is located. Used
        % to get the current relative humidity and control the valve angles
        % accordingly and to calculate the current mass flow entering the
        % CCAA based on the volumetric flow rate
       	oAtmosphere;
        
        % struct that contains basic atmospheric values for the
        % initialization of the CCAA phases. Required fields for the struct
        % are fTemperature, fPressure and fRelHumidity
        tAtmosphere;
        
        % Value for the coolant temperature used for the CCAA
        fCoolantTemperature;
        
        % Property to save the inital water mass within the CHX condensate
        % phase. This is used to calculate the amount of condensate that
        % was actually produced between the activation of the kick valve.
        fInitialCHXWaterMass;
        
        % Temp Change allowed before CHX is recalculated
        fTempChange = 1;
        % Percental Change allowed to Massflow/Pressure/Composition of
        % Flow before CHX is recalculated
        fPercentChange = 0.025;
        
        % Intended temperature set by the crew in K
        fTemperatureSetPoint = 295.35;
        %ICES 2015-27: "...history shows that the crew generally keeps 
        %the temperature inside the USOS at or above 22.2C (72F)..."
        %Here assumption that this is the nominal temperature used
        %throughout ISS 
        
        % Time at which the temperature started to deviate from the set
        % point by more than 0.5 K
        fErrorTime = 0;
        
        % See "Living together in space: the design and operation of the
        % life support systems on the International Space Station" P.O.
        % Wieland, 1998, page 104, where the CCAA fan power consumption is
        % mentioned to be 410 W
        fCurrentPowerConsumption = 410; % W
    end
    
    methods 
        function this = CCAA (oParent, sName, fTimeStep, fCoolantTemperature, tAtmosphere, sCDRA, fCDRA_FlowRate)
            % The time step has to be set since the exec function will not
            % be called frequently otherwise
            this@vsys(oParent, sName, fTimeStep);
            
            % CCAA coolant temperature
            this.fCoolantTemperature = fCoolantTemperature;
            % Struct containing basic atmospheric values used in the phase
            % initialization for the CCAA
            if isempty(tAtmosphere)
                this.tAtmosphere.fTemperature = this.oMT.Standard.Temperature;
                this.tAtmosphere.rRelHumidity = 0.5;
                this.tAtmosphere.fPressure    = this.oMT.Standard.Pressure;
            else
                this.tAtmosphere = tAtmosphere;
            end
            
            % The Carbon Dioxide Removal Assembly (CDRA) can only be used
            % together with a CCAA, however a CCAA can also be used without
            % a CDRA. Therefore it is possible to leave the sCDRA variable,
            % which normaly contains the subsystem name for the asccoiated
            % CDRA empty. If it is empty it is assumed that this CCAA does
            % not have a CDRA connected to it.
            if (nargin > 5) && ~isempty(sCDRA)
                this.sCDRA = sCDRA;
                if nargin > 6
                    this.fCDRA_FlowRate = fCDRA_FlowRate;
                end
            else
                this.fCDRA_FlowRate = 0;
            end
            
            % Loading the flow rate table for the valves
            this.mfCHXAirFlow = load(strrep('lib\+components\+matter\+CCAA\CCAA_CHXAirflowMean.mat', '\', filesep));
                
           	this.Interpolation = griddedInterpolant(this.mfCHXAirFlow.TCCV_Angle, this.mfCHXAirFlow.CHXAirflowMean);
            
            %CHX Effectivness interpolation:
            % Thermal Performance Data (ICES 2005-01-2801)
            % Coolant Water Conditions
            % - 600 lb/hr coolant flow
            % - 40°F coolant inlet temperature
            fAirInletTemperatureData = [67 75 82];
            fAirInletFlowData        = [50 100 150 200 250 300 350 400 450];
            fInletDewPointData       = [42 48 54 60];
            aEffectiveness(1,:,:) = [...
                1.000 0.985 0.970 0.955 0.925 0.890 0.845 0.805 0.760;...
                1.000 0.980 0.960 0.925 0.880 0.840 0.805 0.770 0.740;...
                1.000 0.975 0.945 0.910 0.840 0.780 0.730 0.690 0.655;...
                1.000 0.960 0.920 0.865 0.790 0.720 0.650 0.600 0.555];
            aEffectiveness(2,:,:) = [...
                1.000 0.990 0.975 0.960 0.930 0.895 0.850 0.810 0.770;...
                1.000 0.985 0.965 0.935 0.895 0.860 0.830 0.800 0.765;...
                1.000 0.980 0.960 0.920 0.865 0.810 0.770 0.730 0.700;...
                1.000 0.970 0.940 0.900 0.825 0.760 0.705 0.660 0.625];
            aEffectiveness(3,:,:) = [...
                1.000 0.995 0.980 0.965 0.935 0.895 0.860 0.815 0.775;...
                1.000 0.990 0.970 0.940 0.905 0.875 0.840 0.810 0.770;...
                1.000 0.985 0.965 0.925 0.875 0.830 0.790 0.760 0.730;...
                1.000 0.980 0.955 0.910 0.840 0.780 0.735 0.695 0.670];
            
            aPermutedEffectiveness = permute(aEffectiveness, [2 1 3]);
            
            [X,Y,Z] = ndgrid(fInletDewPointData, fAirInletTemperatureData, fAirInletFlowData);
            this.interpolateEffectiveness = griddedInterpolant(X, Y, Z, aPermutedEffectiveness);
        end
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            
            %% Creating the stores
            % Creating the TCCV (Temperatue Check and Control Valve)
            matter.store(this, 'TCCV', 1e-6); 
            % Uses the custom air helper to set the air phase
            oAir	= this.toStores.TCCV.createPhase( 'gas', 'flow', 'TCCV_PhaseGas', this.toStores.TCCV.fVolume, struct('N2', 0.7896 * this.tAtmosphere.fPressure, 'O2', 0.21 * this.tAtmosphere.fPressure, 'CO2',  0.0004 * this.tAtmosphere.fPressure),	this.tAtmosphere.fTemperature,	this.tAtmosphere.rRelHumidity);
            
            matter.procs.exmes.gas(oAir, 'Port_In');
            matter.procs.exmes.gas(oAir, 'Port_Out_1');
            matter.procs.exmes.gas(oAir, 'Port_Out_2');
            
            % Creating the CHX
            % Within the CHX store the phase change of the humidity in the
            % air to liquid water is done. However the calculation how much
            % water has to condense is done in the CHX!
            %
            % The 2 m³ volume is too large for the actual system but V-HAB
            % has trouble correctly calculating small volumes
            matter.store(this, 'CHX', 0.11);
            % Input phase
            oInput	= this.toStores.CHX.createPhase( 'gas', 'flow', 'CHX_PhaseIn', 1e-6, struct('N2', 0.7896 * this.tAtmosphere.fPressure, 'O2', 0.21 * this.tAtmosphere.fPressure, 'CO2',  0.0004 * this.tAtmosphere.fPressure),	this.tAtmosphere.fTemperature,	this.tAtmosphere.rRelHumidity);
            
            % H2O phase
            oH2O            = this.toStores.CHX.createPhase('liquid',  'CHX_H2OPhase',       0.1,      struct('H2O', 1), this.fCoolantTemperature, this.tAtmosphere.fPressure);
            this.fInitialCHXWaterMass = oH2O.fMass;
            % Creating the ports
            matter.procs.exmes.gas(oInput, 'Flow_In');
            matter.procs.exmes.gas(oInput, 'Flow_Out_Gas');
            % This proc is only required if the CCAA has a CDRA connected to it
            if ~isempty(this.sCDRA)
                matter.procs.exmes.gas(oInput, 'Flow_Out_Gas2');
            end
            matter.procs.exmes.gas(oInput, 'filterport_Gas');
            matter.procs.exmes.liquid(oH2O, 'filterport_Liquid');
            matter.procs.exmes.liquid(oH2O, 'Flow_Out_Liquid');
            
            matter.store(this, 'Mixing', 1e-6);
            % Input phase
            oMixing	= this.toStores.Mixing.createPhase( 'gas', 'flow', 'MixedGas', 1e-6, struct('N2', 0.7896 * this.tAtmosphere.fPressure, 'O2', 0.21 * this.tAtmosphere.fPressure, 'CO2',  0.0004 * this.tAtmosphere.fPressure),	this.tAtmosphere.fTemperature,	this.tAtmosphere.rRelHumidity);
            
            matter.procs.exmes.gas(oMixing, 'Bypass_In');
            matter.procs.exmes.gas(oMixing, 'CHX_Air_In');
            matter.procs.exmes.gas(oMixing, 'CCAA_Out');
            
            % Creating the CHX
            % Some configurating variables
            sHX_type = 'plate_fin';       % Heat exchanger type
            % broadness of the heat exchange area in m
            tGeometry.fBroadness        = 1;  
            % Height of the channel for fluid 1 in m
            tGeometry.fHeight_1         = 0.002;
            % Height of the channel for fluid 2 in m
            tGeometry.fHeight_2         = 0.002;
            % length of the heat exchanger in m
            tGeometry.fLength           = 1;
            % thickness of the plate in m
            tGeometry.fThickness        = 0.0002;
            % number of layers stacked
            tGeometry.iLayers           = 33;
            % number of baffles (evenly distributed)
            tGeometry.iBaffles          = 3;
            % broadness of a fin of the first canal (air)
            tGeometry.fFinBroadness_1	= tGeometry.fBroadness/180;
            % broadness of a fin of the second canal (coolant)
            tGeometry.fFinBroadness_2	= tGeometry.fBroadness/180; 
            %  Thickness of the Fins (for now both fins have the same thickness
            tGeometry.fFinThickness     = 0.0002;
            % Conductivity of the Heat exchanger solid material (W/m K)
            Conductivity = 205;
            % Number of incremental heat exchangers used in the calculation
            % of the CHX
            miIncrements = [10,5];
            % Defines when the CHX should be recalculated: 
            fTempChangeToRecalc = 1;        % If any inlet temperature changes by more than 1 K
            fPercentChangeToRecalc = 0.05;  % If any inlet flowrate or composition changes by more than 5%
            
            % defines the heat exchanged object using the previously created properties
            % (oParent, sName, mHX, sHX_type, iIncrements, fHX_TC, fTempChangeToRecalc, fPercentChangeToRecalc)
            oCCAA_CHX = components.matter.CHX(this, 'CCAA_CHX', tGeometry, sHX_type, miIncrements, Conductivity, fTempChangeToRecalc, fPercentChangeToRecalc);
            
            % adds the P2P proc for the CHX that takes care of the actual
            % phase change
            oCCAA_CHX.oP2P =components.matter.HX.CHX_p2p(this.toStores.CHX, 'CondensingHX', 'CHX_PhaseIn.filterport_Gas', 'CHX_H2OPhase.filterport_Liquid', oCCAA_CHX);

            % Store that contains the coolant passing through the CHX. This
            % store is only necessary because it is not possible to have
            % System Interfaces without a store in between.
            matter.store(this, 'CoolantStore', 1e-6);
            % H2O phase
            % Temperature is from ICES-2015-27: Low temperature loop in US lab 
            % has a temperature between 4.4°c and 9.4°C. But also a document from
            % Boeing about the ECLSS states: "The LTL is designed to operate at 40° F (4° C).."
            % From Active Thermal Control System (ATCS) Overview:
            % http://www.nasa.gov/pdf/473486main_iss_atcs_overview.pdf
            
            oH2O            = this.toStores.CoolantStore.createPhase('liquid', 'flow',  'CHX_H2OPhase',       this.toStores.CoolantStore.fVolume,      struct('H2O', 1), this.fCoolantTemperature, this.tAtmosphere.fPressure);
            matter.procs.exmes.liquid(oH2O, 'Flow_In_Coolant');
            matter.procs.exmes.liquid(oH2O, 'Flow_Out_Coolant');
            
            %% Creating the flowpath into this subsystem ('store.exme', {'f2f-processor', 'f2f-processor'}, 'system level port name')
            %  Creating the flowpaths between the Components
            %  Creating the flowpath out of this subsystem ('store.exme', {'f2f-processor', 'f2f-processor'}, 'system level port name')
            
            components.matter.pipe(this, 'Pipe_TCCV', 1, 0.1, 2e-3);
            components.matter.pipe(this, 'Pipe_CHX', 1, 0.1, 2e-3);
            components.matter.pipe(this, 'Pipe_Out', 1, 0.1, 2e-3);
            components.matter.pipe(this, 'Pipe_Coolant_Out', 1, 0.1, 2e-3);
            
            matter.branch(this, 'TCCV.Port_In',                     {},                     'CCAA_In',                  'CCAA_In_FromCabin');	% Creating the flowpath into this subsystem
            matter.branch(this, 'TCCV.Port_Out_1',                  {'CCAA_CHX_1'},         'CHX.Flow_In',              'TCCV_CHX');
            matter.branch(this, 'CHX.Flow_Out_Gas',                 {'Pipe_CHX'},           'Mixing.CHX_Air_In',        'CHX_Cabin');
            matter.branch(this, 'TCCV.Port_Out_2',                  {'Pipe_TCCV'},          'Mixing.Bypass_In',       	'TCCV_Cabin');
            matter.branch(this, 'Mixing.CCAA_Out',                  {'Pipe_Out'},           'CCAA_Air_Out',              'CCAA_Air_Out');
            matter.branch(this, 'CHX.Flow_Out_Liquid',              {},                     'CCAA_CHX_Condensate_Out',  'Condensate_Out');      % Creating the water flowpath out of this subsystem
            matter.branch(this, 'CoolantStore.Flow_In_Coolant',     {'CCAA_CHX_2'},         'CCAA_CoolantIn',           'Coolant_In');
            matter.branch(this, 'CoolantStore.Flow_Out_Coolant',    {'Pipe_Coolant_Out'},  	'CCAA_CoolantOut',          'Coolant_Out');
            
            
            % These branches are only necessary if a CDRA is connected to
            % the CCAA
            if ~isempty(this.sCDRA)
                matter.branch(this, 'CHX.Flow_Out_Gas2',            {},                     'CCAA_CHX_to_CDRA_Out',     'CHX_CDRA');
            end
            
        end
        
        function sealThermalStructure(this)
            sealThermalStructure@thermal.container(this);
        end
             
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            % Creating the flowpath into this subsystem
            solver.matter.manual.branch(this.toBranches.CCAA_In_FromCabin);
            solver.matter.manual.branch(this.toBranches.TCCV_Cabin);
            solver.matter.manual.branch(this.toBranches.Condensate_Out);
            solver.matter.manual.branch(this.toBranches.Coolant_In);
            
            aoMultiSolverBranches = [this.toBranches.TCCV_CHX, this.toBranches.CHX_Cabin, this.toBranches.CCAA_Air_Out, this.toBranches.Coolant_Out];
            solver.matter_multibranch.iterative.branch(aoMultiSolverBranches, 'complex');
            
            if ~isempty(this.sCDRA)
                solver.matter.manual.branch(this.toBranches.CHX_CDRA);
                
                this.toBranches.CHX_CDRA.oHandler.setFlowRate(this.fCDRA_FlowRate);
            end
            
            if this.bUseFixValues
                
                this.fTCCV_Angle = this.tFixValues.fTCCV_Angle;
                fFlowPercentageCHX = this.Interpolation(this.fTCCV_Angle);
                
                this.toBranches.CCAA_In_FromCabin.oHandler.setVolumetricFlowRate(-this.tFixValues.fVolumetricAirFlowRate);
                
                fTCCV_To_Cabin_FlowRate = (1 - fFlowPercentageCHX) * this.tFixValues.fVolumetricAirFlowRate; 
                this.toBranches.TCCV_Cabin.oHandler.setVolumetricFlowRate(fTCCV_To_Cabin_FlowRate);
                
                this.toBranches.Coolant_In.oHandler.setFlowRate(-this.tFixValues.fCoolantFlowRate);
                
            else
                fInFlow = this.fVolumetricFlowRate*this.oAtmosphere.fDensity;
                fError = this.fTemperatureSetPoint - this.oAtmosphere.fTemperature;

                if this.fErrorTime == 0
                    this.fErrorTime = this.oTimer.fTime;
                end
                % Proportional Part of the control logic:
                fNew_TCCV_Angle = this.fTCCV_Angle + 3.42 * fError + 0.023 * (this.oTimer.fTime - this.fErrorTime);

                % limits the TCCV angle
                if fNew_TCCV_Angle < 9
                    fNew_TCCV_Angle = 9;
                elseif fNew_TCCV_Angle > 84
                    fNew_TCCV_Angle = 84;
                end
                this.fTCCV_Angle = fNew_TCCV_Angle;
                %fTCCV_Angle = (this.rTCCV_ratio) * 77 + 3;

                this.toBranches.CCAA_In_FromCabin.oHandler.setFlowRate(-fInFlow);

                fInFlow2 = 0;

                % Uses the interpolation for the TCCV to calculate the
                % percentage of flow entering the CHX
                fFlowPercentageCHX = this.Interpolation(fNew_TCCV_Angle);
                % Gets the two flow rates exiting the TCCV
                fTCCV_To_Cabin_FlowRate = (1 - fFlowPercentageCHX) * (fInFlow+fInFlow2);

                this.toBranches.TCCV_Cabin.oHandler.setFlowRate(fTCCV_To_Cabin_FlowRate);

                if this.bActive == 1
                    %% Setting of initial flow rates
                    this.toBranches.Coolant_In.oHandler.setFlowRate(-this.fCoolantFlowRate);
                end
            end
            
            % Set time step properties
            csStoreNames = fieldnames(this.toStores);
            for iStore = 1:length(csStoreNames)
                for iPhase = 1:length(this.toStores.(csStoreNames{iStore}).aoPhases)
                    oPhase = this.toStores.(csStoreNames{iStore}).aoPhases(iPhase);
                    
                    arMaxChange = zeros(1,this.oMT.iSubstances);
                    arMaxChange(this.oMT.tiN2I.Ar) = 0.75;
                    arMaxChange(this.oMT.tiN2I.O2) = 0.75;
                    arMaxChange(this.oMT.tiN2I.N2) = 0.75;
                    arMaxChange(this.oMT.tiN2I.H2O) = 0.05;
                    arMaxChange(this.oMT.tiN2I.CO2) = 0.05;
                    tTimeStepProperties.arMaxChange = arMaxChange;
                    tTimeStepProperties.rMaxChange = 0.01;
                    
                    oPhase.setTimeStepProperties(tTimeStepProperties);
                end
            end
            
            this.setThermalSolvers();
        end           
        
            %% Function to connect the system and subsystem level branches with each other
        function setIfFlows(this, sAirIn, sAirOut, sCondensateOut, sCoolantIn, sCoolantOut, sCDRA_IF)
            this.connectIF('CCAA_In' ,                  sAirIn);
            this.connectIF('CCAA_Air_Out' ,             sAirOut);
            this.connectIF('CCAA_CHX_Condensate_Out' ,  sCondensateOut);
            this.connectIF('CCAA_CoolantIn' ,           sCoolantIn);
            this.connectIF('CCAA_CoolantOut' ,          sCoolantOut);
            this.oAtmosphere = this.toBranches.CCAA_In_FromCabin.coExmes{2}.oPhase;
            
            if nargin >= 7
                % Case of a CDRA connected to the CCAA
                this.connectIF('CCAA_CHX_to_CDRA_Out' , sCDRA_IF);
            elseif nargin < 6 || nargin > 7
                error('CCAA Subsystem was given the wrong number of interfaces')
            end
            
        end
        
        function setFixValues(this, tFixValues)
            % tFixValues can have the following fields:
            % fTCCV_Angle
            % fVolumetricAirFlowRate
            % fCoolantFlowRate
            this.tFixValues = tFixValues;
            this.bUseFixValues = true;
        end
        
        function setCoolantFlowRate(this, fCoolantMassFlow)
            % This function can be used to change the coolant mass flow.
            % The base value is 600 lb/hr, but e.g. in US Lab and Hab the
            % flowrate is 1230 lb/hr see:
            % "Living together in space: the design and operation of the
            % life support systems on the International Space Station",
            % Wieland, Paul O., 1998, page 104 Note that the coolant flow
            % is provided with 1230 lb/hr for the lab and hab and 600 lb/hr
            % for the Node 2 and AL
            this.fCoolantFlowRate = fCoolantMassFlow;
            this.toBranches.Coolant_In.oHandler.setFlowRate(-this.fCoolantFlowRate);
        end
        
        function setNumericalParameters(this, fTempChange, fPercentChange)
            
            % Temp Change allowed before CHX is recalculated
            this.fTempChange = fTempChange;
            % Percental Change allowed to Massflow/Pressure/Composition of
            % Flow before CHX is recalculated
            this.fPercentChange = fPercentChange;
        end
        
        function setTemperature(this, fTemperature)
            this.fTemperatureSetPoint = fTemperature;
            
            
            fInFlow = this.fVolumetricFlowRate *this.oAtmosphere.fDensity;
            fError = this.fTemperatureSetPoint - this.oAtmosphere.fTemperature;
            
            if this.fErrorTime == 0
                this.fErrorTime = this.oTimer.fTime;
            end
            % Proportional Part of the control logic:
            fNew_TCCV_Angle = this.fTCCV_Angle + 3.42 * fError + 0.023 * (this.oTimer.fTime - this.fErrorTime);
            
            % limits the TCCV angle
            if fNew_TCCV_Angle < 9
                fNew_TCCV_Angle = 9;
            elseif fNew_TCCV_Angle > 84
                fNew_TCCV_Angle = 84;
            end
            this.fTCCV_Angle = fNew_TCCV_Angle;
          	%fTCCV_Angle = (this.rTCCV_ratio) * 77 + 3;
            
            this.toBranches.CCAA_In_FromCabin.oHandler.setFlowRate(-fInFlow);

            fInFlow2 = 0;
            
            % Uses the interpolation for the TCCV to calculate the
            % percentage of flow entering the CHX
            fFlowPercentageCHX = this.Interpolation(fNew_TCCV_Angle);
            % Gets the two flow rates exiting the TCCV
            fTCCV_To_Cabin_FlowRate = (1 - fFlowPercentageCHX) * (fInFlow+fInFlow2);

            this.toBranches.TCCV_Cabin.oHandler.setFlowRate(fTCCV_To_Cabin_FlowRate);
        end
        
        function setActive(this, bActive)
            % This function can be used to set the CDRA inactive,
            this.bActive = bActive;
            if this.bActive
                this.fCurrentPowerConsumption =  410;
                this.toBranches.Coolant_In.oHandler.setFlowRate(-this.fCoolantFlowRate); 
            else
                this.fCurrentPowerConsumption = 0;
                this.toBranches.CCAA_In_FromCabin.oHandler.setFlowRate(0);
                this.toBranches.TCCV_Cabin.oHandler.setFlowRate(0);
                this.toBranches.Coolant_In.oHandler.setFlowRate(0); 
            end
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
            % in case the CCAA was set to be inactive the flowrates are all
            % set to zero and the calculation is aborted
            if this.bActive == 0
                this.toBranches.CCAA_In_FromCabin.oHandler.setFlowRate(0);
                this.toBranches.TCCV_Cabin.oHandler.setFlowRate(0);
                this.toBranches.Coolant_In.oHandler.setFlowRate(0); 
                
                return
            end
            
            if ~this.bUseFixValues
                % The CHX data is given for 50 to 450 cfm so the CCAA
                % should have at least 450 cfm of inlet flow that can enter
                % the CHX. And 450 cfm are 0.2124 m^3/s
                % cfm = cubic feet per minute
                fInFlow = this.fVolumetricFlowRate*this.oAtmosphere.fDensity;

                fPercentalFlowChange = abs((this.toBranches.CCAA_In_FromCabin.fFlowRate + fInFlow)/(this.toBranches.CCAA_In_FromCabin.fFlowRate));

                fHumidityChange = abs(this.rRelHumidity - this.oAtmosphere.rRelHumidity);

                % Condensate is released over a kickvalve every 75 minutes
                if mod(this.oTimer.fTime, 75 * 60) <= (1.5*this.fTimeStep)
                    %minus this.fInitialCHXWaterMass because that is the inital
                    %mass in the phase and is therefore not the condensate
                    %generated, also serves to prevent numerical errors in the
                    %simulation that occur if a phase is completly emptied.
                    fFlowRateCondOut = (this.toStores.CHX.toPhases.CHX_H2OPhase.fMass - this.fInitialCHXWaterMass) / 600;
                    if fFlowRateCondOut < 0
                        fFlowRateCondOut = 0;
                    end
                    this.toBranches.Condensate_Out.oHandler.setFlowRate(fFlowRateCondOut);
                    this.bKickValveAktivated = true;
                    this.fKickValveAktivatedTime = this.oTimer.fTime;
                end
                if this.bKickValveAktivated && (this.toStores.CHX.toPhases.CHX_H2OPhase.fMass <= this.fInitialCHXWaterMass)
                    this.toBranches.Condensate_Out.oHandler.setFlowRate(0);
                    this.bKickValveAktivated = false;
                end

                % If the inlet flow changed by less than 1% and the humidity
                % changed by less than 1% it is not necessary to recalculate
                % the CCAA

                fError = this.fTemperatureSetPoint - this.oAtmosphere.fTemperature;
                if (fPercentalFlowChange < 0.01) && (fHumidityChange < 0.01) && (abs(fError) < 0.5)
                    return
                end

                this.rRelHumidity = this.oAtmosphere.rRelHumidity;
                %since the original step was 1s the angle change is considered
                %to be given in °/s and therefore is multiplied with the
                %current timestep to get the actual angle change value.
                %Otherwise the control logic would depend on the time step used
                %in the system
                %Note: A low TCCV angle results in a high flow through the
                %CHX!
                % Furthermore the actual control logic as discussed in the
                % original thesis by Christof Roth only controls the
                % temperature and the humidity is only passivly controlled.
                % Controll logic based on figure 6-14 from DA by Christof Roth

                if abs(fError) < 0.5
                    this.fErrorTime = 0;
                    return
                end

                if this.fErrorTime == 0
                    this.fErrorTime = this.oTimer.fTime;
                end
                % Proportional Part of the control logic:
                fNew_TCCV_Angle = this.fTCCV_Angle + 3.42 * fError + 0.023 * fError * (this.oTimer.fTime - this.fErrorTime);

                % limits the TCCV angle
                if fNew_TCCV_Angle < 9
                    fNew_TCCV_Angle = 9;
                elseif fNew_TCCV_Angle > 84
                    fNew_TCCV_Angle = 84;
                end
                this.fTCCV_Angle = fNew_TCCV_Angle;
                %fTCCV_Angle = (this.rTCCV_ratio) * 77 + 3;

                this.toBranches.CCAA_In_FromCabin.oHandler.setFlowRate(-fInFlow);

                fInFlow2 = 0;

                % Uses the interpolation for the TCCV to calculate the
                % percentage of flow entering the CHX
                fFlowPercentageCHX = this.Interpolation(fNew_TCCV_Angle);
                % Gets the two flow rates exiting the TCCV
                fTCCV_To_Cabin_FlowRate = (1 - fFlowPercentageCHX) * (fInFlow+fInFlow2);

                this.toBranches.TCCV_Cabin.oHandler.setFlowRate(fTCCV_To_Cabin_FlowRate);

                fTCCV_To_CHX_FlowRate = (fInFlow+fInFlow2) - fTCCV_To_Cabin_FlowRate;
                if ~isempty(this.sCDRA)
                    if fTCCV_To_CHX_FlowRate >= this.fCDRA_FlowRate
                        this.toBranches.CHX_CDRA.oHandler.setFlowRate(this.fCDRA_FlowRate);
                    else
                        this.toBranches.CHX_CDRA.oHandler.setFlowRate(fTCCV_To_CHX_FlowRate);
                    end
                end
            end
        end
	end
end