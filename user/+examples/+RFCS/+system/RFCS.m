classdef RFCS < vsys
    
    properties
        % array which contains the available solar power
        afPower;
        
        fSolarPanelArea         = 50; %m^2 solarpanele
        rSolarpanelEfficiency   = 0.12;
        
        obranch_hxE;
        obranch_hxF;
        fI_Fuelcell=0;
        fPower=0;
        fuelcell_on;
        electrolyseur_on;
        oRadiator;
        obranch_radiator;
        zyklen=0;
        n
        fPressureMax=300*10^5;
        deltaT=0;
        payload=350;
    end
    
    methods
        function this = RFCS(oParent, sName, fSolarPanelArea, rSolarpanelEfficiency)
            
            this@vsys(oParent, sName,30);
            eval(this.oRoot.oCfgParams.configCode(this));
            
            if nargin > 2
                this.fSolarPanelArea        = fSolarPanelArea;
            end
            if nargin > 3
                this.rSolarpanelEfficiency  = rSolarpanelEfficiency;
            end
            
            this.afPower = this.rEta_solarpanel * this.n_solarpanels * xlsread('user\+examples\+RFCS\+helper\HAPS Available Solar Power.xlsx','C140:C427');%sonnenphase
            
            components.matter.Electrolyzer.Electrolyzer(this, 'Electrolyzer');
            components.matter.FuelCell.FuelCell(this, 'FuelCell');
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            %stores and phases
            % water tank
            
            fInitialTemperature = 293;
            
            matter.store(this, 'Water_Tank', 0.1);
            oWater      = this.toStores.Water_Tank.createPhase(  'liquid',      'Water',   0.1, struct('H2O', 1),  fInitialTemperature, 1e5);
            
            matter.store(this, 'CoolingSystem', 0.1);
            oCooling    = this.toStores.CoolingSystem.createPhase('liquid',     'CoolingWater',  0.1, struct('H2O', 1),  fInitialTemperature, 1e5);
            
            matter.store(this, 'H2_Tank', 0.05*2);
            oH2         = this.toStores.H2_Tank.createPhase(  'gas', 'H2',   0.05*2, struct('H2', 1e5),  fInitialTemperature, 0.8);
            
            matter.store(this, 'O2_Tank', 0.0253*2);
            oO2         = this.toStores.O2_Tank.createPhase(  'gas', 'O2',   0.0253*2, struct('O2', 1e5),  fInitialTemperature, 0.8);
            
            %conection store cooling
            matter.store(this, 'cooling_conection1', 0,1);
            oc1=matter.phases.liquid(this.toStores.cooling_conection1, 'water_c1', struct('H2O',0.1), 0.01, 330,101300);
            
            matter.store(this, 'cooling_conection2', 0,1);
            oc2=matter.phases.liquid(this.toStores.cooling_conection2, 'water_c2', struct('H2O',0.1), 0.01, 330,101300);
            
            %cooling store
            matter.store(this, 'Cooling_Store1', 0,1);
            cooling_phase1=matter.phases.liquid(this.toStores.Cooling_Store1, 'cooling_phase1', struct('H2O',0.5), 0.01, 275,101300);
            
            matter.store(this, 'Cooling_Store2', 0,1);
            cooling_phase2=matter.phases.liquid(this.toStores.Cooling_Store2, 'cooling_phase2', struct('H2O',0.5), 0.01, 275,101300);
            
            matter.store(this, 'Cooling_Store3', 0,1);
            cooling_phase3=matter.phases.liquid(this.toStores.Cooling_Store3, 'cooling_phase3', struct('H2O',0.5), 0.01, 275,101300);
            
            %humidifier store
            matter.store(this, 'H2_Humidifier', 0.18);
            oHumidifier1_Phase=matter.phases.gas(this.toStores.H2_Humidifier, 'H2_H2O', struct('H2O',0.02,'H2',0.019*1.9),1, 273+20);
            
            matter.store(this, 'O2_Humidifier', 0.18);
            oHumidifier2_Phase=matter.phases.gas(this.toStores.O2_Humidifier, 'O2_H2O', struct('H2O',0.02,'O2',0.3*1.9),1, 273+20);
            
            %EXME
            %water tanke
            matter.procs.exmes.liquid(oWater_Phase, 'H2O_Port_in');
            matter.procs.exmes.liquid(oWater_Phase, 'H2O_Port_out');
            %Gastanks
            matter.procs.exmes.gas(oH2_Phase, 'H2_Port_in');
            examples.RFCS.components.reducer_exme(oH2_Phase, 'H2_Port_out', 200000);
            
            matter.procs.exmes.gas(oO2_Phase, 'O2_Port_in');
            examples.RFCS.components.reducer_exme(oO2_Phase, 'O2_Port_out', 200000);
            
            %cooling connection
            matter.procs.exmes.liquid(oc1, 'C1_Port_1');
            matter.procs.exmes.liquid(oc2, 'C2_Port_1');
            matter.procs.exmes.liquid(oc1, 'C1_Port_2');
            matter.procs.exmes.liquid(oc2, 'C2_Port_2');
            
            %cooling store
            matter.procs.exmes.liquid(cooling_phase1, 'Cool_Port_11');
            matter.procs.exmes.liquid(cooling_phase1, 'Cool_Port_12');
            matter.procs.exmes.liquid(cooling_phase2, 'Cool_Port_21');
            matter.procs.exmes.liquid(cooling_phase2, 'Cool_Port_22');
            matter.procs.exmes.liquid(cooling_phase3, 'Cool_Port_31');
            matter.procs.exmes.liquid(cooling_phase3, 'Cool_Port_32');
            
            matter.procs.exmes.gas(oHumidifier1_Phase, 'H1_Port_1');
            matter.procs.exmes.gas(oHumidifier1_Phase, 'H1_Port_2');
            matter.procs.exmes.gas(oHumidifier1_Phase, 'H1_Port_3');
            
            
            matter.procs.exmes.gas(oHumidifier2_Phase, 'H2_Port_1');
            matter.procs.exmes.gas(oHumidifier2_Phase, 'H2_Port_2');
            matter.procs.exmes.gas(oHumidifier2_Phase, 'H2_Port_3');
            
            
            
            
            
            %f2f components
            components.pipe(this, 'Pipe11', 1, 0.01);
            components.pipe(this, 'Pipe12', 1, 0.01);
            
            
            
            %fan to press H2 and O2 in the high pressure tanks
            examples.RFCS.components.compressor(this, 'H2_Compressor',0, 'Left2Right',this.toChildren.Subsystem_Electrolyseur.toStores.Chanal.toPhases.H2,oH2_Phase,1.3*10^5);
            examples.RFCS.components.compressor(this, 'O2_Compressor',0, 'Left2Right',this.toChildren.Subsystem_Electrolyseur.toStores.Chanal.toPhases.O2,oO2_Phase,1.3*10^5);
            
            
            components.pipe(this, 'Pipe21', 3, 0.002);
            components.pipe(this, 'Pipe22', 3, 0.002);
            components.pipe(this, 'Pipe23', 2, 0.003);
            components.pipe(this, 'Pipe24', 2, 0.003);
            
            examples.RFCS.components.compressor_manuell(this, 'Compressor1',2, 'Left2Right',this.toChildren.Subsystem_Fuelcell.toStores.gaschanal_in_h2.toPhases.fuel,oHumidifier1_Phase,1.98^10^5);
            
            components.pipe(this, 'Pipe31', 1, 0.008); %humidifier
            components.pipe(this, 'Pipe32', 1, 0.008); %humidifier
            
            examples.RFCS.components.compressor_manuell(this, 'Compressor2',2 ,'Left2Right',this.toChildren.Subsystem_Fuelcell.toStores.gaschanal_in_o2.toPhases.O2_H2O,oHumidifier2_Phase,1.98*10^5);
            
            components.pipe(this, 'Pipe41', 1, 0.008); %humidifier
            components.pipe(this, 'Pipe42', 1, 0.008); %humidifier
            
            components.pipe(this, 'Pipe43', 2, 0.005);
            components.pipe(this, 'Pipe44', 2, 0.008);
            components.pipe(this, 'Pipe45', 2, 0.005);
            components.pipe(this, 'Pipe46', 2, 0.008);
            
            %heat exchancher
            
            % Some configurating variables
            sHX_type = 'counter plate';       % Heat exchanger type
            Geometry = [20, 0.3, (0.19/2), 0.25, 0.1];   % Geometry [area,height1 heigth2, length, thickness]
            % --> see the HX file for information on the inputs for the different HX types
            Conductivity = 230;                          % Conductivity of the Heat exchanger solid material
            %aluminium 230W/K/m
            %defines the heat exchanged object using the previously created properties
            
            components.HX(this, 'HeatExchanger_Fuelcell', Geometry, sHX_type, Conductivity);
            components.HX(this, 'HeatExchanger_Electrolyseur', Geometry, sHX_type, Conductivity);
            
            
            components.pipe(this, 'Pipe51', 1, 0.005);
            components.pipe(this, 'Pipe52', 1, 0.005);
            components.pipe(this, 'Pipe61', 1, 0.005);
            components.pipe(this, 'Pipe62', 1, 0.005);
            
            components.pipe(this, 'Pipe7', 1, 0.005);
            components.pipe(this, 'Pipe8', 1, 0.008);
            
            
            %valves
            components.valve(this,'Valve_H2',0,2);
            components.valve(this,'Valve_O2',0,2);
            
            components.valve(this,'Valve_1',0,2);
            components.valve(this,'Valve_2',0,2);
            
            %radiator area= 3.5m^2
            this.oRadiator =examples.RFCS.components.radiator(this, 'Radiator',3.5);
            
            %Branches
            
            %CONNECTION ELECTROLYSEUR
            
            %INPUT electrolyseur
            
            matter.branch(this, 'SubsystemInput', {'Pipe11'}, 'Water_Tank.H2O_Port_out');%no_solver
            
            %OUTPUT  electrolyseur
            matter.branch(this, 'SubsystemOutput_H2', {}, 'H2_Tank.H2_Port_in');%no_solver 'Pipe21','H2_Compressor','Pipe22'
            matter.branch(this, 'SubsystemOutput_O2', {}, 'O2_Tank.O2_Port_in');%no_solver  'Pipe23','O2_Compressor','Pipe24'
            
            %cooling circle electrolyseur
            matter.branch(this, 'Cooling_input', {}, 'cooling_conection1.C1_Port_2');%no_solver
            matter.branch(this, 'Cooling_output', {'HeatExchanger_Electrolyseur_1'}, 'cooling_conection1.C1_Port_1');%no_solver
            
            %CONNECTION FUELCELL
            
            %cooling circle fuelcell
            matter.branch(this, 'Cell_cooling_input', {}, 'cooling_conection2.C2_Port_2');%no_solver
            matter.branch(this, 'Cell_cooling_output', {'Pipe51','HeatExchanger_Fuelcell_1','Pipe52'}, 'cooling_conection2.C2_Port_1');%no_solver
            
            %waterooutput fuelcell
            matter.branch(this, 'H2O_output', {}, 'Water_Tank.H2O_Port_in');%no_solver
            %input fuelcell
            matter.branch(this, 'H2_input', {'Pipe7'}, 'H2_Humidifier.H1_Port_3');%no_solver
            matter.branch(this, 'O2_input', {'Pipe8'}, 'O2_Humidifier.H2_Port_3');%no_solver
            %output fuelcell
            matter.branch(this, 'H2_output', {'Pipe31','Compressor1','Pipe32'}, 'H2_Humidifier.H1_Port_2');%no_solver
            matter.branch(this, 'O2_output', {'Pipe41','Compressor2','Pipe42'}, 'O2_Humidifier.H2_Port_2');%no_solver
            %input humidifier
            matter.branch(this, 'H2_Tank.H2_Port_out', {'Pipe43','Valve_H2'}, 'H2_Humidifier.H1_Port_1');
            matter.branch(this, 'O2_Tank.O2_Port_out', {'Pipe44','Valve_O2'}, 'O2_Humidifier.H2_Port_1');
            
            %COOLING MAIN SYSTEM
            
            matter.branch(this, 'Cooling_Store1.Cool_Port_12', {'Pipe61','HeatExchanger_Electrolyseur_2','Pipe62'}, 'Cooling_Store2.Cool_Port_21');
            matter.branch(this, 'Cooling_Store2.Cool_Port_22', {'Radiator'}, 'Cooling_Store3.Cool_Port_31');
            matter.branch(this, 'Cooling_Store3.Cool_Port_32', {'HeatExchanger_Fuelcell_2'}, 'Cooling_Store1.Cool_Port_11');
            
            
            %setIfFlows
            
            %connect electrolyseur subsystem
            this.toChildren.Subsystem_Electrolyseur.setIfFlows('SubsystemInput', 'SubsystemOutput_H2','SubsystemOutput_O2','Cooling_input','Cooling_output');
            
            %connect fuelcell subsystem
            this.toChildren.Subsystem_Fuelcell.setIfFlows('H2_input','O2_input','H2_output','O2_output','H2O_output','Cell_cooling_input', 'Cell_cooling_output');
            
            
            
        end
        
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            solver.matter.iterative.branch(this.aoBranches(1));
            solver.matter.iterative.branch(this.aoBranches(2));
            
            this.obranch_hxE=solver.matter.manual.branch(this.aoBranches(3));
            this.obranch_radiator=solver.matter.manual.branch(this.aoBranches(4));
            this.obranch_hxF=solver.matter.manual.branch(this.aoBranches(5));
            
            
        end
        
        
    end
    
    methods (Access = protected)
        
        function exec(this, ~)
            
            
            exec@vsys(this);
            %second circle heat exchanger
            
            %this is the solar avaliable Solarpower read from a excel sheet
            %minus the required power for the pay load, you get the power
            %supply for the electrolyseur
            P_el=this.afPower(round(this.oTimer.fTime/(60*5))+1)-this.payload; %afPower changes every 5min
            %the whole solar power
            P_solar=this.afPower(round(this.oTimer.fTime/(60*5))+1);
            % P_el=0;
            % P_solar=0;
            
            if P_el>0
                this.toChildren.Subsystem_Electrolyseur.fPower=P_el;
                this.toChildren.Subsystem_Fuelcell.fI=0;
                this.deltaT=this.toChildren.Subsystem_Electrolyseur.toStores.membrane.toPhases.water.fTemperature-(273+65);
            else
                this.toChildren.Subsystem_Electrolyseur.fPower=0;
            end
            
            %control logic P-controller
            k=0.1;
            if this.deltaT<0 %deltaT is the difference between the current temperatur
                %and the goal process temperature (65°C)of fuelcell an electrolyseur
                this.deltaT=0;
            end
            %this branch goes throw the 2 heat exchangers and the radiator
            this.obranch_hxF.setFlowRate(this.deltaT*k);
            this.obranch_radiator.setFlowRate(this.deltaT*k);
            this.obranch_hxE.setFlowRate(this.deltaT*k);
            
            
            
            %             oValve3=this.toProcsF2F.Valve_1;
            %             oValve4=this.toProcsF2F.Valve_2;
            %             oValve3.bValveOpen=0;  %stayes closed for elec test
            %              oValve4.bValveOpen=0;
            %
            %
            
            
            oValve1=this.toProcsF2F.Valve_H2;
            oValve2=this.toProcsF2F.Valve_O2;
            
            oValve1.bValveOpen=0;  %stayes closed for elec test
            oValve2.bValveOpen=0;
            
            
            
            %when there is less avaliable Power (max=3500)
            %start to supply the fuelcell with fresh gas
            if P_solar<400
                
                oValve1.bValveOpen=1;
                oValve2.bValveOpen=1;
            end
            
            if P_solar<200
                
                %start the fuel cell
                this.toChildren.Subsystem_Fuelcell.fI=20;
                %fuelcell is active so its temperature is important to
                %calculate the deltaT
                this.deltaT=this.toChildren.Subsystem_Fuelcell.toStores.membrane.toPhases.H2O_react.fTemperature-(273+65);
                
            end
            
            %test of the capacity of the cooling system
            
            %             if this.oTimer.fTime>400
            %              this.toChildren.Subsystem_Fuelcell.fI=464;
            %                this.deltaT=this.toChildren.Subsystem_Fuelcell.toStores.membrane.toPhases.H2O_react.fTemperature-(273+65);
            %
            %             end
            %
            %             if this.oTimer.fTime>60*60-400
            %              this.toChildren.Subsystem_Fuelcell.fI=0;
            %                this.deltaT=this.toChildren.Subsystem_Fuelcell.toStores.membrane.toPhases.H2O_react.fTemperature-(273+65);
            %
            %             end
            
            
            
            
            
            
        end
        
    end
    
end

