classdef PlantModule < vsys
    % Subsystem to reduce relative humidity of air
    
    properties
        
        fFlowRate;
        fControl=0;
        oInputBranch;
        oOutputBranch;
        oInputWater;
        oOutputInedibleBiomassH2O;
        oOutputFood;
        fFlowrateO2In;
        fFlowrateH2OIn;
        fH2O2NeedKgDay;
        oProc_Absorber_PlantCultivationStore_O2;
        oProc_Manip;
        fPlant;
        fPlantEng=load(strrep('components\+PlantModule\PlantEng.mat','\',filesep));
        fWaterAvailable;
        fCO2PartialPressure;
        fRelHumidity;
        fCrewModulePressure;
        fTick;
        oProc_Absorber_PlantCultivationStoreH2O;
        oProc_Absorber_PlantCultivationStoreO2;
        oProc_Absorber_PlantCultivationStoreCO2;
    end
    
    methods
        function this = PlantModule(oParent, sName)
            this@vsys(oParent, sName, 30);
            this.fControl=1;
            %where it all comes from:
            
            this.fPlant=components.PlantModule.PlantParameters();
            this.fWaterAvailable=this.oParent.toStores.HygieneWaterTank.aoPhases(1).fMass;
            if this.oParent.oParent.oData.oTimer.fTime>1
                this.fRelHumidity=this.oParent.toStores.crew_module.aoPhases(1).rRelHumidity;
                this.fCO2PartialPressure=this.oParent.toStores.crew_module.aoPhases(1).afPP(11);
                this.fCrewModulePressure=this.oParent.toStores.crew_module.aoPhases(1).fPressure;
                this.fTick=this.oParent.oParent.oData.oTimer.fTime;
            else
                this.fTick=this.oParent.oParent.oData.oTimer.fTime;
            end;
            
            this.fH2O2NeedKgDay = 11; %3.033; %kg/day %Paper
            %2.58 L/day DA S.226 = 3.741 kg/day
            %21.5 L/day ?
            this.fFlowrateH2OIn = (9/17)*(this.fH2O2NeedKgDay/3600); %kg/s
            this.fFlowrateO2In = 8/17*this.fH2O2NeedKgDay/3600;  %kg/s
            
            % Creating the filter, last parameter is the filter capacity in
            % kg.
            this.addStore(matter.store(this.oData.oMT, 'PlantCultivationStore', 2));
            
            %Adding Air Phase
            %oAerationPhase = this.toStores.PlantCultivationStore.createPhase('air', 1 ,293,0.5);
            oAerationPhase = matter.phases.gas(this.toStores.PlantCultivationStore, ...
                'air', ... Phase name
                struct('O2',21.49/80*2,'N2',70.35/80*2,'CO2',0.09/80*2), ... Phase contents - set by helper
                2, ... Phase volume
                293.15);
            % creating exmes:
            matter.procs.exmes.gas(oAerationPhase,  'p1');
            matter.procs.exmes.gas(oAerationPhase,  'p2');
            matter.procs.exmes.gas(oAerationPhase,  'p3');
            matter.procs.exmes.gas(oAerationPhase,  'p9');
            matter.procs.exmes.gas(oAerationPhase,  'p11');
            
            
            %Adding Plants:
            oPlants = matter.phases.liquid(this.toStores.PlantCultivationStore, ...   Store in which the phase is located
                'Plants', ...         Phase name
                struct('H2O', 0.01,'CO2', 0.001,'O2', 0.001), ...      Phase contents
                10, ...                 Phase volume
                293.15, ...             Phase temperature
                101325);              % Phase pressure
            
            % Adding a default extract/merge processor to the phase
            matter.procs.exmes.liquid(oPlants, 'p4');
            matter.procs.exmes.liquid(oPlants, 'p5');
            matter.procs.exmes.liquid(oPlants, 'p6');
            matter.procs.exmes.liquid(oPlants, 'p7');
            matter.procs.exmes.liquid(oPlants, 'p8');
            matter.procs.exmes.liquid(oPlants, 'p10');
            
            %adding p2p processors
            this.oProc_Manip = components.PlantModule.PlantReactor('PlantReactor', oPlants, this.fPlantEng, this.fPlant,this.fWaterAvailable,this.fRelHumidity,this.fCO2PartialPressure,this.fCrewModulePressure,this.fTick);
            this.oProc_Absorber_PlantCultivationStoreH2O = components.PlantModule.AbsorberPlantCultivationAir(this.toStores.PlantCultivationStore, 'filterproc', 'Plants.p4','air.p3','H2O');
            this.oProc_Absorber_PlantCultivationStoreO2 = components.PlantModule.AbsorberPlantCultivationAirO2(this.toStores.PlantCultivationStore, 'filterproc2', 'Plants.p8','air.p9','O2');
            this.oProc_Absorber_PlantCultivationStoreCO2 = components.PlantModule.AbsorberPlantCultivationAirCO2(this.toStores.PlantCultivationStore, 'filterproc3','air.p11', 'Plants.p10','CO2');
            
            
            % Adding pipes to connect the components
            this.addProcF2F(components.PlantModule.Pipe1(this.oData.oMT, 'Pipe_1', 0.5, 0.01));
            this.addProcF2F(components.PlantModule.Pipe1(this.oData.oMT, 'Pipe_2', 0.5, 0.01));
            this.addProcF2F(components.PlantModule.Pipe1(this.oData.oMT, 'Pipe_3', 0.5, 0.01));
            this.addProcF2F(components.PlantModule.Pipe1(this.oData.oMT, 'Pipe_4', 0.5, 0.01));
            this.addProcF2F(components.PlantModule.Pipe1(this.oData.oMT, 'Pipe_5', 0.5, 0.01));
            
            
            % Creating the flowpath (=branch) between the components
            oInputBranch = this.createBranch('PlantCultivationStore.p1',  { 'Pipe_1' }, 'InputAir');
            oOutputBranch = this.createBranch('PlantCultivationStore.p2',  { 'Pipe_2' }, 'OutputAir');
            oInputWater = this.createBranch('PlantCultivationStore.p5',  { 'Pipe_3' }, 'InputWater');
            oOutputFood = this.createBranch('PlantCultivationStore.p6',  { 'Pipe_4' }, 'OutputFood');
            oOutputInedibleBiomassH2O = this.createBranch('PlantCultivationStore.p7',  { 'Pipe_5' }, 'OutputInedibleBiomassH2O');
            
            
            
            
            
            % Seal - means no more additions of stores etc can be done to
            % this system.
            this.seal();
            
            
            
            % adding the branches to the solver
            this.oInputBranch = solver.matter.manual.branch(oInputBranch);
            this.oOutputBranch = solver.matter.manual.branch(oOutputBranch);
            this.oInputWater = solver.matter.manual.branch(oInputWater);
            this.oOutputFood = solver.matter.manual.branch(oOutputFood);
            this.oOutputInedibleBiomassH2O = solver.matter.manual.branch(oOutputInedibleBiomassH2O);
            
            %             this.oBranch.setFlowRate(-this.fFlowRate);
            %             this.oBranch2.setFlowRate(this.fFlowRate-this.toStores.water_absorber.oProc.fFlowRate);
            %             this.oBranch3.setFlowRate(this.toStores.water_absorber.oProc.fFlowRate);% Setting the flow rate
            
            %setting fixed timestep
            aoPhases = this.toStores.PlantCultivationStore.aoPhases;
            aoPhases(1).fFixedTS = 15;
            aoPhases(2).fFixedTS = 15;
            
            %Setting the flow rates:
            this.toStores.PlantCultivationStore.aoPhases(2).setPressure(101325);
            %this.toStores.PlantCultivationStore.aoPhases(2).setTemperature(293);
            
            this.oInputBranch.setFlowRate(0);
            this.oOutputBranch.setFlowRate(0);
            this.oInputWater.setFlowRate(0);
            this.oOutputFood.setFlowRate(0);
            this.oOutputInedibleBiomassH2O.setFlowRate(0);
        end
        
        function setIfFlows(this, sInlet, sOutlet, sInlet2, sOutlet2, sOutlet3)
            % This function connects the system and subsystem level branches with each other. It
            % uses the connectIF function provided by the matter.container class
            this.connectIF('InputAir',sInlet);
            this.connectIF('OutputAir', sOutlet);
            this.connectIF('InputWater', sInlet2);
            this.connectIF('OutputFood', sOutlet2);
            this.connectIF('OutputInedibleBiomassH2O', sOutlet3);
            
            
        end
    end
    
    methods (Access = protected)
        
        function exec(this, ~)
            % exec(ute) function for this system
            % Here it calls its parent's exec function
            exec@vsys(this);
            % Since we've added the branch between the two tanks to the manual solver inside of this
            % vsys-object, we can access its setFlowRate method to manually set and change the flow
            % rate of the branch. Here we change between two flow rate every 100 seconds.
            this.fWaterAvailable=this.oParent.toStores.HygieneWaterTank.aoPhases(1).fMass;
            if this.oParent.oParent.oData.oTimer.fTime>1
                this.fRelHumidity=this.oParent.toStores.crew_module.aoPhases(1).rRelHumidity;
                this.fCO2PartialPressure=this.oParent.toStores.crew_module.aoPhases(1).afPP(11);
                this.fCrewModulePressure=this.oParent.toStores.crew_module.aoPhases(1).fPressure;
                this.fTick=this.oParent.oParent.oData.oTimer.fTime;
            else
                this.fTick=this.oParent.oParent.oData.oTimer.fTime;
            end;
            %?bergabe an den oProc_Manip:
            this.oProc_Manip.fCO2PartialPressure=this.fCO2PartialPressure;
            this.oProc_Manip.fTick= this.fTick/60; %weitergabe tick; 1tick entspricht 1h
            this.oProc_Manip.fWaterAvailable= this.fWaterAvailable;
            this.oProc_Manip.fRelHumidity= this.fRelHumidity;
            this.oProc_Manip.fCrewModulePressure= this.fCrewModulePressure;
            
            this.oProc_Absorber_PlantCultivationStoreH2O.fwater_exchange= this.oProc_Manip.fwater_exchange;
            this.oProc_Absorber_PlantCultivationStoreCO2.fCO2_exchange= this.oProc_Manip.fCO2_exchange;
            this.oProc_Absorber_PlantCultivationStoreO2.fO2_exchange= this.oProc_Manip.fO2_exchange;
            
            
            this.oInputBranch.setFlowRate(-0.01);
            this.oOutputBranch.setFlowRate(0.01+this.oProc_Absorber_PlantCultivationStoreH2O.fFlowRate+this.oProc_Absorber_PlantCultivationStoreO2.fFlowRate-this.oProc_Absorber_PlantCultivationStoreCO2.fFlowRate);
            this.oInputWater.setFlowRate(-this.oProc_Manip.fWaterNeed);
            this.oOutputFood.setFlowRate(0);
            this.oOutputInedibleBiomassH2O.setFlowRate(0);
            
            % humidity fController:
            %             if this.oParent.toStores.crew_module.aoPhases(1).rRelHumidity <= 0.98
            %                 if this.fControl ~= 0
            %                     this.fControl = 0;
            %                     disp('Coldplate AUS, da Wasserdampf gering');
            %                 end
            %             elseif this.oParent.toStores.crew_module.aoPhases(1).rRelHumidity >= 0.99
            %                 if this.fControl ~= 1
            %                     this.fControl = 1;
            %                     disp('Coldplate EIN, da Wasserdampf hoch ');
            %
            %                 end
            %             end;
            %             if this.oParent.toStores.HygieneWaterTank.aoPhases(1).fMass < 0.1 || this.oParent.toStores.crew_module.aoPhases(1).afMass(7) < 0.1
            %                 if this.fControl ~= 0
            %                     this.fControl = 0;
            %
            %                     disp('H2O2 Production AUS, da Luft oder Wasser aus (T_BIO_LSS_Production Fcn: fController)');
            %                 end
            %             else
            %
            %                 if this.oParent.toStores.H2O2Tank.aoPhases(1).fMass< 0.5%kg
            %                     if this.fControl ~= 1
            %                         this.fControl = 1;
            %                         disp('H2O2 Production EIN, da zu wenig H2O2 (T_BIO_LSS_Production Fcn: fController)');
            %
            %                     end
            %                 elseif this.oParent.toStores.H2O2Tank.aoPhases(1).fMass > 11.5
            %                     if this.fControl ~= 0
            %                         this.fControl = 0;
            %                         disp('H2O2 Production AUS, da genug H2O2 (T_BIO_LSS_Production Fcn: fController)');
            %
            %                     end
            %                 end
            %             end
            
            
            
        end
        
    end
    
end

