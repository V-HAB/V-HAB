classdef Example2 < vsys
    %EXAMPLE2 Example simulation demonstrating P2P processors in V-HAB 2.0
    %   Creates two tanks, one with ~two bars of pressure, one completely
    %   empty tank. A filter is created. The tanks are connected to the filter with
    %   pipes of 50cm length and 5mm diameter.
    %   The filter only filters O2 (oxygen) up to a certain capacity.
    
    properties
    end
    
    methods
        function this = Example2(oParent, sName)
            this@vsys(oParent, sName, 60);
            
            % Creating a store, volume 10m^3
            matter.store(this, 'Atmos', 10);
            
            % Creating normal air (standard atmosphere) for 20m^3. Will
            % have 2 bar of pressure because the store is actually smaller.
            oAir = this.toStores.Atmos.createPhase('air', 20);
            
            % Adding a default extract/merge processors to the phase
            matter.procs.exmes.gas(oAir, 'Out');
            
            % Creating a second store 
            matter.store(this, 'Atmos2', 10);
            
            % Better usage of air helper than above - provide the correct
            % volume, then empty values for temperature and humidity (so
            % the defaults are used) and then the parameter for the
            % pressure.
            oAir = this.toStores.Atmos2.createPhase('air', 10, [], [], 0);
            
            % Adding a default extract/merge processor to the phase
            matter.procs.exmes.gas(oAir, 'In');
            
            % Create the filter. See the according files, just an example
            % for an implementation - copy to your own directory and change
            % as needed.
            fFilterVolume = 1;
            matter.store(this, 'Filter', fFilterVolume);
            oFlow = this.toStores.Filter.createPhase('air', 'FlowPhase', fFilterVolume/ 2, 293.15);
            
            oFiltered = matter.phases.gas(this.toStores.Filter, ...
                          'FilteredPhase', ... Phase name
                          struct(), ... Phase contents
                          fFilterVolume / 2, ... Phase volume
                          293.15); % Phase temperature 
            
            % Create the according exmes - default for the external
            % connections, i.e. the air stream that should be filtered. The
            % filterports are internal ones for the p2p processor to use.
            matter.procs.exmes.gas(oFlow,       'In');
            matter.procs.exmes.gas(oFlow,       'In_P2P');
            matter.procs.exmes.gas(oFiltered,  	'Out');
            matter.procs.exmes.gas(oFiltered,  	'Out_P2P');
            
            % Creating the p2p processor
            % Input parameters: name, flow phase name, absorber phase name, 
            % species to be filtered, filter capacity
            fSubstance = 'O2';
            fCapacity = 0.1;
            tutorials.p2p.components.AbsorberExample(this.toStores.Filter, 'filterproc', 'FlowPhase.In_P2P', 'FilteredPhase.Out_P2P', fSubstance, fCapacity);
            
            % Adding pipes to connect the components
            components.pipe(this, 'Pipe_1', 0.5, 0.01);
            components.pipe(this, 'Pipe_2', 0.5, 0.01);
            
            % Creating the flowpath between the components
            matter.branch(this, 'Atmos.Out',  { 'Pipe_1' }, 'Filter.In');
            matter.branch(this, 'Filter.Out', { 'Pipe_2' }, 'Atmos2.In');
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            % In the create solver structure function the solver for the
            % different branches can be assigned. In this case we will use
            % the iterative solver. 
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

