classdef Tutorial_Greenhouse < vsys
    
    properties
        % Flowrate of air circulation
        fFlowRate = 0.065;                  % [kg/s]
        
        % Flowrate of leakage loss due to pressure deficit Greenhouse <-> environment
        % Represents the mass loss due to greenhouse construction at current test state;  
        % Leakage loss 4.5 times main gh volume per day * density kg/m^3     
        fLeakageFlowRate = 0.00144;            % [kg/s]
        
        % Amount of CO2 in Greenhouse's 'air'-phase 
        fCO2;                       % parts per million
        
        % Flowrate used for CO2 controller  
        fCO2flowrate;               % [kg/s]
        
        % Flowrate used for O2 controller
        fO2flowrate;                % [kg/s]
        
        % Pressure water separator 'air'-phase
        fPressureWaterSeparator;    % [Pa]
        
        % Pressure of Greenhouse's 'air'-phase 
        fPressureGreenhouseAir;     % [Pa]
        
        % Partial mass of O2 in Greenhouse's 'air'-phase
        fparMassO2Greenhouse;
        
        % Partial mass of N2 in Greenhouse's 'air'-phase
        fparMassN2Greenhouse;
   
        % Relative humidty in 'air'-phase
        fRH;                        % [-]

        % Absorber Objects
        oProc_ExceedingCO2Absorber;
        oProc_ExceedingO2Absorber;
        
        % plant module subsystem object
        oPlantModule;
    end
    
    methods
        function this = Tutorial_Greenhouse(oParent, sName)
            % call superconstructor
            this@vsys(oParent, sName);
            
            % necessary for configuration
            eval(this.oRoot.oCfgParams.configCode(this));
            
            %% Subsystems
            
            % Initializing Subsystem: PlantModule
            this.oPlantModule = modules.PlantModule(this, 'PlantModule');
        end
        
        function createMatterStructure(this)
            % Greenhouse System Structure
            
            %% Greenhouse Unit
            
            % Creating the greenhouse main unit
            matter.store(this, 'GreenhouseUnit', 22.9);
            
            % add phase to greenhouse unit
            oAir = matter.phases.gas(...
                this.toStores.GH_Unit , ...    	% Phase name
                'Greenhouse_Air', ...           % Phase name
                struct(...                      % Phase contents
                    'O2', 6.394, ...
                    'N2', 21.192, ...
                    'CO2', 0.040, ...
                    'H2O', 0.193), ...     
                22.9, ...                       % Phase volume
                292.65);                        % Phase temperature
            
            % add exmes for greenhouse unit
            % to/from air circulation
            matter.procs.exmes.gas(oAir, 'ToCirculation_Out');
            matter.procs.exmes.gas(oAir, 'FromCirculation_In');
                        
            % to/from PlantModule
            matter.procs.exmes.gas(oAir, 'ToPlantModule_Out');
            matter.procs.exmes.gas(oAir, 'FromPlantModule_In');
            
            % to leakage tank
            matter.procs.exmes.gas(oAir, 'ToLeakageStore_Out');
            
            % to CO2 excess phase
            matter.procs.exmes.gas(oAir, 'ToCO2Excess_Out');
            
            % to O2 excess phase
            matter.procs.exmes.gas(oAir, 'ToO2Excess_Out');
            
            % Add Phase for excess CO2 - Excess CO2 is ejected to this 
            % phase. (Avoid to exceed CO2 limit due to nightly CO2 
            % production by plants)
            oCO2ExcessPhase = matter.phases.gas(...
                this.toStores.GreenhouseUnit, ...
                'CO2ExcessPhase', ...               % Phase name
                struct(...                          % Phase contens
                    'CO2', 0.00000001), ...      
                0.5, ...                            % Phase volume
                293.15);                            % Phase temperature
            
            % add exme to CO2 excess phase
            matter.procs.exmes.gas(oCO2ExcessPhase, 'CO2Excess_In');

            % Add Phase for excess O2 - Excess O2 is ejected to this phase.
            % (Because of no O2 consumers, just the plants nightly O2
            % consumption - the exceeding O2 has to be ejected)
            oCO2ExcessPhase = matter.phases.gas(...
                this.toStores.GreenhouseUnit, ...
                'O2ExcessPhase', ...                % Phase name
                struct(...                          % Phase contens
                    'O2', 0.00000001), ...       
                0.5, ...                            % Phase volume
                293.15);                            % Phase temperature

            % add exmes to CO2 excess phase
            matter.procs.exmes.gas(oCO2ExcessPhase, 'O2Excess_In');

                        
            % Initializing of CO2 absorber that processes the excess CO2
            this.oProc_ExceedingCO2Absorber = tutorials.plant_module.components.CO2Absorber.AbsorbingCO2(this.toStores.GreenhouseUnit, 'CO2Absorber', 'Greenhouse_Air.CO2Excess_Out', 'CO2ExcessPhase.CO2Excess_In', 'CO2');
            % Initializing of CO2 absorber that processes the excess CO2
            this.oProc_ExceedingO2Absorber = tutorials.plant_module.components.O2Absorber.AbsorbingO2(this.toStores.GreenhouseUnit, 'O2Absorber', 'Greenhouse_Air.O2Excess_Out', 'O2ExcessPhase.O2Excess_In', 'O2');
            
            %% Water Separator
          
            % add water separator
            tutorials.plant_module.components.WaterSeparator.SeparatorStore(this, 'WaterSeparator');
            
            %% Leakage Tank
            
            % add leakage tank
            matter.store(this, 'LeakageStore', 1e6);
            
            % add phase to leakage tank
            oLeakage = matter.phases.gas(...
                this.toStores.LeakageStore, ...
                'Leakage_Air', ...
                struct(...                      % Phase contents
                    'O2', 6.394, ...
                    'N2', 21.192, ...
                    'CO2', 0.040, ...
                    'H2O', 0.193), ...
                 1e6, ...
                 292.65);
            
            % add exmes to leakage tank
            matter.procs.exmes.gas(oLeakage, 'FromGreenhouseUnit_In');
             
            %% CO2 and N2 Supply Tanks
             
            % CO2 supply tank - Provide CO2 for plant growth
            % Adding CO2 buffer store
            matter.store(this, 'CO2Buffer', 2e4);
                
            % Adding CO2 phase
            oCO2BufferPhase = matter.phases.gas(...
                this.toStores.CO2Buffer, ...
                'CO2BufferPhase', ...               % Phase name
                struct(...                          % Phase contents
                    'CO2', 1e4), ...           
                2e4, ...                            % Phase volume
                293.15);                            % Phase temperature
                
            % add exmes to CO2 buffer tank
            matter.procs.exmes.gas(oAir, 'CO2Buffer_In');
            matter.procs.exmes.gas(oCO2BufferPhase, 'CO2Buffer_Out');
            
            
            % N2 supply tank - Provide N2 for stable air composition
            % Adding N2 buffer store
            matter.store(this, 'N2Buffer', 8e3);
                
            % Adding CO2 phase
            oN2BufferPhase = matter.phases.gas(...
                this.toStores.N2Buffer, ...
                'N2BufferPhase', ...            % Phase name
                struct(...                      % Phase contents
                    'N2', 1e4), ...            
                8e3, ...                        % Phase volume
                293.15);                        % Phase temperature
                
           	% add exmes to N2 buffer tank
            matter.procs.exmes.gas(oAir, 'N2Buffer_In');
            matter.procs.exmes.gas(oN2BufferPhase, 'N2Buffer_Out');
            
            %% Plant Module Water Supply and Biomass Storage
            
            % Adding water store - Water for plant growth
            matter.store(this, 'WaterTank', 5);
            
            % Adding water phase
            oWaterPhase = matter.phases.liquid(...
                this.toStores.WaterTank, ...   
                'WaterPhase', ...               %Phase name
                struct(...
                    'H2O', 10 * 500), ...       %Phase contents
                10, ...                         %Phase volume
                293.15, ...                     %Phase temperature
                101325);                        %Phase pressure

            % add exmes to water tank
            matter.procs.exmes.liquid(oWaterPhase, 'Water_Out');
            
            % Edible biomass store - destination of produced biomass after harvesting
            matter.store(this, 'FoodStore', 30);
            
            % Edible biomass phase
            oEdibleBiomass = matter.phases.liquid(...
                this.toStores.FoodStore, ...
                'EdibleBiomass', ...            %Phase name
                struct(...
                    'Food',0.001), ...       %Phase contents
                10, ...                         %Phase volume
                293.15, ...                     %Phase temperature
                101325);                        %Phase pressure
            
            % add exmes to edible biomass 
            matter.procs.exmes.liquid(oEdibleBiomass, 'EdibleBiomass_In');
            
            % Inedible biomass store - destination of arised waste after harvesting
            matter.store(this, 'WasteStore', 30);
            
            % Inedible biomass phase 
            oInedibleBiomass = matter.phases.liquid(...
                this.toStores.WasteTank, ...
                'InedibleBiomass', ...          %Phase name
                struct(...
                    'Waste',0.001), ...      %Phase contents
                30, ...                         %Phase volume
                293.15, ...                     %Phase temperature
                101325);                        %Phase pressure
            
            % add exmes to inedible biomass
            matter.procs.exmes.liquid(oInedibleBiomass, 'InedibleBiomass_In');
            
            %% Set Reference Phases
            
            % atmosphere and water supply for plant module
            this.toChildren.PlantModule.setReferencePhase(this.toStores.GreenhouseUnit.aoPhases(1,1), this.toStores.WaterTank.aoPhases(1,1));
            
            %% Create Flowpaths
            
            % Branches regarding the Greenhouse
            matter.branch(this, 'GreenhouseUnit.ToCirculation_Out',     {}, 'WaterSeparator.FromGreenhouse',        'Air_GreenhouseToWaterSeparator');
            matter.branch(this, 'WaterSeparator.ToGreenhouse',          {}, 'GreenhouseUnit.FromCirculation_In',    'Air_WaterSeparatorToGreenhouse');
            matter.branch(this, 'N2Buffer.N2Buffer_Out',                {}, 'GreenhouseUnit.N2Buffer_In',           'N2_BufferToGreenhouse');
            matter.branch(this, 'GreenhouseUnit.ToLeakageStore_Out',    {}, 'LeakageStore.FromGreenhouseUnit_In',   'Air_GreenhouseToLeakage');
            matter.branch(this, 'CO2Buffer.CO2Buffer_Out',              {}, 'GreenhouseUnit.CO2Buffer_In',          'CO2_BufferToGreenhouse');

            % Branches regarding the PlantModule interface
            matter.branch(this, 'Plants_Atmosphere_In',     {}, 'GreenhouseUnit.ToPlantModule_Out');
            matter.branch(this, 'Plants_Atmosphere_Out',    {}, 'GreenhouseUnit.FromPlantModule_In');
            matter.branch(this, 'Plants_H2O_In',            {}, 'WaterTank.Water_Out');
            matter.branch(this, 'Plants_Food_Out',          {}, 'FoodStore.EdibleBiomass_In');
            matter.branch(this, 'Plants_Waste_Out',         {}, 'WasteStore.InedibleBiomass_In');
        end
        
        function createSolverStructure(this)
            % call superconstructor
            createSolverStructure@vsys(this);
            
            %% Add Branches to Solver
            
            solver.matter.manual.branch(this.toBranches.Air_GreenhouseToWaterSeparator);
            solver.matter.manual.branch(this.toBranches.Air_WaterSeparatorToGreenhouse);
            solver.matter.manual.branch(this.toBranches.N2_BufferToGreenhouse);
            solver.matter.manual.branch(this.toBranches.Air_GreenhouseToLeakage);
            solver.matter.manual.branch(this.toBranches.CO2_BufferToGreenhouse);
            
            %% Initialize Flowrates
            
            this.toBranches.Air_GreenhouseToWaterSeparator.oHandler.setFlowRate(this.fFlowRate);
            this.toBranches.Air_WaterSeparatorToGreenhouse.oHandler.setFlowRate(this.fFlowRate);
            this.toBranches.N2_BufferToGreenhouse.oHandler.setFlowRate(0);
            this.toBranches.Air_GreenhouseToLeakage.oHandler.setFlowRate(this.fLeakageFlowRate);
            this.toBranches.CO2_BufferToGreenhouse.oHandler.setFlowRate(0.00005);
            
            %% Connect Subsystem Interfaces
            
            % connect plant module
            this.oPlantModule.setIfFlows(...
                'Plants_Atmosphere_In', ...             % atmosphere in from greenhouse
                'Plants_Atmosphere_Out', ...            % atmosphere out to greenhouse
                'Plants_H2O_In', ...                    % H2O in from water tank
                'Plants_Food_Out', ...                  % Edible Biomass out to food biomass tank
                'Plants_Waste_Out');                    % Inedible Biomass out to waste biomass tank 
        end
        
        function exec(this, ~)
            %
            exec@vsys(this);
            
            % get CO2 concentration from atmosphere phase
            this.fCO2 = components.PlantModule.Clac_CO2_ppm(this.toStores.GreenhouseUnit.aoPhases(1,1));
            
            %% Control relative humidity
            
            % Controlling Frequency
            if ~(mod(this.oTimer.fTime, 30))
                % Air cirulation for reducing the humidity of greenhouse's atmosphere
            
                % Allocating relative humidity
                this.fRH = this.toStores.GreenhouseUnit.aoPhases(1,1).rRelHumidity;
                 
                % 
                if  this.fRH > 0.70                       % relative Humidity
                    % Flowrate to 'air'-phase of the WaterSeparator
                    this.toBranches.Air_GreenhouseToWaterSeparator.oHandler.setFlowRate(this.fFlowRate);                              % [kg/s]
            
                    % Pressure in water separators air phase
                    this.fPressureWaterSeparator = this.toStores.WaterSeparator.aoPhases(1,1).fPressure;   % [Pa]
        
                    % Flowrate from WaterSeparator's 'air'-phase to Greenhouse's atmosphere
                    % To avoid instability due to pressure
                    % loss in separator air-phase
                    % --> Simple controller:
                    % separator air-phase is too low --> reduce
                    % outgoing flowrate 
                                
                    % where do the values for the flowrates come from???
                    if  this.fPressureWaterSeparator > 100000       % [Pa]
                        this.toBranches.Air_WaterSeparatorToGreenhouse.oHandler.setFlowRate(this.fFlowRate);                           % [kg/s]
                    elseif this.fPressureWaterSeparator >= 90000    % [Pa]
                        this.toBranches.Air_WaterSeparatorToGreenhouse.oHandler.setFlowRate(this.fFlowRate - 0.00045);                 % [kg/s]
                    elseif this.fPressureWaterSeparator < 90000     % [Pa]
                        this.toBranches.Air_WaterSeparatorToGreenhouse.oHandler.setFlowRate(this.fFlowRate - 0.0009);                  % [kg/s]
                    end
                                    
                elseif this.fRH < 0.65                   % relative Humidity
                    % Flowrate to 'air'-phase of the WaterSeparator
                    this.toBranches.Air_GreenhouseToWaterSeparator.oHandler.setFlowRate(0);
                
                    % Flowrate from WaterSeparator's 'air'-phase to Greenhouse's atmosphere
                    this.toBranches.Air_WaterSeparatorToGreenhouse.oHandler.setFlowRate(0);          
                end
            end 
            
            %% Control CO2 Concentration
            
            % Controlling Frequency
            if ~(mod(this.oTimer.fTime, 50))
                % Exchange flowrate of CO2 
                this.fCO2flowrate =  abs(this.toChildren.PlantModule.toStores.PlantCultivationStore.toProcsP2P.CO2_ExchangePlants.fFlowRate);

                % Simple On/Off Stabilization of the CO2 ppm level in the greenhouse's atmosphere
                % General functionality:        
                % If too less CO2 --> Switching on supply flowrate 
                % If too much CO2 --> Activating CO2 Absorber
                        
                % No CO2 supply flow over 1000 ppm CO2
                if this.fCO2 > 1005 % ppm
                    this.toBranches.CO2_BufferToGreenhouse.oHandler.setFlowRate(0); % [kg/s]
                    
                    % Absorbing CO2, when crossing a level of 1200 ppm CO2 in atmosphere                  
                    if this.fCO2 > 1200 % ppm
                        this.oProc_ExceedingCO2Absorber.fCO2AbsorptionRate = 0.0000000001 + 1.5 * this.fCO2flowrate; %[kg/s]
                    end
                end

                % Stop absorbing CO2, when level drops under 1100 ppm CO2
                if this.fCO2 < 1100  % ppm
                    this.oProc_ExceedingCO2Absorber.fCO2AbsorptionRate = 0; % [kg/s]
                end

                % Under a level of 995 ppm CO2, the supply flow is activated
                if this.fCO2 < 995  % ppm
                    % At
                    if this.oTimer.fTime < 10000 % [s]
                        this.toBranches.CO2_BufferToGreenhouse.oHandler.setFlowRate(0.000002);  % [kg/s]
                    else
                        this.toBranches.CO2_BufferToGreenhouse.oHandler.setFlowRate(0.0000000001 + 2 * this.fCO2flowrate);  % [kg/s]
                    end
                end                             
            end 
           
            %% Control O2 and N2 Levels
            
            if ~(mod(this.oTimer.fTime, 250))
                % O2 controller
                
                % Partial mass of O2
                this.fparMassO2Greenhouse = this.toStores.GreenhouseUnit.aoPhases(1,1).arPartialMass(this.oMT.tiN2I.O2);   % [-]
                
                % Reference flowrate for O2 absorption
                this.fO2flowrate =  abs(this.toChildren.PlantModule.toStores.PlantCultivationStore.toProcsP2P.O2_ExchangePlants);            % [kg/s]

                % If O2 partial mass higher than 23.5%  --> start absorption
                % If O2 partial mass lower than 21.5    --> stop  absortion
                if this.fparMassO2Greenhouse > 0.232
                    this.oProc_ExceedingO2Absorber.fO2AbsorptionRate = 0.000000001 + 1.5 * this.fO2flowrate; %this.fO2flowrate    % [kg/s]
                elseif this.fparMassO2Greenhouse < 0.228
                    this.oProc_ExceedingO2Absorber.fO2AbsorptionRate = 0;                  % [kg/s]
                end
                        
                % N2 controller
                
                % Partial mass of N2 
                this.fparMassN2Greenhouse = this.toStores.GreenhouseUnit.aoPhases(1,1).arPartialMass(this.oMT.tiN2I.N2);   % [-]
                
                % If N2 partial mass lower than  75%    --> start supply
                % If N2 partial mass higher than 76%    --> stopp supply
                if this.fparMassN2Greenhouse < 0.75
                    this.toBranches.N2_BufferToGreenhouse.oHandler.setFlowRate(0.0000007); % [kg/s]
                elseif this.fparMassN2Greenhouse > 0.755
                    this.toBranches.N2_BufferToGreenhouse.oHandler.setFlowRate(0);        % [kg/s]
                end       
            end
           
            %% Leakage Loss
             
            % If pressure deficit: pressure inside greenhouse
            % higher than 101325Pa (approximate pressure
            % outside)
            this.fPressureGreenhouseAir = this.toStores.GH_Unit.aoPhases(1).fPressure;
                            
            if  this.fPressureGreenhouseAir > 101325
                this.toBranches.Air_GreenhouseToLeakage.oHandler.setFlowRate(this.fLeakageFlowRate);
            else % If lower than supposed outside pressure -> no leakage loss
                this.toBranches.Air_GreenhouseToLeakage.oHandler.setFlowRate(0);
            end
        end
    end
end