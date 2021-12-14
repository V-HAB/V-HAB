classdef Example < vsys
    %EXAMPLE V-HAB system with a Bosch Reactor 
    % This system includes all required interfaces for the reactor, the
    % reactor itself is located in the library.
    
    methods
        function this = Example(oParent, sName)
            
            this@vsys(oParent, sName, 0.1);
            
            % BoschReactor
            components.matter.Bosch.BoschReactor(this, 'BoschReactor');
            
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            %storage tanks for H2 and CO2 for input and output
            matter.store(this, 'TankH2', 5);
            oInH2Phase = this.toStores.TankH2.createPhase('gas', 'boundary', 'H2', 5, struct('H2', 2e5), 293.15, 0);
            
            matter.procs.exmes.gas(oInH2Phase, 'Outlet');
            matter.procs.exmes.gas(oInH2Phase, 'Inlet');
            
            matter.store(this, 'TankCO2', 5);
            oInCO2Phase = this.toStores.TankCO2.createPhase('gas', 'boundary', 'CO2', 5, struct('CO2', 2e5), 293.15, 0); 
            
            matter.procs.exmes.gas(oInCO2Phase, 'Outlet');
            matter.procs.exmes.gas(oInCO2Phase, 'Inlet');
            
            matter.store(this, 'Condensate', 5);
            oCondensate = this.toStores.Condensate.createPhase('liquid', 'Condensate', 5, struct('H2O', 1), 293.15, 1e5); 
            matter.procs.exmes.liquid(oCondensate, 'Inlet');
            
            matter.store(this, 'Carbon', 5);
            oCarbon = this.toStores.Carbon.createPhase('solid', 'C', 5, struct('C', 1), 293.15, 1e5); 
            matter.procs.exmes.solid(oCarbon, 'Inlet');
            
            %adding branches
            matter.branch(this, 'H2_to_Bosch',    {}, 'TankH2.Outlet',    'H2_to_Bosch');
            matter.branch(this, 'CO2_to_Bosch',   {}, 'TankCO2.Outlet',   'CO2_to_Bosch');
            
            matter.branch(this, 'H2_from_Bosch',  {}, 'TankH2.Inlet',     'H2_from_Bosch');
            matter.branch(this, 'CO2_from_Bosch', {}, 'TankCO2.Inlet',    'CO2_from_Bosch');
            matter.branch(this, 'H2O_from_Bosch', {}, 'Condensate.Inlet', 'H2O_from_Bosch');
            matter.branch(this, 'C_from_Bosch',   {}, 'Carbon.Inlet',     'C_from_Bosch');
            
            this.toChildren.BoschReactor.setIfFlows('H2_to_Bosch', 'CO2_to_Bosch', 'H2O_from_Bosch', 'CO2_from_Bosch', 'H2_from_Bosch', 'C_from_Bosch')
            
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            this.setThermalSolvers();
        end
    end
    
    methods (Access = protected)
        function exec(this, ~)
            exec@vsys(this);
            fCO2FlowRate = 0.05;
            fFactor = this.oMT.afMolarMass(this.oMT.tiN2I.H2) / this.oMT.afMolarMass(this.oMT.tiN2I.CO2);
            fH2FlowRate = fFactor * fCO2FlowRate;
            
            this.toChildren.BoschReactor.toBranches.H2_Inlet.oHandler.setFlowRate(-fH2FlowRate);
            this.toChildren.BoschReactor.toBranches.CO2_Inlet.oHandler.setFlowRate(-fCO2FlowRate);
        end
    end
end