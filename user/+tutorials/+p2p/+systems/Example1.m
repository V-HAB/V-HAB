classdef Example1 < vsys
    %EXAMPLE1 Example simulation demonstrating P2P processors in V-HAB 2.0
    %   Creates one tank, one with ~two bars of pressure, one completely
    %   empty tank. A filter is created. The tanks are connected to the 
    %   filter with pipes of 50cm length and 5mm diameter.
    %   The filter only filters O2 (oxygen) up to a certain capacity. 
    
    properties
    end
    
    methods
        function this = Example1(oParent, sName)
            this@vsys(oParent, sName, 60);
           
            % Creating a store, volume 10m^3
            this.addStore(matter.store(this.oData.oMT, 'Atmos', 10));
            
            % Creating a phase using the 'air' helper
            oAir = this.toStores.Atmos.createPhase('air', 10);
            
            % Adding a extract/merge processor to the phase
            matter.procs.exmes.gas(oAir, 'Out');
            matter.procs.exmes.gas(oAir, 'In');
            
            % Creating the filter, last parameter is the filter capacity in
            % kg.
            this.addStore(tutorials.p2p.components.Filter(this.oData.oMT, 'Filter', 0.5));
            
            % Adding a fan
            this.addProcF2F(components.fan(this.oData.oMT, 'Fan', 'setSpeed', 40000, 'Left2Right'));
            
            % Adding pipes to connect the components
            this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_1', 0.5, 0.005));
            this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_2', 0.5, 0.005));
            this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_3', 0.5, 0.005));
            
            % Creating the flowpath (=branch) between the components
            % Since we are using default exme-processors here, the input
            % format can be 'store.phase' instead of 'store.exme'
            this.createBranch('Atmos.Out', { 'Pipe_1', 'Fan', 'Pipe_2' }, 'Filter.In');
            this.createBranch('Filter.Out', {'Pipe_3' }, 'Atmos.In');
            
            % Seal - means no more additions of stores etc can be done to
            % this system.
            this.seal();
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
            
        end
        
     end
    
end

