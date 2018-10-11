classdef Example < vsys
    %   The testloop consists of one tank which simulates the
    %   volume of the space suit. Two tanks with CO2 and H2O supply the
    %   distributer with gas to simulate the metabolic consumption of a crew
    %   member. Another O2 tank is added that compansates the mass that is
    %   lost to the loop through the filter process in the RCA filter beds.
    
    properties
        toManualBranches = struct();
        
        fPipeLength   = 0.5;
        fPipeDiameter = 0.0254/2;
    end
    
    methods
        function this = Example(oParent, sName)
            this@vsys(oParent, sName);
            
            % Instatiating the RCA
            components.RCA(this, 'RCA', 'N2Atmosphere');
            
        end
        
        function createMatterStructure(this)
            
            fInitialTemperature = 298.65;
            
            createMatterStructure@vsys(this);
            %% Building Test Loop
            % Creating a store simulating the gaseous part of the space suit
            % Influence of residence mass can/should be analyzed in a future work
            matter.store(this, 'SpaceSuit', 0.015);
            cAirHelper = matter.helper.phase.create.N2Atmosphere(this.toStores.SpaceSuit, 0.015, fInitialTemperature);
            oAir = matter.phases.gas_flow_node(this.toStores.SpaceSuit, 'N2Atmosphere',  cAirHelper{1}, cAirHelper{2}, cAirHelper{3});
            
            special.matter.const_press_exme(oAir, 'Out', 28900);
            special.matter.const_press_exme(oAir, 'In', 28300);
            matter.procs.exmes.gas(oAir, 'H2OInlet');
            matter.procs.exmes.gas(oAir, 'CO2Inlet');
            matter.procs.exmes.gas(oAir, 'N2Inlet');
            
            % Creating a H2O store to simulate metabolic rates
            matter.store(this, 'H2OStore', 10);
            % Add Phase: gas(oStore, sName, tfMasses, fVolume, fTemp)
            oH2OGas = matter.phases.gas(this.toStores.H2OStore, 'H2OGas', struct('H2O', 1), 10, fInitialTemperature);
            matter.procs.exmes.gas(oH2OGas, 'H2OPort');
            
            % Creating a CO2 store to simulate metabolic rates
            matter.store(this, 'CO2Store', 10);
            % Add Phase: gas(oStore, sName, tfMasses, fVolume, fTemp)
            oCO2Gas = matter.phases.gas(this.toStores.CO2Store, 'CO2Gas', struct('CO2', 1), 10, fInitialTemperature);
            matter.procs.exmes.gas(oCO2Gas, 'CO2Port');
                        
            % Creating a N2 store
            matter.store(this, 'N2Store', 10);
            oN2Gas = matter.phases.gas(this.toStores.N2Store, 'N2Gas', struct('N2', 1), 10, fInitialTemperature);
            matter.procs.exmes.gas(oN2Gas, 'N2Port');
            
            % Adding pipes to connect the stores
            components.pipe(this, 'Pipe_H2O', 1.0, 0.01, 0.0002);
            components.pipe(this, 'Pipe_CO2', 1.0, 0.01, 0.0002);
            components.pipe(this, 'Pipe_N2', 1.0, 0.01, 0.0002);
            
            % Creating branches
            matter.branch(this, 'H2OStore.H2OPort', {'Pipe_H2O'}, 'SpaceSuit.H2OInlet');
            matter.branch(this, 'CO2Store.CO2Port', {'Pipe_CO2'}, 'SpaceSuit.CO2Inlet');
            matter.branch(this, 'N2Store.N2Port', {'Pipe_N2'}, 'SpaceSuit.N2Inlet');
            
            % Adding pipes to connect the components
            components.pipe(this, 'Pipe_1', this.fPipeLength, this.fPipeDiameter);
            components.pipe(this, 'Pipe_2', this.fPipeLength, this.fPipeDiameter);
            
            % Creating flow branches to connect to the RCA
            matter.branch(this, 'RCA_In', {'Pipe_1'}, 'SpaceSuit.Out');
            matter.branch(this, 'RCA_Out', {'Pipe_2'}, 'SpaceSuit.In');
            
            % Setting the in and out flow for the RCA
            this.toChildren.RCA.setInterfaces('RCA_In', 'RCA_Out');
            
            % Setting the flow rate
            %this.toChildren.RCA.fFlowRate = 6.834e-4;      
        end
        
        function createSolverStructure(this)
            
            createSolverStructure@vsys(this);
            
            this.toManualBranches.H2O = solver.matter.manual.branch(this.toBranches.H2OStore__H2OPort___SpaceSuit__H2OInlet);
            this.toManualBranches.N2  = solver.matter.manual.branch(this.toBranches.N2Store__N2Port___SpaceSuit__N2Inlet);
            this.toManualBranches.CO2 = solver.matter.manual.branch(this.toBranches.CO2Store__CO2Port___SpaceSuit__CO2Inlet);
            
            % Setting the flow rates (simulating the metabolic rates)
            % TEST 1: 2.295e-5 H2O; 2.583e-5 CO2; 6.834e-4 N2 FlowRate
            % TEST 2: 2.37e-5  H2O; 3.23e-5  CO2; 9.112e-4 N2 FlowRate;
            
            % CO2 injection rate
            this.toManualBranches.CO2.setFlowRate(2.583e-5);                 
            % N2 injection rate
            this.toManualBranches.N2.setFlowRate(0);
            % H2O injection rate
            this.toManualBranches.H2O.setFlowRate(0);
            
            this.setThermalSolvers();
        end
        
    end
    
    
    
    methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
        end
        
        
    end
end

