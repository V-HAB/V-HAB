classdef Example < vsys
    %EXAMPLE Example is the main system for initial simulations using a
    %hollow fiber contactor (HFC) for CO2 removal from a simulated cabin or
    %from AETHER (CU Boulder experimental gas rig)
    
    properties
        tAtmosphere;
        
        tTestData;
        
        fEstimatedMassTransferCoefficient;
       
        iSwitchCount = 1;
    end
    
    methods
        function this = Example(oParent, sName)
            % Calling the parent constructor. This has to be done for any
            % class that has a parent. The third parameter defines how
            % often the .exec() method of this subsystem is called. 
            % Values can be: 0-inf for interval in [s] (zero means with
            % lowest time step set for the timer). -1 means with every TICK
            % of the timer, which is determined by the smallest time step
            % of any of the systems. Providing a logical 'false' means the
            % .exec() method is called when the oParent.exec() is executed
            % (see this .exec() method - always call exec@vsys as well!).
            this@vsys(oParent, sName, 1);
            
            this.fEstimatedMassTransferCoefficient;
            this.tAtmosphere.fTemperature = 303.15;
            this.tAtmosphere.rRelHumidity = 0.5;
            this.tAtmosphere.fPressure = 8.41e4;
            this.tAtmosphere.fCO2Percent = 0.005;
            sUserName = getenv('username');
            if strcmp(sUserName,'ASUS')
                [afUpTime, afUpCO2]  = hojo.ILCO2.importCO2file('C:\Users\ASUS\Documents\STEPS2\user\+hojo\+ILCO2\+data\April-04-2017-upstrm2.csv',3,1220);
                [afDnTime, afDnCO2]  = hojo.ILCO2.importCO2file('C:\Users\ASUS\Documents\STEPS2\user\+hojo\+ILCO2\+data\April-04-2017-dwnstrm2.csv',3,1217);
            else
            % Determine maximum simulation time for X-HAB data validation
                [afUpTime, afUpCO2]  = hojo.ILCO2.importCO2file('C:\Users\ge52qut\VHAB\STEPS\user\+hojo\+ILCO2\+data\April-04-2017-upstrm2.csv',3,1220);
                [afDnTime, afDnCO2]  = hojo.ILCO2.importCO2file('C:\Users\ge52qut\VHAB\STEPS\user\+hojo\+ILCO2\+data\April-04-2017-dwnstrm2.csv',3,1217);
            end
            
            afUpTime(1:106) = [];
            afDnTime(1:102) = [];
            afUpCO2(1:106) = [];
            afDnCO2(1:102) = [];
            
            afUpErr               = 50*ones(size(afUpCO2));
            afUpErr(afUpCO2>=1667)  = 0.03.*(afUpCO2(afUpCO2>=1667));
            afDnErr               = 50*ones(size(afDnCO2));
            afDnErr(afDnCO2>=1667)  = 0.03.*(afDnCO2(afDnCO2>=1667));
            
            % Initialize Common Time Array
            afTime_C  = linspace(min([afDnTime;afUpTime]),max([afDnTime;afUpTime]),1200)';
            afTime_C(end) = [];
            dt      = afTime_C(2)-afTime_C(1);      % Bin Width
            fprintf('Bin Width: %5.2f [s]\n',seconds(dt))

            % Initialize Data Arrays to size of Common Time
            afUpCO2_C = nan(length(afTime_C)-1,1);  % Concentration     [PPM]
            afUpCO2_n = nan(length(afTime_C)-1,1);  % Number of Data    []
            afUpCO2_E = nan(length(afTime_C)-1,1);  % Measurement Error [PPM]

            afDnCO2_C = nan(length(afTime_C)-1,1);  % Concentration     [PPM]
            afDnCO2_n = nan(length(afTime_C)-1,1);  % Number of Data    []
            afDnCO2_E = nan(length(afTime_C)-1,1);  % Measurement Error [PPM]

            for i = 1:length(afTime_C)-1
                % Find all indices for Upstream measurements with times in the bin
                iFindUp    = find(and(afTime_C(i)<=afUpTime,afUpTime<=afTime_C(i+1)));
                % Average those measurements and assign to data array
                afUpCO2_C(i) = mean(afUpCO2(iFindUp));
                afUpCO2_n(i) = length(iFindUp);
                afUpCO2_E(i) = sum(afUpErr(iFindUp))/afUpCO2_n(i);

                % Find all indices for Downstream measurements with times in the bin
                iFindDn    = find(and(afTime_C(i)<=afDnTime,afDnTime<=afTime_C(i+1)));
                % Average those measurements and assign to data array
                afDnCO2_C(i) = mean(afDnCO2(iFindDn));
                afDnCO2_n(i) = length(iFindDn);
                afDnCO2_E(i) = sum(afDnErr(iFindDn))/afDnCO2_n(i);
            end
            afTime_C(end) = [];

            %% Get rid of Data Gaps
            iDelete     = or(afUpCO2_n==0,afDnCO2_n==0);
            afTime_C(iDelete)  = [];
            afUpCO2_C(iDelete) = [];
            afUpCO2_E(iDelete) = [];
            afDnCO2_C(iDelete) = [];
            afDnCO2_E(iDelete) = [];
            afDnCO2_n(iDelete) = [];
            afUpCO2_n(iDelete) = [];

            % Convert Datetime values to Seconds
            afTime = zeros(length(afTime_C),1);
            for ii = 1:length(afTime_C)
                afTime(ii) = seconds(afTime_C(ii) - afTime_C(1));
            end

            if(any([isnan(afUpCO2_E);isnan(afDnCO2_E)]))
                disp('UH OH!')
            end
            
            this.tTestData.afUpCO2 = afUpCO2_C;
            this.tTestData.afDnCO2 = afDnCO2_C;
            this.tTestData.afTime = afTime;
            
            try
                tInitialization = oParent.oCfgParams.ptConfigParams('tInitialization');
                hojo.ILCO2.subsystems.HFC(this, 'HFC', this.tAtmosphere, tInitialization);
            catch
                hojo.ILCO2.subsystems.HFC(this, 'HFC', this.tAtmosphere);
            end
            eval(this.oRoot.oCfgParams.configCode(this));
            
            
            
        end
        
        
        function createMatterStructure(this)
            % This function creates all simulation objects in the matter
            % domain. 
            
            % First we always need to call the createMatterStructure()
            % method of the parent class.
            createMatterStructure@vsys(this);
            
            % Creating a store, volume 1 m^3
            % Aether is the name of the test rig for gas provision and
            % measurements at CU Boulder; name used here to differntiate
            % from a cabin where a response to CO2 removal would be
            % expected in a looped system. Aether provides a constant (or
            % set profile) gas input with set CO2 concentration
            matter.store(this, 'Aether', inf);
            
            % Adding a phase to the store 'Aether', 1 m^3 air at 25 deg C
            % This should be updated to match the input CO2 concentration
            % from experiments as either a constant source or a time-based
            % profile from data provided
            %                                             sHelper, sPhaseName, fVolume, tfPartialPressure,                  fTemperature,             rRelativeHumidity)

            oGasPhaseOut = this.toStores.Aether.createPhase(  'gas', 'boundary',  'Air',   1, struct('N2', .8*this.tAtmosphere.fPressure, 'O2', .2*this.tAtmosphere.fPressure, 'CO2', 0), this.tAtmosphere.fTemperature, this.tAtmosphere.rRelHumidity);          
            
            % Creating a second store, volume Inf, as a psuedo outlet to
            % the experiment for logging values
            matter.store(this, 'Exhaust', inf); 
            % Adding a phase to the store 'Exhaust', Inf air at 25 deg C
            oGasPhaseReturn = this.toStores.Exhaust.createPhase(  'gas', 'boundary',  'Air',   1, struct('N2', .8*this.tAtmosphere.fPressure, 'O2', .2*this.tAtmosphere.fPressure, 'CO2', 0), this.tAtmosphere.fTemperature, this.tAtmosphere.rRelHumidity);            
            
            matter.store(this, 'VacuumSupply', inf);
            oVacuumSupply = this.toStores.VacuumSupply.createPhase(  'gas', 'boundary',  'vacuum',   1, struct('N2', .08*this.tAtmosphere.fPressure, 'O2', .02*this.tAtmosphere.fPressure, 'CO2', 0), this.tAtmosphere.fTemperature, 0);            

            matter.store(this, 'VacuumRemoval', inf);
            oVacuumRemoval = this.toStores.VacuumRemoval.createPhase(  'gas', 'boundary',  'vacuum',   1, struct('N2', .08*this.tAtmosphere.fPressure, 'O2', .02*this.tAtmosphere.fPressure, 'CO2', 0), this.tAtmosphere.fTemperature, 0);            

            
            % Add the HFC into the system
            matter.branch(this, 'AirInterfaceOut',  {}, oGasPhaseOut);
            matter.branch(this, 'AirInterfaceReturn', {}, oGasPhaseReturn);
            matter.branch(this, 'VacuumSupply', {}, oVacuumSupply);
            matter.branch(this, 'VacuumRemoval', {}, oVacuumRemoval);
            this.toChildren.HFC.setIfFlows('AirInterfaceOut', 'AirInterfaceReturn', 'VacuumSupply', 'VacuumRemoval');
            
        end
        
        
        function createThermalStructure(this)
            % This function creates all simulation objects in the thermal
            % domain. 
            
            % First we always need to call the createThermalStructure()
            % method of the parent class.
            createThermalStructure@vsys(this);
            
            % We need to do nothing else here for this simple model. All
            % thermal domain objects related to advective (mass-based) heat
            % transfer will automatically be created by the
            % setThermalSolvers() method. 
            % Here one would create simulation objects for radiative and
            % conductive heat transfer.
            
        end
        
        function createSolverStructure(this)
            % This function creates all of the solver objects required for
            % a simulation. 
            
            % NOTE: specific solver functions are defined at the subsystem
            % level
            
            % First we always need to call the createSolverStructure()
            % method of the parent class.
            createSolverStructure@vsys(this);

            % Since we want V-HAB to calculate the temperature changes in
            % this system we call the setThermalSolvers() method of the
            % thermal.container class. 
            this.setThermalSolvers();
            
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            % exec(ute) function for this system 
            % This function can be used to change the system state, e.g.
            % close valves or switch on/off components.
            
            % Here it only calls its parent's exec() method
            exec@vsys(this);
                    
            fPressure = this.tAtmosphere.fPressure;
            fTemperature = this.tAtmosphere.fTemperature;
            
            % Update the CO2 partial pressure in the inlet gas flow based
            % on the actual test data of the inlet flow during CU Boulder
            % X-HAB experiments. Due to discrepencies between simulation
            % time and timestamp of the test data, the ppCO2 is updated
            % each time the simulation time passes a new timestamp in the
            % experimental data. The simulation tick width needs to be
            % small enough to provide enough resolution for updating the
            % inlet flow at EVERY test data point (instead of skipping over
            % a point or two, which adds up over the simulation). 
            if this.oTimer.fTime > this.tTestData.afTime(this.iSwitchCount)
                this.iSwitchCount = this.iSwitchCount + 1;
                % Special case: where the iSwitchCount reaches end of data
                if this.iSwitchCount == length(this.tTestData.afUpCO2)
                    this.iSwitchCount = this.iSwitchCount - 1;
                end
                
                % Read in the current boundary phase conditions
                oBoundary = this.toStores.Aether.toPhases.Air;
                % Set the boundary phase afPP property to equal the
                % previous step's afPP (i.e. N2, O2, etc.)
                tProperties.afPP = oBoundary.afPP;
                
                % Special case: initialization
                if this.iSwitchCount == 1
                    tProperties.afPP(this.oMT.tiN2I.CO2) = this.tTestData.afUpCO2(this.iSwitchCount)./1000000.*fPressure;
                    yCO2Up = this.tTestData.afUpCO2(this.iSwitchCount)./1000000;
                    yCO2Dn = this.tTestData.afDnCO2(this.iSwitchCount)./1000000;
                else
                    % Nominal case:
                    tProperties.afPP(this.oMT.tiN2I.CO2) = this.tTestData.afUpCO2(this.iSwitchCount-1)./1000000.*fPressure;
                    yCO2Up = this.tTestData.afUpCO2(this.iSwitchCount-1)./1000000;
                    yCO2Dn = this.tTestData.afDnCO2(this.iSwitchCount-1)./1000000;
                end 
               
                % Update the properties of the boundary phase
                oBoundary.setBoundaryProperties(tProperties);
                fContactArea = 0.0379;
                
                % Set the flow rates during each regime of the experiment
                if this.tTestData.afTime(this.iSwitchCount) <= 2000
                    fVolumetricFlowRate = -1e-8;                    
                    CCO2Up = yCO2Up .* fPressure ./ this.oMT.Const.fUniversalGas ./ fTemperature;
                    CCO2Dn = yCO2Dn .* fPressure ./ this.oMT.Const.fUniversalGas ./ fTemperature;
                    this.fEstimatedMassTransferCoefficient = log(yCO2Up./yCO2Dn)./(yCO2Up-yCO2Dn)./fPressure.*this.oMT.Const.fUniversalGas.*fTemperature.*-fVolumetricFlowRate./(fContactArea).*(CCO2Up-CCO2Dn);                    
                elseif 2000 < this.tTestData.afTime(this.iSwitchCount) && this.tTestData.afTime(this.iSwitchCount) <= 3423
                    fVolumetricFlowRate = -(0.2*(fTemperature/273.15)*(101325/fPressure))/60000;
                    CCO2Up = yCO2Up .* fPressure ./ this.oMT.Const.fUniversalGas ./ fTemperature;
                    CCO2Dn = yCO2Dn .* fPressure ./ this.oMT.Const.fUniversalGas ./ fTemperature;
                    this.fEstimatedMassTransferCoefficient = log(yCO2Up./yCO2Dn)./(yCO2Up-yCO2Dn)./fPressure.*this.oMT.Const.fUniversalGas.*fTemperature.*-fVolumetricFlowRate./(fContactArea).*(CCO2Up-CCO2Dn);
                elseif 3423 < this.tTestData.afTime(this.iSwitchCount) && this.tTestData.afTime(this.iSwitchCount) <= 4360
                    fVolumetricFlowRate = -(0.3*(fTemperature/273.15)*(101325/fPressure))/60000;
                    CCO2Up = yCO2Up .* fPressure ./ this.oMT.Const.fUniversalGas ./ fTemperature;
                    CCO2Dn = yCO2Dn .* fPressure ./ this.oMT.Const.fUniversalGas ./ fTemperature;
                    this.fEstimatedMassTransferCoefficient = log(yCO2Up./yCO2Dn)./(yCO2Up-yCO2Dn)./fPressure.*this.oMT.Const.fUniversalGas.*fTemperature.*-fVolumetricFlowRate./(fContactArea).*(CCO2Up-CCO2Dn);
                elseif 4360 < this.tTestData.afTime(this.iSwitchCount) 
                    fVolumetricFlowRate = -(0.4*(fTemperature/273.15)*(101325/fPressure))/60000;
                    CCO2Up = yCO2Up .* fPressure ./ this.oMT.Const.fUniversalGas ./ fTemperature;
                    CCO2Dn = yCO2Dn .* fPressure ./ this.oMT.Const.fUniversalGas ./ fTemperature;
                    this.fEstimatedMassTransferCoefficient = log(yCO2Up./yCO2Dn)./(yCO2Up-yCO2Dn)./fPressure.*this.oMT.Const.fUniversalGas.*fTemperature.*-fVolumetricFlowRate./(fContactArea).*(CCO2Up-CCO2Dn);
                end
                this.toChildren.HFC.toBranches.HFC_Air_In_1.oHandler.setVolumetricFlowRate(fVolumetricFlowRate);
%                 this.toChildren.HFC.fEstimatedMassTransferCoefficient = this.fEstimatedMassTransferCoefficient;
                
            end
            
        end
     end
end

