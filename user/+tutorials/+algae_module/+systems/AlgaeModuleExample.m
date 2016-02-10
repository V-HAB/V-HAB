classdef AlgaeModuleExample < vsys
    % system level of bio_lss; contains system level structure;
    
    properties
        oBranch4;
        oBranchWaterPump;
        n2_control=0;
        oProc_Manip;
        fDeadlockControl=0;
        fWaterPumpControl=0;
    end
    
    methods
        function this = AlgaeModuleExample(oParent, sName)
            this@vsys(oParent, sName, 15);
 
            % Creating the crew_module store, volume 80m^3
            this.addStore(matter.store(this.oData.oMT, 'crew_module', 8*700));
            
            % Creating the phase for the crew module using the 'air' helper
            %oCrew_Module_Air = this.toStores.crew_module.createPhase('air', 80,293,0);
           oCrew_Module_Air = matter.phases.gas(this.toStores.crew_module, ...
                'air', ... Phase name
                struct('O2',8*21.49/8*700,'N2',8*70.35/8*700,'CO2',8*0.09/8*700), ... Phase contents - set by helper
                8*7000, ... Phase volume
                293.15);
            
            % Adding extract/merge processors to the phase
            matter.procs.exmes.gas(oCrew_Module_Air, 'p1');
            matter.procs.exmes.gas(oCrew_Module_Air, 'p2');
            matter.procs.exmes.gas(oCrew_Module_Air, 'p3');
            matter.procs.exmes.gas(oCrew_Module_Air, 'p4');
            matter.procs.exmes.gas(oCrew_Module_Air, 'p5');
            matter.procs.exmes.gas(oCrew_Module_Air, 'p6');
            matter.procs.exmes.gas(oCrew_Module_Air, 'p7');
            matter.procs.exmes.gas(oCrew_Module_Air, 'p8');
            matter.procs.exmes.gas(oCrew_Module_Air, 'p9');
            matter.procs.exmes.gas(oCrew_Module_Air, 'p10');
            matter.procs.exmes.gas(oCrew_Module_Air, 'p11');
            matter.procs.exmes.gas(oCrew_Module_Air, 'p12');
            matter.procs.exmes.gas(oCrew_Module_Air, 'p13');
            
            
            %creating the potable H2O tank; volume 30m?
            this.addStore(matter.store(this.oData.oMT, 'PotableWaterTank', 30));
            
            %creating water phase for the potable H2O tank; filled with 10m?
            %water
            oPotableWaterPhase = matter.phases.liquid(this.toStores.PotableWaterTank, ...   Store in which the phase is located
                'Water_Phase', ...      Phase name
                struct('H2O', 500), ... Phase contents
                10, ...                 Phase volume
                293.15, ...             Phase temperature
                101325);              % Phase pressure
            
            % Adding a default extract/merge processor to the phase
            matter.procs.exmes.liquid(oPotableWaterPhase, 'p1');
            matter.procs.exmes.liquid(oPotableWaterPhase, 'p2');
            matter.procs.exmes.liquid(oPotableWaterPhase, 'p3');
            
            
            %creating the Nutrient Tank; volume 30m?
            this.addStore(matter.store(this.oData.oMT, 'NutrientTank', 30));
            
            %creating Nutrient phase for the Nutrient Tank; filled with 10m?
            %NO3
            oNutrientPhase = matter.phases.liquid(this.toStores.NutrientTank, ...   Store in which the phase is located
                'NO3_Phase', ...        Phase name
                struct('NO3', 10), ...  Phase contents
                10, ...                 Phase volume
                293.15, ...             Phase temperature
                101325);              % Phase pressure
            
            % Adding a default extract/merge processor to the phase
            matter.procs.exmes.liquid(oNutrientPhase, 'p1');
            
            
            % Creating the Inedible Biomass store
            this.addStore(matter.store(this.oData.oMT, 'Inedible_Biomass', 30));
            oInedibleBiomass = matter.phases.liquid(this.toStores.Inedible_Biomass, ...
                'Inedible_Biomass_Phase', ... Phase name
                struct('Waste',0.001), ...    Phase contents - set by helper
                10, ...                       Phase volume
                293.15, ...                   Phase temperature
                101325);                    % Phase pressure
            
            % Adding a default extract/merge processor to the phase
            matter.procs.exmes.liquid(oInedibleBiomass, 'p1');
            matter.procs.exmes.liquid(oInedibleBiomass, 'p2');
            matter.procs.exmes.liquid(oInedibleBiomass, 'p3');
            
            
            % Creating the Food_Storage Store
            this.addStore(matter.store(this.oData.oMT, 'Food_Storage', 30));
            oFoodStorage = matter.phases.liquid(this.toStores.Food_Storage, ...
                'Food', ... Phase name
                struct('Food',0.001), ... Phase contents - set by helper
                10, ... Phase volume
                293.15, ...             Phase temperature
                101325);              % Phase pressure
            
            % Adding a default extract/merge processor to the phase
            matter.procs.exmes.liquid(oFoodStorage,'p1');
            matter.procs.exmes.liquid(oFoodStorage,'p2');
            matter.procs.exmes.liquid(oFoodStorage,'p3');
            
            %transform all matter in food storage to 'Food'
           % this.oProc_Manip = hami.BIO_LSS.components.food_Reactor('food_Reactor', oFoodStorage);
            
            % Creating the Inedible Biomass + H2O store
            this.addStore(matter.store(this.oData.oMT, 'InedibleBiomassH2O', 30));
            oInedibleBiomassH2O = matter.phases.liquid(this.toStores.InedibleBiomassH2O, ...
                'InedibleBiomassH2O', ... Phase name
                struct('Waste',3, 'H2O',7), ... Phase contents - set by helper
                30, ... Phase volume
                293.15, ...             Phase temperature
                101325);              % Phase pressure
            
            % Adding a default extract/merge processor to the phase
            matter.procs.exmes.liquid(oInedibleBiomassH2O,'p1');
            matter.procs.exmes.liquid(oInedibleBiomassH2O,'p2');
            matter.procs.exmes.liquid(oInedibleBiomassH2O,'p3');
            
            %Adding Hygiene Water Tank
            this.addStore(matter.store(this.oData.oMT, 'HygieneWaterTank', 30));
            
            %creating water phase for the potable H2O tank; filled with 10m?
            %water
            oHygieneWaterPhase = matter.phases.liquid(this.toStores.HygieneWaterTank, ...   Store in which the phase is located
                'HygieneWaterPhase', ...         Phase name
                struct('H2O', 1000), ...      Phase contents
                1000, ...                 Phase volume
                293.15, ...             Phase temperature
                101325);              % Phase pressure
            
            % Adding a default extract/merge processor to the phase
            matter.procs.exmes.liquid(oHygieneWaterPhase, 'p1');
            matter.procs.exmes.liquid(oHygieneWaterPhase, 'p2');
            matter.procs.exmes.liquid(oHygieneWaterPhase, 'p3');
            matter.procs.exmes.liquid(oHygieneWaterPhase, 'p4');
            
            
            
            %Adding Hygiene Water Tank
            this.addStore(matter.store(this.oData.oMT, 'H2O2Tank', 30));
            
            %Adding H2O2 Phase:
            oH2O2Phase = matter.phases.liquid(this.toStores.H2O2Tank, ...   Store in which the phase is located
                'H2O2Phase', ...         Phase name
                struct('H2O2',1), ...      Phase contents
                10, ...                 Phase volume
                293.15, ...             Phase temperature
                101325);              % Phase pressure
            
            % Adding a default extract/merge processor to the phase
            matter.procs.exmes.liquid(oH2O2Phase, 'p1');
            matter.procs.exmes.liquid(oH2O2Phase, 'p2');
            
            % Creating the Deadlock store, volume 30m^3
            this.addStore(matter.store(this.oData.oMT, 'Deadlock', 30));
            
            % Creating the phase for the N2 buffer store
            oDeadlockPhase = matter.phases.gas(this.toStores.Deadlock, ...   Store in which the phase is located
                'DeadlockPhase', ...         Phase name
                struct('H2O',0.001), ...      Phase contents
                30, ...                 Phase volume
                293.15);
            
            % Adding a default extract/merge processor to the phase
            matter.procs.exmes.gas(oDeadlockPhase, 'p1');
            matter.procs.exmes.gas(oDeadlockPhase, 'p2');
            
            
            % Creating the N2 buffer store, volume 30m^3
            this.addStore(matter.store(this.oData.oMT, 'N2_buffer_tank', 30));
            
            % Creating the phase for the N2 buffer store
            oN2_buffer_phase = matter.phases.gas(this.toStores.N2_buffer_tank, ...   Store in which the phase is located
                'N2_buffer_phase', ...         Phase name
                struct('N2', 40), ...      Phase contents
                3000, ...                 Phase volume
                293.15);
            
            % Adding a default extract/merge processor to the phase
            matter.procs.exmes.gas(oN2_buffer_phase, 'p1');
            
            
            
            
            %Adding subsystems:
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %Coldplate:
            %oSubSysColdplate = hami.BIO_LSS.subsystems.coldplate(this, 'SubSystemColdplate');
            
            %algae_module:
            oSubSysAlgaeModule = modules.AlgaeModule(this, 'SubSystemAlgaeModule');
            
            
            %human_dummy:
            %oSubSysHumanDummy = hami.BIO_LSS.subsystems.human_dummy(this, 'SubSystemHumanDummy');
            
            
            %HydrogenPeroxidProduction:
            %oSubSysHydrogenPeroxidProduction = hami.BIO_LSS.subsystems.HydrogenPeroxidProduction(this, 'SubSystemHydrogenPeroxidProduction');
            
            %HydrogenWaterManagement:
            %oSubSysHygieneWaterManagement = hami.BIO_LSS.subsystems.HygieneWaterManagement(this, 'SubSystemHygieneWaterManagement');
            
            %WasteManagement:
            %oSubSysWasteManagement = hami.BIO_LSS.subsystems.WasteManagement(this, 'SubSystemWasteManagement');
            
            %Plant Cultivation:
           % oSubSysPlantCultivation = hami.BIO_LSS.subsystems.PlantCultivation(this, 'SubSystemPlantCultivation');
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            
            % Adding pipes to connect the components
            this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_1', 0.5, 0.005));
            this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_2', 0.5, 0.005));
            this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_3', 0.5, 0.005));
            this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_4', 0.5, 0.005));
            this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_5', 0.5, 0.005));
            this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_6', 0.5, 0.005));
            this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_7', 0.5, 0.005));
            this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_8', 0.5, 0.005));
            this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_9', 0.5, 0.005));
            this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_10', 0.5, 0.005));
            this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_11', 0.5, 0.005));
            this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_12', 0.5, 0.005));
            this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_13', 0.5, 0.005));
            this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_14', 0.5, 0.005));
            this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_15', 0.5, 0.005));
            this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_16', 0.5, 0.005));
            this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_17', 0.5, 0.005));
            this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_18', 0.5, 0.005));
            this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_19', 0.5, 0.005));
            this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_20', 0.5, 0.005));
            this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_21', 0.5, 0.005));
            this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_22', 0.5, 0.005));
            this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_23', 0.5, 0.005));
            this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_24', 0.5, 0.005));
            this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_25', 0.5, 0.005));
            this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_26', 0.5, 0.005));
            this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_27', 0.5, 0.005));
            this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_28', 0.5, 0.005));
            this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_29', 0.5, 0.005));
            this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_30', 0.5, 0.005));
            this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_31', 0.5, 0.005));
            
            % creating the branches
