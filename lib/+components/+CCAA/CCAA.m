classdef CCAA < vsys
    
    
    %% Common Cabin Air Assembly (CCAA)
    %
    % The ISS uses a total of 8 condensing heat exchangers for humidity
    % control. The distribution can be checked here: http://wsn.spaceflight.esa.int/docs/Factsheets/30%20ECLSS%20LR.pdf
    % However not all of these are actually CCAAs, for example the CHX in
    % Columbus is a different one developed by Europe and the russians have
    % a different one as well. However to simplify the simulation it is
    % currently assumed that all of the CHX can be modeled as CCAAs.
    
    
    properties (SetAccess = public, GetAccess = public)
        %Variable to decide wether the CCAA is active or not. Used for the
        %Case study to make it easier to switch them on or off
        bActive = true;
    end
    properties
        bKickValveAktivated = 0;            % Variable used to execute the kick valve
        fKickValveAktivatedTime = 0;        % Variable used to execute the kick valve
        
        mfCHXAirFlow;                      % Table used to calculate the flow rates of the ARS valve
        rTCCV_ratio;                        % Starting opening angle of the TCCV valve 0.025974
        
        %relative humidity in the connected module
        rRelHumidity = 0.45;
        
        
        %Property to save the interpolation for the CHX air flow based on
        %the angle value
        Interpolation;
        
        %Porperty to save the interpolation for the CHX effectiveness
        interpolateEffectiveness;
        
        % subsystem name for the asccociated CDRA
        sCDRA;
        
        %According to "International Space Station Carbon Dioxide Removal
        %Assembly Testing" 00ICES-234 James C. Knox (2000) the minmal flow
        %rate for CDRA to remove enough CO2 is 41 kg/hr but that figure is
        %for removal of CO2 for 6 crew members.
        fCDRA_FlowRate = 1.138e-2;
        
        %Object for the phase of the module where the CCAA is located. Used
        %to get the current relative humidity and control the valve angles
        %accordingly and to calculate the current mass flow entering the
        %CCAA based on the volumetric flow rate
       	oAtmosphere;
        
        fRelHumidity;
        tAtmosphere;
        fCoolantTemperature;
        
        fInitialCHXWaterMass;
    end
    
    methods 
        function this = CCAA (oParent, sName, fTimeStep, rTCCV_InitialAngle, fCoolantTemperature, tAtmosphere, sCDRA, fCDRA_FlowRate)
            this@vsys(oParent, sName, fTimeStep);
            
            this.rTCCV_ratio = rTCCV_InitialAngle;
            this.fCoolantTemperature = fCoolantTemperature;
            this.tAtmosphere = tAtmosphere;
            if ~isempty(sCDRA)
                this.fCDRA_FlowRate = fCDRA_FlowRate;
                this.sCDRA = sCDRA;
            end
            
            % Loading the flow rate table for the valves
            this.mfCHXAirFlow = load(strrep('lib\+components\+CCAA\CCAA_CHXAirflowMean.mat', '\', filesep));
                
           	this.Interpolation = griddedInterpolant(this.mfCHXAirFlow.TCCV_Angle, this.mfCHXAirFlow.CHXAirflowMean);
            
            %CHX Effectivness interpolation:
            % Thermal Performance Data (ICES 2005-01-2801)
            % Coolant Water Conditions
            % - 600 lb/hr coolant flow
            % - 40?F coolant inlet temperature
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
            
            %Temp Change allowed before CHX are recalculated
            fTempChange = 1;
            %Percental Change allowed to Massflow/Pressure/Composition of
            %Flow before CHX is recalculated
            fPercentChange = 0.025;
            
            fPressure = 101325;
            fCO2Percent = 0.0038;
            
            %% Creating the stores
            % Creating the TCCV
            %originally volume of 0.01 but mass of 1kg air...
            matter.store(this, 'TCCV', 1); 
            cAirHelper = matter.helper.phase.create.air_custom(this.toStores.TCCV, 1, struct('CO2', fCO2Percent), this.tAtmosphere.fTemperature, this.tAtmosphere.fRelHumidity, this.tAtmosphere.fPressure);
            oAir = matter.phases.gas(this.toStores.TCCV, 'TCCV_PhaseGas', cAirHelper{1}, cAirHelper{2}, cAirHelper{3});
            
            matter.procs.exmes.gas(oAir, 'Port_In');
            if ~isempty(this.sCDRA)
                matter.procs.exmes.gas(oAir, 'Port_In2');
            end
            matter.procs.exmes.gas(oAir, 'Port_Out_1');
            matter.procs.exmes.gas(oAir, 'Port_Out_2');
            
            % Creating the CHX
            % The volume is set relativly large to allow a larger time
            % step.
            matter.store(this, 'CHX', 2);
            % Input phase
            cAirHelper = matter.helper.phase.create.air_custom(this.toStores.CHX, 1, struct('CO2', fCO2Percent), this.tAtmosphere.fTemperature, this.tAtmosphere.fRelHumidity, this.tAtmosphere.fPressure);
            oInput = matter.phases.gas(this.toStores.CHX, 'CHX_PhaseIn',  cAirHelper{1}, cAirHelper{2}, cAirHelper{3});
            % H2O phase
            cWaterHelper = matter.helper.phase.create.water(this.toStores.CHX, 1, this.fCoolantTemperature, fPressure);
            oH2O = matter.phases.liquid(this.toStores.CHX, 'CHX_H2OPhase', cWaterHelper{1}, cWaterHelper{2}, cWaterHelper{3}, cWaterHelper{4});
            this.fInitialCHXWaterMass = oH2O.fMass;
            % Creating the ports
            matter.procs.exmes.gas(oInput, 'Flow_In');
            matter.procs.exmes.gas(oInput, 'Flow_Out_Gas');
            if ~isempty(this.sCDRA)
                matter.procs.exmes.gas(oInput, 'Flow_Out_Gas2');
            end
            matter.procs.exmes.gas(oInput, 'filterport');
            matter.procs.exmes.liquid(oH2O, 'filterport');
            matter.procs.exmes.liquid(oH2O, 'Flow_Out_Liquid');
            
            % Creating the CHX
            oCCAA_CHX = components.CHX(this, 'CCAA_CHX', this.interpolateEffectiveness, 'ISS CHX', 0, 15, fTempChange, fPercentChange);
            
            %adds the P2P proc for the CHX that takes care of the actual
            %phase change
            oCCAA_CHX.oP2P =components.HX.CHX_p2p(this.toStores.CHX, 'CondensingHX', 'CHX_PhaseIn.filterport', 'CHX_H2OPhase.filterport', oCCAA_CHX);

            matter.store(this, 'CoolantStore', 0.02);
            % H2O phase
            % Temperature is from ICES-2015-27: Low temperature loop in US lab 
            % has a temperature between 4.4°c and 9.4°C. But also a document from
            % Boeing about the ECLSS states: "The LTL is designed to operate at 40° F (4° C).."
            % From Active Thermal Control System (ATCS) Overview:
            % http://www.nasa.gov/pdf/473486main_iss_atcs_overview.pdf
            
            cWaterHelper = matter.helper.phase.create.water(this.toStores.CoolantStore, 0.02, this.fCoolantTemperature, fPressure);
            oH2O = matter.phases.liquid(this.toStores.CoolantStore, 'CoolantPhase', cWaterHelper{1}, cWaterHelper{2}, cWaterHelper{3}, cWaterHelper{4});
            matter.procs.exmes.liquid(oH2O, 'Flow_In_Coolant');
            matter.procs.exmes.liquid(oH2O, 'Flow_Out_Coolant');
            
            % Adding pipes to connect the Components
            components.pipe(this, 'Pipe_1', 1, 0.1);
            components.pipe(this, 'Pipe_2', 1, 0.1);
            components.pipe(this, 'Pipe_3', 1, 0.1);
            components.pipe(this, 'Pipe_4', 1, 0.1);
            components.pipe(this, 'Pipe_5', 1, 0.1);
            components.pipe(this, 'Pipe_6', 1, 0.1);
            components.pipe(this, 'Pipe_7', 1, 0.1);
            components.pipe(this, 'Pipe_8', 1, 0.1);
            
            %% Creating the flowpath into this subsystem ('store.exme', {'f2f-processor', 'f2f-processor'}, 'system level port name')
            %  Creating the flowpaths between the Components
            %  Creating the flowpath out of this subsystem ('store.exme', {'f2f-processor', 'f2f-processor'}, 'system level port name')
            
            matter.branch(this, 'TCCV.Port_In', {'Pipe_1'}, 'CCAA_In', 'CCAA_In_FromCabin');                                % Creating the flowpath into this subsystem
            matter.branch(this, 'TCCV.Port_Out_1', {'CCAA_CHX_1'}, 'CHX.Flow_In', 'TCCV_CHX');
            matter.branch(this, 'CHX.Flow_Out_Gas', {'Pipe_5'}, 'CCAA_Out_1', 'CHX_Cabin');
            matter.branch(this, 'TCCV.Port_Out_2', {'Pipe_4'}, 'CCAA_Out_2', 'TCCV_Cabin');
            matter.branch(this, 'CHX.Flow_Out_Liquid', {'Pipe_6'}, 'CCAA_Out_3', 'Condensate_Out');               % Creating the water flowpath out of this subsystem
            matter.branch(this, 'CoolantStore.Flow_In_Coolant', {'Pipe_7'}, 'CCAA_CoolantIn', 'Coolant_In');
            matter.branch(this, 'CoolantStore.Flow_Out_Coolant', {'CCAA_CHX_2'}, 'CCAA_CoolantOut', 'Coolant_Out');
            
            if ~isempty(this.sCDRA)
                matter.branch(this, 'CHX.Flow_Out_Gas2', {'Pipe_8'}, 'CCAA_Out_4', 'CHX_CDRA');
                matter.branch(this, 'TCCV.Port_In2', {'Pipe_2'}, 'CCAA_In_2', 'CDRA_TCCV');
            end
        end
             
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            % Creating the flowpath into this subsystem
            solver.matter.manual.branch(this.toBranches.CCAA_In_FromCabin);
            solver.matter.manual.branch(this.toBranches.TCCV_CHX);
            solver.matter.manual.branch(this.toBranches.CHX_Cabin);
            solver.matter.manual.branch(this.toBranches.TCCV_Cabin);
            solver.matter.manual.branch(this.toBranches.Condensate_Out);
            solver.matter.manual.branch(this.toBranches.Coolant_In);
            solver.matter.manual.branch(this.toBranches.Coolant_Out);
            
            if ~isempty(this.sCDRA)
                solver.matter.manual.branch(this.toBranches.CHX_CDRA);
                
                solver.matter.manual.branch(this.toBranches.CDRA_TCCV);
            end
            
            if this.bActive == 1
                %% Setting of fixed flow rates
                this.toBranches.CCAA_In_FromCabin.oHandler.setFlowRate(-0.2324661667);
                this.toBranches.TCCV_CHX.oHandler.setFlowRate(0.2317);
                this.toBranches.CHX_Cabin.oHandler.setFlowRate(0.2317);
                %allowed coolant flow is between 600 and 1290 lb/hr but the CHX
                %performance data is given for 600 lb/hr so this flow rate is
                %assumed here for the coolant
                this.toBranches.Coolant_In.oHandler.setFlowRate(-0.0755987283); %600 lb/hr
                this.toBranches.Coolant_Out.oHandler.setFlowRate(0.0755987283); %600 lb/hr

                if ~isempty(this.sCDRA)
                    this.toBranches.CDRA_TCCV.oHandler.setFlowRate(-0.01133971667);
                end
            end
        end           
        
            %% Function to connect the system and subsystem level branches with each other
        function setIfFlows(this, sInterface1, sInterface2, sInterface3, sInterface4, sInterface5, sInterface6, sInterface7, sInterface8)
            if nargin == 7
                this.connectIF('CCAA_In' , sInterface1);
                this.connectIF('CCAA_Out_1' , sInterface2);
                this.connectIF('CCAA_Out_2' , sInterface3);
                this.connectIF('CCAA_Out_3' , sInterface4);
                this.connectIF('CCAA_CoolantIn' , sInterface5);
                this.connectIF('CCAA_CoolantOut' , sInterface6);
            elseif nargin == 9
                this.connectIF('CCAA_In' , sInterface1);
                this.connectIF('CCAA_In_2' , sInterface2);
                this.connectIF('CCAA_Out_1' , sInterface3);
                this.connectIF('CCAA_Out_2' , sInterface4);
                this.connectIF('CCAA_Out_3' , sInterface5);
                this.connectIF('CCAA_Out_4' , sInterface6);
                this.connectIF('CCAA_CoolantIn' , sInterface7);
                this.connectIF('CCAA_CoolantOut' , sInterface8);
            else
                error('CCAA Subsystem was given the wrong number of interfaces')
            end
        end
        
        function setReferencePhase(this, oPhase)
                this.oAtmosphere = oPhase;
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
            if this.bActive == 0
                this.toBranches.CCAA_In_FromCabin.oHandler.setFlowRate(0);
                this.toBranches.TCCV_CHX.oHandler.setFlowRate(0.);
                this.toBranches.CHX_Cabin.oHandler.setFlowRate(0);
                this.toBranches.Coolant_In.oHandler.setFlowRate(0); 
                this.toBranches.Coolant_Out.oHandler.setFlowRate(0);
                if ~isempty(this.sCDRA)
                    this.toBranches.CDRA_TCCV.oHandler.setFlowRate(0);
                end
                return
            end
            % Setting of the valve angle of the TCCV split
            if this.oTimer.fTime > 60
                this.rRelHumidity = this.oAtmosphere.rRelHumidity;
                %since the original step was 1s the angle change is considered
                %to be given in °/s and therefore is multiplied with the
                %current timestep to get the actual angle change value.
                %Otherwise the control logic would depend on the time step used
                %in the system
                %Note: A low TCCV angle results in a high flow through the
                %CHX! Meaning for high humidity the angle has to increase
                %and vice versa
                if this.rRelHumidity > 0.45 && this.rTCCV_ratio > 0
                    this.rTCCV_ratio = this.rTCCV_ratio - 0.0256*min(this.oTimer.afTimeStep); 
                elseif this.rRelHumidity < 0.35 && this.rTCCV_ratio < 1
                    this.rTCCV_ratio = this.rTCCV_ratio + 0.0256*min(this.oTimer.afTimeStep);
                end
                
                if this.rTCCV_ratio > 1
                    this.rTCCV_ratio = 1;
                elseif this.rTCCV_ratio < 0
                    this.rTCCV_ratio = 0;
                end
            end
          	fTCCV_Angle = (this.rTCCV_ratio) * 77 + 3;
            
            % Calculation of the kick valve, which opens every 75 minutes
            % for 1 minute with a constant flow rate, which empties it completly
            if this.oTimer.fTime >= this.fKickValveAktivatedTime + 60 && this.bKickValveAktivated
                this.bKickValveAktivated = 0;
                this.toBranches.Condensate_Out.oHandler.setFlowRate(0);
            end
            
            if mod(this.oTimer.fTime, 75 * 60) <= 1
                %minus this.fInitialCHXWaterMass because that is the inital
                %mass in the phase and is therefore not the condensate
                %generated, also serves to prevent numerical errors in the
                %simulation that occur if a phase is completly emptied.
                fFlowRateCondOut = (this.toStores.CHX.toProcsP2P.CondensingHX.oStore.aoPhases(2).fMass - this.fInitialCHXWaterMass) / 60;
                if fFlowRateCondOut < 0
                    fFlowRateCondOut = 0;
                end
                this.toBranches.Condensate_Out.oHandler.setFlowRate(fFlowRateCondOut);
                this.bKickValveAktivated = 1;
                this.fKickValveAktivatedTime = this.oTimer.fTime;
            end
            
            if this.oTimer.fTime > 5
                % Setting of fixed flow rates
                % The CHX data is given for 50 to 450 cfm so the CCAA
                % should have at least 450 cfm of inlet flow that can enter
                % the CHX. And 450 cfm are 0.2124 m^3/s
                % cfm = cubic feet per minute
                
                fInFlow = 0.2124*this.oAtmosphere.fDensity;
                
                this.toBranches.CCAA_In_FromCabin.oHandler.setFlowRate(-fInFlow);
                
                if ~isempty(this.sCDRA)
                    fInFlow2 = this.oParent.toChildren.(this.sCDRA).toBranches.CDRA_Air_Out1.oHandler.fRequestedFlowRate + this.oParent.toChildren.(this.sCDRA).toBranches.CDRA_Air_Out2.oHandler.fRequestedFlowRate;
                    this.toBranches.CDRA_TCCV.oHandler.setFlowRate(-fInFlow2);
                else
                    fInFlow2 = 0;
                end
                
                fFlowPercentageCHX = this.Interpolation(fTCCV_Angle);
                fTCCVFirstFlowRate = fFlowPercentageCHX*(fInFlow+fInFlow2);
                fTCCVSecondFlowRate = (1-fFlowPercentageCHX)*(fInFlow+fInFlow2);
                
                
                this.toBranches.TCCV_CHX.oHandler.setFlowRate(fTCCVFirstFlowRate);
                this.toBranches.TCCV_Cabin.oHandler.setFlowRate(fTCCVSecondFlowRate);
                
                fFlowRateGas = fTCCVFirstFlowRate - this.toStores.CHX.toProcsP2P.CondensingHX.fFlowRate;
                
                if ~isempty(this.sCDRA)
                    if fFlowRateGas >= this.fCDRA_FlowRate
                        this.toBranches.CHX_Cabin.oHandler.setFlowRate(fFlowRateGas-this.fCDRA_FlowRate);
                        this.toBranches.CHX_CDRA.oHandler.setFlowRate(this.fCDRA_FlowRate);
                    elseif fFlowRateGas < this.fCDRA_FlowRate
                        this.toBranches.CHX_Cabin.oHandler.setFlowRate(0);
                        if fFlowRateGas < 0
                            this.toBranches.CHX_CDRA.oHandler.setFlowRate(0);
                        else
                            this.toBranches.CHX_CDRA.oHandler.setFlowRate(fFlowRateGas);
                        end
                    end
                else
                    % in case the CCAA does not have an ascociated CDRA the
                    % full gas flow is put back into the cabin
                    this.toBranches.CHX_Cabin.oHandler.setFlowRate(fFlowRateGas);
                end
            end
        end
	end
end