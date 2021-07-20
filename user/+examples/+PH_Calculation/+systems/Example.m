classdef Example < vsys
    %EXAMPLE Example simulation for a simple flow in V-HAB 2.0
    %   Two tanks filled with gas at different temperatures and pressures
    %   with a pipe in between
    
    properties
        % This system does not have any properties
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
            
            % Creating a store, volume 1 m^3
            matter.store(this, 'Tank_1', 10);
            
            fMolH3PO4 = 10;
            
            % Adding a phase to the store 'Tank_1', 1 m^3 air at 20 deg C
            oTank1 = matter.phases.liquid(this.toStores.Tank_1, 'Water', struct('H2O', 998 , 'H3PO4', fMolH3PO4 * this.oMT.afMolarMass(this.oMT.tiN2I.H3PO4)), 293, 1e5);
            
            components.matter.pH_Module.stationaryManip('GrowthMediumChanges_Manip', oTank1);
            
            
            matter.store(this, 'Tank_2', 1000);
            
            fMolNaOH        = 8 * fMolH3PO4;
%             fMassNaplus     = fMolNaOH * this.oMT.afMolarMass(this.oMT.tiN2I.Naplus);
%             fMassOHMinus    = fMolNaOH * this.oMT.afMolarMass(this.oMT.tiN2I.OH);
            fMassNaOH       = fMolNaOH * this.oMT.afMolarMass(this.oMT.tiN2I.NaOH);
            
%             oTank2 = matter.phases.liquid(this.toStores.Tank_2, 'Water', struct('H2O', 1994 , 'Naplus', fMassNaplus, 'OH', fMassOHMinus), 293, 1e5);
            
            oTank2 = this.toStores.Tank_2.createPhase(  'liquid', 'boundary',   'Water',   this.toStores.Tank_2.fVolume, struct('H2O', 1994/(1994 + fMassNaOH) , 'NaOH', fMassNaOH/(1994 + fMassNaOH)),          293,          1e5);
           
            % Adding a pipe to connect the tanks, 1.5 m long, 5 mm in
            % diameter. The pipe is in the components library and is
            % derived from the flow-to-flow (f2f) processor class
            components.matter.pipe(this, 'Pipe', 1.5, 0.005);
            
            % Creating the flowpath, called a branch in V-HAB, between the
            % components. 
            % The input parameter format is always:
            % system object, phase object, {name(s) of f2f-processor(s)}, phase object
            matter.branch(this, oTank2, {'Pipe'}, oTank1, 'Branch');
            
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
            tTimeStepProperties.arMaxChange = ones(1,this.oMT.iSubstances) .* 0.01;
            tTimeStepProperties.rMaxChange  = 0.005;
            this.toStores.Tank_1.toPhases.Water.setTimeStepProperties(tTimeStepProperties);
            
            % Creating an manual solver object that will solve for the
            % flow rate of the one branch in this system.
            solver.matter.manual.branch(this.toBranches.Branch);
            
            this.toBranches.Branch.oHandler.setFlowRate(0.1);

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
        end
        
     end
    
end

