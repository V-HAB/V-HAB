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
            
            
            %algae_module:
            modules.AlgaeModule(this, 'SubSystemAlgaeModule');
        end
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
 
            % Creating the crew_module store, volume 80m^3
            matter.store(this, 'crew_module', 8*700);
            
            % Creating the phase for the crew module using the 'air' helper
            %oCrew_Module_Air = this.toStores.crew_module.createPhase('air', 80,293,0);
           oCrew_Module_Air = matter.phases.gas(this.toStores.crew_module, ...
                'air', ... Phase name
                struct('O2',8*21.49/8*700,'N2',8*70.35/8*700,'CO2',8*0.09/8*700), ... Phase contents - set by helper
                8*7000, ... Phase volume
                293.15);
            
            % Adding extract/merge processors to the phase
%             matter.procs.exmes.gas(oCrew_Module_Air, 'p1');
%             matter.procs.exmes.gas(oCrew_Module_Air, 'p2');
%             matter.procs.exmes.gas(oCrew_Module_Air, 'p3');
            matter.procs.exmes.gas(oCrew_Module_Air, 'p4');
            matter.procs.exmes.gas(oCrew_Module_Air, 'p5');
%             matter.procs.exmes.gas(oCrew_Module_Air, 'p6');
%             matter.procs.exmes.gas(oCrew_Module_Air, 'p7');
%             matter.procs.exmes.gas(oCrew_Module_Air, 'p8');
%             matter.procs.exmes.gas(oCrew_Module_Air, 'p9');
%             matter.procs.exmes.gas(oCrew_Module_Air, 'p10');
%             matter.procs.exmes.gas(oCrew_Module_Air, 'p11');
%             matter.procs.exmes.gas(oCrew_Module_Air, 'p12');
%             matter.procs.exmes.gas(oCrew_Module_Air, 'p13');
            
            %creating the Nutrient Tank; volume 30m?
            matter.store(this, 'NutrientTank', 30);
            
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
            matter.store(this, 'Inedible_Biomass', 30);
            oInedibleBiomass = matter.phases.liquid(this.toStores.Inedible_Biomass, ...
                'Inedible_Biomass_Phase', ... Phase name
                struct('Waste',0.001), ...    Phase contents - set by helper
                10, ...                       Phase volume
                293.15, ...                   Phase temperature
                101325);                    % Phase pressure
            
            % Adding a default extract/merge processor to the phase
            matter.procs.exmes.liquid(oInedibleBiomass, 'p1');
            
            
            % Creating the Food_Storage Store
            matter.store(this, 'Food_Storage', 30);
            oFoodStorage = matter.phases.liquid(this.toStores.Food_Storage, ...
                'Food', ... Phase name
                struct('Food',0.001), ... Phase contents - set by helper
                10, ... Phase volume
                293.15, ...             Phase temperature
                101325);              % Phase pressure
            
            % Adding a default extract/merge processor to the phase
            matter.procs.exmes.liquid(oFoodStorage,'p1');
            
            % Adding pipes to connect the components
            components.pipe(this, 'Pipe_1', 0.5, 0.005);
            components.pipe(this, 'Pipe_2', 0.5, 0.005);
            components.pipe(this, 'Pipe_3', 0.5, 0.005);
            components.pipe(this, 'Pipe_4', 0.5, 0.005);
            components.pipe(this, 'Pipe_5', 0.5, 0.005);
            components.pipe(this, 'Pipe_6', 0.5, 0.005);
            components.pipe(this, 'Pipe_7', 0.5, 0.005);
            components.pipe(this, 'Pipe_8', 0.5, 0.005);
            components.pipe(this, 'Pipe_9', 0.5, 0.005);
            components.pipe(this, 'Pipe_10', 0.5, 0.005);
            components.pipe(this, 'Pipe_11', 0.5, 0.005);
            components.pipe(this, 'Pipe_12', 0.5, 0.005);
            components.pipe(this, 'Pipe_13', 0.5, 0.005);
            components.pipe(this, 'Pipe_14', 0.5, 0.005);
            components.pipe(this, 'Pipe_15', 0.5, 0.005);
            components.pipe(this, 'Pipe_16', 0.5, 0.005);
            components.pipe(this, 'Pipe_17', 0.5, 0.005);
            components.pipe(this, 'Pipe_18', 0.5, 0.005);
            components.pipe(this, 'Pipe_19', 0.5, 0.005);
            components.pipe(this, 'Pipe_20', 0.5, 0.005);
            components.pipe(this, 'Pipe_21', 0.5, 0.005);
            components.pipe(this, 'Pipe_22', 0.5, 0.005);
            components.pipe(this, 'Pipe_23', 0.5, 0.005);
            components.pipe(this, 'Pipe_24', 0.5, 0.005);
            components.pipe(this, 'Pipe_25', 0.5, 0.005);
            components.pipe(this, 'Pipe_26', 0.5, 0.005);
            components.pipe(this, 'Pipe_27', 0.5, 0.005);
            components.pipe(this, 'Pipe_28', 0.5, 0.005);
            components.pipe(this, 'Pipe_29', 0.5, 0.005);
            components.pipe(this, 'Pipe_30', 0.5, 0.005);
            components.pipe(this, 'Pipe_31', 0.5, 0.005);
            
            % creating the branches
            matter.branch(this, 'SubsystemInput1_algae_module', { 'Pipe_5' }, 'crew_module.p4');
            matter.branch(this, 'SubsystemOutput1_algae_module', { 'Pipe_6' }, 'crew_module.p5');
            matter.branch(this, 'SubsystemOutput2_algae_module', { 'Pipe_7' }, 'Food_Storage.p1');
            matter.branch(this, 'SubsystemOutput3_algae_module', { 'Pipe_8' }, 'Inedible_Biomass.p1');
            matter.branch(this, 'SubsystemInput2_algae_module', { 'Pipe_9' }, 'NutrientTank.p1');
            
            this.toChildren.SubSystemAlgaeModule.setIfFlows('SubsystemInput1_algae_module', 'SubsystemOutput1_algae_module','SubsystemOutput2_algae_module','SubsystemOutput3_algae_module','SubsystemInput2_algae_module');
            
            
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
%             this.oBranch4 = solver.matter.manual.branch(oBranch4);
%             this.oBranch4.setFlowRate(0);
%             this.oBranchWaterPump = solver.matter.manual.branch(oBranchWaterPump);
%             this.oBranchWaterPump.setFlowRate(0);
            
%            setting the fixed timesteps for the phases:

            tTimeStepProperties.fFixedTimeStep = 15;
            
            this.toStores.crew_module.aoPhases(1).setTimeStepProperties(tTimeStepProperties);
            this.toStores.Food_Storage.aoPhases(1).setTimeStepProperties(tTimeStepProperties);
            this.toStores.Inedible_Biomass.aoPhases(1).setTimeStepProperties(tTimeStepProperties);
            this.toStores.NutrientTank.aoPhases(1).setTimeStepProperties(tTimeStepProperties);
            
            this.setThermalSolvers();
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