%             this.createBranch('SubsystemInput', { 'Pipe_2' }, 'crew_module.p1');
%             this.createBranch('SubsystemOutput', { 'Pipe_3' }, 'crew_module.p2');
%             this.createBranch('SubsystemOutput2', { 'Pipe_1' }, 'PotableWaterTank.p1');
%             oBranch4=this.createBranch('N2_buffer_tank.p1', { 'Pipe_4' }, 'crew_module.p3');
            this.createBranch('SubsystemInput1_algae_module', { 'Pipe_5' }, 'crew_module.p4');
            this.createBranch('SubsystemOutput1_algae_module', { 'Pipe_6' }, 'crew_module.p5');
            this.createBranch('SubsystemOutput2_algae_module', { 'Pipe_7' }, 'Food_Storage.p1');
            this.createBranch('SubsystemOutput3_algae_module', { 'Pipe_8' }, 'Inedible_Biomass.p1');
            this.createBranch('SubsystemInput2_algae_module', { 'Pipe_9' }, 'NutrientTank.p1');
%             this.createBranch('SubsystemInput1_human_dummy', { 'Pipe_10' }, 'crew_module.p6');
%             this.createBranch('SubsystemInput2_human_dummy', { 'Pipe_11' }, 'Food_Storage.p2');
%             this.createBranch('SubsystemInput3_human_dummy', { 'Pipe_12' }, 'PotableWaterTank.p2');
%             this.createBranch('SubsystemOutput1_human_dummy', { 'Pipe_13' }, 'crew_module.p7');
%             this.createBranch('SubsystemOutput2_human_dummy', { 'Pipe_14' }, 'InedibleBiomassH2O.p1');
%             this.createBranch('SubsystemInput1_hydrogen_peroxid_production', { 'Pipe_15' }, 'crew_module.p8');
%             this.createBranch('SubsystemOutput1_hydrogen_peroxid_production', { 'Pipe_16' }, 'crew_module.p9');
%             this.createBranch('SubsystemInput2_hydrogen_peroxid_production', { 'Pipe_17' }, 'HygieneWaterTank.p1');
%             this.createBranch('SubsystemOutput2_hydrogen_peroxid_production', { 'Pipe_18' }, 'H2O2Tank.p1');
%             this.createBranch('SubsystemInput1_hygiene_water_management', { 'Pipe_19' }, 'InedibleBiomassH2O.p2');
%             this.createBranch('SubsystemOutput1_hygiene_water_management', { 'Pipe_20' }, 'Inedible_Biomass.p2');
%             this.createBranch('SubsystemOutput2_hygiene_water_management', { 'Pipe_21' }, 'HygieneWaterTank.p2');
%             this.createBranch('SubsystemInput1WasteManagement', { 'Pipe_22' }, 'Inedible_Biomass.p3');
%             this.createBranch('SubsystemInput2WasteManagement', { 'Pipe_23' }, 'H2O2Tank.p2');
%             this.createBranch('SubsystemOutput1WasteManagement', { 'Pipe_24' }, 'crew_module.p10');
%             this.createBranch('SubsystemOutput2WasteManagement', { 'Pipe_25' }, 'Deadlock.p1');
%             this.createBranch('SubsystemInput1PlantCultivation', { 'Pipe_26' }, 'crew_module.p13');
%             this.createBranch('SubsystemOutput1PlantCultivation', { 'Pipe_27' }, 'crew_module.p12');
%             this.createBranch('SubsystemInput2PlantCultivation', { 'Pipe_28' }, 'HygieneWaterTank.p3');
%             this.createBranch('SubsystemOutput2PlantCultivation', { 'Pipe_29' }, 'Food_Storage.p3');
%             this.createBranch('SubsystemOutput3PlantCultivation', { 'Pipe_30' }, 'InedibleBiomassH2O.p3');
%             oBranchWaterPump=this.createBranch('PotableWaterTank.p3', { 'Pipe_31' }, 'HygieneWaterTank.p4');
            
            % Now we need to connect the subsystem with the top level system (this one). This is
            % done by a method provided by the subsystem.
            %oSubSysColdplate.setIfFlows('SubsystemInput', 'SubsystemOutput','SubsystemOutput2');
            oSubSysAlgaeModule.setIfFlows('SubsystemInput1_algae_module', 'SubsystemOutput1_algae_module','SubsystemOutput2_algae_module','SubsystemOutput3_algae_module','SubsystemInput2_algae_module');
            %oSubSysHumanDummy.setIfFlows('SubsystemInput1_human_dummy','SubsystemOutput1_human_dummy','SubsystemInput3_human_dummy','SubsystemOutput2_human_dummy','SubsystemInput2_human_dummy');
            %oSubSysHydrogenPeroxidProduction.setIfFlows('SubsystemInput1_hydrogen_peroxid_production','SubsystemOutput1_hydrogen_peroxid_production','SubsystemInput2_hydrogen_peroxid_production','SubsystemOutput2_hydrogen_peroxid_production');
            %oSubSysHygieneWaterManagement.setIfFlows('SubsystemInput1_hygiene_water_management','SubsystemOutput1_hygiene_water_management','SubsystemOutput2_hygiene_water_management');
            %oSubSysWasteManagement.setIfFlows('SubsystemInput1WasteManagement','SubsystemInput2WasteManagement','SubsystemOutput1WasteManagement','SubsystemOutput2WasteManagement');
            %oSubSysPlantCultivation.setIfFlows('SubsystemInput1PlantCultivation','SubsystemOutput1PlantCultivation','SubsystemInput2PlantCultivation','SubsystemOutput2PlantCultivation','SubsystemOutput3PlantCultivation');
            
            
            % Seal - means no more additions of stores etc can be done to
            % this system.
            this.seal();
