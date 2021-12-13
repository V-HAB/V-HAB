classdef Example < vsys
    %EXAMPLE Simulation demonstrating stationary P2P processors in V-HAB 2
    %   Creates two tanks, one with ~two bars of pressure, one with ~one
    %   bar and a filter in between. The tanks are connected to the filter
    %   with pipes of 50 cm length and 5 mm diameter.
    %   The filter removes CO2, and H2O based on the material used in the
    %   filter and the corresponding calculation from the matter table.

    properties
    end
    
    methods
        function this = Example(oParent, sName)
            this@vsys(oParent, sName, 10);
            
            eval(this.oRoot.oCfgParams.configCode(this));
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            matter.store(this, 'Atmos', 10);
            oAir = this.toStores.Atmos.createPhase(   'gas',      	'Air',          10,     struct('N2', 8e4, 'O2', 2e4, 'CO2', 500),       293,    0.5);
            
            fFilterVolume = 1;
            matter.store(this, 'Filter', fFilterVolume);
            
            oFiltered = matter.phases.mixture(this.toStores.Filter, 'FilteredPhase', 'solid', struct('Zeolite13x', 1), 293, 1e5);
            
            oFlow = this.toStores.Filter.createPhase(	'gas',   	'FlowPhase',	fFilterVolume - oFiltered.fVolume,   struct('N2', 8e4, 'O2', 2e4, 'CO2', 500),       293,	0.5);
            
            % Creating the p2p processor.  The filepath
            % "tutorials.p2p.stationary.components.AbsorberExample" depends
            % on the location of the class file for the p2p we want to add.
            % The inputs depend on the definition of the respecitve p2p
            % class. Please open the p2p file of this tutorial to find
            % additional information with regard to manipulators.
            %
            % A stationary p2p means it is fixed for one time step within
            % V-HAB and usually does not change its flowrate multiple times
            % within a single time step. However, over multiple time steps,
            % it is indeed variable and dynamic. The difference to the flow
            % P2Ps is, that flow P2Ps are called by the matter multibranch
            % solver to ensure the correct P2P flowrates are used on flow
            % phases (for highly dynamic processes at small volumes). The
            % stationary P2P is best suited to slower processes which do
            % not change significantly in a short amount of time.
            tutorials.p2p.stationary.components.AbsorberExample(this.toStores.Filter, 'filterproc', oFlow, oFiltered);
            
            components.matter.fan(this, 'Fan', 40000, true);
            
            components.matter.pipe(this, 'Pipe_1', 0.5, 0.005);
            components.matter.pipe(this, 'Pipe_2', 0.5, 0.005);
            components.matter.pipe(this, 'Pipe_3', 0.5, 0.005);
            
            matter.branch(this, oAir,	{ 'Pipe_1', 'Fan', 'Pipe_2' },  oFlow);
            matter.branch(this, oFlow,  { 'Pipe_3' },                   oAir);
        end
        
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            solver.matter.interval.branch(this.aoBranches(1));
            solver.matter.interval.branch(this.aoBranches(2));

            this.setThermalSolvers();
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
        end
     end
end