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
        % Intermediate Venting Valve (Port to SWME) 
        oIVValveSWME;
        % Intermediate Venting Valve (Port to Environment)
        oIVValveEnviron;
        % Specific enthalpy of water vapor
        fEnthalpyVapor = 2000000;

    end
    
    properties (SetAccess = public, GetAccess = public)
        % Water supply power by evaporation (Cooling Power) (For logging
        % purposes only)
        fSupplyPow = 0;
        
    end
    
    methods
        function this = SEAR(oParent, sName, tParameters)
            
            % Calling vsys-constructor-method. Third parameter determines
            % how often the .exec() method of this subsystem is called.
            % Possible Interval: 0-inf [s]
            % -1 for every tick, 0 for global time step
            this@vsys(oParent, sName, -1);
            
            %% LCAR Subsystem
            
            % Adding the subsystem
            components.SEAR.subsystems.LCARSystem(this, 'LCARSystem', tParameters);
            
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
        
        end
        
     end
    
end

