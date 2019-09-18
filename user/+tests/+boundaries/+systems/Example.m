classdef Example < vsys
    %EXAMPLE Example simulation for a simple flow in V-HAB 2.0
    %   Two tanks filled with gas at different temperatures and pressures
    %   with a pipe in between
    
    properties
        bSetNewBoundary = false;
    end
    
    methods
        function this = Example(oParent, sName)
            % Calling the parent constructor. This has to be done for any
            % class that has a parent. The third parameter defines how
            % often the .exec() method of this subsystem is called. 
            % Values can be: 0-inf for interval in [s] (zero means with
            % lowest time step set for the timer). -1 means with every TICK
            % of the timer, which is determined by the smallest time step
            % of any of the systems. Providing a logical 'false' means the
            % .exec() method is called when the oParent.exec() is executed
            % (see this .exec() method - always call exec@vsys as well!).
            this@vsys(oParent, sName, 30);
            
        end
        
        
        function createMatterStructure(this)
            % This function creates all simulation objects in the matter
            % domain. 
            
            % First we always need to call the createMatterStructure()
            % method of the parent class.
            createMatterStructure@vsys(this);
            
            % Creating a store with an infinite volume since we want it to
            % be a boundary
            matter.store(this, 'Tank_1', Inf);
            
            % Adding a phase to the store 'Tank_1' with air at 20 deg C. We
            % are also passing in a volume of 1 m^3, but that is only for
            % the matter table to be able to correctly calculate the
            % properties of the phase. The actual phase volume will be Inf.
            oGasPhase = this.toStores.Tank_1.createPhase('air', 'boundary', 1, 293.15);
            
            % Creating a second store, again with infinite volume
            matter.store(this, 'Tank_2', Inf);
            
            % Adding a phase to the store 'Tank_2', air at 50 deg C and 
            % 200 kPA.
            oAirPhase = this.toStores.Tank_2.createPhase('air', 'boundary', 1, 323.15, 2e5);
            
            % Adding a pipe to connect the tanks, 1.5 m long, 5 mm in
            % diameter. The pipe is in the components library and is
            % derived from the flow-to-flow (f2f) processor class
            components.matter.pipe(this, 'Pipe', 1.5, 0.005);
            
            % Creating the flowpath, called a branch in V-HAB, between the
            % components. 
            % The input parameter format is always:
            % system object, phase object, {name(s) of f2f-processor(s)}, phase object
            matter.branch(this, oGasPhase, {'Pipe'}, oAirPhase, 'Branch');
            
            
            % Creating a store, volume 100 m^3
            matter.store(this, 'InletTank', 100);
            
            % Adding a phase to the store
            oInletPhase = this.toStores.InletTank.createPhase('water', 'boundary', 100, 288.15);
            
            % Creating a second store, volume 100 m^3
            matter.store(this, 'OutletTank', 100);
            
            % Adding a phase to the store
            oOutletPhase = this.toStores.OutletTank.createPhase('water', 'boundary', 100, 293.15);
            
            % Adding another pipe
            components.matter.pipe(this, 'Pipe2', 1.5, 0.005);
            
            % And another branch
            matter.branch(this, oInletPhase, {'Pipe2'}, oOutletPhase, 'WaterBranch');
        end
        
        
        function createThermalStructure(this)
            % This function creates all simulation objects in the thermal
            % domain. 
            
            % First we always need to call the createThermalStructure()
            % method of the parent class.
            createThermalStructure@vsys(this);
            
            % We need to do nothing else here for this simple model. All
            % thermal domain objects related to advective (mass-based) heat
            % transfer will automatically be created by the
            % setThermalSolvers() method. 
            % Here one would create simulation objects for radiative and
            % conductive heat transfer.
            
        end
        
        
        function createSolverStructure(this)
            % This function creates all of the solver objects required for
            % a simulation. 
            
            % First we always need to call the createSolverStructure()
            % method of the parent class.
            createSolverStructure@vsys(this);
            
            % Creating an interval solver object that will solve for the
            % flow rate of the one branch in this system.
            solver.matter.interval.branch(this.toBranches.Branch);
            
            % Creating a manual solver object and setting the flow rate
            oBranch = solver.matter.manual.branch(this.toBranches.WaterBranch);
            oBranch.setFlowRate(0.002);

            % Since we want V-HAB to calculate the temperature changes in
            % this system we call the setThermalSolvers() method of the
            % thermal.container class. 
            this.setThermalSolvers();
            
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            % exec(ute) function for this system 
            % This function can be used to change the system state, e.g.
            % close valves or switch on/off components.
            
            % Here it only calls its parent's exec() method
            exec@vsys(this);
            
            if this.oTimer.fTime > 600 && ~this.bSetNewBoundary
                
                tProperties.fPressure = 2e5;
                afMass = zeros(1,this.oMT.iSubstances);
                afMass(this.oMT.tiN2I.N2) = 1;
                tProperties.afMass = afMass;
                
                this.toStores.Tank_1.aoPhases(1).setBoundaryProperties(tProperties);
                tProperties.fPressure = 1e5;
                this.toStores.Tank_2.aoPhases(1).setBoundaryProperties(tProperties);
                
                this.bSetNewBoundary = true;
            end
        end
        
     end
    
end