%             
%             this.oBranch4 = solver.matter.manual.branch(oBranch4);
%             this.oBranch4.setFlowRate(0);
%             this.oBranchWaterPump = solver.matter.manual.branch(oBranchWaterPump);
%             this.oBranchWaterPump.setFlowRate(0);
            
%            setting the fixed timesteps for the phases:
            aoPhases = this.toStores.crew_module.aoPhases;
            aoPhases(1).fFixedTS = 30;
            aoPhases = this.toStores.PotableWaterTank.aoPhases;
            aoPhases(1).fFixedTS = 30;
            aoPhases = this.toStores.Food_Storage.aoPhases;
            aoPhases(1).fFixedTS = 30;
            aoPhases = this.toStores.Inedible_Biomass.aoPhases;
            aoPhases(1).fFixedTS = 30;
            aoPhases = this.toStores.NutrientTank.aoPhases;
            aoPhases(1).fFixedTS = 30;
            aoPhases = this.toStores.Deadlock.aoPhases;
            aoPhases(1).fFixedTS = 30;
            aoPhases = this.toStores.Inedible_Biomass.aoPhases;
            aoPhases(1).fFixedTS = 30;
            aoPhases = this.toStores.InedibleBiomassH2O.aoPhases;
            aoPhases(1).fFixedTS = 30;
            aoPhases = this.toStores.HygieneWaterTank.aoPhases;
            aoPhases(1).fFixedTS = 30;
            aoPhases = this.toStores.N2_buffer_tank.aoPhases;
            aoPhases(1).fFixedTS = 30;
            aoPhases = this.toStores.H2O2Tank.aoPhases;
            aoPhases(1).fFixedTS = 30;
        end
    end
    
    methods (Access = protected)
        
        function exec(this, ~)
            % exec(ute) function for this system
            % Here it calls its parent's exec function
            exec@vsys(this);
            
