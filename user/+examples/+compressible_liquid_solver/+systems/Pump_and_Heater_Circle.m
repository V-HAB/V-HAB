classdef Pump_and_Heater_Circle < vsys
    %Example simulation for liquid flow problems V-HAB 2.0
    %This example contains a continous flow between two tanks driven by a
    %pump.Additionally a heater increasing the temperature of the fluid in
    %the first branch is implemented.
    
    properties
        
    end
    
    methods
        function this = Pump_and_Heater_Circle(oParent, sName)
            % Call parent constructor. Third parameter defined how often
            % the .exec() method of this subsystem is called. This can be
            % used to change the system state, e.g. close valves or switch
            % on/off components.
            % Values can be: 0-inf for interval in [s] (zero means with
            % lowest time step set for the timer). -1 means with every TICK
            % of the timer, which is determined by the smallest time step
            % of any of the systems. Providing a logical false (def) means
            % the .exec method is called when the oParent.exec() is
            % executed (see this .exec() method - always call exec@vsys as
            % well!).
            this@vsys(oParent, sName, 60);
            % Make the system configurable
%             disp(this);
%             disp('------------');
%             disp(this.oRoot.oCfgParams.configCode(this));
%             disp('------------');
%             disp(this.oRoot.oCfgParams.get(this));
%             disp('------------');
            eval(this.oRoot.oCfgParams.configCode(this));
            
            %disp(this);
            
            
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            % Creating a store
            matter.store(this, 'Tank_1', 0.01, 0);
            
            % Creating a second store
            matter.store(this, 'Tank_2', 0.01, 0);
            
            % Adding phases to the store 'Tank_1'
            oWaterPhase1 = this.toStores.Tank_1.createPhase('water', 0.005, 293, 3*10^5);

            tTimeStepProperties.rMaxChange = 0.000001;
            oWaterPhase1.setTimeStepProperties(tTimeStepProperties);
            
            % Adding phases to the store 'Tank_2'
            oWaterPhase2 = this.toStores.Tank_2.createPhase('water', 0.005, 293, 3*10^5);
            
            oWaterPhase2.setTimeStepProperties(tTimeStepProperties);
            
            % Adding extract/merge processors to the phases
            matter.procs.exmes.liquid(oWaterPhase1, 'Port_1' );
            matter.procs.exmes.liquid(oWaterPhase2, 'Port_2');
            matter.procs.exmes.liquid(oWaterPhase2, 'Port_3');
            matter.procs.exmes.liquid(oWaterPhase1, 'Port_4');
            
            % Adding a pump
            tutorials.compressible_liquid_solver.components.fan(this, 'Fan', 0.5*10^5);
            
            % Adding a heater
         	tutorials.compressible_liquid_solver.components.heater(this, 'Heater', 313, 0.01, 0.25, 0.2*10^-3);
            
            % Adding pipes to connect the components
            components.matter.pipe(this, 'Pipe_1', 0.5, 0.01, 0.2*10^-3);
            components.matter.pipe(this, 'Pipe_2', 0.5, 0.01, 0.2*10^-3);
            components.matter.pipe(this, 'Pipe_3', 0.5, 0.01, 0.2*10^-3);
            components.matter.pipe(this, 'Pipe_4',   1, 0.01, 0.2*10^-3);
            
            % Creating the flow branches
            matter.branch(this, 'Tank_1.Port_1', {'Pipe_1', 'Fan', 'Pipe_2', 'Heater', 'Pipe_3',}, 'Tank_2.Port_2');
            matter.branch(this, 'Tank_2.Port_3', {'Pipe_4'}, 'Tank_1.Port_4');%             %for branch liquid the second entry is the number of cells used

        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            %to calculate the branches
            %branch_liquid(oBranch, iCells, fPressureResidual, fMassFlowResidual, fCourantNumber, sCourantAdaption)
            sCourantAdaption = struct( 'bAdaption', 0,'fIncreaseFactor', 1.005, 'iTicksBetweenIncrease', 50, 'iInitialTicks', 1000, 'fMaxCourantNumber', 1);
            solver.matter.fdm_liquid.branch_liquid(this.aoBranches(1), 4, 0, 0, 0.1, sCourantAdaption);
            solver.matter.fdm_liquid.branch_liquid(this.aoBranches(2), 3, 0, 0, 1, sCourantAdaption);
            
            this.setThermalSolvers();
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
        end
        
     end
    
end

