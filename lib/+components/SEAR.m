classdef SEAR < vsys
%SEAR A simulation model of a Space Evaporator Absorber Radiator panel
%   
%   SWME is modeled as simple store that serves as source for water
%   vapor. An intermediate venting valve connects the SWME with the
%   absorber/radiator (LCAR) and additionally with the environment. In case
%   of an insufficient LCAR performance, water vapor can be vented.
%
%   Input:
%   fCoolingRate    [W]     Profile for heat load due to metabolic rate
%   fTempSink       [K]     Profile for temperature of the environment
%
%   Assumptions:
%   none


    properties (SetAccess = protected, GetAccess = public)
        % Cooling Rate of SWME [W]
        fCoolingRate = 0;
        % Intermediate Venting Valve (Port to SWME) 
        oIVValveSWME;
        % Intermediate Venting Valve (Port to Environment)
        oIVValveEnviron;
        % Water supply power by evaporation (Cooling Power)
        fSupplyPow = 0;
        % Specific enthalpy of water vapor
        fEnthalpyVapor = 2000000;

    end
    
    methods
        function this = SEAR(oParent, sName)
            
            % Calling vsys-constructor-method. Third parameter determines
            % how often the .exec() method of this subsystem is called.
            % Possible Interval: 0-inf [s]
            % -1 for every tick, 0 for global time step
            this@vsys(oParent, sName, -1);
            
            %% LCAR Subsystem
            
            % Adding the subsystem
            components.SEAR.subsystems.LCARSystem(this, 'LCARSystem');
            
        end
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);

            %% SWME - Spacesuit Water Membrane Evaporator
             
            % Simple store filled with water vapor and constant pressure
            % exme to represent SWME output flow to LCAR:
            matter.store(this, 'SWME', 2000);
            
            % Adding water vapor to SWME-Store  
            oVapor = matter.phases.gas (this.toStores.SWME,...
                                        'WaterVapor', ...
                                        struct('H2O', 100),... 
                                        20,...
                                        293.15);       
            oVapor.bSynced  = true;
            oVapor.fFixedTS = 2;
                      
            % Special Exme to maintain constant pressure and temperature at Exme OUT
            components.SEAR.special.const_temp_press_exme(oVapor, 'Out', 2300, 293.15);
                      
            %% Simple Store to simulate Environment (Needed for Venting)
            
            % Creating a second store: Evironment
            matter.store(this, 'Environment', 10);
            
            % Add air phase to store
            oAir = this.toStores.Environment.createPhase('air', 10, [], [], 101325);
            
            oAir.bSynced  = true;
            oAir.fFixedTS = 2;
            
            % Adding a constant pressure exme to maintain vacuum/environment conditions
            % In_1 for Venting Valve
            special.matter.const_press_exme(oAir, 'In_1', 0);
            % In_2 to vent non-condensable gases
            special.matter.const_press_exme(oAir, 'In_2', 0); 
            
            %% Intermediate Venting Valve (Venting in case of high heat load)
            
            matter.store(this, 'IVV', 8e-6);
            
            % Adding water vapor to Valve (Pressure shall be about 2300Pa)
            oValvePhase = matter.phases.gas(this.toStores.IVV,...
                                        'ValveVapor',...
                                        struct('H2O', 1.36e-7),...
                                        8e-6,...
                                        292.15);
            
            % Adding a constant pressure exme 
            components.SEAR.special.const_temp_press_exme(oValvePhase, 'Out_1', 2300, 293.15);
            components.SEAR.special.const_temp_press_exme(oValvePhase, 'Out_2', 2300, 293.15);
            matter.procs.exmes.gas(oValvePhase, 'In');
            
            %% Conecting the components

            % Branch 1: Flowpath from control valve (IVV) into the LCAR subsystem
            matter.branch(this, 'LCARSysInput',{},'IVV.Out_1');            
            % Branch 2: Flowpath from SWME to control valve (IVV)
            matter.branch(this, 'IVV.In', {}, 'SWME.Out'); 
            % Branch 3: Flowpath from control valve (IVV) to environment
            matter.branch(this, 'Environment.In_1', {},'IVV.Out_2'); 
            % Branch 4: Flowpath out of the LCAR subsystem to environment
            matter.branch(this, 'LCARSysOutput', {}, 'Environment.In_2');
            
            % Connect the subsystem with the top level system
            this.toChildren.LCARSystem.setIfFlows('LCARSysInput', 'LCARSysOutput');
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            % Add solvers to branches
            this.oIVValveSWME    = solver.matter.manual.branch(this.toBranches.IVV__In___SWME__Out);
            this.oIVValveEnviron = solver.matter.manual.branch(this.toBranches.Environment__In_1___IVV__Out_2); 

            
        end
    end
    
    methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
            %% -------- Choose mode of operation --------------------
            % 0 - ABSORPTION (LCAR connected to SWME)
            % 1 - REGENERATION (LCAR connected to Regeneration System)
            flag_mode = 0;
            
            switch flag_mode
                case 0
                    %% --------(INPUT FROM EXTERNAL SWME MODEL)--------------
                    % As long as no external SWME is available, temperature,
                    % pressure and enthalpy of the water vapor flowing into the
                    % LCAR have to be set manually!
                    % Set SMWE exit temperature in range of 283K to 308K
                    fTempSWME = 293.15;
                    
                    % Compute enthalpy by interpolating/extrapolating table values
                    fT = 283:5:363;
                    % Sample values from tables for temperatures from 283K to 308K
                    % For H2O vapor enthalpy [kJ/kg]
                    fh = [2518.2 2528.4 2537.5 2546.5 2555.6 2564.6...
                          2573.5 2582.5 2591.3 2600.1 2608.8 2617.5 2626.1...
                          2634.6 2643.0 2651.3 2659.5];
                    % For H2O vapor pressure [kPa]
                    fP = [1.2282 1.7057  2.3392 3.1697 4.2467 5.6286...
                          7.3844 9.5944 12.341 15.761 19.946 25.041 31.201...
                         38.595 47.415  57.867 70.182];
                    % Use spline function to interpolate or extrapolate
                    % Enthalpy of water vapor from SWME
                    fEnthalpySWME = 1000 * (spline(fT,fh, fTempSWME)); % [J/kg]
                    % Vapor side pressure of SWME
                    fPressureSWME = 1000 * (spline(fT,fP, fTempSWME)); % [Pa]
                    
                    % Set computed value for LCAR simulation
                    % -> Enthalpy of water vapor needed to compute heat flow due
                    % to mass transport into absorber:
                    this.toChildren.LCARSystem.oAbsorber.oProc.fEnthalpySWME = fEnthalpySWME;
                    % -> For a given SWME cooling rate, enthalpy is needed to compute
                    % flow rate from SWME to absorber:
                    this.fEnthalpyVapor = fEnthalpySWME;
                    % -> Vapor side pressure in SWME is set as equilibrium pressure
                    this.toChildren.LCARSystem.oAbsorber.toPhases.AbsorberPhase.fEvapPressure = fPressureSWME;
                    
                case 1
                    %% --------(INPUT FROM EXTERNAL REGENERATION SYSTEM)-------
                    % As long as no external regeneration system is available,
                    % temperature and pressure have to be set manually!
                    
                    % Flow rate = fCoolingRate/this.fEnthalpyVapor = 0. Dividing by
                    % 0 is not possible -> Set denominator = 1;
                    this.fEnthalpyVapor = 1;
                    % Set pressure of regeneration system [Pa]
                    this.toChildren.LCARSystem.oAbsorber.toPhases.AbsorberPhase.fEvapPressure = 300;
                    % Set temperature of the regeneration system [K]
                    fTempReg = 393;
                    
            end
            
            %% Metabolic/cooling rate profile from SWME for the simulation
            
            % Chose cooling rate profile
            % 1 - user case
            % 2 - First dual LCAR Test (2013, honeycomb demonstrator)
            % 3 - Second dual LCAR Test
            % 4 - 2012 test with subscale, flexible LCAR (Run2)
            % 5 - 2012 test with flexible LCAR (Run1)
            % 6 - Regeneration mode (addiationally, adjust equilibrium pressure!)
            % 7 - 2012 test with flexible LCAR (Run3)
            flag_Rate = 2;
            
            % Check if regeneration mode active? If yes switch to
            % regeneration conditions
            if flag_mode == 1
                flag_Rate = 6;
            elseif flag_mode == 0 && flag_Rate == 6
                this.throw('Example', 'Selected mode of operation is not compatible with cooling rate profile!');
            end
            
            
            switch flag_Rate
                case 1 % User case

                    %Temperature
                    if this.oTimer.fTime > 0
                        this.toChildren.LCARSystem.fSinkTemperature = 227;
                    end

                    % Metabolic rate 
                    if this.oTimer.fTime > 0
                        this.fCoolingRate = 330;
                    end

                case 2 % First dual LCAR Test (2013, honeycomb demonstrator)
                    % Cooling Rate
                    if this.oTimer.fTime > 0
                        this.fCoolingRate = 97.8;
                    end

                    if this.oTimer.fTime > 1140
                        this.fCoolingRate = 65.5;
                    end

                    if this.oTimer.fTime > 7356
                        this.fCoolingRate = 52.5;
                    end

                    if this.oTimer.fTime > 10212
                        this.fCoolingRate = 60.2;
                    end
                    
                    % Temperature
                    if this.oTimer.fTime > 0
                        this.toChildren.LCARSystem.fSinkTemperature = 173;
                    end
                    
                    if this.oTimer.fTime > 7356
                        this.toChildren.LCARSystem.fSinkTemperature = 248;
                    end
                    
                case 3 % Second dual LCAR Test
                    % Cooling Rate
                    if this.oTimer.fTime > 0
                        this.fCoolingRate = 50;
                    end

                    if this.oTimer.fTime > 1140
                        this.fCoolingRate = 88.9;
                    end

                    if this.oTimer.fTime > 3540
                        this.fCoolingRate = 69.7;
                    end

                    if this.oTimer.fTime > 7770
                        this.fCoolingRate = 31.6;
                    end
                   
                    % Temperature
                    if this.oTimer.fTime > 0
                        this.toChildren.LCARSystem.fSinkTemperature = 175;
                    end
                    if this.oTimer.fTime > 7770
                        this.toChildren.LCARSystem.fSinkTemperature = 173;
                    end
                    
                case 4 % 2013 test with subscale, flexible LCAR (Run2)
                    % Cooling Rate
                    if this.oTimer.fTime > 0
                        this.fCoolingRate = 150;
                    end

                    if this.oTimer.fTime > 2772
                        this.fCoolingRate = 128;
                    end

                    if this.oTimer.fTime > 8300
                        this.fCoolingRate = 0;
                    end
                    % Temperature
                    if this.oTimer.fTime > 0
                        this.toChildren.LCARSystem.fSinkTemperature = 241;
                    end

                    
                case 5 % 2013 test with flexible LCAR (Run1)