%             if this.toStores.crew_module.aoPhases(1).fPressure >= 102700
%                 if this.fDeadlockControl ~= 1
%                     this.fDeadlockControl = 1;
%                     disp('Druck in Crew Module zu hoch, da Druck >= 1.027 e10^5 Pa, Druckablass nach Deadlock');
%                     
%                 end
%             elseif this.toStores.crew_module.aoPhases(1).fPressure <= 100000
%                 if this.fDeadlockControl ~= 0
%                     this.fDeadlockControl = 0;
%                     disp('Druckablass nach Deadlock aus, da Druck <= 1e10^5 Pa');
%                 end
%             end;
            
%             %%%%%%%%%%%%%%%%%%%%%%%%%
%             if this.toStores.PotableWaterTank.aoPhases(1).fMass <= 50;
%                 if this.fWaterPumpControl ~= 0
%                     this.fWaterPumpControl = 0;
%                     disp('H2O Pumpe AUS, da Potable Water Mass unter 50 kg (T_BIO_LSS_PotableWaterToHygieneWaterPump Fcn: controller)');
%                 end
%                 
%             else
%                 if this.toStores.HygieneWaterTank.aoPhases(1).fMass <= 20
%                     if this.fWaterPumpControl ~= 1
%                         this.fWaterPumpControl = 1;
%                         disp('H2O Pumpe EIN, da Hygiene Water Tank H2O Mass unter 20 kg(T_BIO_LSS_PotableWaterToHygieneWaterPump Fcn: controller)');
%                     end
%                 end
%             end
%             %%%%%%%%%%%%%%%%%%%%%%%%%%%
%             
%             if  this.toStores.N2_buffer_tank.aoPhases(1).fMass > 0.4
%                 if this.toStores.crew_module.aoPhases(1).fPressure >= 100000
%                     if this.n2_control ~= 0
%                         this.n2_control = 0;
%                         disp('Druckerh?hung durch N2 System aus, da Druck >= 1e10^5 Pa');
%                     end
%                 elseif this.toStores.crew_module.aoPhases(1).fPressure <= 95000
%                     if this.n2_control ~= 1
%                         this.n2_control = 1;
%                         disp('Druckerh?hung durch N2 System ein, da Druck <= 0.95e10^5 Pa');
%                         
%                     end
%                 end;
%             else
%                 this.n2_control = 0;
%                 disp('Druckerh?hung durch N2 System aus, da kein N2-Tank leer');
%                 
%             end;
%             % Zuweisung der flow rate f?r das N2 buffer System:
%             this.oBranch4.setFlowRate(this.n2_control*0.01);
%             this.oBranchWaterPump.setFlowRate(this.fWaterPumpControl*0.1);
        end
        
    end
    
end

