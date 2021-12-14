classdef Example < vsys
    %EXAMPLE Example simulation for the Common Cabin Air Assembly (CCAA)
    % Subsystem, which also serves as verification for this subsystem. For
    % verification data from the protoflight test (Hamilton Standard.
    % PFT-ISSA-9610. Technical Report, 1996.) is used but since the
    % original report was not available, the data used is from the second
    % hand source "ISS Active Thermal Control System Dynamic Modeling",
    % Christof Roth, 2012, LRT-DA-2012-22, Table 6-1. It was extracted from
    % the raw data available for this source at the Institute of
    % Astronautics at TUM.
    % In total 6 protoflight tests with different set point were reported,
    % but not dynamically, only in steady state conditions. Therefore, the
    % example implements 6 CCAAs and runs the 6 test cases in parallel. It
    % does so for a longer simulation time, but the verification only uses
    % the results from the initial calculations, as only there the values
    % of the protoflight tests and the V-HAB data match. The dynamic
    % calculation data can be used however, to check that the calculated
    % dynamic values do not show physically impossible errors.
    properties (SetAccess = public, GetAccess = public)
        tProtoTestSetpoints;
    end
    
    methods
        function this = Example(oParent, sName, tParameters)
            this@vsys(oParent, sName);
            
            if nargin < 3
                tParameters = struct();
            end
            %
            % temperature for the coolant passing through the CCAA
            tProtoTestSetpoints(1).fCoolantTemperature  = 273.15 + 6.44;
            tProtoTestSetpoints(2).fCoolantTemperature  = 273.15 + 5.61;
            tProtoTestSetpoints(3).fCoolantTemperature  = 273.15 + 5.72;
            tProtoTestSetpoints(4).fCoolantTemperature  = 273.15 + 6.01;
            tProtoTestSetpoints(5).fCoolantTemperature  = 273.15 + 6.00;
            tProtoTestSetpoints(6).fCoolantTemperature  = 273.15 + 5.64;
            
            tProtoTestSetpoints(1).fGasTemperature      = 273.15 + 18.16;
            tProtoTestSetpoints(2).fGasTemperature      = 273.15 + 18.01;
            tProtoTestSetpoints(3).fGasTemperature      = 273.15 + 20.81;
            tProtoTestSetpoints(4).fGasTemperature      = 273.15 + 20.87;
            tProtoTestSetpoints(5).fGasTemperature      = 273.15 + 25.78;
            tProtoTestSetpoints(6).fGasTemperature      = 273.15 + 25.78;
            
            tProtoTestSetpoints(1).fDewPointAir         = 273.15 + 13.06;
            tProtoTestSetpoints(2).fDewPointAir         = 273.15 + 12.81;
            tProtoTestSetpoints(3).fDewPointAir         = 273.15 + 14.65;
            tProtoTestSetpoints(4).fDewPointAir         = 273.15 + 14.77;
            tProtoTestSetpoints(5).fDewPointAir         = 273.15 + 14.51;
            tProtoTestSetpoints(6).fDewPointAir         = 273.15 + 15.01;
            
            % For the first test the source states an angle of 5°, but
            % looking at the original test data, an angle of 40° was used
            % for test 1 and the 5° were used for test 2. Which also makes
            % more sense from a result perspective
            tProtoTestSetpoints(1).fTCCV_Angle          = 40;
            tProtoTestSetpoints(2).fTCCV_Angle          = 5;
            tProtoTestSetpoints(3).fTCCV_Angle          = 5;
            tProtoTestSetpoints(4).fTCCV_Angle          = 40;
            tProtoTestSetpoints(5).fTCCV_Angle          = 40;
            tProtoTestSetpoints(6).fTCCV_Angle          = 40;
            
            tProtoTestSetpoints(1).fVolumetricAirFlow	= 0.2;
            tProtoTestSetpoints(2).fVolumetricAirFlow	= 0.2;
            tProtoTestSetpoints(3).fVolumetricAirFlow	= 0.2;
            tProtoTestSetpoints(4).fVolumetricAirFlow	= 0.2;
            tProtoTestSetpoints(5).fVolumetricAirFlow	= 0.2;
            tProtoTestSetpoints(6).fVolumetricAirFlow	= 0.2;
            
            % The unit for the coolant flow in the diploma thesis of C.
            % Roth are wrong. In other sources the minimum coolant flow is
            % mentioned to be 600 lb/hr ("Centrifuge Accommodation Module
            % (CAM) Cabin Air Temperature and Humidity Control Analysis",
            % Ching-fen Tsai et. al 2005) which is 75.6 g/s so the unit is
            % likely in g/s
            
            tProtoTestSetpoints(1).fCoolantFlow	= 145.15e-3;
            tProtoTestSetpoints(2).fCoolantFlow	= 74.27e-3;
            tProtoTestSetpoints(3).fCoolantFlow	= 75.13e-3;
            tProtoTestSetpoints(4).fCoolantFlow	= 146.66e-3;
            tProtoTestSetpoints(5).fCoolantFlow	= 145.28e-3;
            tProtoTestSetpoints(6).fCoolantFlow	= 74.68e-3;
            
            % The values for air pressure etc are not available, therefore
            % we use standard values for the air pressure
            tAtmosphere.fPressure = 101325;

            % name for the asscociated CDRA subsystem, leave empty if CCAA
            % is used as standalone
            sCDRA = [];
            
            for iProtoflightTest = 1:6
                tAtmosphere.fTemperature = tProtoTestSetpoints(iProtoflightTest).fGasTemperature;
                
                fVaporPressureGasTemperature    = this.oMT.calculateVaporPressure(tProtoTestSetpoints(iProtoflightTest).fGasTemperature, 'H2O');
                fVaporPressureDewPoint          = this.oMT.calculateVaporPressure(tProtoTestSetpoints(iProtoflightTest).fDewPointAir, 'H2O');
                
                tProtoTestSetpoints(iProtoflightTest).rRelHumidity = fVaporPressureDewPoint / fVaporPressureGasTemperature;
                tAtmosphere.rRelHumidity                           = fVaporPressureDewPoint / fVaporPressureGasTemperature;
                % Adding the subsystem CCAA
                oCCAA = components.matter.CCAA.CCAA(this, ['CCAA_', num2str(iProtoflightTest)], 5, tProtoTestSetpoints(iProtoflightTest).fCoolantTemperature, tAtmosphere, sCDRA);
            
                tFixValues.fTCCV_Angle                  = tProtoTestSetpoints(iProtoflightTest).fTCCV_Angle;
            	tFixValues.fVolumetricAirFlowRate       = tProtoTestSetpoints(iProtoflightTest).fVolumetricAirFlow;
                tFixValues.fCoolantFlowRate             = tProtoTestSetpoints(iProtoflightTest).fCoolantFlow;
                oCCAA.setFixValues(tFixValues);
                
                oCCAA.setParameterOverwrite(tParameters);
            end
            
            this.tProtoTestSetpoints = tProtoTestSetpoints;
            
            eval(this.oRoot.oCfgParams.configCode(this));
            
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            %% create a seperate set of stores with the corresponding values for each protoflight test
            fTotalGasPressure = 101325;
            for iProtoflightTest = 1:6
                matter.store(this, ['Cabin_', num2str(iProtoflightTest)], 10);
                oCabin              = this.toStores.(['Cabin_', num2str(iProtoflightTest)]).createPhase(        'gas',                  'Air',          this.toStores.(['Cabin_', num2str(iProtoflightTest)]).fVolume,        struct('N2', 0.7896 * fTotalGasPressure, 'O2', 0.21 * fTotalGasPressure, 'CO2',  0.0004 * fTotalGasPressure),	this.tProtoTestSetpoints(iProtoflightTest).fGasTemperature,	this.tProtoTestSetpoints(iProtoflightTest).rRelHumidity);
                
                matter.store(this, ['Coolant_',  num2str(iProtoflightTest)], 2);
                oCoolant            = this.toStores.(['Coolant_', num2str(iProtoflightTest)]).createPhase(      'liquid', 'boundary',   'Water',        this.toStores.(['Coolant_', num2str(iProtoflightTest)]).fVolume,      struct('H2O', 1), this.tProtoTestSetpoints(iProtoflightTest).fCoolantTemperature, 1e5);

                matter.store(this, ['Condensate_',  num2str(iProtoflightTest)], 2);
                oCondensate         = this.toStores.(['Condensate_', num2str(iProtoflightTest)]).createPhase(   'liquid',               'Water',        this.toStores.(['Condensate_', num2str(iProtoflightTest)]).fVolume,      struct('H2O', 1), this.tProtoTestSetpoints(iProtoflightTest).fCoolantTemperature, 1e5);

                matter.branch(this, ['CCAAinput',               num2str(iProtoflightTest)],    	{}, oCabin);
                matter.branch(this, ['CCAA_Output',             num2str(iProtoflightTest)],  	{}, oCabin);
                matter.branch(this, ['CCAA_CondensateOutput',   num2str(iProtoflightTest)],     {}, oCondensate);
                matter.branch(this, ['CCAA_CoolantInput',       num2str(iProtoflightTest)],     {}, oCoolant);
                matter.branch(this, ['CCAA_CoolantOutput',      num2str(iProtoflightTest)],   	{}, oCoolant);

                % now the interfaces between this system and the CCAA subsystem
                % are defined
                this.toChildren.(['CCAA_', num2str(iProtoflightTest)]).setIfFlows(['CCAAinput',               num2str(iProtoflightTest)],...
                                                                                  ['CCAA_Output',             num2str(iProtoflightTest)],...
                                                                                  ['CCAA_CondensateOutput',   num2str(iProtoflightTest)],...
                                                                                  ['CCAA_CoolantInput',       num2str(iProtoflightTest)],...
                                                                                  ['CCAA_CoolantOutput',      num2str(iProtoflightTest)]);
            end
        end
        
        function createThermalStructure(this)
            createThermalStructure@vsys(this);
            
        end
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            %% Assign thermal solvers
            this.setThermalSolvers();
        end
    end
    
    methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
            
        end
    end
end