%                     this.toChildren.LCARSystem.oAbsorber.fHeatLoss = 20;
                    
                    if this.oTimer.fTime > 0
                        this.fCoolingRate = 100;
                    end
                    
                    if this.oTimer.fTime > 1134
                        this.fCoolingRate = 50;
                    end
                   
                    if this.oTimer.fTime > 2268
                        this.fCoolingRate = 140;
                    end
                    
                    if this.oTimer.fTime > 14280
                        this.fCoolingRate = 132;
                    end
                    % Temperature
                    if this.oTimer.fTime > 0
                        this.toChildren.LCARSystem.fSinkTemperature = 152;
                    end
                   
                case 6 % Regeneration
                    if this.oTimer.fTime > 0
                        this.fCoolingRate = 0;
                        this.toChildren.LCARSystem.fSinkTemperature = fTempReg;
                    end
                    
                case 7 % Run3, 2012 test
                    %this.toChildren.LCARSystem.oAbsorber.fHeatLoss = 24;
                    if this.oTimer.fTime > 0
                        this.fCoolingRate = 160;
                    end
                    
                    if this.oTimer.fTime > 1660
                        this.fCoolingRate = 100;
                    end
                    if this.oTimer.fTime > 11630
                        this.fCoolingRate = 92;
                    end
                    if this.oTimer.fTime > 18275
                        this.fCoolingRate = 72;
                    end
                    
                    % Temperature
                    if this.oTimer.fTime > 0
                        this.toChildren.LCARSystem.fSinkTemperature = 230;
                    end                    
                    if this.oTimer.fTime > 2280
                        this.toChildren.LCARSystem.fSinkTemperature = 255;
                    end
                    if this.oTimer.fTime > 10140
                        this.toChildren.LCARSystem.fSinkTemperature = 230;
                    end
                    if this.oTimer.fTime > 12420
                        this.toChildren.LCARSystem.fSinkTemperature = 210;
                    end
                    if this.oTimer.fTime > 15420
                        this.toChildren.LCARSystem.fSinkTemperature = 230;
                    end                    
                    if this.oTimer.fTime > 19140
                        this.toChildren.LCARSystem.fSinkTemperature = 240;
                    end                  
            end
            
            fFlowRateSWME = this.fCoolingRate/this.fEnthalpyVapor;
            this.oIVValveSWME.setFlowRate(-fFlowRateSWME);
                    
            
            %% Control LCAR Inflow
            % If flow rate from SWME to LCAR is smaller than the possible
            % rate of absorption -> no venting necessary
            if (this.fCoolingRate / this.fEnthalpyVapor) < this.toChildren.LCARSystem.toStores.LCARAbsorber.oProc.fAbsorbRate
                % No Venting! IVV flow is equal to SWME flow
                fFlowIn = fFlowRateSWME;
                % Close Venting Valve
                this.oIVValveEnviron.setFlowRate(0);
            else
                % Venting!
                fFlowIn = this.toChildren.LCARSystem.toStores.LCARAbsorber.oProc.fAbsorbRate;
                fVenting = (this.fCoolingRate / this.fEnthalpyVapor) - fFlowIn;
                % Open Venting Valve
                this.oIVValveEnviron.setFlowRate(-fVenting);
                
            end
            
            this.toChildren.LCARSystem.oIVValveLCAR.setFlowRate(-fFlowIn);
            
            % Compute water supply power (here coolingRate = supply power)
            this.fSupplyPow = fFlowRateSWME * this.fEnthalpyVapor;

           
        end
        
     end
    
end

