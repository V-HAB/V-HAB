classdef Example < vsys
    %EXAMPLE simulation demonstrating flow P2P processors in V-HAB 2
    % 
    %   Creates two tanks, one with ~two bars of pressure, one with ~one
    %   bar and a filter in between. The tanks are connected to the filter
    %   with pipes of 50cm length and 5mm diameter.
    %   The filter removes CO2, and H2O based on the material used in the
    %   filter and the corresponding calculation from the matter table.
    
    properties
    end
    
    methods
        function this = Example(oParent, sName)
            this@vsys(oParent, sName, 60);
            
            matter.store(this, 'Atmos', 10, false);
            oAir1 = this.toStores.Atmos.createPhase('gas', 'Air', 10, struct('N2', 1.6e5, 'O2', 4e4, 'CO2', 1000), 303, 0.5);
            
            matter.store(this, 'Atmos2', 10);
            oAir2 = this.toStores.Atmos2.createPhase('gas', 'Air', 10, struct('N2', 8e4, 'O2', 2e4, 'CO2', 500), 293, 0.5);
            
            fFilterVolume = 1;
            matter.store(this, 'Filter', fFilterVolume);
            oFlow = this.toStores.Filter.createPhase('gas', 'flow',	'FlowPhase', 1e-6, struct('N2', 8e4, 'O2', 2e4, 'CO2', 500), 293,	0.5);
            
            oFiltered = matter.phases.mixture(this.toStores.Filter, 'FilteredPhase', 'solid', struct('Zeolite13x', 1), 293, 1e5);
            
            % Creating the p2p processor.  The filepath
            % "tutorials.p2p.flow.components.AbsorberExampleFlow" depends
            % on the location of the class file for the p2p we want to add.
            % The inputs depend on the definition of the respecitve p2p
            % class. Please open the p2p file of this tutorial to find
            % additional information with regard to manipulators.
            %
            % a stationary p2p means it is fix for one time step within
            % V-HAB and usually does not change its flowrate multiple times
            % within a single time step. However, over multiple time steps,
            % it is indeed variable and dynamic. The difference to the flow
            % P2Ps is, that flow P2Ps are called by the matter multibranch
            % solver to ensure the correct P2P flowrates are used at flow
            % phases (for highly dynamic processes at small volumes). The
            % stationary P2P is best suited to slower processes which do
            % not change significantly in a short amount of time.
            tutorials.p2p.flow.components.AbsorberExampleFlow(this.toStores.Filter, 'filterproc', oFlow, oFiltered);
            
            components.matter.pipe(this, 'Pipe_1', 0.5, 0.01);
            components.matter.pipe(this, 'Pipe_2', 0.5, 0.01);
            
            matter.branch(this, oAir1,  { 'Pipe_1' }, oFlow);
            matter.branch(this, oFlow,  { 'Pipe_2' }, oAir2);
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            solver.matter_multibranch.iterative.branch(this.aoBranches, 'complex');
            
            this.setThermalSolvers();
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
            
        end
     end
end