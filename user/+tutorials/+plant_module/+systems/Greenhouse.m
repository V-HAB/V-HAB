classdef Greenhouse < vsys
  %Main Structure of the Lunar Greenhouse
    
   properties

        
        %Flowrate of air circulation
            fFlowRate;                  % [kg/s]
        %Flowrate of leakage loss due to pressure deficit Greenhouse <-> environment
            fLeakageFlowRate            % [kg/s]
        %Amount of CO2 in Greenhouse's 'air'-phase 
            fCO2ppm_Measured;           % parts per million
        %Flowrate used for CO2 controller  
            fCO2flowrate;               % [kg/s]
        %Flowrate used for O2 controller
            fO2flowrate;                % [kg/s]
        
        %Pressure water separator 'air'-phase
            fPressureWaterSeparator;    % [Pa]
        %Pressure of Greenhouse's 'air'-phase 
            fPressureGreenhouseAir;     % [Pa]
        %Partial mass of O2 in Greenhouse's 'air'-phase
            fparMassO2Greenhouse;
        %Partial mass of N2 in Greenhouse's 'air'-phase
            fparMassN2Greenhouse;
            
            
        %Relative humidty in 'air'-phase
            fRH;                        % [-]
      
      
        %global timestep for multiple setup of timestep 
            fglobTS;                    % [s]  
        
        %Absorber Objects
            oProc_ExceedingCO2Absorber;
            oProc_ExceedingO2Absorber;
        
        %Object properties for handling following branch objects
            oB1;
            oB2;
            oB3;
            oB4;
            oB5;
      
       
    end
    
    %% -System Definition
    
    methods
        function this = Greenhouse(oParent, sName)
          % Call of the supercalls constructor

                this@vsys(oParent, sName, 60);
                                

                    
        %% -General Settings-    
                
            %Set global timestep for Water Separator Phases
                    this.fglobTS = 30.0; %[s]
        
        
        
            %FlowRate settings
                %Start condition - circulation flowrate
                    this.fFlowRate = 0;
                %Represents the mass loss due to greenhouse construction at current test state;  
                %Leakage loss 4.5 times main gh volume per day * density kg/m^3     
                    this.fLeakageFlowRate = 0.00144;  % [kg/s]  
                 
                    
                    
        %% -Greenhouse System structure-
            %Greenhouse Unit
                %Creating the greenhouse main unit
                    this.addStore(matter.store(this.oData.oMT, 'GH_Unit', 22.9));

                %Greenhouses start atmosphere
                    oAir = matter.phases.gas( this.toStores.GH_Unit , ...                       %Phase name
                            'air', ...                                                          %Phase name
                            struct('O2', 6.394,'N2', 21.192,'CO2', 0.040,'H2O', 0.193), ...     %Phase contents
                            22.9, ...                                                           %Phase volume
                            292.65);                                                            %Phase temperature
                              
                %Corresponding Interfaces
                    %To air circulation
                        matter.procs.exmes.gas(oAir, 'CirculationOut');
                        matter.procs.exmes.gas(oAir, 'CirculationIn');
                        
                    %To PlantModule
                        matter.procs.exmes.gas(oAir, 'ToPlantModuleIn');
                        matter.procs.exmes.gas(oAir, 'FromPlantModuleOut');
            
            
            
            %Setting up water separator
                this.addStore(tutorials.plant_module.components.WaterSeparator.SeparatorStore(this, this.oData.oMT, 'WaterSeparator'));
            
                        
            %Leakage tank - Implementation of leakage loss
                %Leakage store
                    this.addStore(matter.store(this.oData.oMT, 'LeakageStore', 10000000));
                
                %Adding leakage phase
                    oLeakagePhase = this.toStores.LeakageStore.createPhase('air', ...  %Phase content
                            10000000, ...                                             %Phase volume
                            292.65, ...                                           %Phase temperature
                            0.5);                                                 %Phase (air) humidity
                
                %Interaces
                    matter.procs.exmes.gas(oAir, 'ToLeakageStore');
                    matter.procs.exmes.gas(oLeakagePhase, 'From_GH_Unit');
                
                    
                    
            %CO2 supply tank - Provide CO2 for plant growth
                %Adding CO2 buffer store
                    this.addStore(matter.store(this.oData.oMT, 'CO2Buffer', 20000));
                
                %Adding CO2 phase
                    oCO2BufferPhase = matter.phases.gas(this.toStores.CO2Buffer, ...
                        'CO2BufferPhase', ...               %Phase name
                        struct('CO2', 10000), ...           %Phase contents
                        10000000, ...                       %Phase volume
                        293.15);                            %Phase temperature
                
                %Interfaces
                    matter.procs.exmes.gas(oAir, 'CO2BufferIn');
                    matter.procs.exmes.gas(oCO2BufferPhase, 'CO2BufferOut');
                
                
            %N2 supply tank - Provide N2 for stable air composition
                %Adding N2 buffer store
                    this.addStore(matter.store(this.oData.oMT, 'N2Buffer', 8000));
                
                %Adding CO2 phase
                    oN2BufferPhase = matter.phases.gas(this.toStores.N2Buffer, ...
                        'N2BufferPhase', ...                %Phase name
                        struct('N2', 10000), ...            %Phase contents
                        8000, ...                           %Phase volume
                        293.15);                            %Phase temperature
                
                %Interfaces
                    matter.procs.exmes.gas(oAir, 'N2BufferIn');
                    matter.procs.exmes.gas(oN2BufferPhase, 'N2BufferOut');
                    
                    
            %Adding to existing 'gh_main' store ...
                %Exceeding CO2
                    %Phase for exceeding CO2 - Exceeding CO2 is ejected to this phase.
                    %(Avoid to exceed CO2 limit due to nightly CO2 production by plants)
                    oCO2ExcessPhase = matter.phases.gas(this.toStores.GH_Unit, ...
                        'CO2ExcessPhase', ...               %Phase name
                        struct('CO2', 0.00000001), ...      %Phase contens
                        0.5, ...                            %Phase volume
                        293.15);                            %Phase temperature

                    %Interfaces
                        matter.procs.exmes.gas(oAir, 'CO2ExcessOut');
                        matter.procs.exmes.gas(oCO2ExcessPhase, 'CO2ExcessIn');

                    %Initializing of CO2 absorber that processes the exceeding CO2
                        this.oProc_ExceedingCO2Absorber = tutorials.plant_module.components.CO2Absorber.AbsorbingCO2(this.toStores.GH_Unit, 'CO2Absorber', 'air.CO2ExcessOut', 'CO2ExcessPhase.CO2ExcessIn', 'CO2');
                %Exceeding O2
                   %Phase for exceeding O2 - Exceeding O2 is ejected to this phase.
                   %(Because of no O2 consumers - neglecting the plants nightly O2 consume - the exceeding O2 has to be ejected)
                   oCO2ExcessPhase = matter.phases.gas(this.toStores.GH_Unit, ...
                        'O2ExcessPhase', ...                %Phase name
                        struct('O2', 0.00000001), ...       %Phase contens
                        0.5, ...                            %Phase volume
                        293.15);                            %Phase temperature

                    %Interfaces
                        matter.procs.exmes.gas(oAir, 'O2ExcessOut');
                        matter.procs.exmes.gas(oCO2ExcessPhase, 'O2ExcessIn');

                    %Initializing of CO2 absorber that processes the exceeding CO2
                        this.oProc_ExceedingO2Absorber = tutorials.plant_module.components.O2Absorber.AbsorbingO2(this.toStores.GH_Unit, 'O2Absorber', 'air.O2ExcessOut', 'O2ExcessPhase.O2ExcessIn', 'O2');
                
                    
            %% -Plant Module-
                
                %Adding water store - Water for plant growth
                    this.addStore(matter.store(this.oData.oMT, 'WaterTank', 5));
                    %Adding water phase
                        oWaterPhase = matter.phases.liquid(this.toStores.WaterTank, ...   
                            'Water_Phase', ...              %Phase name
                            struct('H2O', 10*500), ...      %Phase contents
                            10, ...                         %Phase volume
                            293.15, ...                     %Phase temperature
                            101325);                        %Phase pressure

                    %Intefaces
                        matter.procs.exmes.liquid(oWaterPhase, 'WaterOut');

                        

                 %Edible biomass store - destination of produced biomass after harvesting
                    this.addStore(matter.store(this.oData.oMT, 'FoodStore', 30));
                    %Edible biomass phase
                        oEdibleBiomass = matter.phases.liquid(this.toStores.FoodStore, ...
                            'EdibleBiomass', ...            %Phase name
                            struct('Food',0.001), ...       %Phase contents
                            10, ...                         %Phase volume
                            293.15, ...                     %Phase temperature
                            101325);                        %Phase pressure
                    %Intefaces
                        matter.procs.exmes.liquid(oEdibleBiomass, 'EdibBioIn');

                        

                 %Inedible biomass store - destination of arised waste after harvesting
                    this.addStore(matter.store(this.oData.oMT, 'WasteTank', 30));
                    %Inedible biomass phase 
                        oInedibleBiomass = matter.phases.liquid(this.toStores.WasteTank, ...
                            'InedibleBiomass', ...          %Phase name
                            struct('Waste',0.001), ...      %Phase contents
                            30, ...                         %Phase volume
                            293.15, ...                     %Phase temperature
                            101325);                        %Phase pressure
                    %Interfaces
                        matter.procs.exmes.liquid(oInedibleBiomass, 'InedibBioIn');

                        
                        

        %% -Subsystems-
            
            %Initializing Subsystem: PlantModule
                oSubSysPlantCultivation = modules.PlantModule(this, 'PlantModule');
                % Assigning an object for handling later following interface connections
             
                
                
                
        %% -Connections-      
           %Misc
            %Adding Pipes
               %Greenhouse system
                    this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_01', 0.5, 0.10)); 
                    this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_02', 0.5, 0.10)); 
                    this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_03', 0.5, 0.10)); 
                    this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_04', 0.5, 0.05));     
                    this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_05', 0.5, 0.05));
                
               %To PlantModule subsystem
                    this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_06',  0.5, 0.005));
                    this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_07',  0.5, 0.005));
                    this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_08',  0.5, 0.005));
                    this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_09',  0.5, 0.005));
                    this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_10', 0.5, 0.005));

                    
               %Branches regarding the Greenhouse
                    oBranch1 = this.createBranch('GH_Unit.CirculationOut',      {'Pipe_01'}, 'WaterSeparator.FromGreenhouse');
                    oBranch2 = this.createBranch('WaterSeparator.ToGreenhouse', {'Pipe_02'}, 'GH_Unit.CirculationIn');
                    oBranch3 = this.createBranch('N2Buffer.N2BufferOut',        {'Pipe_03'}, 'GH_Unit.N2BufferIn');
                    oBranch4 = this.createBranch('GH_Unit.ToLeakageStore',      {'Pipe_04'}, 'LeakageStore.From_GH_Unit');
                    oBranch5 = this.createBranch('CO2Buffer.CO2BufferOut',      {'Pipe_05'}, 'GH_Unit.CO2BufferIn');

               %Branches regarding the PlantModule interface
                    this.createBranch('sFromLSS_AirIN', { 'Pipe_06' }, 'GH_Unit.ToPlantModuleIn');
                    this.createBranch('sToLSS_AirOUT',  { 'Pipe_07' }, 'GH_Unit.FromPlantModuleOut');
                    this.createBranch('sWaterSupply',   { 'Pipe_08' }, 'WaterTank.WaterOut');
                    this.createBranch('sFoodOUT',       { 'Pipe_09' }, 'FoodStore.EdibBioIn');
                    this.createBranch('sWasteOUT',      { 'Pipe_10' }, 'WasteTank.InedibBioIn');
                
                    
                    
                    
                    
               %Connecting 'LSS' system with subsystem 'PlantModule'
               %   (setIfFlows  =  set interface flows)
                 oSubSysPlantCultivation.setIfFlows(... % Call setIfFlows-function of "PlantModule"'s assigned object
                                                    ... % Strings used for branch connectors:
                                  'sFromLSS_AirIN', ... %   Air-phase connector (FYI: from LSS to PlantModule)
                                  'sToLSS_AirOUT',  ... %   Air-phase connector (FYI: from PlantModule to LSS)
                                  'sWaterSupply',   ... %   Connector to Water tank 
                                  'sFoodOUT',       ... %   Connector to food store
                                  'sWasteOUT');         %   Connector to waste tank
                
                                               
            this.seal();
            
            %Definition of solvers for 'Greenhouse' system
                this.oB1 = solver.matter.manual.branch(oBranch1);
                this.oB2 = solver.matter.manual.branch(oBranch2);
                this.oB3 = solver.matter.manual.branch(oBranch3);
                this.oB4 = solver.matter.manual.branch(oBranch4);
                this.oB5 = solver.matter.manual.branch(oBranch5);
            
            
            

             %Initial setting of the branches flowrates
                this.oB1.setFlowRate(this.fFlowRate);          
                this.oB2.setFlowRate(this.fFlowRate);
                this.oB3.setFlowRate(0);
                this.oB4.setFlowRate(this.fLeakageFlowRate); 
                this.oB5.setFlowRate(0.00005);
                

             %Setting timesteps of phases to a global timestep ...
                
                %CO2 supply phase
                    aoPhases = this.toStores.CO2Buffer.aoPhases;
                        aoPhases(1).fFixedTS = this.fglobTS;
                %N2 supply phase
                    aoPhases = this.toStores.N2Buffer.aoPhases;
                        aoPhases(1).fFixedTS = this.fglobTS;
                %Leakage store phase
                    aoPhases = this.toStores.LeakageStore.aoPhases;
                        aoPhases(1).fFixedTS=  this.fglobTS;
                %Water tank phase
                    aoPhases = this.toStores.WaterTank.aoPhases;
                        aoPhases(1).fFixedTS = this.fglobTS;
                %Edible biomass phase
                    aoPhases = this.toStores.FoodStore.aoPhases;
                        aoPhases(1).fFixedTS = this.fglobTS;
                %Inedible biomass phase
                    aoPhases = this.toStores.WasteTank.aoPhases;
                        aoPhases(1).fFixedTS = this.fglobTS;

                        
             %Setting separate timesteps for some phases
             
                %Phases of Greenhouse unit
                    aoPhases = this.toStores.GH_Unit.aoPhases;
                        %Air phase of Greenhouse unit
                        aoPhases(1).fFixedTS = 15;% this.fglobTS;
                        %CO2-excess phase of Greenhouse unit
                        aoPhases(2).fFixedTS = 15;% this.fglobTS;
                        %O2-excess phase of Greenhouse unit
                        aoPhases(3).fFixedTS = 15;% this.fglobTS;
                        
                        
                %Phases of Water Separator
                    aoPhases = this.toStores.WaterSeparator.aoPhases;
                        %Flow phase
                        aoPhases(1).fFixedTS = 15; %this.fglobTS;
                        %Separated water phase
                        aoPhases(2).fFixedTS = 15; %this.fglobTS;
                        
                
        end
        
    end
    
    %% -Updating-
    
    methods (Access = protected)
        function exec(this, ~)
            
            exec@vsys(this);   
                        
                        
        %% -Controllers-
            
            
            
               %Calculating the current CO2 ppm level in the greenhouse's atmosphere
                   this.fCO2ppm_Measured = tutorials.plant_module.functions.Calc_CO2_ppm(this.toStores.GH_Unit.aoPhases(1));
            
           if this.oTimer.fTime ~=0 
           %Controlling Frequency
           if ~(mod(this.oData.oTimer.fTime, 30))
                                      %Air cirulation for reducing the humidity of greenhouse's atmosphere
                       %Allocating relative humidity
                        this.fRH = this.toStores.GH_Unit.aoPhases(1).rRelHumidity;
                        
                        if  this.fRH > 0.70                       % relative Humidity
                                                   
                                %Circulation flowrate
                                    this.fFlowRate = 0.065;                                            % [kg/s]
                                %Flowrate to 'air'-phase of the WaterSeparator
                                    this.oB1.setFlowRate(this.fFlowRate);                              % [kg/s]
                                %Pressure in water separators air phase
                                    this.fPressureWaterSeparator = ...
                                        this.toStores.WaterSeparator.aoPhases(1).fPressure;            % [Pa]
                                %Flowrate from WaterSeparator's 'air'-phase to Greenhouse's atmosphere
                                %  To avoid instability due to pressure
                                %  loss in separator air-phase
                                %  --> Simple controller:
                                %  separator air-phase is too low --> reduce
                                %  outgoing flowrate 
                                
                                    if  this.fPressureWaterSeparator > 100000      % [Pa]
                                        this.oB2.setFlowRate(this.fFlowRate);                           % [kg/s]
                                    elseif this.fPressureWaterSeparator >= 90000  % [Pa]
                                        this.oB2.setFlowRate(this.fFlowRate - 0.00045);                 % [kg/s]
                                    elseif this.fPressureWaterSeparator < 90000   % [Pa]
                                        this.oB2.setFlowRate(this.fFlowRate - 0.0009);                  % [kg/s]
                                    end
                                    
                                    
                             %this.oBranch2.bind('outdated', @(~) this.oB2.setFlowRate(this.fFlowRate - this.toStores.WaterSeparator.toProcsP2P.SeparatorProc.fFlowRate));
                        elseif this.fRH < 0.65                   % relative Humidity
                            %Flowrate to 'air'-phase of the WaterSeparator
                                this.oB1.setFlowRate(0);
                            %Flowrate from WaterSeparator's 'air'-phase to Greenhouse's atmosphere
                                this.oB2.setFlowRate(0);
                            
                        end
           end %End of Frequency If statement 
           end
           
           
           %Controlling Frequency
           if ~(mod(this.oData.oTimer.fTime, 50))
                     

                        

                   %Exchange flowrate of CO2 
                       this.fCO2flowrate =  abs(this.toChildren.PlantModule.oProc_Plants_CO2GasExchange.fFlowRate);

                    
                  %Simple On/Off Stabilization of the CO2 ppm level in the greenhouse's atmosphere
                       %General functionality:        
                        %If too less CO2 --> Switching on supply flowrate 
                        %If too much CO2 --> Activating CO2 Absorber
                        
                            %No CO2 supply flow over 1000 ppm CO2
                            if this.fCO2ppm_Measured > 1005 % ppm
                                this.oB5.setFlowRate(0); % [kg/s]
                                %Absorbing CO2, when crossing a level of 1200 ppm CO2 in atmosphere                  
                                    if this.fCO2ppm_Measured >1200 % ppm
                                        this.oProc_ExceedingCO2Absorber.fCO2AbsorptionRate = 0.0000000001+1.5*this.fCO2flowrate; %[kg/s]
                                    end
                            end

                            %Stop absorbing CO2, when level drops under 1100 ppm CO2
                            if this.fCO2ppm_Measured < 1100  % ppm
                                    this.oProc_ExceedingCO2Absorber.fCO2AbsorptionRate = 0; % [kg/s]
                            end

                            %Under a level of 995 ppm CO2, the supply flow is activated
                            if this.fCO2ppm_Measured < 995  % ppm
                                %At
                                if this.oData.oTimer.fTime < 10000 % [s]
                                    this.oB5.setFlowRate(0.000002);  % [kg/s]
                                else
                                    this.oB5.setFlowRate(0.0000000001+2*this.fCO2flowrate);  % [kg/s]
                                end
                            end 
                                              
                                            
           end %End of Frequency If statement 
                    
                   
                    
                   
           if ~(mod(this.oData.oTimer.fTime, 250))
                    
                   %O2 controller
                       %Partial mass of O2
                        this.fparMassO2Greenhouse = this.toStores.GH_Unit.aoPhases(1).arPartialMass(this.oData.oMT.tiN2I.O2);   % [-]
                       %Reference flowrate for O2 absorption
                        this.fO2flowrate =  abs(this.toChildren.PlantModule.oProc_Plants_O2GasExchange.fFlowRate);            % [kg/s]

                       %If O2 partial mass higher than 23.5%  --> start absorption
                       %If O2 partial mass lower than 21.5    --> stop  absortion
                        if this.fparMassO2Greenhouse > 0.232
                            this.oProc_ExceedingO2Absorber.fO2AbsorptionRate = 0.000000001 + 1.5*this.fO2flowrate; %this.fO2flowrate    % [kg/s]
                        elseif this.fparMassO2Greenhouse < 0.228
                            this.oProc_ExceedingO2Absorber.fO2AbsorptionRate = 0;                  % [kg/s]
                        end
                        
                        
                    %N2 controller
                       %Partial mass of N2 
                        this.fparMassN2Greenhouse = this.toStores.GH_Unit.aoPhases(1).arPartialMass(this.oData.oMT.tiN2I.N2);   % [-]
                        %If N2 partial mass lower than  75%    --> start supply
                        %If N2 partial mass higher than 76%    --> stopp supply
                       
                        if this.fparMassN2Greenhouse < 0.75
                            this.oB3.setFlowRate(0.0000007); % [kg/s]
                        end
                        
                        if this.fparMassN2Greenhouse > 0.755
                            this.oB5.setFlowRate(0);        % [kg/s]
                        end
                        
           end %End of Frequency If statement 
                    
                    

                    

                    %Leakage loss 
                        %If pressure deficit: pressure inside greenhouse
                        %higher than 101325Pa (approximate pressure
                        %outside)
                        this.fPressureGreenhouseAir = this.toStores.GH_Unit.aoPhases(1).fPressure;
                            
                        if  this.fPressureGreenhouseAir > 101325
                            this.oB4.setFlowRate(this.fLeakageFlowRate);
                        else %If lower than supposed outside pressure -> no leakage loss
                            this.oB4.setFlowRate(0);
                        end


                
        end

    end
    
    
end